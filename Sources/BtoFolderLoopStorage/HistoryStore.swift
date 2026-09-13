// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import CSQLite
import BtoFolderLoopCore

extension SQLiteStore {
    func backupBeforeMigration() throws {
        let url = location.deletingLastPathComponent().appendingPathComponent("pre-schema-2-" + UUID().uuidString + ".sqlite")
        guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
            throw CleanupError.filesystem("No se pudo preparar el respaldo previo a la migración.")
        }
        var copy: OpaquePointer?
        guard sqlite3_open_v2(url.path, &copy, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            if let copy { sqlite3_close(copy) }
            throw CleanupError.filesystem("No se pudo abrir el respaldo previo a la migración.")
        }
        defer { sqlite3_close(copy) }
        guard let backup = sqlite3_backup_init(copy, "main", db, "main") else {
            throw CleanupError.filesystem("No se pudo iniciar el respaldo; la base original se conserva.")
        }
        let step = sqlite3_backup_step(backup, -1)
        let finish = sqlite3_backup_finish(backup)
        guard step == SQLITE_DONE, finish == SQLITE_OK else {
            throw CleanupError.filesystem("No se pudo completar el respaldo; no se migró la base.")
        }
    }

    public func loadRetention() throws -> RetentionPolicy {
        guard let text = try rows("SELECT value FROM settings WHERE key='retention_policy'").first?.first else { return RetentionPolicy() }
        let policy = try JSONDecoder().decode(RetentionPolicy.self, from: Data(text.utf8))
        try policy.validate()
        return policy
    }

    public func saveRetention(_ policy: RetentionPolicy) throws {
        try policy.validate()
        let text = String(decoding: try JSONEncoder().encode(policy), as: UTF8.self)
        _ = try rows("INSERT INTO settings(key,value) VALUES('retention_policy',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", values: [text])
    }

    public func folderHistory() throws -> [FolderHistory] {
        try rows("SELECT root_path,MAX(updated_at),COUNT(*),SUM(moved) FROM runs GROUP BY root_path ORDER BY MAX(updated_at) DESC LIMIT 200").map {
            FolderHistory(path: $0[0], lastActivity: $0[1], runs: Int($0[2]) ?? 0, moved: Int($0[3]) ?? 0)
        }
    }

    public func events(runID: String, beforeID: Int? = nil) throws -> [JournalEvent] {
        try rows("SELECT id,recorded_at,source_path,phase,destination_path,detail FROM events WHERE run_id=? AND id<? ORDER BY id DESC LIMIT 200",
                 values: [runID, String(beforeID ?? Int.max)]).map {
            JournalEvent(id: Int($0[0]) ?? 0, date: $0[1], source: $0[2], phase: $0[3], destination: $0[4], detail: $0[5])
        }
    }

    /// Caller schedules this only while idle. Incomplete/error/cancelled journals are never expired.
    /// Only application-owned records are affected; no filesystem source or Trash URL is acted on.
    @discardableResult
    public func expireCompletedHistory(policy: RetentionPolicy, now: Date = Date()) throws -> Int {
        try policy.validate()
        let cutoff = ISO8601DateFormatter().string(from: now.addingTimeInterval(-Double(policy.historyDays) * 86400))
        lock.lock(); defer { lock.unlock() }
        try executeSQL("BEGIN IMMEDIATE;")
        do {
            // Group only the selected run. Avoid a large index duplicating all private path strings.
            // A prepared path must have a later terminal receipt; count equality alone is insufficient.
            let eligible = try rows("""
                SELECT r.id FROM runs r WHERE r.status='completed' AND r.errors=0 AND r.finished_at<?
                AND r.moved=(SELECT COUNT(*) FROM events e WHERE e.run_id=r.id AND e.phase='moved')
                AND r.skipped=(SELECT COUNT(*) FROM events e WHERE e.run_id=r.id AND e.phase='skipped')
                AND NOT EXISTS(SELECT 1 FROM events e WHERE e.run_id=r.id AND e.phase='error')
                AND NOT EXISTS(SELECT source_path FROM events e WHERE e.run_id=r.id GROUP BY source_path
                  HAVING MAX(CASE WHEN phase='prepared' THEN id ELSE 0 END) >
                    MAX(CASE WHEN phase IN ('moved','skipped') THEN id ELSE 0 END))
                """, values: [cutoff])
            for row in eligible {
                _ = try rows("DELETE FROM events WHERE run_id=?", values: [row[0]])
                _ = try rows("DELETE FROM runs WHERE id=?", values: [row[0]])
            }
            try executeSQL("COMMIT;")
            return eligible.count
        } catch { try? executeSQL("ROLLBACK;"); throw error }
    }
}
