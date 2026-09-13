// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import AppKit
import BtoFolderLoopCore
import BtoFolderLoopMac
import BtoFolderLoopStorage

@MainActor
final class AppModel: ObservableObject {
    @Published var inputURLs: [URL] = []
    @Published var resolvedFolders: [ResolvedFolder] = []
    @Published var inputIssues: [ScanIssue] = []
    var root: URL? { resolvedFolders.first?.url }
    @Published var mode: CleanupMode = .singlePass
    @Published var plan: CleanupBatch?
    @Published private(set) var selection = BatchSelection()
    @Published private(set) var pendingApproval: CleanupBatch?
    @Published var report: CleanupReport?
    @Published var busy = false
    @Published var updating = false
    @Published var updates: ReleaseUpdater?
    var canWork: Bool { !busy && !updating }
    @Published var activeRunID: String?
    @Published var status = "Elige una carpeta para empezar."
    @Published var error: String?
    @Published var history: [RunSummary] = []
    @Published var folders: [FolderHistory] = []
    @Published var historyEvents: [JournalEvent] = []
    @Published var historyRunID: String?
    @Published var hasOlderEvents = false
    @Published var showSettings = false
    @Published var retention = RetentionPolicy()
    @Published var settingsDraft = RetentionPolicy()
    @Published var diagnosticWarning: String?
    @Published var showHistory = false
    @Published var showConfirmation = false
    var token = CancellationToken()
    let fileSystem = NativeFileSystem()
    private(set) var store: SQLiteStore?
    var diagnostics: DiagnosticLog?
    var lastMaintenance = Date.distantPast

    init(storageDirectory: URL? = nil) {
        do {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            // The test override is used only for synthetic UI smoke tests; no fixtures ship with the app.
            let base = storageDirectory ?? ProcessInfo.processInfo.environment["BTOFOLDERLOOP_TEST_DATA"].map { URL(fileURLWithPath: $0) }
                ?? support.appendingPathComponent("BtoFolderLoop", isDirectory: true)
            let store = try SQLiteStore(location: base.appendingPathComponent("settings.sqlite"))
            self.store = store
            mode = try store.loadMode()
            retention = try store.loadRetention(); settingsDraft = retention
            do { diagnostics = try DiagnosticLog(directory: base.appendingPathComponent("Diagnostics"), policy: retention) }
            catch { diagnosticWarning = "El diagnóstico no está disponible. El registro de movimientos se mantiene separado." }
            log(.applicationOpened)
            maintainIfIdle()
        } catch { self.error = error.localizedDescription }
        if storageDirectory == nil, ProcessInfo.processInfo.environment["BTOFOLDERLOOP_TEST_DATA"] == nil {
            updates = ReleaseUpdater(version: BrandAssets.version,
                                     workIsBusy: { [weak self] in self?.busy ?? true },
                                     activityChanged: { [weak self] active in self?.updating = active },
                                     record: { [weak self] code in self?.log(code) })
        }
    }

    func resetSelection(for batch: CleanupBatch? = nil) {
        selection = BatchSelection(batch: batch); pendingApproval = nil; showConfirmation = false
    }

    func setSelected(_ id: String, _ selected: Bool) {
        guard canWork, !showConfirmation else { return }
        selection.setSelected(id, selected)
    }
    func selectAll() { guard canWork, !showConfirmation else { return }; selection.selectAll() }
    func selectNone() { guard canWork, !showConfirmation else { return }; selection.selectNone() }

    func reviewSelection() {
        guard canWork, let plan, !selection.selectedIDs.isEmpty else { return }
        do {
            pendingApproval = try selection.approvedBatch(from: plan)
            showConfirmation = true
        } catch { self.error = error.localizedDescription }
    }

    func cancelApproval() { pendingApproval = nil; showConfirmation = false }

    func executeApprovedPlan() {
        guard canWork, let plan = pendingApproval, let current = self.plan,
              current.id == plan.id, let store, !plan.candidates.isEmpty,
              Set(plan.candidates.map(\.id)) == selection.selectedIDs else { return }
        self.plan = nil // Consume the approval once; cannot run the same plan twice from the UI.
        resetSelection()
        busy = true; error = nil; token = CancellationToken()
        activeRunID = nil
        status = "Comprobando y enviando carpetas vacías a la Papelera…"
        let cancellation = token, fs = fileSystem
        let journal = ObservedJournal(store: store, log: diagnostics) { [weak self] in
            Task { @MainActor in self?.diagnosticWarning = "No se pudo escribir el diagnóstico. Consulta el registro de movimientos." }
        }
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try BatchExecutor(fileSystem: fs, journal: journal).execute(plan, cancellation: cancellation) { done, total, runID in
                        Task { @MainActor [weak self] in
                            guard let self, self.busy, self.token === cancellation else { return }
                            self.activeRunID = runID.uuidString
                            self.status = "\(done.formatted()) de \(total.formatted()) carpetas comprobadas…"
                        }
                    }
                }.value
                report = result
                status = result.cancelled ? "Detenido por ti. Los movimientos realizados están registrados."
                    : (result.errors.isEmpty ? "Proceso terminado." : "Lote detenido. Las carpetas pendientes se conservan; revisa el detalle.")
            } catch { log(.cleanupStopped); self.error = error.localizedDescription; status = "Proceso detenido." }
            activeRunID = nil; busy = false
            maintainIfIdle()
        }
    }

    func cancel() { token.cancel(); status = "Deteniendo después de la operación actual…" }

    func openHistory() {
        do {
            try refreshHistory()
            showHistory = true
        } catch { self.error = error.localizedDescription }
    }
    func revealDatabase() {
        if let url = store?.location { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }
}
