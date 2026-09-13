// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import BtoFolderLoopCore

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var targeted = false
    @State private var filter = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "folder.badge.minus").font(.system(size: 34)).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("BtoFolderLoop").font(.largeTitle.bold())
                    Text("Menos carpetas vacías. Tú decides cada limpieza.").foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.openHistory() } label: { Label("Registro", systemImage: "clock.arrow.circlepath") }
                    .disabled(model.busy).accessibilityIdentifier("historyButton")
            }
            dropZone
            HStack(alignment: .top, spacing: 12) {
                ForEach(CleanupMode.allCases, id: \.rawValue) { mode in modeCard(mode) }
            }
            if model.busy {
                HStack { ProgressView().controlSize(.small); Text(model.status); Spacer(); Button("Detener", action: model.cancel) }
                    .padding(12).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            } else {
                Text(model.status).font(.callout).foregroundStyle(.secondary).accessibilityIdentifier("statusText")
            }
            if let error = model.error {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
            if let plan = model.plan { preview(plan) }
            else if let report = model.report { result(report) }
            else if !model.busy { welcome }
            Spacer(minLength: 0)
            Divider()
            HStack {
                Label("Solo carpetas vacías · Archivos y carpeta principal protegidos", systemImage: "checkmark.shield")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("GPL v3+ · Local").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(minWidth: 800, minHeight: 720)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Enviar carpetas vacías a la Papelera", isPresented: $model.showConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Enviar a la Papelera", role: .destructive) { model.executeApprovedPlan() }
        } message: {
            if let plan = model.plan {
                Text("Se comprobarán las \(plan.candidates.count) carpetas de la lista dentro de «\(URL(fileURLWithPath: plan.root.path).lastPathComponent)» en modo \(plan.mode.title.lowercased()).\n\nSolo se enviarán las que sigan vacías. La carpeta principal y los archivos se conservan. La Papelera no se vacía.")
            }
        }
        .sheet(isPresented: $model.showHistory) { HistoryView(model: model) }
    }

    private var dropZone: some View {
        HStack(spacing: 16) {
            Image(systemName: model.root == nil ? "tray.and.arrow.down" : "folder.fill")
                .font(.system(size: 30)).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 5) {
                Text(model.root?.lastPathComponent ?? "Arrastra aquí una carpeta").font(.title3.bold())
                Text(model.root?.path ?? "La analizamos primero. Tú revisas la lista antes de mover nada.")
                    .font(.callout).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
            }
            Spacer()
            Button(model.root == nil ? "Elegir carpeta…" : "Cambiar…", action: model.choose)
                .disabled(model.busy).accessibilityIdentifier("chooseFolderButton")
        }
        .padding(20).frame(maxWidth: .infinity, minHeight: 94)
        .background(Color.accentColor.opacity(targeted ? 0.14 : 0.055), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.accentColor.opacity(targeted ? 0.8 : 0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6])))
        .dropDestination(for: URL.self) { urls, _ in
            guard urls.count == 1, let url = urls.first, !model.busy else { return false }
            model.select(url); return true
        } isTargeted: { targeted = $0 }
        .accessibilityIdentifier("folderDropZone")
    }

    private func modeCard(_ mode: CleanupMode) -> some View {
        Button { model.changeMode(mode) } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: model.mode == mode ? "largecircle.fill.circle" : "circle")
                    .font(.title3).foregroundStyle(model.mode == mode ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 5) {
                    Label(mode.title, systemImage: mode == .singlePass ? "1.circle" : "arrow.triangle.2.circlepath").font(.headline)
                    Text(mode.detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14).frame(maxWidth: .infinity, minHeight: 85, alignment: .topLeading)
            .background(model.mode == mode ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.mode == mode ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1))
        }.buttonStyle(.plain).disabled(model.busy).accessibilityIdentifier(mode.rawValue + "Mode")
            .accessibilityAddTraits(model.mode == mode ? .isSelected : [])
    }

    private func preview(_ plan: CleanupPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(plan.candidates.count.formatted()) carpetas en la lista").font(.title3.bold())
                Spacer()
                Text("\(plan.scannedDirectories.formatted()) revisadas · \(plan.passes) niveles").font(.caption).foregroundStyle(.secondary)
            }
            if !plan.issues.isEmpty {
                DisclosureGroup("\(plan.issues.count) rutas no se pudieron revisar: se conservan") {
                    ScrollView { ForEach(plan.issues) { issue in Text(issue.path + ": " + issue.message).font(.caption).textSelection(.enabled) } }.frame(maxHeight: 80)
                }.foregroundStyle(.orange)
            }
            if !plan.candidates.isEmpty {
                TextField("Filtrar la lista (no cambia qué carpetas se aprobarán)", text: $filter)
                    .textFieldStyle(.roundedBorder).accessibilityIdentifier("filterCandidates")
                List(plan.candidates.filter { filter.isEmpty || $0.relativePath.localizedCaseInsensitiveContains(filter) }) { candidate in
                    HStack {
                        Image(systemName: "folder").foregroundStyle(.secondary)
                        Text(candidate.relativePath).textSelection(.enabled)
                        Spacer()
                        Text(candidate.initiallyEmpty ? "Vacía ahora" : "Después de sus hijas · \(candidate.pass)")
                            .font(.caption).foregroundStyle(candidate.initiallyEmpty ? Color.secondary : Color.accentColor)
                    }.padding(.vertical, 2)
                }.listStyle(.bordered).frame(minHeight: 150, maxHeight: 260).accessibilityIdentifier("candidateList")
            }
            HStack {
                Button("Volver a analizar", action: model.analyze)
                Spacer()
                Button { model.showConfirmation = true } label: {
                    Label("Revisar y enviar \(plan.candidates.count) a la Papelera…", systemImage: "trash")
                }.buttonStyle(.borderedProminent).disabled(plan.candidates.isEmpty || model.busy)
                    .accessibilityIdentifier("reviewTrashButton")
            }
        }
    }

    private func result(_ report: CleanupReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("\(report.moved.count.formatted()) carpetas enviadas a la Papelera", systemImage: report.errors.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title3.bold()).foregroundStyle(report.errors.isEmpty ? Color.green : Color.orange)
            Text("\(report.skipped.count) conservadas por cambios · \(report.errors.count) errores. El registro guarda los destinos de los movimientos confirmados.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !report.errors.isEmpty || !report.skipped.isEmpty {
                List(report.errors + report.skipped) { issue in
                    VStack(alignment: .leading) { Text(issue.path).font(.caption); Text(issue.message).font(.callout) }.textSelection(.enabled)
                }.frame(maxHeight: 150)
            }
            Text("Puedes recuperar carpetas desde la Papelera mientras no la vacíes. Para estructuras anidadas, devuelve primero los padres a rutas libres; el registro conserva las rutas originales.")
                .font(.callout).foregroundStyle(.secondary)
            HStack { Button("Revisar de nuevo", action: model.analyze); Button("Ver registro", action: model.openHistory) }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("1. Analiza", systemImage: "magnifyingglass").font(.headline)
            Text("Verás todas las carpetas que podrían enviarse a la Papelera.")
            Label("2. Revisa y aprueba", systemImage: "checklist").font(.headline)
            Text("Una carpeta con archivos ocultos no está vacía. Los enlaces y paquetes de aplicaciones se conservan.")
            Label("3. Comprueba el resultado", systemImage: "checkmark.shield").font(.headline)
            Text("Cada movimiento se verifica y se registra solo en este Mac.")
        }.foregroundStyle(.secondary).padding(18)
    }
}

private struct HistoryView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Registro local").font(.title2.bold()); Spacer(); Button("Cerrar") { model.showHistory = false } }
            Text("El registro puede contener rutas privadas. Permanece en este Mac; no se envía a GitHub ni a ningún servidor.").foregroundStyle(.secondary)
            List(model.history) { run in
                HStack { Text(run.date); Text(CleanupMode(rawValue: run.mode)?.title ?? run.mode); Spacer(); Text("\(run.moved) enviadas · \(run.status)") }
            }.frame(height: 150)
            Text("Últimos 500 eventos · fecha / origen / estado / destino / detalle").font(.caption)
            ScrollView([.horizontal, .vertical]) { Text(model.journalText.isEmpty ? "Todavía no hay operaciones." : model.journalText).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
                .frame(height: 210)
            Button("Mostrar base local en Finder", action: model.revealDatabase)
        }.padding(24).frame(width: 820, height: 530)
    }
}
