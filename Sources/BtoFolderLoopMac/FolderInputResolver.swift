// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import BtoFolderLoopCore

public struct ResolvedFolder: Identifiable, Sendable {
    public var id: String { input.path }
    public let input: URL
    public let url: URL
    public let directory: DirectoryIdentity
    public let shortcut: Bool
}

/// Resolve only user-supplied inputs. The tree scanner still never follows internal links.
public struct FolderInputResolver: Sendable {
    public init() {}
    public func resolve(_ input: URL) throws -> ResolvedFolder {
        guard input.isFileURL else { throw CleanupError.filesystem("Solo se admiten carpetas locales o accesos directos del Finder.") }
        let fs = NativeFileSystem()
        var current = input.standardizedFileURL, visited: Set<String> = []
        var shortcut = false
        for _ in 0..<32 {
            guard visited.insert(current.path).inserted else { throw CleanupError.filesystem("El acceso directo forma un ciclo; se conserva.") }
            let resolved = current.resolvingSymlinksInPath()
            if resolved.path != current.path { shortcut = true; current = resolved }
            let values = try current.resourceValues(forKeys: [.isAliasFileKey, .canonicalPathKey])
            if values.isAliasFile == true {
                shortcut = true
                current = try URL(resolvingAliasFileAt: current, options: [.withoutUI, .withoutMounting]).standardizedFileURL
                continue
            }
            if let canonical = values.canonicalPath { current = URL(fileURLWithPath: canonical) }
            let entry = try fs.inspect(current.path)
            guard entry.kind == .directory else {
                throw CleanupError.filesystem("El destino no es una carpeta admitida. Los archivos, paquetes y accesos rotos se conservan; los .lnk de Windows no se resuelven.")
            }
            return ResolvedFolder(input: input, url: current, directory: DirectoryIdentity(path: current.path, identity: entry.identity), shortcut: shortcut)
        }
        throw CleanupError.filesystem("El acceso directo tiene demasiados saltos; se conserva.")
    }
}
