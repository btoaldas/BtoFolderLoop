// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Selection belongs to the complete batch and never expands to other roots or descendants.
public struct BatchSelection: Sendable {
    public private(set) var selectedIDs: Set<String> = []
    private let batchID: UUID?
    private let available: Set<String>
    public init(batch: CleanupBatch? = nil) {
        batchID = batch?.id; available = Set(batch?.candidates.map(\.id) ?? [])
    }
    public mutating func setSelected(_ id: String, _ selected: Bool) {
        guard available.contains(id) else { return }
        if selected { selectedIDs.insert(id) } else { selectedIDs.remove(id) }
    }
    public mutating func selectAll() { selectedIDs = available }
    public mutating func selectNone() { selectedIDs = [] }
    public func approvedBatch(from batch: CleanupBatch) throws -> CleanupBatch {
        guard batchID == batch.id, !selectedIDs.isEmpty, selectedIDs.isSubset(of: available),
              available.count == batch.candidates.count else { throw CleanupError.invalidPlan }
        let plans = try batch.plans.compactMap { plan -> CleanupPlan? in
            var selection = CandidateSelection(plan: plan)
            for candidate in plan.candidates where selectedIDs.contains(candidate.id) { selection.setSelected(candidate.id, true) }
            return selection.selectedIDs.isEmpty ? nil : try selection.approvedPlan(from: plan)
        }
        return CleanupBatch(id: batch.id, mode: batch.mode, plans: plans, requestedRoots: batch.requestedRoots)
    }
}
