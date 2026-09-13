// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

public protocol FolderFileSystem {
    func inspect(_ path: String) throws -> FileEntry
    func children(_ path: String) throws -> [FileEntry]
    /// Revalidate every ancestor and candidate; never follow links or permanently delete.
    func trashEmpty(_ candidate: Candidate, ancestors: [DirectoryIdentity]) throws -> TrashOutcome
}

public protocol OperationJournal {
    func begin(_ plan: CleanupPlan) throws
    func record(run: UUID, path: String, phase: String, destination: String?, detail: String?) throws
    func finish(_ report: CleanupReport) throws
}

public protocol PreferencesStore {
    func loadMode() throws -> CleanupMode
    func saveMode(_ mode: CleanupMode) throws
    func recentRuns() throws -> [RunSummary]
}
