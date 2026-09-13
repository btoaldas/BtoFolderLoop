// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

public struct CleanupExecutor {
    private let fs: FolderFileSystem
    private let journal: OperationJournal
    public init(fileSystem: FolderFileSystem, journal: OperationJournal) { fs = fileSystem; self.journal = journal }

    /// Caller must present the immutable plan and obtain explicit approval before invoking this method.
    public func execute(_ plan: CleanupPlan, cancellation: CancellationToken = .init(),
                        progress: (Int, Int) -> Void = { _, _ in }) throws -> CleanupReport {
        guard plan.candidates.allSatisfy({ $0.path != plan.root.path && $0.path.hasPrefix(plan.root.path + "/") }),
              Set(plan.candidates.map(\.path)).count == plan.candidates.count else { throw CleanupError.invalidPlan }
        let root = try fs.inspect(plan.root.path)
        guard root.kind == .directory && root.identity == plan.root.identity else { throw CleanupError.changed(plan.root.path) }
        try journal.begin(plan)
        var report = CleanupReport(runID: plan.id)
        // Candidates are grouped by the number of dependency passes. Each pass only uses the approved set.
        for (index, candidate) in plan.candidates.enumerated() {
            if cancellation.isCancelled { report.cancelled = true; break }
            var ancestors = [plan.root]
            var parent = URL(fileURLWithPath: candidate.path).deletingLastPathComponent().path
            while parent != plan.root.path {
                guard let identity = plan.directories[parent] else { throw CleanupError.invalidPlan }
                ancestors.append(identity)
                parent = URL(fileURLWithPath: parent).deletingLastPathComponent().path
            }
            do {
                try journal.record(run: plan.id, path: candidate.path, phase: "prepared", destination: nil,
                                   detail: "inode=\(candidate.identity.inode);device=\(candidate.identity.device)")
                switch try fs.trashEmpty(candidate, ancestors: ancestors) {
                case .moved(let receipt):
                    // Keep the in-memory receipt even if the durable post-move write fails.
                    report.moved.append(receipt)
                    try journal.record(run: plan.id, path: candidate.path, phase: "moved", destination: receipt.destination, detail: nil)
                case .skipped(let reason):
                    report.skipped.append(ScanIssue(path: candidate.path, message: reason))
                    try journal.record(run: plan.id, path: candidate.path, phase: "skipped", destination: nil, detail: reason)
                }
            } catch {
                report.errors.append(ScanIssue(path: candidate.path, message: error.localizedDescription))
                try? journal.record(run: plan.id, path: candidate.path, phase: "error", destination: nil, detail: error.localizedDescription)
                break
            }
            progress(index + 1, plan.candidates.count)
        }
        do { try journal.finish(report) }
        catch { report.errors.append(ScanIssue(path: plan.root.path, message: "No se pudo cerrar el registro: \(error.localizedDescription)")) }
        return report
    }
}
