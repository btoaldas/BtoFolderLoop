// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
import Foundation
import CSQLite
import BtoFolderLoopCore
@testable import BtoFolderLoopStorage

final class HistoryRetentionTests: XCTestCase {
    func fixture() throws -> URL {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".tmp/history-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    func makePlan() throws -> CleanupPlan {
        let fs = MockFileSystem(); fs.add("/fixture/empty")
        return try CleanupPlanner(fileSystem: fs).analyze(root: "/fixture", mode: .cascade)
    }
    func seed(_ store: SQLiteStore, status: String = "completed", age: Int = 200, unresolved: Bool = false) throws -> UUID {
        let plan = try makePlan()
        try store.begin(plan)
        try store.record(run: plan.id, path: "/fixture/empty", phase: "prepared", destination: nil, detail: "inode=7;device=1")
        if !unresolved { try store.record(run: plan.id, path: "/fixture/empty", phase: "moved", destination: "/synthetic-trash/empty", detail: nil) }
        let date = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-Double(age) * 86400))
        _ = try store.rows("UPDATE runs SET started_at=?,updated_at=?,finished_at=?,status=? WHERE id=?", values: [date,date,date,status,plan.id.uuidString])
        return plan.id
    }
    func testDefaultsValidationAndSavedPolicySurviveReopen() throws {
        let url = try fixture().appendingPathComponent("settings.sqlite")
        do {
            let store = try SQLiteStore(location: url)
            let defaults = try store.loadRetention()
            XCTAssertEqual(defaults.diagnosticDays, 30); XCTAssertEqual(defaults.historyDays, 180); XCTAssertEqual(defaults.diagnosticMiB, 10)
            var policy = defaults; policy.diagnosticDays = 7; policy.historyDays = 365; policy.diagnosticMiB = 5
            try store.saveRetention(policy)
            for invalid in [-1, 0, 3651] { var bad = policy; bad.historyDays = invalid; XCTAssertThrowsError(try store.saveRetention(bad)) }
            var bad = policy; bad.diagnosticMiB = 101; XCTAssertThrowsError(try store.saveRetention(bad))
            XCTAssertEqual(try store.loadRetention(), policy)
        }
        let reopened = try SQLiteStore(location: url)
        XCTAssertEqual(try reopened.loadRetention().historyDays, 365)
    }
    func testLiveCountersAreAtomicWithEventAndPersistBeforeFinish() throws {
        let url = try fixture().appendingPathComponent("settings.sqlite"), plan = try makePlan()
        let store = try SQLiteStore(location: url)
        try store.begin(plan)
        try store.record(run: plan.id, path: "/fixture/empty", phase: "prepared", destination: nil, detail: nil)
        try store.record(run: plan.id, path: "/fixture/empty", phase: "moved", destination: "/synthetic-trash/empty", detail: nil)
        let reader = try SQLiteStore(location: url)
        XCTAssertEqual(try reader.recentRuns().first?.moved, 1)
        XCTAssertEqual(try reader.recentRuns().first?.status, "running")
        try store.executeSQL("CREATE TRIGGER synthetic_failure BEFORE UPDATE ON runs BEGIN SELECT RAISE(ABORT,'fixture'); END;")
        XCTAssertThrowsError(try store.record(run: plan.id, path: "other", phase: "moved", destination: nil, detail: nil))
        XCTAssertEqual(try reader.events(runID: plan.id.uuidString).count, 2)
        XCTAssertEqual(try reader.recentRuns().first?.moved, 1)
    }
    func testRetentionProtectsIncompleteErroredCancelledAndInconsistentHistory() throws {
        let root = try fixture(), store = try SQLiteStore(location: root.appendingPathComponent("settings.sqlite"))
        let control = root.appendingPathComponent("keep.txt"), data = Data("original control".utf8)
        try data.write(to: control)
        let expired = try seed(store)
        let ids = try [seed(store, age: 1), seed(store, status: "running"), seed(store, status: "cancelled"), seed(store, status: "stopped"), seed(store, unresolved: true)]
        let erroneous = try seed(store)
        try store.record(run: erroneous, path: "error", phase: "error", destination: nil, detail: "synthetic")
        let inconsistent = try seed(store)
        _ = try store.rows("UPDATE runs SET moved=2 WHERE id=?", values: [inconsistent.uuidString])
        XCTAssertEqual(try store.expireCompletedHistory(policy: .init()), 1)
        let remaining = Set(try store.recentRuns().map(\.id))
        XCTAssertFalse(remaining.contains(expired.uuidString))
        for id in ids + [erroneous,inconsistent] { XCTAssertTrue(remaining.contains(id.uuidString)) }
        XCTAssertTrue(try store.events(runID: expired.uuidString).isEmpty)
        XCTAssertTrue(try store.rows("PRAGMA foreign_key_check").isEmpty)
        XCTAssertTrue(try store.integrityCheck())
        XCTAssertEqual(try Data(contentsOf: control), data)
        XCTAssertEqual(try store.expireCompletedHistory(policy: .init()), 0)
    }
    func testRetentionRollsBackEntireOperationOnFailure() throws {
        let store = try SQLiteStore(location: fixture().appendingPathComponent("settings.sqlite"))
        let id = try seed(store)
        try store.executeSQL("CREATE TRIGGER prevent_removal BEFORE DELETE ON runs BEGIN SELECT RAISE(ABORT,'fixture'); END;")
        XCTAssertThrowsError(try store.expireCompletedHistory(policy: .init()))
        XCTAssertEqual(try store.events(runID: id.uuidString).count, 2)
        XCTAssertEqual(try store.recentRuns().count, 1)
    }
    func testEqualEventCountsDoNotHideWrongPathOrOutOfOrderReceipts() throws {
        let store = try SQLiteStore(location: fixture().appendingPathComponent("settings.sqlite"))
        let wrong = try seed(store, unresolved: true)
        try store.record(run: wrong, path: "/fixture/another", phase: "moved", destination: "/synthetic-trash/another", detail: nil)
        let outOfOrder = try seed(store)
        try store.record(run: outOfOrder, path: "/fixture/empty", phase: "prepared", destination: nil, detail: nil)
        XCTAssertEqual(try store.expireCompletedHistory(policy: .init()), 0)
        XCTAssertEqual(try store.recentRuns().count, 2)
    }
    func testFolderAggregationAndPaginationUseOnlyRequestedRun() throws {
        let store = try SQLiteStore(location: fixture().appendingPathComponent("settings.sqlite"))
        let first = try seed(store), second = try seed(store)
        for i in 0..<205 { try store.record(run: first, path: "synthetic-\(i)", phase: "skipped", destination: nil, detail: nil) }
        let page1 = try store.events(runID: first.uuidString)
        let page2 = try store.events(runID: first.uuidString, beforeID: page1.last?.id)
        XCTAssertEqual(page1.count, 200); XCTAssertEqual(page2.count, 7)
        XCTAssertTrue(Set(page1.map(\.id)).isDisjoint(with: Set(page2.map(\.id))))
        XCTAssertEqual(try store.events(runID: second.uuidString).count, 2)
        let folders = try store.folderHistory()
        XCTAssertEqual(folders.count, 1); XCTAssertEqual(folders.first?.runs, 2); XCTAssertEqual(folders.first?.moved, 2)
        let query = try store.rows("EXPLAIN QUERY PLAN SELECT id FROM events WHERE run_id='example' AND id>1")
        XCTAssertTrue(query.flatMap { $0 }.joined().contains("events_run_id_id"))
    }
    func testVersionOneMigrationBacksUpAndReconstructsProgressWithoutLosingPaths() throws {
        let root = try fixture(), location = root.appendingPathComponent("settings.sqlite")
        let schemaURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/BtoFolderLoopStorage/Resources/001_initial.sql")
        var original: OpaquePointer?
        XCTAssertEqual(sqlite3_open(location.path, &original), SQLITE_OK)
        defer { if let original { sqlite3_close(original) } }
        XCTAssertEqual(sqlite3_exec(original, try String(contentsOf: schemaURL), nil, nil, nil), SQLITE_OK)
        let seed = """
        INSERT INTO settings VALUES('cleanup_mode','cascade');
        INSERT INTO runs VALUES('legacy','2025-01-01T00:00:00Z','/fixture/legacy','cascade','running',2,0);
        INSERT INTO events VALUES(1,'legacy','2025-01-01T00:00:01Z','/fixture/legacy/child','prepared',NULL,'inode=123;device=1');
        INSERT INTO events VALUES(2,'legacy','2025-01-01T00:00:02Z','/fixture/legacy/child','moved','/synthetic-trash/child',NULL);
        """
        XCTAssertEqual(sqlite3_exec(original, seed, nil, nil, nil), SQLITE_OK)
        let store = try SQLiteStore(location: location)
        XCTAssertEqual(try store.loadMode(), .cascade)
        XCTAssertEqual(try store.recentRuns().first?.moved, 1)
        XCTAssertEqual(try store.recentRuns().first?.status, "running")
        XCTAssertEqual(try store.events(runID: "legacy").first?.destination, "/synthetic-trash/child")
        XCTAssertEqual(try store.expireCompletedHistory(policy: .init()), 0)
        let backups = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("pre-schema-2-") }
        XCTAssertEqual(backups.count, 1)
        var backup: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(try XCTUnwrap(backups.first).path, &backup, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(backup) }
        var statement: OpaquePointer?
        sqlite3_prepare_v2(backup, "PRAGMA user_version", -1, &statement, nil)
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW); XCTAssertEqual(sqlite3_column_int(statement, 0), 1); sqlite3_finalize(statement)
        sqlite3_prepare_v2(backup, "SELECT COUNT(*) FROM events", -1, &statement, nil)
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW); XCTAssertEqual(sqlite3_column_int(statement, 0), 2); sqlite3_finalize(statement)
        let fresh = try SQLiteStore(location: root.appendingPathComponent("fresh.sqlite"))
        let schema = "SELECT type,name,sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY type,name"
        XCTAssertEqual(try store.rows(schema), try fresh.rows(schema))
        XCTAssertTrue(try store.integrityCheck()); XCTAssertTrue(try store.rows("PRAGMA foreign_key_check").isEmpty)
    }
}
