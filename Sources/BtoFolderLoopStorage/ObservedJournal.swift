// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import BtoFolderLoopCore

/// Recovery is durable per item; diagnostics are sampled so large runs do not duplicate every path.
public final class ObservedJournal: OperationJournal {
    private let store: SQLiteStore
    private let log: DiagnosticLog?
    private let warning: () -> Void
    private var lastProgress = Date.distantPast
    private var moved = 0
    public init(store: SQLiteStore, log: DiagnosticLog?, warning: @escaping () -> Void) {
        self.store = store; self.log = log; self.warning = warning
    }
    private func emit(_ code: DiagnosticCode, run: UUID, count: Int? = nil) {
        do { try log?.write(code, runID: run, count: count) } catch { warning() }
    }
    public func begin(_ plan: CleanupPlan) throws {
        do { try store.begin(plan) }
        catch { emit(.journalFailed, run: plan.id); throw error }
        lastProgress = Date(); moved = 0
        emit(.cleanupStarted, run: plan.id, count: plan.candidates.count)
    }
    public func record(run: UUID, path: String, phase: String, destination: String?, detail: String?) throws {
        do { try store.record(run: run, path: path, phase: phase, destination: destination, detail: detail) }
        catch { emit(.journalFailed, run: run); throw error }
        if phase == "moved" { moved += 1 }
        if Date().timeIntervalSince(lastProgress) >= 10 {
            emit(.cleanupProgress, run: run, count: moved); lastProgress = Date()
        }
    }
    public func finish(_ report: CleanupReport) throws {
        do { try store.finish(report) }
        catch { emit(.journalFailed, run: report.runID); throw error }
        emit(report.cancelled || !report.errors.isEmpty ? .cleanupStopped : .cleanupCompleted,
             run: report.runID, count: report.moved.count)
    }
}
