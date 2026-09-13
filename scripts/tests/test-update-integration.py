#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise the real production updater against signed, disposable app fixtures.

Never targets an installed user app or its data. Requires the maintainer's signing
key in Keychain. Keeps fixtures/evidence. HTTP is loopback-only for this test;
the production release client and appcast both use HTTPS.
"""
import functools
import hashlib
import http.server
import json
import os
from pathlib import Path
import plistlib
import subprocess
import threading
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / ".build/artifacts/sparkle/Sparkle/bin"
ACCOUNT = "io.github.btoaldas.BtoFolderLoop.updates"


def run(*args, **kwargs):
    return subprocess.run([str(a) for a in args], check=True, cwd=ROOT, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, **kwargs).stdout


def main():
    with (ROOT / "Resources/Info.plist").open("rb") as source:
        public_key = plistlib.load(source)["SUPublicEDKey"]
    assert run(TOOLS / "generate_keys", "--account", ACCOUNT, "-p").strip() == public_key
    for case in ("valid", "valid-running", "bad-archive", "bad-feed"):
        fixture = ROOT / ".tmp" / ("update-integration-" + str(uuid.uuid4()))
        web = fixture / "web"
        web.mkdir(parents=True)
        handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(web))
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            prefix = f"http://127.0.0.1:{server.server_port}/"
            bundle_id = "io.github.btoaldas.BtoFolderLoop.UpdaterFixture." + uuid.uuid4().hex
            source = fixture / "main.m"
            source.write_text('''#import <AppKit/AppKit.h>
#include <unistd.h>
int main(void) { @autoreleasepool {
    NSApplication *app = [NSApplication sharedApplication];
    [app setActivationPolicy:NSApplicationActivationPolicyProhibited];
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *marker = [@''' + json.dumps(str(fixture)) + ''' stringByAppendingPathComponent:[version stringByAppendingString:@".pid"]];
    [[NSString stringWithFormat:@"%d", getpid()] writeToFile:marker atomically:YES encoding:NSUTF8StringEncoding error:nil];
    if ([version isEqualToString:@"0.3.0"]) { [app run]; }
    return 0;
} }
''')
            for location, version, build in (("installed", "0.3.0", "3"), ("new", "0.4.0", "4")):
                app = fixture / location / "UpdateFixture.app"
                (app / "Contents/MacOS").mkdir(parents=True)
                run("clang", source, "-framework", "AppKit", "-o", app / "Contents/MacOS/UpdateFixture")
                info = dict(CFBundleIdentifier=bundle_id, CFBundleName="UpdateFixture", CFBundleExecutable="UpdateFixture",
                            CFBundlePackageType="APPL", CFBundleVersion=build, CFBundleShortVersionString=version,
                            LSMinimumSystemVersion="14.0", LSUIElement=True, SUFeedURL=prefix + "appcast.xml", SUPublicEDKey=public_key,
                            SUEnableAutomaticChecks=False, SUAutomaticallyUpdate=False, SUAllowsAutomaticUpdates=False,
                            SUEnableSystemProfiling=False, SUVerifyUpdateBeforeExtraction=True,
                            SURequireSignedFeed=True, SUSignedFeedFailureExpirationInterval=0)
                with (app / "Contents/Info.plist").open("wb") as target:
                    plistlib.dump(info, target)
                run("codesign", "--sign", "-", app)
            # Independent data sentinel: updater must not change it.
            sentinel = fixture / "user-data.txt"
            sentinel.write_text("Synthetic history and settings must remain unchanged.\n")
            expected = hashlib.sha256(sentinel.read_bytes()).hexdigest()
            archive = web / "UpdateFixture.zip"
            run("ditto", "-c", "-k", "--keepParent", fixture / "new/UpdateFixture.app", archive)
            run(TOOLS / "generate_appcast", "--account", ACCOUNT, "--maximum-deltas", "0", "--maximum-versions", "0",
                "--download-url-prefix", prefix, "-o", web / "appcast.xml", web)
            run(TOOLS / "sign_update", "--account", ACCOUNT, "--verify", web / "appcast.xml")
            if case == "bad-archive":
                with archive.open("ab") as target:
                    target.write(b"tampered-synthetic-archive")
            if case == "bad-feed":
                feed = web / "appcast.xml"
                feed.write_bytes(feed.read_bytes().replace(b"UpdateFixture", b"AlteredFixture", 1))
            (fixture / "archive-url.txt").write_text(prefix + archive.name)
            if case == "valid-running":
                run("open", "-g", "-n", fixture / "installed/UpdateFixture.app")
                for _ in range(100):
                    if (fixture / "0.3.0.pid").exists():
                        break
                    time.sleep(0.1)
                assert (fixture / "0.3.0.pid").exists(), "Synthetic old app did not start"
            env = dict(os.environ, BTOFOLDERLOOP_UPDATE_FIXTURE=str(fixture),
                       BTOFOLDERLOOP_UPDATE_EXPECT_REJECTION="0" if case.startswith("valid") else "1")
            result = subprocess.run(["swift", "test", "--jobs", "2", "--filter", "ReleaseUpdateTests/testSignedFixtureUpdateE2E"],
                                    cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
            (fixture / "test.log").write_text(result.stdout)
            print(f"{case}: exit={result.returncode}; evidence={fixture}", flush=True)
            print(result.stdout[-6000:], flush=True)
            assert result.returncode == 0, f"Failed fixture {case}"
            assert hashlib.sha256(sentinel.read_bytes()).hexdigest() == expected
            with (fixture / "installed/UpdateFixture.app/Contents/Info.plist").open("rb") as target:
                assert plistlib.load(target)["CFBundleShortVersionString"] == ("0.4.0" if case.startswith("valid") else "0.3.0")
            if case == "valid-running":
                for _ in range(100):
                    if (fixture / "0.4.0.pid").exists():
                        break
                    time.sleep(0.1)
                assert (fixture / "0.4.0.pid").exists(), "New app was not relaunched"
                assert (fixture / "0.3.0.pid").read_text() != (fixture / "0.4.0.pid").read_text()
                print("Old fixture terminated and new fixture relaunched with a new PID.", flush=True)
        finally:
            server.shutdown()
            server.server_close()
    print("Signed update installed; altered archive and altered feed rejected; data sentinels preserved.")


if __name__ == "__main__":
    main()
