// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import BtoFolderLoopCore

struct HistoryView: View {
    @ObservedObject var model: AppModel
    @State private var section = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                BrandIcon(size: 32); Text("Registro local").font(.title2.bold()); Spacer()
                Button("Actualizar", action: model.openHistory)
                Button("Cerrar") { model.showHistory = false }
            }
            Text("Rutas privadas: se guardan solo en este Mac. Historial: \(model.retention.historyDays) días; diagnóstico: \(model.retention.diagnosticDays) días.")
                .font(.caption).foregroundStyle(.secondary)
            if model.busy { Text(model.status).font(.callout).foregroundStyle(.tint) }
            if let error = model.error { Text(error).font(.caption).foregroundStyle(.orange) }
            Picker("Vista", selection: $section) {
                Text("Operaciones").tag(0); Text("Carpetas trabajadas").tag(1)
            }.pickerStyle(.segmented)
            if section == 0 {
                List(model.history) { run in
                    Button { model.selectHistoryRun(run.id) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(URL(fileURLWithPath: run.root).lastPathComponent).font(.headline)
                                Spacer(); Text(run.id == model.activeRunID ? "En curso" : run.statusTitle)
                            }
                            Text(run.root).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            Text("\(CleanupMode(rawValue: run.mode)?.title ?? run.mode) · \(run.moved) de \(run.planned) enviadas · \(run.skipped) conservadas · \(run.errors) errores").font(.caption)
                            Text("Inicio: \(localDate(run.date)) · Última actividad: \(localDate(run.updatedAt))").font(.caption2).foregroundStyle(.secondary)
                        }.padding(5).frame(maxWidth: .infinity, alignment: .leading)
                            .background(model.historyRunID == run.id ? Color.accentColor.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }.buttonStyle(.plain)
                }.frame(height: 170)
                HStack {
                    Text("Detalle de la operación seleccionada · hasta 200 eventos por página").font(.caption)
                    Spacer()
                    Button("Recientes") { if let id = model.historyRunID { model.selectHistoryRun(id) } }
                    Button("Anteriores", action: model.olderHistoryEvents).disabled(!model.hasOlderEvents)
                }
                List(model.historyEvents) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title + " · " + localDate(event.date)).font(.caption.bold())
                        Text(event.source).font(.caption).textSelection(.enabled)
                        if !event.destination.isEmpty { Text("Papelera: " + event.destination).font(.caption).textSelection(.enabled) }
                        if !event.detail.isEmpty { Text(event.detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                    }.padding(.vertical, 3)
                }
            } else {
                List(model.folders) { folder in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(folder.path).textSelection(.enabled)
                        Text("\(folder.runs) operaciones · \(folder.moved) enviadas · Última actividad: \(localDate(folder.lastActivity))")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }
            }
            Text("Se muestran las 200 operaciones o carpetas más recientes del historial conservado. Un registro sin cierre no prueba que la app siga trabajando.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Mostrar base local", action: model.revealDatabase)
                Button("Mostrar diagnóstico", action: model.revealDiagnostics)
            }
        }.padding(24).frame(width: 900, height: 700)
    }
    private func localDate(_ value: String) -> String {
        ISO8601DateFormatter().date(from: value)?.formatted(date: .abbreviated, time: .standard) ?? value
    }
}
