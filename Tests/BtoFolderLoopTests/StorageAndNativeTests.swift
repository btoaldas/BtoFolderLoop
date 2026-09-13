// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
import Foundation
import BtoFolderLoopCore
import BtoFolderLoopStorage
import BtoFolderLoopMac

final class StorageAndNativeTests: XCTestCase {
    // Synthetic fixtures are retained in the ignored project .tmp directory; no user data is touched.
    func fixture() throws -> URL {
        let p = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".tmp/BtoFolderLoop-Test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: p, withIntermediateDirectories: true)
        return p
    }
    func testSQLiteModeSurvivesReopenAndIntegrityCheck() throws {
        let root = try fixture(), db = root.appendingPathComponent("settings.sqlite")
        do {
            let store = try SQLiteStore(location: db)
            XCTAssertEqual(try store.loadMode(), .singlePass)
            try store.saveMode(.cascade)
            XCTAssertTrue(try store.integrityCheck())
        }
        let reopened = try SQLiteStore(location: db)
        XCTAssertEqual(try reopened.loadMode(), .cascade)
        XCTAssertTrue(try reopened.integrityCheck())
    }
    func testSQLiteJournalPersistenceAndBoundStrings() throws {
        let location = try fixture().appendingPathComponent("settings.sqlite")
        let fs = MockFileSystem(); fs.add("/fixture/quote'folder")
        let plan = try CleanupPlanner(fileSystem: fs).analyze(root: "/fixture", mode: .singlePass)
        do {
            let store = try SQLiteStore(location: location)
            let report = try CleanupExecutor(fileSystem: fs, journal: store).execute(plan)
            XCTAssertEqual(report.moved.count, 1)
        }
        let store = try SQLiteStore(location: location)
        XCTAssertEqual(try store.recentRuns().first?.moved, 1)
        XCTAssertTrue(try store.journalText().contains("quote'folder"))
        XCTAssertThrowsError(try store.begin(plan))
        XCTAssertThrowsError(try store.record(run: UUID(), path: "test", phase: "moved", destination: nil, detail: nil))
    }
    func testNativeScanProtectsHiddenFilesSymlinksAndPackages() throws {
        let root = try fixture(), fm = FileManager.default
        for p in ["empty", "occupied", "hidden", "Example.app", "parent/child"] {
            try fm.createDirectory(at: root.appendingPathComponent(p), withIntermediateDirectories: true)
        }
        try Data("original".utf8).write(to: root.appendingPathComponent("occupied/photo.txt"))
        try Data().write(to: root.appendingPathComponent("hidden/.DS_Store"))
        try fm.createSymbolicLink(at: root.appendingPathComponent("link"), withDestinationURL: root.appendingPathComponent("empty"))
        let p = try CleanupPlanner(fileSystem: NativeFileSystem()).analyze(root: root.path, mode: .cascade)
        XCTAssertEqual(Set(p.candidates.map(\.relativePath)), ["parent/child", "parent"])
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("occupied/photo.txt")), Data("original".utf8))
    }
    func testNativeRejectsFolderInsideApplicationPackage() throws {
        let root = try fixture().appendingPathComponent("Example.app/internal")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        XCTAssertThrowsError(try CleanupPlanner(fileSystem: NativeFileSystem()).analyze(root: root.path, mode: .cascade))
    }
    func testNativeSingleAndCascadeTrashWithOriginalFilePreserved() throws {
        guard ProcessInfo.processInfo.environment["BTOFOLDERLOOP_NATIVE_TRASH_TEST"] == "1" else {
            throw XCTSkip("Native Trash smoke test is opt-in and uses only generated empty directories.")
        }
        let root = try fixture(), fm = FileManager.default, fs = NativeFileSystem()
        let selected = root.appendingPathComponent("selected"), chain = selected.appendingPathComponent("A/B/C")
        try fm.createDirectory(at: chain, withIntermediateDirectories: true)
        let file = selected.appendingPathComponent("keep.txt"), original = Data("DO NOT DELETE — synthetic".utf8)
        try original.write(to: file)
        let before = try fs.inspect(file.path).identity
        let store = try SQLiteStore(location: root.appendingPathComponent("local/settings.sqlite"))
        let single = try CleanupPlanner(fileSystem: fs).analyze(root: selected.path, mode: .singlePass)
        XCTAssertEqual(single.candidates.map(\.relativePath), ["A/B/C"])
        let one = try CleanupExecutor(fileSystem: fs, journal: store).execute(single)
        XCTAssertEqual(one.moved.count, 1); XCTAssertTrue(one.errors.isEmpty)
        XCTAssertTrue(fm.fileExists(atPath: selected.appendingPathComponent("A/B").path))
        let cascade = try CleanupPlanner(fileSystem: fs).analyze(root: selected.path, mode: .cascade)
        XCTAssertEqual(cascade.candidates.map(\.relativePath), ["A/B", "A"])
        let rest = try CleanupExecutor(fileSystem: fs, journal: store).execute(cascade)
        XCTAssertEqual(rest.moved.count, 2); XCTAssertTrue(rest.errors.isEmpty)
        for moved in one.moved + rest.moved {
            XCTAssertEqual(try fs.inspect(moved.destination).identity, moved.identity)
            XCTAssertTrue(try fm.contentsOfDirectory(atPath: moved.destination).isEmpty)
        }
        XCTAssertEqual(try fs.inspect(file.path).identity, before)
        XCTAssertEqual(try Data(contentsOf: file), original)
        XCTAssertTrue(try CleanupPlanner(fileSystem: fs).analyze(root: selected.path, mode: .cascade).candidates.isEmpty)
        print("NATIVE_TRASH_SMOKE=3 empty directories verified; original file bytes/identity unchanged")
    }
}
