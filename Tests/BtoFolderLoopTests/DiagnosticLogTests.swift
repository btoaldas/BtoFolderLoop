// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
import Foundation
import BtoFolderLoopCore
@testable import BtoFolderLoopStorage

final class DiagnosticLogTests: XCTestCase {
    func fixture() throws -> URL {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".tmp/diagnostic-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    func segment(_ root: URL, bytes: Int, date: Date) throws -> URL {
        let url = root.appendingPathComponent("diagnostic-" + UUID().uuidString + ".jsonl")
        try Data(repeating: 0x20, count: bytes).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        return url
    }
    func testTypedRecordsAndDailyRotationDoNotIncludePaths() throws {
        let root = try fixture(), log = try DiagnosticLog(directory: root, policy: .init())
        let id = UUID(), now = Date()
        try log.write(.cleanupStarted, runID: id, count: 500, now: now)
        try log.write(.cleanupCompleted, runID: id, count: 500, now: now.addingTimeInterval(86400))
        let urls = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        XCTAssertEqual(urls.count, 2)
        for url in urls {
            let data = try Data(contentsOf: url)
            let record = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertEqual(Set(record.keys), ["timestamp", "level", "event", "runID", "count"])
            XCTAssertEqual(record["level"] as? String, "info")
            XCTAssertEqual(record["runID"] as? String, id.uuidString)
            XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("/fixture"))
            XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        }
    }
    func testExpirationAndBudgetOnlyRemoveOwnedRegularLogSegments() throws {
        let root = try fixture(), now = Date()
        let control = root.appendingPathComponent("keep.txt"), bytes = Data("keep original".utf8)
        try bytes.write(to: control)
        let unrelated = root.appendingPathComponent("diagnostic-not-a-uuid.jsonl")
        try bytes.write(to: unrelated)
        let old = try segment(root, bytes: 100, date: now.addingTimeInterval(-31 * 86400))
        let olderLarge = try segment(root, bytes: 700_000, date: now.addingTimeInterval(-20))
        let newLarge = try segment(root, bytes: 700_000, date: now.addingTimeInterval(-10))
        let link = root.appendingPathComponent("diagnostic-" + UUID().uuidString + ".jsonl")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: control)
        var policy = RetentionPolicy(); policy.diagnosticMiB = 1
        let log = try DiagnosticLog(directory: root, policy: policy)
        try log.maintain(now: now)
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: olderLarge.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newLarge.path))
        XCTAssertEqual(try Data(contentsOf: control), bytes); XCTAssertEqual(try Data(contentsOf: unrelated), bytes)
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: link.path), control.path)
        try log.write(.preferencesSaved, now: now)
        XCTAssertEqual(try Data(contentsOf: control), bytes)
    }
    func testSegmentSizeRotationAndUserBudgetApplyOnNextWrite() throws {
        let root = try fixture(), log = try DiagnosticLog(directory: root, policy: .init()), now = Date()
        try log.write(.applicationOpened, now: now)
        let first = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).first)
        let handle = try FileHandle(forWritingTo: first)
        try handle.seekToEnd(); try handle.write(contentsOf: Data(repeating: 0x20, count: 2 * 1024 * 1024)); try handle.close()
        try log.write(.scanStarted, now: now.addingTimeInterval(1))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).count, 2)
        var smaller = RetentionPolicy(); smaller.diagnosticMiB = 1
        try log.configure(smaller)
        try log.write(.scanCompleted, now: now.addingTimeInterval(2))
        let urls = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        let sizes = try urls.map { (try FileManager.default.attributesOfItem(atPath: $0.path)[.size] as? NSNumber)?.intValue ?? 0 }
        XCTAssertLessThanOrEqual(sizes.reduce(0,+), 1024 * 1024)
    }
    func testBrokenDiagnosticsDoNotDiscardDurableMovementHistory() throws {
        let root = try fixture(), logDir = root.appendingPathComponent("Diagnostics")
        let store = try SQLiteStore(location: root.appendingPathComponent("settings.sqlite"))
        let log = try DiagnosticLog(directory: logDir, policy: .init())
        try FileManager.default.moveItem(at: logDir, to: root.appendingPathComponent("retained-diagnostics"))
        var warnings = 0
        let journal = ObservedJournal(store: store, log: log) { warnings += 1 }
        let fs = MockFileSystem(); fs.add("/fixture/empty")
        let plan = try CleanupPlanner(fileSystem: fs).analyze(root: "/fixture", mode: .singlePass)
        let report = try CleanupExecutor(fileSystem: fs, journal: journal).execute(plan)
        XCTAssertTrue(report.errors.isEmpty); XCTAssertEqual(report.moved.count, 1)
        XCTAssertGreaterThan(warnings, 0)
        XCTAssertEqual(try store.events(runID: plan.id.uuidString).count, 2)
        XCTAssertEqual(try store.recentRuns().first?.status, "completed")
    }
    func testJournalFailureStillStopsAndLogsTypedError() throws {
        let root = try fixture(), store = try SQLiteStore(location: root.appendingPathComponent("settings.sqlite"))
        let logDir = root.appendingPathComponent("Diagnostics"), log = try DiagnosticLog(directory: logDir, policy: .init())
        try store.executeSQL("CREATE TRIGGER synthetic_failure BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture'); END;")
        let fs = MockFileSystem(); fs.add("/fixture/empty")
        let plan = try CleanupPlanner(fileSystem: fs).analyze(root: "/fixture", mode: .singlePass)
        let report = try CleanupExecutor(fileSystem: fs, journal: ObservedJournal(store: store, log: log, warning: {})).execute(plan)
        XCTAssertEqual(report.moved.count, 0); XCTAssertFalse(report.errors.isEmpty)
        let all = try FileManager.default.contentsOfDirectory(at: logDir, includingPropertiesForKeys: nil).map { try String(contentsOf: $0) }.joined()
        XCTAssertTrue(all.contains("journalFailed")); XCTAssertFalse(all.contains("/fixture"))
    }
}
