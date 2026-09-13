// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import CSQLite
import BtoFolderLoopCore

public final class SQLiteStore: OperationJournal, PreferencesStore, @unchecked Sendable {
    public let location: URL
    var db: OpaquePointer?
    let lock = NSRecursiveLock()
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(location: URL) throws {
        self.location = location
        let fm = FileManager.default
        let parent = location.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        guard sqlite3_open_v2(location.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            if let db { sqlite3_close(db) }; self.db = nil
            throw CleanupError.filesystem("No se pudo abrir la base local. No se moverán carpetas.")
        }
        do {
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: location.path)
            sqlite3_busy_timeout(db, 5000)
            try executeSQL("PRAGMA foreign_keys=ON; PRAGMA synchronous=FULL; PRAGMA journal_mode=DELETE;")
            let version = Int(try rows("PRAGMA user_version").first?.first ?? "0") ?? 0
            guard version <= 2 else { throw CleanupError.filesystem("La base pertenece a una versión más nueva de la app.") }
            if version == 1 { try backupBeforeMigration() }
            for next in (version + 1)..<3 {
                guard let url = Self.migrationURL(next) else { throw CleanupError.filesystem("No se encontró la migración de la base dentro de la aplicación.") }
                try executeSQL("BEGIN IMMEDIATE;")
                do { try executeSQL(String(contentsOf: url)); try executeSQL("COMMIT;") }
                catch { try? executeSQL("ROLLBACK;"); throw error }
            }
        } catch { sqlite3_close(db); db = nil; throw error }
    }

    deinit { if let db { sqlite3_close(db) } }

    // Avoid SwiftPM's generated absolute build-directory fallback in a distributed app.
    private static func migrationURL(_ version: Int) -> URL? {
        let name = "BtoFolderLoop_BtoFolderLoopStorage.bundle"
        let own = Bundle(for: SQLiteStore.self)
        var locations = [Bundle.main.resourceURL, Bundle.main.bundleURL, own.resourceURL,
                         own.bundleURL, own.bundleURL.deletingLastPathComponent()].compactMap { $0 }
        if var executableParent = Bundle.main.executableURL?.deletingLastPathComponent() {
            for _ in 0..<5 { locations.append(executableParent); executableParent.deleteLastPathComponent() }
        }
        for location in locations {
            if let bundle = Bundle(url: location.appendingPathComponent(name)),
               let migration = bundle.url(forResource: version == 1 ? "001_initial" : "002_history", withExtension: "sql") { return migration }
        }
        return nil
    }

    private func failure() -> Error {
        CleanupError.filesystem("Error en el registro local: \(db.map { String(cString: sqlite3_errmsg($0)) } ?? "base cerrada")")
    }
    func executeSQL(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw failure() }
    }
    func rows(_ sql: String, values: [String?] = []) throws -> [[String]] {
        lock.lock(); defer { lock.unlock() }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw failure() }
        defer { sqlite3_finalize(statement) }
        for (index, value) in values.enumerated() {
            let result: Int32
            if let value { result = sqlite3_bind_text(statement, Int32(index + 1), value, -1, transient) }
            else { result = sqlite3_bind_null(statement, Int32(index + 1)) }
            guard result == SQLITE_OK else { throw failure() }
        }
        var output: [[String]] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { return output }
            guard result == SQLITE_ROW else { throw failure() }
            output.append((0..<sqlite3_column_count(statement)).map { i in
                sqlite3_column_text(statement, i).map { String(cString: $0) } ?? ""
            })
        }
    }

    public func loadMode() throws -> CleanupMode {
        let value = try rows("SELECT value FROM settings WHERE key=?", values: ["cleanup_mode"]).first?.first
        return value.flatMap(CleanupMode.init(rawValue:)) ?? .singlePass
    }
    public func saveMode(_ mode: CleanupMode) throws {
        _ = try rows("INSERT INTO settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", values: ["cleanup_mode", mode.rawValue])
    }
    public func begin(_ plan: CleanupPlan) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        _ = try rows("INSERT INTO runs(id,started_at,root_path,mode,status,planned,updated_at) VALUES(?,?,?,?,?,?,?)",
                     values: [plan.id.uuidString, now, plan.root.path, plan.mode.rawValue, "running", String(plan.candidates.count), now])
    }
    public func record(run: UUID, path: String, phase: String, destination: String?, detail: String?) throws {
        _ = try rows("INSERT INTO events(run_id,recorded_at,source_path,phase,destination_path,detail) VALUES(?,?,?,?,?,?)",
                     values: [run.uuidString, ISO8601DateFormatter().string(from: Date()), path, phase, destination, detail])
    }
    public func finish(_ report: CleanupReport) throws {
        let status = report.cancelled ? "cancelled" : (report.errors.isEmpty ? "completed" : "stopped")
        let now = ISO8601DateFormatter().string(from: Date())
        _ = try rows("UPDATE runs SET status=?,moved=?,skipped=?,errors=?,finished_at=?,updated_at=? WHERE id=?",
                     values: [status, String(report.moved.count), String(report.skipped.count), String(report.errors.count), now, now, report.runID.uuidString])
    }
    public func recentRuns() throws -> [RunSummary] {
        try rows("SELECT id,started_at,mode,status,moved,root_path,planned,skipped,errors,updated_at,finished_at FROM runs ORDER BY updated_at DESC,id DESC LIMIT 200").map {
            RunSummary(id: $0[0], date: $0[1], mode: $0[2], status: $0[3], moved: Int($0[4]) ?? 0,
                       root: $0[5], planned: Int($0[6]) ?? 0, skipped: Int($0[7]) ?? 0, errors: Int($0[8]) ?? 0,
                       updatedAt: $0[9], finishedAt: $0[10])
        }
    }
    public func journalText() throws -> String {
        let events = try rows("SELECT recorded_at,source_path,phase,destination_path,detail FROM events ORDER BY id DESC LIMIT 500")
        return events.map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }
    public func integrityCheck() throws -> Bool { try rows("PRAGMA integrity_check").first?.first == "ok" }
}
