// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import BtoFolderLoopCore
import BtoFolderLoopMac

extension AppModel {
    func choose() {
        guard canWork else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = true
        panel.resolvesAliases = false; panel.allowsMultipleSelection = true
        panel.prompt = "Analizar carpetas"
        panel.message = "Elige carpetas o accesos directos del Finder. Los archivos normales se conservan."
        if panel.runModal() == .OK { select(panel.urls) }
    }

    func select(_ url: URL) { select([url]) }
    func select(_ urls: [URL]) {
        guard canWork else { return }
        guard !urls.isEmpty, urls.count <= 128 else { error = "Elige entre 1 y 128 carpetas o accesos directos por lote."; return }
        inputURLs = urls
        analyze()
    }

    func changeMode(_ newMode: CleanupMode) {
        guard canWork else { return }
        mode = newMode; plan = nil; report = nil; resetSelection()
        do { try store?.saveMode(mode) }
        catch { self.error = error.localizedDescription; return }
        if !inputURLs.isEmpty { analyze() }
    }

    func analyze() {
        guard canWork, !inputURLs.isEmpty else { return }
        resetSelection()
        guard store != nil else { error = "El registro local no está disponible. Cierra y vuelve a abrir la app."; return }
        plan = nil; report = nil; error = nil; busy = true
        resolvedFolders = []; inputIssues = []
        token = CancellationToken()
        status = "Resolviendo rutas y leyendo carpetas… No se está moviendo nada."
        log(.scanStarted)
        let selectedMode = mode, cancellation = token, fs = fileSystem, inputs = inputURLs
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    var folders: [ResolvedFolder] = [], issues: [ScanIssue] = []
                    for input in inputs {
                        if cancellation.isCancelled { throw CleanupError.cancelled }
                        do { folders.append(try FolderInputResolver().resolve(input)) }
                        catch { issues.append(ScanIssue(path: input.path, message: error.localizedDescription)) }
                    }
                    let batch = folders.isEmpty ? nil : try BatchPlanner(fileSystem: fs).analyze(roots: folders.map(\.directory), mode: selectedMode, cancellation: cancellation) { count in
                        Task { @MainActor [weak self] in
                            guard let self, self.busy, self.token === cancellation else { return }
                            self.status = "\(count.formatted()) carpetas revisadas en el lote…"
                        }
                    }
                    return (folders, issues, batch)
                }.value
                resolvedFolders = result.0; inputIssues = result.1; plan = result.2
                log(.scanCompleted, count: plan?.scannedDirectories ?? 0)
                resetSelection(for: plan)
                if plan == nil { status = "No hay carpetas válidas para analizar. Revisa las entradas indicadas." }
                else if plan?.candidates.isEmpty == true { status = "Análisis terminado. No se encontraron carpetas vacías que se puedan retirar." }
                else { status = "Marca las carpetas que quieras enviar. Todas empiezan desmarcadas." }
            } catch {
                log(.scanStopped)
                if cancellation.isCancelled { status = "Análisis cancelado. No se movió nada." }
                else { self.error = error.localizedDescription; status = "No se pudo completar el lote; no se habilita una selección parcial." }
            }
            busy = false
            maintainIfIdle()
        }
    }
}
