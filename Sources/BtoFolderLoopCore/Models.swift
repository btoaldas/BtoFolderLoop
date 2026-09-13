// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

public enum CleanupMode: String, Codable, CaseIterable, Sendable {
    case singlePass, cascade
    public var title: String { self == .singlePass ? "Una pasada" : "En bucle" }
    public var detail: String {
        self == .singlePass
        ? "Solo las carpetas que ya están vacías. Sus padres se conservan."
        : "También sus padres, si quedan vacíos al retirar las carpetas interiores."
    }
}

public struct FileIdentity: Codable, Equatable, Sendable {
    public let device: UInt64
    public let inode: UInt64
    public init(device: UInt64, inode: UInt64) { self.device = device; self.inode = inode }
}

public enum EntryKind: String, Codable, Sendable { case directory, file, symbolicLink, protected }

public struct FileEntry: Sendable {
    public let path: String
    public let identity: FileIdentity
    public let kind: EntryKind
    public let linkTarget: String?
    public init(path: String, identity: FileIdentity, kind: EntryKind, linkTarget: String? = nil) {
        self.path = path; self.identity = identity; self.kind = kind; self.linkTarget = linkTarget
    }
}

public struct DirectoryIdentity: Codable, Sendable {
    public let path: String
    public let identity: FileIdentity
    public init(path: String, identity: FileIdentity) { self.path = path; self.identity = identity }
}

public struct Candidate: Codable, Identifiable, Sendable {
    public var id: String { path }
    public let path: String
    public let relativePath: String
    public let identity: FileIdentity
    public let pass: Int
    public var initiallyEmpty: Bool { pass == 1 }
}

public struct ScanIssue: Codable, Identifiable, Sendable {
    public let id: UUID
    public let path: String
    public let message: String
    public init(path: String, message: String) { id = UUID(); self.path = path; self.message = message }
}

public struct CleanupPlan: Sendable {
    public let id: UUID
    public let root: DirectoryIdentity
    public let mode: CleanupMode
    public let candidates: [Candidate]
    public let directories: [String: DirectoryIdentity]
    public let issues: [ScanIssue]
    public let scannedDirectories: Int
    public let protectedEntries: Int
    public let createdAt: Date
    public var passes: Int { candidates.map(\.pass).max() ?? 0 }
}

public struct TrashReceipt: Codable, Sendable {
    public let source: String
    public let destination: String
    public let identity: FileIdentity
    public init(source: String, destination: String, identity: FileIdentity) {
        self.source = source; self.destination = destination; self.identity = identity
    }
}

public enum TrashOutcome: Sendable { case moved(TrashReceipt), skipped(String) }

public struct CleanupReport: Sendable {
    public let runID: UUID
    public var moved: [TrashReceipt] = []
    public var skipped: [ScanIssue] = []
    public var errors: [ScanIssue] = []
    public var cancelled = false
    public init(runID: UUID) { self.runID = runID }
}

public struct RunSummary: Identifiable, Sendable {
    public let id: String
    public let date: String
    public let mode: String
    public let status: String
    public let moved: Int
    public init(id: String, date: String, mode: String, status: String, moved: Int) {
        self.id = id; self.date = date; self.mode = mode; self.status = status; self.moved = moved
    }
}

public enum CleanupError: LocalizedError {
    case unsafeRoot, changed(String), invalidPlan, limitExceeded, cancelled, filesystem(String)
    public var errorDescription: String? {
        switch self {
        case .unsafeRoot: return "Elige una carpeta real. No se admiten enlaces, paquetes, la raíz del disco ni carpetas protegidas."
        case .changed(let p): return "La carpeta cambió después del análisis: \(p). Vuelve a analizar."
        case .invalidPlan: return "La vista previa ya no es válida. Vuelve a analizar."
        case .limitExceeded: return "El análisis alcanzó el límite de seguridad. Elige una carpeta más pequeña."
        case .cancelled: return "Operación cancelada."
        case .filesystem(let m): return m
        }
    }
}

public final class CancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    public init() {}
    public func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    public var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
}
