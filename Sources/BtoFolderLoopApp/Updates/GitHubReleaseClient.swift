// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import BtoFolderLoopCore

protocol ReleaseChecking: Sendable {
    func latest(architecture: String) async throws -> ReleaseOffer?
}

struct GitHubReleaseClient: ReleaseChecking {
    func latest(architecture: String) async throws -> ReleaseOffer? {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.httpShouldSetCookies = false
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        // /latest excludes previews; this project's published previews also need to be discoverable.
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/btoaldas/BtoFolderLoop/releases?per_page=30")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("BtoFolderLoop", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CleanupError.filesystem("No se pudo consultar GitHub. Puedes volver a intentarlo.")
        }
        return try ReleaseCatalog.latestCompatible(in: data, architecture: architecture)
    }
}
