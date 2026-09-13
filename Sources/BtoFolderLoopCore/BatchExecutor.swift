// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

public struct BatchExecutor {
    private let fs: FolderFileSystem
    private let journal: OperationJournal
    public init(fileSystem: FolderFileSystem, journal: OperationJournal) { fs = fileSystem; self.journal = journal }
    public func execute(_ batch: CleanupBatch, cancellation: CancellationToken = .init(),
                        progress: (Int, Int, UUID) -> Void = { _, _, _ in }) throws -> CleanupReport {
        guard !batch.candidates.isEmpty, Set(batch.candidates.map(\.id)).count == batch.candidates.count,
              batch.candidates.allSatisfy({ candidate in !batch.requestedRoots.contains { $0.path == candidate.path || $0.path.hasPrefix(candidate.path + "/") } }) else {
            throw CleanupError.invalidPlan
        }
        var report = CleanupReport(runID: batch.id), done = 0
        for plan in batch.plans {
            if cancellation.isCancelled { report.cancelled = true; break }
            do {
                let offset = done
                progress(done, batch.candidates.count, plan.id)
                let result = try CleanupExecutor(fileSystem: fs, journal: journal).execute(plan, cancellation: cancellation) { count, _ in
                    progress(offset + count, batch.candidates.count, plan.id)
                }
                report.moved += result.moved; report.skipped += result.skipped; report.errors += result.errors
                report.cancelled = result.cancelled
                done += result.moved.count + result.skipped.count
                if result.cancelled || !result.errors.isEmpty { break }
            } catch {
                report.errors.append(ScanIssue(path: plan.root.path, message: error.localizedDescription)); break
            }
        }
        return report
    }
}
