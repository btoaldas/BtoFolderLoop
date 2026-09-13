// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
import Foundation
import AppKit
import SwiftUI
import Sparkle
import BtoFolderLoopCore
import BtoFolderLoopStorage
@testable import BtoFolderLoopApp

private struct StubReleaseClient: ReleaseChecking {
    let result: ReleaseOffer?
    var fail = false
    func latest(architecture: String) async throws -> ReleaseOffer? {
        if fail { throw URLError(.notConnectedToInternet) }; return result
    }
}

private actor FailingRefreshClient: ReleaseChecking {
    let offer: ReleaseOffer
    var first = true
    init(offer: ReleaseOffer) { self.offer = offer }
    func latest(architecture: String) async throws -> ReleaseOffer? {
        if first { first = false; return offer }
        throw URLError(.notConnectedToInternet)
    }
}

final class ReleaseUpdateTests: XCTestCase {
    func offer(_ version: String = "0.4.0") -> ReleaseOffer {
        let version = ReleaseVersion(version)!
        return .init(version: version, archiveURL: URL(string: "https://github.com/btoaldas/BtoFolderLoop/releases/download/v\(version)/BtoFolderLoop-\(version)-macos-arm64.zip")!,
                     pageURL: URL(string: "https://github.com/btoaldas/BtoFolderLoop/releases/tag/v\(version)")!, preview: true)
    }
    func testNumericVersionsRejectMalformedTagsAndOrderCorrectly() {
        XCTAssertLessThan(ReleaseVersion("0.9.0")!, ReleaseVersion("v0.10.0")!)
        XCTAssertEqual(ReleaseVersion("v0.3.0"), ReleaseVersion("0.3.0"))
        for value in ["", "0.3", "0.3.0.1", "0.3.-1", "0.03.0", "0.3.0-beta", "０.3.0", "v0.3.0/other", "999999999999999999999.0.0"] { XCTAssertNil(ReleaseVersion(value)) }
    }
    func testPublishedPreviewsAreFoundAndDraftsWrongOriginsAndArchitecturesAreIgnored() throws {
        func entry(_ version: String, draft: Bool = false, arch: String = "arm64", host: String = "github.com") -> [String: Any] {
            ["tag_name": "v" + version, "draft": draft, "prerelease": true, "assets": [["name":"BtoFolderLoop-\(version)-macos-\(arch).zip", "browser_download_url":"https://\(host)/btoaldas/BtoFolderLoop/releases/download/v\(version)/BtoFolderLoop-\(version)-macos-\(arch).zip"]]]
        }
        let data = try JSONSerialization.data(withJSONObject: [entry("0.10.0"),entry("0.9.0"),entry("0.11.0",draft:true),entry("0.12.0",arch:"x86_64"),entry("0.13.0",host:"invalid.example")])
        XCTAssertEqual(try ReleaseCatalog.latestCompatible(in: data, architecture: "arm64")?.version, ReleaseVersion("0.10.0"))
        XCTAssertEqual(try ReleaseCatalog.latestCompatible(in: data, architecture: "x86_64")?.version, ReleaseVersion("0.12.0"))
        XCTAssertThrowsError(try ReleaseCatalog.latestCompatible(in: data, architecture: "unknown"))
        XCTAssertThrowsError(try ReleaseCatalog.latestCompatible(in: Data("error".utf8), architecture: "arm64"))
    }
    @MainActor func testNoDowngradeAndBusyGuardBeforeStartingSparkle() async {
        var busy = false, activity: [Bool] = []
        let same = ReleaseUpdater(version: "0.3.0", client: StubReleaseClient(result: offer("0.3.0")), workIsBusy: { busy }, activityChanged: { activity.append($0) })
        await same.check(); XCTAssertFalse(same.canInstall); same.install(); XCTAssertNil(same.sparkle)
        let older = ReleaseUpdater(version: "0.3.0", client: StubReleaseClient(result: offer("0.2.0")), workIsBusy: { busy }, activityChanged: { activity.append($0) })
        await older.check(); XCTAssertFalse(older.canInstall); XCTAssertTrue(older.message.contains("más nueva"))
        let newer = ReleaseUpdater(version: "0.3.0", client: StubReleaseClient(result: offer()), workIsBusy: { busy }, activityChanged: { activity.append($0) })
        await newer.check(); XCTAssertTrue(newer.canInstall)
        busy = true; newer.install(); XCTAssertFalse(newer.installing); XCTAssertNil(newer.sparkle); XCTAssertTrue(activity.isEmpty)
    }
    @MainActor func testBusyGuardAtReadyToInstallCancelsWithoutRelaunch() async {
        var activity: [Bool] = []
        let updater = ReleaseUpdater(version: "0.3.0", client: StubReleaseClient(result: offer()), workIsBusy: { true }, activityChanged: { activity.append($0) })
        updater.installAuthorized = true; updater.setInstalling(true)
        var choice: SPUUserUpdateChoice?
        updater.showReady(toInstallAndRelaunch: { choice = $0 })
        XCTAssertEqual(choice, .skip); XCTAssertFalse(updater.committedToRelaunch)
        XCTAssertEqual(activity, [true,false])
    }
    @MainActor func testSingleApprovalCoversInstallAndRelaunchAndInterlockPersists() async {
        var activity: [Bool] = []
        let updater = ReleaseUpdater(version: "0.3.0", client: StubReleaseClient(result: offer()), workIsBusy: { false }, activityChanged: { activity.append($0) })
        updater.installAuthorized = true; updater.setInstalling(true)
        var choice: SPUUserUpdateChoice?
        updater.showReady(toInstallAndRelaunch: { choice = $0 })
        XCTAssertEqual(choice, .install); XCTAssertTrue(updater.committedToRelaunch)
        updater.dismissUpdateInstallation(); XCTAssertTrue(updater.installing)
        XCTAssertEqual(activity, [true])
    }
    @MainActor func testOfflineErrorAndCancellationReleaseInterlock() async {
        var records: [DiagnosticCode] = []
        let updater = ReleaseUpdater(version: "0.3.0", client: StubReleaseClient(result: nil, fail: true), workIsBusy: { false }, activityChanged: { _ in }, record: { records.append($0) })
        await updater.check(); XCTAssertFalse(updater.checking); XCTAssertFalse(updater.canInstall); XCTAssertNotNil(updater.errorMessage)
        var cancelled = false
        updater.setInstalling(true); updater.cancelDownload = { cancelled = true }; updater.cancel()
        XCTAssertTrue(cancelled); XCTAssertFalse(updater.installing); XCTAssertFalse(updater.installAuthorized)
        XCTAssertEqual(records, [.updateCheckStarted, .updateCheckFailed, .updateCancelled])
    }
    @MainActor func testFailedRefreshClearsObsoleteOfferAndAllowsRetry() async {
        let updater = ReleaseUpdater(version: "0.3.0", client: FailingRefreshClient(offer: offer()), workIsBusy: { false }, activityChanged: { _ in })
        await updater.check(); XCTAssertTrue(updater.canInstall)
        await updater.check(); XCTAssertNil(updater.offer); XCTAssertFalse(updater.canInstall)
        XCTAssertFalse(updater.checking); XCTAssertNotNil(updater.errorMessage)
        updater.install(); XCTAssertNil(updater.sparkle)
    }
    @MainActor func testApplicationCannotStartWorkOrMaintenanceWhileUpdating() async throws {
        let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".tmp/update-interlock-" + UUID().uuidString)
        let model = AppModel(storageDirectory: directory)
        model.updating = true; model.lastMaintenance = .distantPast
        model.select(directory); model.analyze(); model.changeMode(.cascade); model.openSettings(); model.maintainIfIdle()
        XCTAssertNil(model.root); XCTAssertFalse(model.busy); XCTAssertEqual(model.mode, .singlePass)
        XCTAssertFalse(model.showSettings); XCTAssertEqual(model.lastMaintenance, .distantPast)
        XCTAssertEqual(try model.store?.recentRuns().count, 0)
    }
    func testLiveReleaseCatalogReadOnly() async throws {
        guard ProcessInfo.processInfo.environment["BTOFOLDERLOOP_LIVE_RELEASE_TEST"] == "1" else { throw XCTSkip("Optional public read-only GitHub check") }
        let offer = try await GitHubReleaseClient().latest(architecture: "arm64")
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(offer).version, ReleaseVersion("0.2.0")!)
        print("LATEST_PUBLIC_RELEASE=" + (offer?.version.description ?? "none"))
    }

    @MainActor func testSignedFixtureUpdateE2E() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let root = env["BTOFOLDERLOOP_UPDATE_FIXTURE"] else { throw XCTSkip("Run scripts/tests/test-update-integration.py; synthetic apps only") }
        let directory = URL(fileURLWithPath: root).standardizedFileURL
        let allowed = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".tmp/update-integration-").path
        guard directory.path.hasPrefix(allowed) else { XCTFail("Fixture must be inside the project's synthetic .tmp tree"); return }
        _ = NSApplication.shared
        let fixture = directory.appendingPathComponent("installed/UpdateFixture.app")
        let bundle = try XCTUnwrap(Bundle(url: fixture))
        XCTAssertTrue(bundle.bundleIdentifier?.hasPrefix("io.github.btoaldas.BtoFolderLoop.UpdaterFixture.") == true)
        let archive = try XCTUnwrap(URL(string: try String(contentsOf: directory.appendingPathComponent("archive-url.txt")).trimmingCharacters(in: .whitespacesAndNewlines)))
        let offer = ReleaseOffer(version: ReleaseVersion("0.4.0")!, archiveURL: archive, pageURL: archive, preview: true)
        let updater = ReleaseUpdater(bundle: bundle, version: "0.3.0", client: StubReleaseClient(result: offer), workIsBusy: { false }, activityChanged: { _ in })
        await updater.check(); XCTAssertTrue(updater.canInstall)
        updater.install()
        let deadline = Date().addingTimeInterval(80)
        var installed = ""
        repeat {
            try await Task.sleep(for: .milliseconds(150))
            let info = try Data(contentsOf: fixture.appendingPathComponent("Contents/Info.plist"))
            let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: info, format: nil) as? [String: Any])
            installed = plist["CFBundleShortVersionString"] as? String ?? ""
        } while installed != "0.4.0" && updater.errorMessage == nil && Date() < deadline
        if env["BTOFOLDERLOOP_UPDATE_EXPECT_REJECTION"] == "1" {
            XCTAssertNotNil(updater.errorMessage, updater.message)
            XCTAssertEqual(installed, "0.3.0"); XCTAssertFalse(updater.installing)
            print("UPDATE_FIXTURE_REJECTED=" + (updater.errorMessage ?? "missing error"))
        } else {
            XCTAssertNil(updater.errorMessage, updater.message)
            XCTAssertEqual(installed, "0.4.0", updater.message)
            print("UPDATE_FIXTURE_INSTALLED=" + installed)
        }
    }

    @MainActor func testFooterPresentation() async throws {
        guard ProcessInfo.processInfo.environment["BTOFOLDERLOOP_RENDER_TEST"] == "1" else { throw XCTSkip("Optional offscreen UI snapshot") }
        let updater = ReleaseUpdater(version: "0.3.0", client: StubReleaseClient(result: offer()), workIsBusy: { false }, activityChanged: { _ in })
        await updater.check()
        let view = UpdateFooterView(updates: updater, folderWorkBusy: false).padding(16).frame(width: 900, height: 80).environment(\.colorScheme, .light).background(Color.white)
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 80), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua); host.appearance = NSAppearance(named: .aqua)
        window.contentView = host; host.setFrameSize(NSSize(width: 900, height: 80))
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))
        host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".tmp/update-footer-" + UUID().uuidString + ".png")
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output)
        print("UPDATE_FOOTER_SNAPSHOT=" + output.path)
    }
}
