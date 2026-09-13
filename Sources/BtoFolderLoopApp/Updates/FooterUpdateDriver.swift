// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import Sparkle
import BtoFolderLoopCore

extension ReleaseUpdater: SPUUserDriver, SPUUpdaterDelegate {
    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false))
    }
    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        cancelDownload = cancellation; message = "Verificando el release firmado…"
    }
    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        guard installAuthorized, !workIsBusy(), !appcastItem.isInformationOnlyUpdate else {
            reply(.dismiss); message = "Actualización disponible para revisión manual"; finishSession(); return
        }
        reply(.install)
    }
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}
    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        message = "No hay una actualización firmada compatible"; errorMessage = error.localizedDescription
        acknowledgement(); finishSession()
    }
    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        fail(error); acknowledgement()
    }
    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        record(.updateDownloadStarted)
        cancelDownload = cancellation; receivedBytes = 0; expectedBytes = 0
        message = "Descargando la actualización…"; progress = 0
    }
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) { expectedBytes = expectedContentLength }
    func showDownloadDidReceiveData(ofLength length: UInt64) {
        receivedBytes += length
        if expectedBytes > 0 { progress = min(1, Double(receivedBytes) / Double(expectedBytes)) }
    }
    func showDownloadDidStartExtractingUpdate() {
        cancelDownload = nil; progress = nil; message = "Firma verificada. Preparando la instalación…"
    }
    func showExtractionReceivedProgress(_ progress: Double) { self.progress = min(1, max(0, progress)) }
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        guard installAuthorized, !workIsBusy() else { reply(.skip); finishSession(); return }
        committedToRelaunch = true; message = "Instalando y reiniciando BtoFolderLoop…"; progress = nil
        record(.updateInstalling)
        reply(.install)
    }
    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        committedToRelaunch = true; message = "Instalando y reiniciando BtoFolderLoop…"
    }
    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        message = "Actualización instalada"; acknowledgement()
    }
    func dismissUpdateInstallation() {
        // Once installation is committed, keep folder work blocked until this process exits.
        if !committedToRelaunch { finishSession() }
    }
    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        guard installAuthorized, !workIsBusy() else { throw CleanupError.filesystem("Espera a que termine el trabajo de carpetas.") }
    }
    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate updateItem: SUAppcastItem, updateCheck: SPUUpdateCheck) throws {
        guard installAuthorized, !workIsBusy(), let offer,
              updateItem.displayVersionString == offer.version.description,
              updateItem.fileURL == offer.archiveURL else {
            throw CleanupError.filesystem("El feed firmado no coincide con el release elegido. No se instalará.")
        }
    }
    func updaterShouldRelaunchApplication(_ updater: SPUUpdater) -> Bool { !workIsBusy() && installAuthorized }
}
