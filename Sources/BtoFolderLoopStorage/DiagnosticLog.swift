// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import BtoFolderLoopCore

/// An allow-list prevents diagnostic files from receiving user paths, credentials or raw errors.
public enum DiagnosticCode: String, Codable, Sendable {
    case applicationOpened, scanStarted, scanCompleted, scanStopped
    case cleanupStarted, cleanupProgress, cleanupCompleted, cleanupStopped, journalFailed
    case maintenanceCompleted, maintenanceFailed, preferencesSaved
    var level: String {
        switch self {
        case .journalFailed, .maintenanceFailed: return "error"
        case .scanStopped, .cleanupStopped: return "warning"
        default: return "info"
        }
    }
}

public final class DiagnosticLog: @unchecked Sendable {
    public let directory: URL
    private let lock = NSLock()
    private var policy: RetentionPolicy
    private var current: URL?
    private let fm = FileManager.default
    private struct Record: Codable {
        let timestamp: String
        let level: String
        let event: DiagnosticCode
        let runID: UUID?
        let count: Int?
    }
    private struct Segment {
        let url: URL
        let modified: Date
        let size: Int
    }

    public init(directory: URL, policy: RetentionPolicy) throws {
        try policy.validate()
        self.directory = directory; self.policy = policy
        try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let attributes = try fm.attributesOfItem(atPath: directory.path)
        guard attributes[.type] as? FileAttributeType == .typeDirectory else {
            throw CleanupError.filesystem("La carpeta de diagnóstico debe ser un directorio local real.")
        }
    }

    public func configure(_ policy: RetentionPolicy) throws {
        try policy.validate()
        lock.lock(); defer { lock.unlock() }; self.policy = policy
    }

    private func segments() throws -> [Segment] {
        try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).compactMap { url in
            let name = url.lastPathComponent
            guard name.hasPrefix("diagnostic-"), name.hasSuffix(".jsonl"),
                  UUID(uuidString: String(name.dropFirst(11).dropLast(6))) != nil else { return nil }
            let a = try fm.attributesOfItem(atPath: url.path)
            guard a[.type] as? FileAttributeType == .typeRegular,
                  let modified = a[.modificationDate] as? Date else { return nil }
            return Segment(url: url, modified: modified, size: (a[.size] as? NSNumber)?.intValue ?? 0)
        }.sorted { $0.modified == $1.modified ? $0.url.path < $1.url.path : $0.modified < $1.modified }
    }

    private func prune(now: Date, reserving: Int = 0) throws {
        let cutoff = now.addingTimeInterval(-Double(policy.diagnosticDays) * 86400)
        let all = try segments()
        var bytes = all.reduce(0) { $0 + $1.size }
        for segment in all where segment.modified < cutoff || bytes + reserving > policy.diagnosticMiB * 1024 * 1024 {
            try fm.removeItem(at: segment.url)
            bytes -= segment.size
            if current == segment.url { current = nil }
        }
    }

    public func maintain(now: Date = Date()) throws {
        lock.lock(); defer { lock.unlock() }
        try prune(now: now)
    }

    public func write(_ code: DiagnosticCode, runID: UUID? = nil, count: Int? = nil, now: Date = Date()) throws {
        lock.lock(); defer { lock.unlock() }
        let formatter = ISO8601DateFormatter()
        let record = Record(timestamp: formatter.string(from: now), level: code.level, event: code, runID: runID, count: count)
        var data = try JSONEncoder().encode(record); data.append(0x0a)
        try prune(now: now, reserving: data.count)
        if let url = current, let segment = try segments().first(where: { $0.url == url }) {
            let sameDay = formatter.string(from: segment.modified).prefix(10) == formatter.string(from: now).prefix(10)
            if !sameDay || segment.size + data.count > min(2, policy.diagnosticMiB) * 1024 * 1024 { current = nil }
        } else { current = nil }
        if current == nil {
            let url = directory.appendingPathComponent("diagnostic-" + UUID().uuidString + ".jsonl")
            guard fm.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
                throw CleanupError.filesystem("No se pudo crear el diagnóstico local.")
            }
            current = url
        }
        guard let current else { return }
        let handle = try FileHandle(forWritingTo: current)
        defer { try? handle.close() }
        try handle.seekToEnd(); try handle.write(contentsOf: data)
        try fm.setAttributes([.modificationDate: now], ofItemAtPath: current.path)
    }
}
