// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Selection belongs to one scan and always begins empty. It never expands dependencies.
public struct CandidateSelection: Sendable {
    public private(set) var selectedIDs: Set<String> = []
    private let planID: UUID?
    private let availableIDs: Set<String>

    public init(plan: CleanupPlan? = nil) {
        planID = plan?.id
        availableIDs = Set(plan?.candidates.map(\.id) ?? [])
    }

    public mutating func setSelected(_ id: String, _ selected: Bool) {
        guard availableIDs.contains(id) else { return }
        if selected { selectedIDs.insert(id) } else { selectedIDs.remove(id) }
    }

    public mutating func selectAll() { selectedIDs = availableIDs }
    public mutating func selectNone() { selectedIDs = [] }

    public func approvedPlan(from plan: CleanupPlan) throws -> CleanupPlan {
        guard planID == plan.id, !selectedIDs.isEmpty,
              selectedIDs.isSubset(of: Set(plan.candidates.map(\.id))) else { throw CleanupError.invalidPlan }
        // Keep the original order, identities, scan UUID and ancestor proofs. A selected parent
        // is skipped by the native adapter if an unselected child still occupies it.
        return CleanupPlan(id: plan.id, root: plan.root, mode: plan.mode,
                           candidates: plan.candidates.filter { selectedIDs.contains($0.id) },
                           directories: plan.directories, issues: plan.issues,
                           scannedDirectories: plan.scannedDirectories,
                           protectedEntries: plan.protectedEntries, createdAt: plan.createdAt)
    }
}
