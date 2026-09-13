// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

public struct CleanupPlanner {
    private let fs: FolderFileSystem
    public init(fileSystem: FolderFileSystem) { fs = fileSystem }

    public func analyze(root: String, mode: CleanupMode, cancellation: CancellationToken = .init(),
                        maximumDirectories: Int = 250_000,
                        progress: (Int) -> Void = { _ in }) throws -> CleanupPlan {
        let rootPath = URL(fileURLWithPath: root).standardizedFileURL.path
        guard rootPath != "/" else { throw CleanupError.unsafeRoot }
        let rootEntry = try fs.inspect(rootPath)
        guard rootEntry.kind == .directory else { throw CleanupError.unsafeRoot }
        // Validate every component above the chosen root too; a symlink ancestor is unsafe.
        var ancestor = URL(fileURLWithPath: rootPath).deletingLastPathComponent()
        while ancestor.path != "/" {
            guard try fs.inspect(ancestor.path).kind != .symbolicLink else { throw CleanupError.unsafeRoot }
            ancestor.deleteLastPathComponent()
        }
        var directories: [String: DirectoryIdentity] = [:]
        var contents: [String: [FileEntry]] = [:]
        var issues: [ScanIssue] = []
        var protectedCount = 0
        var linkTargets: Set<String> = []
        var queue = [rootEntry]
        while let dir = queue.popLast() {
            if cancellation.isCancelled { throw CleanupError.cancelled }
            guard directories.count < maximumDirectories else { throw CleanupError.limitExceeded }
            directories[dir.path] = DirectoryIdentity(path: dir.path, identity: dir.identity)
            do {
                let now = try fs.inspect(dir.path)
                guard now.kind == .directory && now.identity == dir.identity else { throw CleanupError.changed(dir.path) }
                let children = try fs.children(dir.path)
                contents[dir.path] = children
                for child in children {
                    if let target = child.linkTarget { linkTargets.insert(target) }
                    if child.kind == .directory && child.identity.device == rootEntry.identity.device {
                        queue.append(child)
                    } else { protectedCount += 1 }
                }
            } catch {
                if dir.path == rootPath { throw error }
                issues.append(ScanIssue(path: dir.path, message: error.localizedDescription))
            }
            if directories.count % 100 == 0 { progress(directories.count) }
        }
        // Postorder dynamic programming predicts exactly the approved cascade, without mutation.
        var removablePass: [String: Int] = [:]
        var candidates: [Candidate] = []
        let postorder = directories.keys.sorted {
            let a = $0.split(separator: "/").count, b = $1.split(separator: "/").count
            return a == b ? $0 < $1 : a > b
        }
        for path in postorder where path != rootPath {
            guard let children = contents[path], let directory = directories[path] else { continue }
            // Preserve targets of links discovered in this tree, and ancestors of those targets.
            guard !linkTargets.contains(where: { $0 == path || $0.hasPrefix(path + "/") }) else { continue }
            let pass: Int
            if children.isEmpty { pass = 1 }
            else if mode == .cascade && children.allSatisfy({ removablePass[$0.path] != nil }) {
                pass = 1 + (children.compactMap { removablePass[$0.path] }.max() ?? 0)
            } else { continue }
            removablePass[path] = pass
            candidates.append(Candidate(path: path, relativePath: String(path.dropFirst(rootPath.count + 1)),
                                        identity: directory.identity, pass: pass))
        }
        candidates.sort { $0.pass == $1.pass ? $0.relativePath < $1.relativePath : $0.pass < $1.pass }
        return CleanupPlan(id: UUID(), root: DirectoryIdentity(path: rootPath, identity: rootEntry.identity),
                           mode: mode, candidates: candidates, directories: directories, issues: issues,
                           scannedDirectories: directories.count, protectedEntries: protectedCount, createdAt: Date())
    }
}
