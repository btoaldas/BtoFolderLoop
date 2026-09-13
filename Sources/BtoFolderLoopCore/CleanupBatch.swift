// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

public struct BatchCandidate: Identifiable, Sendable {
    public var id: String { candidate.id }
    public let candidate: Candidate
    public let rootPath: String
    public var path: String { candidate.path }
    public var relativePath: String { candidate.relativePath }
    public var initiallyEmpty: Bool { candidate.initiallyEmpty }
    public var pass: Int { candidate.pass }
}

public struct CleanupBatch: Sendable {
    public let id: UUID
    public let mode: CleanupMode
    public let plans: [CleanupPlan]
    public let candidates: [BatchCandidate]
    public let issues: [ScanIssue]
    public let requestedRoots: [DirectoryIdentity]
    public var scannedDirectories: Int { plans.reduce(0) { $0 + $1.scannedDirectories } }
    public var passes: Int { plans.map(\.passes).max() ?? 0 }
    public init(id: UUID = UUID(), mode: CleanupMode, plans: [CleanupPlan], issues: [ScanIssue] = [], requestedRoots: [DirectoryIdentity]) {
        self.id = id; self.mode = mode; self.plans = plans; self.requestedRoots = requestedRoots
        candidates = plans.flatMap { plan in plan.candidates.map { BatchCandidate(candidate: $0, rootPath: plan.root.path) } }
        self.issues = issues + plans.flatMap(\.issues)
    }
}
