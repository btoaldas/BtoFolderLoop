// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
import SwiftUI
import AppKit
import BtoFolderLoopCore
@testable import BtoFolderLoopApp

final class HistoryPresentationTests: XCTestCase {
    func fixture() throws -> URL {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".tmp/presentation-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    @MainActor func testBusyStatePreventsSettingsAndMaintenanceAndHistoryRemainsReadable() async throws {
        let root = try fixture(), model = AppModel(storageDirectory: root)
        XCTAssertNotNil(model.store); XCTAssertNil(model.error)
        let fs = MockFileSystem(); fs.add("/fixture/empty")
        let plan = try CleanupPlanner(fileSystem: fs).analyze(root: "/fixture", mode: .cascade)
        try model.store?.begin(plan)
        try model.store?.record(run: plan.id, path: "/fixture/empty", phase: "moved", destination: "/synthetic-trash/empty", detail: nil)
        model.busy = true; model.lastMaintenance = .distantPast
        model.openSettings(); XCTAssertFalse(model.showSettings)
        model.settingsDraft.historyDays = 1; model.saveSettings()
        XCTAssertEqual(try model.store?.loadRetention().historyDays, 180)
        model.maintainIfIdle(); XCTAssertEqual(model.lastMaintenance, .distantPast)
        model.openHistory(); XCTAssertTrue(model.showHistory)
        XCTAssertEqual(model.history.first?.moved, 1)
        XCTAssertEqual(model.historyEvents.count, 1)
        model.busy = false; model.openSettings(); XCTAssertTrue(model.showSettings)
        model.settingsDraft.historyDays = 365; model.saveSettings()
        XCTAssertEqual(try model.store?.loadRetention().historyDays, 365)
        XCTAssertFalse(model.showSettings)
    }
    @MainActor func testHistoryAndSettingsRenderOffscreenWithSyntheticData() async throws {
        guard ProcessInfo.processInfo.environment["BTOFOLDERLOOP_RENDER_TEST"] == "1" else {
            throw XCTSkip("Optional offscreen rendering; no application is opened or replaced.")
        }
        let root = try fixture(), model = AppModel(storageDirectory: root)
        let fs = MockFileSystem(); fs.add("/fixture/Family Albums"); fs.add("/fixture/Family Albums/empty")
        let plan = try CleanupPlanner(fileSystem: fs).analyze(root: "/fixture", mode: .cascade)
        let report = try CleanupExecutor(fileSystem: fs, journal: XCTUnwrap(model.store)).execute(plan)
        XCTAssertTrue(report.errors.isEmpty)
        model.openHistory()
        try await render(HistoryView(model: model), size: NSSize(width: 900, height: 700), to: root.appendingPathComponent("history.png"))
        try await render(SettingsView(model: model), size: NSSize(width: 650, height: 580), to: root.appendingPathComponent("settings.png"))
        print("OFFSCREEN_HISTORY_SETTINGS=" + root.path)
    }
    @MainActor private func render<V: View>(_ view: V, size: NSSize, to url: URL) async throws {
        // Host native AppKit-backed controls in an unshown window; ImageRenderer omits them.
        let host = NSHostingView(rootView: view.environment(\.colorScheme, .light).background(Color.white))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        host.appearance = NSAppearance(named: .aqua)
        window.contentView = host
        host.setFrameSize(size)
        defer { window.close() }
        try await Task.sleep(nanoseconds: 100_000_000)
        host.layoutSubtreeIfNeeded()
        let representation = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: representation)
        let png = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
        try png.write(to: url)
    }
}
