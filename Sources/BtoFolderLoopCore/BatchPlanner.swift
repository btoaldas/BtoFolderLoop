// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

public struct BatchPlanner {
    private let fs: FolderFileSystem
    public init(fileSystem: FolderFileSystem) { fs = fileSystem }
    public func analyze(roots: [DirectoryIdentity], mode: CleanupMode, cancellation: CancellationToken = .init(),
                        progress: (Int) -> Void = { _ in }) throws -> CleanupBatch {
        guard !roots.isEmpty, roots.count <= 128 else { throw CleanupError.filesystem("Elige entre 1 y 128 carpetas por lote.") }
        var unique: [DirectoryIdentity] = []
        for root in roots where !unique.contains(where: { $0.identity == root.identity || $0.path == root.path }) { unique.append(root) }
        unique.sort { $0.path < $1.path }
        let top = unique.filter { child in !unique.contains { parent in parent.path != child.path && child.path.hasPrefix(parent.path + "/") } }
        var issues: [ScanIssue] = [], invalid: Set<String> = []
        for root in unique {
            if cancellation.isCancelled { throw CleanupError.cancelled }
            do {
                let actual = try fs.inspect(root.path)
                guard actual.kind == .directory, actual.identity == root.identity else { throw CleanupError.changed(root.path) }
            } catch { invalid.insert(root.path); issues.append(ScanIssue(path: root.path, message: error.localizedDescription)) }
        }
        var plans: [CleanupPlan] = [], total = 0
        for root in top {
            if cancellation.isCancelled { throw CleanupError.cancelled }
            guard !invalid.contains(where: { $0 == root.path || $0.hasPrefix(root.path + "/") }) else { continue }
            do {
                let offset = total
                let plan = try CleanupPlanner(fileSystem: fs).analyze(root: root.path, mode: mode, cancellation: cancellation,
                        maximumDirectories: 250_000 - total, progress: { progress(offset + $0) })
                let nested = unique.filter { $0.path.hasPrefix(root.path + "/") }
                // Even an explicitly dropped nested root remains protected, along with its ancestors.
                let candidates = plan.candidates.filter { candidate in
                    !nested.contains { $0.path == candidate.path || $0.path.hasPrefix(candidate.path + "/") }
                }
                plans.append(CleanupPlan(id: plan.id, root: plan.root, mode: mode, candidates: candidates,
                    directories: plan.directories, issues: plan.issues, scannedDirectories: plan.scannedDirectories,
                    protectedEntries: plan.protectedEntries, createdAt: plan.createdAt))
                total += plan.scannedDirectories
            } catch CleanupError.cancelled { throw CleanupError.cancelled }
            catch CleanupError.limitExceeded { throw CleanupError.limitExceeded }
            catch { issues.append(ScanIssue(path: root.path, message: error.localizedDescription)) }
        }
        return CleanupBatch(mode: mode, plans: plans, issues: issues, requestedRoots: unique)
    }
}
