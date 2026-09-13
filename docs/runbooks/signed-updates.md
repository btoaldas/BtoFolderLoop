# Signed release updates

The updater uses Sparkle 2.9.6 (MIT with bundled component notices), fixed by `Package.resolved`. The release ZIP includes the framework, its symlinks and its license. Official references: [Sparkle setup](https://sparkle-project.org/documentation/) and [signed-feed configuration](https://sparkle-project.org/documentation/customization/).

## Maintainer key

The private Ed25519 key is held by the macOS login Keychain under account `io.github.btoaldas.BtoFolderLoop.updates`. It is never exported by the build or publication workflow. The corresponding public key is in `Resources/Info.plist`. `generate_keys --account <account> -p` reads only the public key. Key backup, transfer or rotation requires its own reviewed procedure; do not replace the key for an ordinary release or commit private material.

## Prepare without publishing

1. Finish and review changes; run Swift/Python tests and `scripts/check-public.py` with new files staged. Increase both the numeric display version and `CFBundleVersion` monotonically. Commit the reviewed source.
2. Run `bash scripts/build-app.sh`. It creates a new `dist` directory without installing over an existing app. Verify `BUILD-INFO.txt` matches that source commit, portable checksums, archive contents, embedded framework loading and `codesign --verify --deep --strict`.
3. Run `bash scripts/prepare-update.sh <new-dist-directory>`. It first checks that the Keychain public key matches the bundle. It uses a unique signing-stage directory, no delta generation and no pruning of prior archives. The generated architecture-specific appcast and ZIP signatures are validated locally. Do not edit the XML after signing.
4. Optional real updater tests: `python3 scripts/tests/test-update-integration.py`. This creates independent application identifiers in `.tmp`, serves fixtures only on loopback and invokes the production updater through XCTest. It checks installation, termination/relaunch with a new PID, preservation of a data sentinel, and rejection of altered ZIP/feed bytes. It never targets a user installation or journal. The maintainer Keychain key is used to sign synthetic data but is never exported. Fixtures and receipts remain local.

## Authorized publication

Publication and replacing an installed app require authority for that exact release. Preparation does not grant it.

1. Publish the reviewed source/tag and release ZIP, `SHA256SUMS`, `BUILD-INFO.txt` and matching signed appcast as release assets. The public URL must exactly match the generated GitHub download URL. Keep older releases available.
2. Download the public assets freshly, verify hashes/signatures, source commit and bundle version before advertising the update.
3. Copy the signed XML byte-for-byte into `updates/appcast-macos-<architecture>.xml` on the default branch and publish that separate feed change. Never publish a feed before its archive is available. Verify the public raw XML signature and bytes against the reviewed file.
4. Check the footer against the public catalog, then validate an authorized isolated installed-copy update. An API response or uploaded release alone is not proof of installation.

Only Apple Silicon is currently distributed. Build and validate Intel separately before publishing an Intel feed; never point that feed to an ARM archive. GitHub previews are included because this project's public versions are previews. The app queries the release list instead of the `/latest` endpoint that excludes previews.

## Failure and rollback

If the feed or archive is missing, incompatible or incorrectly signed, the old application remains and the UI reports the failure. Do not bypass verification. Avoid withdrawing or replacing a public asset silently; correct the issue in a higher reviewed version. Feed withdrawal and installed rollback require a specific decision. An application rollback does not undo SQLite migration or restore a historical backup safely; preserve later journals and review compatibility separately.

The first move from public 0.2.0 to an updater-enabled version is a manual installation. Update signatures do not replace Apple Developer ID/notarization. No production feed is published by the local preparation script.
