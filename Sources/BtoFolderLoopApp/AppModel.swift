// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import AppKit
import BtoFolderLoopCore
import BtoFolderLoopMac
import BtoFolderLoopStorage

@MainActor
final class AppModel: ObservableObject {
    @Published var root: URL?
    @Published var mode: CleanupMode = .singlePass
    @Published var plan: CleanupPlan?
    @Published private(set) var selection = CandidateSelection()
    @Published private(set) var pendingApproval: CleanupPlan?
    @Published var report: CleanupReport?
    @Published var busy = false
    @Published var status = "Elige una carpeta para empezar."
    @Published var error: String?
    @Published var history: [RunSummary] = []
    @Published var journalText = ""
    @Published var showHistory = false
    @Published var showConfirmation = false
    private var token = CancellationToken()
    private let fileSystem = NativeFileSystem()
    private(set) var store: SQLiteStore?

    init() {
        do {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            // The test override is used only for synthetic UI smoke tests; no fixtures ship with the app.
            let base = ProcessInfo.processInfo.environment["BTOFOLDERLOOP_TEST_DATA"].map { URL(fileURLWithPath: $0) }
                ?? support.appendingPathComponent("BtoFolderLoop", isDirectory: true)
            let store = try SQLiteStore(location: base.appendingPathComponent("settings.sqlite"))
            self.store = store
            mode = try store.loadMode()
        } catch { self.error = error.localizedDescription }
    }

    func choose() {
        guard !busy else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false; panel.prompt = "Analizar carpeta"
        if panel.runModal() == .OK, let url = panel.url { select(url) }
    }

    func select(_ url: URL) {
        guard !busy else { return }
        guard url.isFileURL else { error = "Arrastra una carpeta local."; return }
        root = url.standardizedFileURL
        analyze()
    }

    func changeMode(_ newMode: CleanupMode) {
        guard !busy else { return }
        mode = newMode; plan = nil; report = nil
        resetSelection()
        do { try store?.saveMode(mode) }
        catch { self.error = error.localizedDescription; return }
        if root != nil { analyze() }
    }

    func analyze() {
        guard !busy, let root else { return }
        resetSelection()
        guard store != nil else { error = "El registro local no está disponible. Cierra y vuelve a abrir la app."; return }
        plan = nil; report = nil; error = nil; busy = true
        token = CancellationToken()
        status = "Leyendo carpetas… No se está moviendo nada."
        let selectedMode = mode, cancellation = token, fs = fileSystem
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try CleanupPlanner(fileSystem: fs).analyze(root: root.path, mode: selectedMode, cancellation: cancellation) { count in
                        Task { @MainActor [weak self] in self?.status = "\(count.formatted()) carpetas revisadas…" }
                    }
                }.value
                plan = result
                selection = CandidateSelection(plan: result)
                status = result.candidates.isEmpty ? "No se encontraron carpetas vacías que se puedan retirar."
                    : "Marca las carpetas que quieras enviar. Todas empiezan desmarcadas."
            } catch {
                if cancellation.isCancelled { status = "Análisis cancelado. No se movió nada." }
                else { self.error = error.localizedDescription; status = "No se pudo completar el análisis." }
            }
            busy = false
        }
    }

    private func resetSelection() {
        selection = CandidateSelection(); pendingApproval = nil; showConfirmation = false
    }

    func setSelected(_ id: String, _ selected: Bool) {
        guard !busy, !showConfirmation else { return }
        selection.setSelected(id, selected)
    }
    func selectAll() { guard !busy, !showConfirmation else { return }; selection.selectAll() }
    func selectNone() { guard !busy, !showConfirmation else { return }; selection.selectNone() }

    func reviewSelection() {
        guard !busy, let plan, !selection.selectedIDs.isEmpty else { return }
        do {
            pendingApproval = try selection.approvedPlan(from: plan)
            showConfirmation = true
        } catch { self.error = error.localizedDescription }
    }

    func cancelApproval() { pendingApproval = nil; showConfirmation = false }

    func executeApprovedPlan() {
        guard !busy, let plan = pendingApproval, let current = self.plan,
              current.id == plan.id, let store, !plan.candidates.isEmpty,
              Set(plan.candidates.map(\.id)) == selection.selectedIDs else { return }
        self.plan = nil // Consume the approval once; cannot run the same plan twice from the UI.
        resetSelection()
        busy = true; error = nil; token = CancellationToken()
        status = "Comprobando y enviando carpetas vacías a la Papelera…"
        let cancellation = token, fs = fileSystem
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try CleanupExecutor(fileSystem: fs, journal: store).execute(plan, cancellation: cancellation) { done, total in
                        Task { @MainActor [weak self] in self?.status = "\(done.formatted()) de \(total.formatted()) carpetas comprobadas…" }
                    }
                }.value
                report = result
                status = result.cancelled ? "Detenido por ti. Los movimientos realizados están registrados."
                    : (result.errors.isEmpty ? "Proceso terminado." : "Proceso detenido. Revisa el detalle antes de continuar.")
            } catch { self.error = error.localizedDescription; status = "Proceso detenido." }
            busy = false
        }
    }

    func cancel() { token.cancel(); status = "Deteniendo después de la operación actual…" }

    func openHistory() {
        do {
            history = try store?.recentRuns() ?? []
            journalText = try store?.journalText() ?? ""
            showHistory = true
        } catch { self.error = error.localizedDescription }
    }
    func revealDatabase() {
        if let url = store?.location { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }
}
