// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import AppKit
import BtoFolderLoopCore
import BtoFolderLoopStorage

extension AppModel {
    func log(_ code: DiagnosticCode, count: Int? = nil) {
        do { try diagnostics?.write(code, runID: activeRunID.flatMap(UUID.init(uuidString:)), count: count) }
        catch { diagnosticWarning = "No se pudo escribir el diagnóstico. Consulta el registro de movimientos." }
    }

    func maintainIfIdle() {
        guard !busy, Date().timeIntervalSince(lastMaintenance) >= 86400, let store else { return }
        do {
            let expired = try store.expireCompletedHistory(policy: retention)
            try diagnostics?.maintain()
            lastMaintenance = Date()
            log(.maintenanceCompleted, count: expired)
        } catch {
            // Back off until the next idle hourly retry; never spin or interrupt cleanup.
            lastMaintenance = Date().addingTimeInterval(-23 * 3600)
            diagnosticWarning = "No se pudo completar la retención de registros. Se volverá a intentar mientras la app esté inactiva."
            log(.maintenanceFailed)
        }
    }

    func openSettings() {
        guard !busy else { return }
        settingsDraft = retention; showSettings = true
    }

    func saveSettings() {
        guard !busy, let store else { return }
        do {
            try settingsDraft.validate()
            try store.saveRetention(settingsDraft)
            retention = settingsDraft
            try diagnostics?.configure(retention)
            log(.preferencesSaved)
            showSettings = false
            lastMaintenance = .distantPast
            maintainIfIdle()
        } catch { self.error = error.localizedDescription }
    }

    func refreshHistory() throws {
        history = try store?.recentRuns() ?? []
        folders = try store?.folderHistory() ?? []
        if historyRunID == nil || !history.contains(where: { $0.id == historyRunID }) { historyRunID = history.first?.id }
        if let id = historyRunID { try loadEvents(id) }
        else { historyEvents = []; hasOlderEvents = false }
    }

    func loadEvents(_ id: String, older: Bool = false) throws {
        historyRunID = id
        let events = try store?.events(runID: id, beforeID: older ? historyEvents.last?.id : nil) ?? []
        // One page at a time keeps very large operation histories bounded in the UI.
        historyEvents = events; hasOlderEvents = events.count == 200
    }

    func selectHistoryRun(_ id: String) {
        do { try loadEvents(id) } catch { self.error = error.localizedDescription }
    }

    func olderHistoryEvents() {
        guard let id = historyRunID else { return }
        do { try loadEvents(id, older: true) } catch { self.error = error.localizedDescription }
    }

    func revealDiagnostics() {
        if let url = diagnostics?.directory { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }
}
