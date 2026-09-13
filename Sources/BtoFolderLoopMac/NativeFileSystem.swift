// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import Darwin
import BtoFolderLoopCore

@_silgen_name("setiopolicy_np") private func setIOPolicy(_ type: Int32, _ scope: Int32, _ value: Int32) -> Int32
@_silgen_name("getiopolicy_np") private func getIOPolicy(_ type: Int32, _ scope: Int32) -> Int32

public final class NativeFileSystem: FolderFileSystem, @unchecked Sendable {
    private static let gate = NSRecursiveLock()
    private let fm = FileManager.default
    private let packageExtensions: Set<String> = ["app", "bundle", "framework", "plugin", "photoslibrary", "photolibrary", "xcodeproj", "xcworkspace", "playground", "sparsebundle", "band"]
    private let protectedNames: Set<String> = [".git", ".hg", ".svn", ".Trash", ".Trashes", ".dtrash", ".DocumentRevisions-V100", ".Spotlight-V100", ".fseventsd"]
    public init() {}

    private func withPolicy<T>(_ value: Int32, _ body: () throws -> T) throws -> T {
        Self.gate.lock(); defer { Self.gate.unlock() }
        let old = getIOPolicy(3, 0)
        guard old >= 0, setIOPolicy(3, 0, value) == 0 else {
            throw CleanupError.filesystem("No se pudo establecer la política segura de acceso a carpetas.")
        }
        defer { _ = setIOPolicy(3, 0, old) }
        return try body()
    }

    public func inspect(_ path: String) throws -> FileEntry {
        try withPolicy(1) { try readEntry(path) }
    }

    private func readEntry(_ path: String, protectPaths: Bool = true) throws -> FileEntry {
        var s = stat()
        guard lstat(path, &s) == 0 else {
            throw CleanupError.filesystem("No se pudo leer la carpeta o entrada: \(path) (\(String(cString: strerror(errno)))).")
        }
        let identity = FileIdentity(device: UInt64(UInt32(bitPattern: s.st_dev)), inode: UInt64(s.st_ino))
        let type = s.st_mode & S_IFMT
        let kind: EntryKind
        if type == S_IFLNK { kind = .symbolicLink }
        else if type == S_IFDIR {
            let url = URL(fileURLWithPath: path)
            let systemRoots: Set<String> = ["/", "/System", "/Library", "/Applications", "/Users", "/Volumes", NSHomeDirectory(), NSHomeDirectory() + "/Library"]
            let knownPackage = packageExtensions.contains(url.pathExtension.lowercased())
            let systemPackage = (try? url.resourceValues(forKeys: [.isPackageKey]).isPackage) ?? false
            let protectedAncestor = url.pathComponents.contains { protectedNames.contains($0) || packageExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
            kind = protectPaths && (s.st_flags != 0 || systemRoots.contains(path) || protectedAncestor || knownPackage || systemPackage) ? .protected : .directory
        } else { kind = .file }
        var linkTarget: String?
        if kind == .symbolicLink, let destination = try? fm.destinationOfSymbolicLink(atPath: path) {
            let base = URL(fileURLWithPath: path).deletingLastPathComponent()
            linkTarget = URL(fileURLWithPath: destination, relativeTo: base).standardizedFileURL.path
        }
        return FileEntry(path: path, identity: identity, kind: kind, linkTarget: linkTarget)
    }

    public func children(_ path: String) throws -> [FileEntry] {
        try withPolicy(1) {
            guard try readEntry(path).kind == .directory else { throw CleanupError.changed(path) }
            return try fm.contentsOfDirectory(atPath: path).map {
                try readEntry(URL(fileURLWithPath: path).appendingPathComponent($0).path)
            }
        }
    }

    public func trashEmpty(_ candidate: Candidate, ancestors: [DirectoryIdentity]) throws -> TrashOutcome {
        try withPolicy(1) {
            guard !ancestors.isEmpty, !ancestors.contains(where: { $0.path == candidate.path }) else { throw CleanupError.invalidPlan }
            func check() throws {
                for ancestor in ancestors {
                    let entry = try readEntry(ancestor.path)
                    guard entry.kind == .directory && entry.identity == ancestor.identity else { throw CleanupError.changed(ancestor.path) }
                }
                var outer = URL(fileURLWithPath: candidate.path).deletingLastPathComponent()
                while outer.path != "/" {
                    guard try readEntry(outer.path).kind != .symbolicLink else { throw CleanupError.changed(outer.path) }
                    outer.deleteLastPathComponent()
                }
                let current = try readEntry(candidate.path)
                guard current.kind == .directory && current.identity == candidate.identity else { throw CleanupError.changed(candidate.path) }
            }
            try check()
            guard try fm.contentsOfDirectory(atPath: candidate.path).isEmpty else { return .skipped("Ahora contiene alguna entrada; se conservó.") }
            try check()
            guard try fm.contentsOfDirectory(atPath: candidate.path).isEmpty else { return .skipped("El contenido cambió; se conservó.") }
            // Native Trash may need File Provider bookkeeping. Permit it only for this verified empty directory.
            var destination: NSURL?
            try withPolicy(2) { try fm.trashItem(at: URL(fileURLWithPath: candidate.path), resultingItemURL: &destination) }
            guard let target = destination as URL? else {
                throw CleanupError.filesystem("macOS no devolvió el destino de Papelera. Se detuvo el proceso; revisa el registro y la Papelera.")
            }
            let receipt = TrashReceipt(source: candidate.path, destination: target.path, identity: candidate.identity)
            var s = stat()
            let exists = lstat(candidate.path, &s)
            guard exists != 0 && errno == ENOENT else {
                throw CleanupError.filesystem("Verificación detenida: el origen reapareció. Destino registrado: \(target.path)")
            }
            let after = try readEntry(target.path, protectPaths: false)
            guard after.identity == candidate.identity && after.kind == .directory,
                  try fm.contentsOfDirectory(atPath: target.path).isEmpty else {
                throw CleanupError.filesystem("El destino cambió durante el traslado. No se hicieron más movimientos. Revisa: \(target.path)")
            }
            return .moved(receipt)
        }
    }
}
