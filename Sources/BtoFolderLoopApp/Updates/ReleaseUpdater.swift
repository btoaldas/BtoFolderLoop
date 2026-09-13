// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import Combine
import AppKit
import Sparkle
import BtoFolderLoopCore
import BtoFolderLoopStorage

@MainActor
final class ReleaseUpdater: NSObject, ObservableObject {
    @Published private(set) var offer: ReleaseOffer?
    @Published var message = "Consultar la última versión publicada"
    @Published private(set) var checking = false
    @Published private(set) var installing = false
    @Published var progress: Double?
    @Published var errorMessage: String?
    let installedVersion: ReleaseVersion
    let bundle: Bundle
    let client: ReleaseChecking
    let workIsBusy: () -> Bool
    let activityChanged: (Bool) -> Void
    let record: (DiagnosticCode) -> Void
    var sparkle: SPUUpdater?
    var sparkleStarted = false
    var installAuthorized = false
    var committedToRelaunch = false
    var cancelDownload: (() -> Void)?
    var receivedBytes: UInt64 = 0
    var expectedBytes: UInt64 = 0
    var didInitialCheck = false
    var canInstall: Bool { offer.map { $0.version > installedVersion } == true && !checking && !installing }
    static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }

    init(bundle: Bundle = .main, version: String, client: ReleaseChecking = GitHubReleaseClient(),
         workIsBusy: @escaping () -> Bool, activityChanged: @escaping (Bool) -> Void,
         record: @escaping (DiagnosticCode) -> Void = { _ in }) {
        self.bundle = bundle; installedVersion = ReleaseVersion(version) ?? ReleaseVersion("0.0.0")!
        self.client = client; self.workIsBusy = workIsBusy; self.activityChanged = activityChanged
        self.record = record
    }

    func initialCheck() async {
        guard !didInitialCheck else { return }; didInitialCheck = true
        await check()
    }

    func check() async {
        guard !checking, !installing else { return }
        checking = true; offer = nil; errorMessage = nil; message = "Consultando GitHub…"
        record(.updateCheckStarted)
        defer { checking = false }
        do {
            offer = try await client.latest(architecture: Self.architecture)
            record(.updateCheckCompleted)
            guard let offer else { message = "Sin release compatible para este Mac"; return }
            if offer.version > installedVersion { message = "Disponible \(offer.version)" + (offer.preview ? " · preliminar" : "") }
            else if offer.version == installedVersion { message = "Estás en la última versión publicada" }
            else { message = "Compilación más nueva · publicada \(offer.version)" }
        } catch { record(.updateCheckFailed); message = "No se pudo consultar la versión"; errorMessage = error.localizedDescription }
    }

    func install() {
        guard canInstall, !workIsBusy() else { return }
        errorMessage = nil; installAuthorized = true; committedToRelaunch = false
        record(.updateRequested)
        setInstalling(true); message = "Verificando el release firmado…"
        if sparkle == nil { sparkle = SPUUpdater(hostBundle: bundle, applicationBundle: bundle, userDriver: self, delegate: self) }
        do {
            guard let sparkle else { return }
            if !sparkleStarted { try sparkle.start(); sparkleStarted = true }
            guard sparkle.canCheckForUpdates else { throw CleanupError.filesystem("El actualizador aún está terminando una operación. Vuelve a intentarlo.") }
            sparkle.checkForUpdates()
        } catch { fail(error) }
    }

    func cancel() {
        guard !committedToRelaunch, let cancelDownload else { return }
        self.cancelDownload = nil; cancelDownload()
        record(.updateCancelled)
        message = "Actualización cancelada"; finishSession()
    }

    func setInstalling(_ value: Bool) { installing = value; activityChanged(value) }
    func finishSession() {
        installAuthorized = false; cancelDownload = nil; progress = nil
        setInstalling(false)
    }
    func fail(_ error: Error) {
        record(.updateFailed)
        errorMessage = error.localizedDescription; message = "No se pudo completar la actualización"
        committedToRelaunch = false; finishSession()
    }
}
