// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

public struct ReleaseVersion: Comparable, Sendable, CustomStringConvertible {
    private let parts: [Int]
    public init?(_ text: String) {
        let version = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let components = version.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3 else { return nil }
        var result: [Int] = []
        for item in components {
            guard !item.isEmpty, item.utf8.allSatisfy({ (48...57).contains($0) }),
                  item.count == 1 || !item.hasPrefix("0"), let value = Int(item) else { return nil }
            result.append(value)
        }
        parts = result
    }
    public var description: String { parts.map(String.init).joined(separator: ".") }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.parts.lexicographicallyPrecedes(rhs.parts) }
}

public struct ReleaseOffer: Equatable, Sendable {
    public let version: ReleaseVersion
    public let archiveURL: URL
    public let pageURL: URL
    public let preview: Bool
    public init(version: ReleaseVersion, archiveURL: URL, pageURL: URL, preview: Bool) {
        self.version = version; self.archiveURL = archiveURL; self.pageURL = pageURL; self.preview = preview
    }
}

public enum ReleaseCatalog {
    private struct Release: Decodable {
        let tag_name: String
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
    }
    private struct Asset: Decodable {
        let name: String
        let browser_download_url: URL
    }
    public static func latestCompatible(in data: Data, architecture: String) throws -> ReleaseOffer? {
        guard ["arm64", "x86_64"].contains(architecture), data.count <= 4 * 1024 * 1024 else {
            throw CleanupError.filesystem("La respuesta de versiones no es válida.")
        }
        return try JSONDecoder().decode([Release].self, from: data).compactMap { release -> ReleaseOffer? in
            guard !release.draft, let version = ReleaseVersion(release.tag_name), release.tag_name == "v" + version.description else { return nil }
            let name = "BtoFolderLoop-\(version)-macos-\(architecture).zip"
            let expected = URL(string: "https://github.com/btoaldas/BtoFolderLoop/releases/download/\(release.tag_name)/\(name)")!
            guard release.assets.contains(where: { $0.name == name && $0.browser_download_url == expected }) else { return nil }
            return ReleaseOffer(version: version, archiveURL: expected,
                                pageURL: URL(string: "https://github.com/btoaldas/BtoFolderLoop/releases/tag/\(release.tag_name)")!, preview: release.prerelease)
        }.max { $0.version < $1.version }
    }
}
