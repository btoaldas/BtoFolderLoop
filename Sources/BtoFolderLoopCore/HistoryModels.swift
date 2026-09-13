// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

public struct RetentionPolicy: Codable, Equatable, Sendable {
    public var diagnosticDays: Int = 30
    public var historyDays: Int = 180
    public var diagnosticMiB: Int = 10
    public init() {}
    public func validate() throws {
        guard (1...3650).contains(diagnosticDays), (1...3650).contains(historyDays),
              (1...100).contains(diagnosticMiB) else {
            throw CleanupError.filesystem("Usa entre 1 y 3650 días y entre 1 y 100 MiB de diagnóstico.")
        }
    }
}

public struct FolderHistory: Identifiable, Sendable {
    public var id: String { path }
    public let path: String
    public let lastActivity: String
    public let runs: Int
    public let moved: Int
    public init(path: String, lastActivity: String, runs: Int, moved: Int) {
        self.path = path; self.lastActivity = lastActivity; self.runs = runs; self.moved = moved
    }
}

public struct JournalEvent: Identifiable, Sendable {
    public let id: Int
    public let date: String
    public let source: String
    public let phase: String
    public let destination: String
    public let detail: String
    public init(id: Int, date: String, source: String, phase: String, destination: String, detail: String) {
        self.id = id; self.date = date; self.source = source; self.phase = phase
        self.destination = destination; self.detail = detail
    }
    public var title: String {
        switch phase {
        case "prepared": return "Comprobación iniciada"
        case "moved": return "Enviada a la Papelera"
        case "skipped": return "Conservada"
        case "error": return "Error: revisar"
        default: return phase
        }
    }
}
