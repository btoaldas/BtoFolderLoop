// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
import AppKit
import SwiftUI
import BtoFolderLoopCore
import BtoFolderLoopMac
@testable import BtoFolderLoopApp

final class FolderInputTests: XCTestCase {
    func fixture() throws -> URL {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".tmp/folder-input-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    func alias(_ target: URL, at path: URL) throws {
        let bookmark = try target.bookmarkData(options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
        try URL.writeBookmarkData(bookmark, to: path)
    }
    func testFinderAliasSymlinkChainAndCanonicalCaseResolveWithoutChangingInputs() throws {
        let base = try fixture(), folder = base.appendingPathComponent("Albums")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let shortcut = base.appendingPathComponent("Photos alias"), link = base.appendingPathComponent("Shortcut")
        try alias(folder, at: shortcut)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: shortcut)
        let bytes = try Data(contentsOf: shortcut), resolver = FolderInputResolver()
        let direct = try resolver.resolve(folder), aliased = try resolver.resolve(shortcut), linked = try resolver.resolve(link)
        XCTAssertFalse(direct.shortcut); XCTAssertTrue(aliased.shortcut); XCTAssertTrue(linked.shortcut)
        XCTAssertEqual(direct.directory.identity, aliased.directory.identity)
        XCTAssertEqual(direct.url, linked.url); XCTAssertEqual(try Data(contentsOf: shortcut), bytes)
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: link.path), shortcut.path)
        let lower = base.appendingPathComponent("albums")
        if FileManager.default.fileExists(atPath: lower.path) { XCTAssertEqual(try resolver.resolve(lower).url, direct.url) }
    }
    func testBrokenCyclicFileAndProtectedTargetsAreRejectedAndLinksRemain() throws {
        let base = try fixture(), resolver = FolderInputResolver(), fm = FileManager.default
        let broken = base.appendingPathComponent("Broken"), a = base.appendingPathComponent("A"), b = base.appendingPathComponent("B")
        try fm.createSymbolicLink(at: broken, withDestinationURL: base.appendingPathComponent("Missing"))
        try fm.createSymbolicLink(at: a, withDestinationURL: b); try fm.createSymbolicLink(at: b, withDestinationURL: a)
        let file = base.appendingPathComponent("document.txt"); try Data("preserve".utf8).write(to: file)
        let fileAlias = base.appendingPathComponent("Document alias"); try alias(file, at: fileAlias)
        let package = base.appendingPathComponent("Example.app"); try fm.createDirectory(at: package, withIntermediateDirectories: true)
        for item in [broken, a, file, fileAlias, package, URL(fileURLWithPath: "/"), URL(string: "https://example.invalid/folder")!] {
            XCTAssertThrowsError(try resolver.resolve(item))
        }
        XCTAssertEqual(try Data(contentsOf: file), Data("preserve".utf8))
        XCTAssertEqual(try fm.destinationOfSymbolicLink(atPath: broken.path), base.appendingPathComponent("Missing").path)
    }
    @MainActor func testApplicationBatchResolvesAliasesReportsBadInputsAndResetsApproval() async throws {
        let base = try fixture(), fm = FileManager.default
        let a = base.appendingPathComponent("Client A"), b = base.appendingPathComponent("Client B")
        for root in [a,b] { try fm.createDirectory(at: root.appendingPathComponent("empty"), withIntermediateDirectories: true) }
        let shortcut = base.appendingPathComponent("Client shortcut"); try alias(a, at: shortcut)
        let invalid = base.appendingPathComponent("document.txt"); try Data("keep".utf8).write(to: invalid)
        let model = AppModel(storageDirectory: base.appendingPathComponent("state"))
        model.select([a,b,shortcut,invalid])
        try await awaitIdle(model)
        XCTAssertNil(model.error); XCTAssertEqual(model.plan?.plans.count, 2)
        XCTAssertEqual(model.resolvedFolders.count, 3); XCTAssertEqual(model.inputIssues.count, 1)
        XCTAssertEqual(model.plan?.candidates.count, 2); XCTAssertTrue(model.selection.selectedIDs.isEmpty)
        model.selectAll(); model.reviewSelection()
        XCTAssertTrue(model.showConfirmation); XCTAssertEqual(model.pendingApproval?.plans.count, 2)
        model.cancelApproval(); XCTAssertNil(model.pendingApproval)
        XCTAssertEqual(try model.store?.recentRuns().count, 0)
        model.changeMode(.cascade); try await awaitIdle(model)
        XCTAssertTrue(model.selection.selectedIDs.isEmpty); XCTAssertEqual(model.plan?.candidates.count, 2)
        if ProcessInfo.processInfo.environment["BTOFOLDERLOOP_RENDER_TEST"] == "1" {
            try await render(ContentView(model: model), size: NSSize(width: 930, height: 820), output: base.appendingPathComponent("batch-preview.png"))
            model.selectAll(); model.reviewSelection()
            try await render(ApprovalView(model: model), size: NSSize(width: 680, height: 560), output: base.appendingPathComponent("batch-approval.png"))
            print("BATCH_UI_SNAPSHOTS=" + base.path)
        }
        XCTAssertTrue(fm.fileExists(atPath: a.appendingPathComponent("empty").path))
        XCTAssertTrue(fm.fileExists(atPath: b.appendingPathComponent("empty").path))
    }
    @MainActor func awaitIdle(_ model: AppModel) async throws {
        let deadline = Date().addingTimeInterval(10)
        while model.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(model.busy)
    }
    @MainActor func testNativeBatchWithAliasNestedRootAndIndependentReceiptChecks() async throws {
        guard ProcessInfo.processInfo.environment["BTOFOLDERLOOP_NATIVE_BATCH_TEST"] == "1" else { throw XCTSkip("Opt-in: three synthetic empty directories to native Trash") }
        let base = try fixture(), fm = FileManager.default, fs = NativeFileSystem()
        let a = base.appendingPathComponent("Group A"), b = base.appendingPathComponent("Group B"), nested = a.appendingPathComponent("Nested root")
        let empties = [a.appendingPathComponent("empty-a"), nested.appendingPathComponent("empty-inner"), b.appendingPathComponent("empty-b")]
        for path in empties { try fm.createDirectory(at: path, withIntermediateDirectories: true) }
        let files = [a.appendingPathComponent("keep.txt"), b.appendingPathComponent("keep.txt")]
        for file in files { try Data("File contents must remain intact.\n".utf8).write(to: file) }
        let shortcut = base.appendingPathComponent("Nested alias"); try alias(nested, at: shortcut)
        let aliasBytes = try Data(contentsOf: shortcut)
        let protected = [a,b,nested] + files
        let identities = try protected.map { try fs.inspect($0.path).identity }
        let bytes = try files.map { try Data(contentsOf: $0) }
        let model = AppModel(storageDirectory: base.appendingPathComponent("state"))
        model.mode = .cascade
        model.select([a,b,shortcut,a]); try await awaitIdle(model)
        XCTAssertNil(model.error)
        XCTAssertEqual(Set(model.plan?.candidates.map(\.path) ?? []), Set(empties.map(\.path)))
        XCTAssertTrue(model.selection.selectedIDs.isEmpty)
        model.selectAll(); model.reviewSelection(); model.cancelApproval()
        XCTAssertEqual(try model.store?.recentRuns().count, 0)
        model.reviewSelection(); model.executeApprovedPlan(); try await awaitIdle(model)
        let result = try XCTUnwrap(model.report)
        XCTAssertEqual(result.moved.count, 3); XCTAssertTrue(result.errors.isEmpty); XCTAssertTrue(result.skipped.isEmpty)
        for receipt in result.moved {
            XCTAssertFalse(fm.fileExists(atPath: receipt.source))
            let attributes = try fm.attributesOfItem(atPath: receipt.destination)
            XCTAssertEqual((attributes[.systemFileNumber] as? NSNumber)?.uint64Value, receipt.identity.inode)
            XCTAssertEqual((attributes[.systemNumber] as? NSNumber)?.uint64Value, receipt.identity.device)
            XCTAssertTrue(try fm.contentsOfDirectory(atPath: receipt.destination).isEmpty)
        }
        XCTAssertEqual(try protected.map { try fs.inspect($0.path).identity }, identities)
        XCTAssertEqual(try files.map { try Data(contentsOf: $0) }, bytes)
        XCTAssertEqual(try Data(contentsOf: shortcut), aliasBytes)
        let history = try XCTUnwrap(model.store).recentRuns()
        XCTAssertEqual(history.count, 2); XCTAssertEqual(history.reduce(0) { $0 + $1.moved }, 3)
        XCTAssertTrue(history.allSatisfy { $0.status == "completed" })
        model.executeApprovedPlan(); XCTAssertFalse(model.busy)
        XCTAssertEqual(try model.store?.recentRuns().count, 2)
        print("NATIVE_BATCH_EVIDENCE=" + base.path)
    }
    @MainActor func render<V: View>(_ view: V, size: NSSize, output: URL) async throws {
        let host = NSHostingView(rootView: view.environment(\.colorScheme, .light).background(Color.white))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.appearance = NSAppearance(named: .aqua); host.appearance = NSAppearance(named: .aqua)
        window.contentView = host; host.setFrameSize(size); defer { window.close() }
        try await Task.sleep(for: .milliseconds(100)); host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output)
    }
}
