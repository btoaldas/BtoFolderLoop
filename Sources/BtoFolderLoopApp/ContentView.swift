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
                BrandIcon(size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text("BtoFolderLoop").font(.largeTitle.bold())
                    Text("Menos carpetas vacías. Tú decides cada limpieza.").foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.openHistory() } label: { Label("Registro", systemImage: "clock.arrow.circlepath") }
                    .accessibilityIdentifier("historyButton")
                Button { model.openSettings() } label: { Image(systemName: "gearshape") }
                    .disabled(!model.canWork).help("Configuración de registros").accessibilityIdentifier("settingsButton")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    dropZone
                    if !model.resolvedFolders.isEmpty || !model.inputIssues.isEmpty { FolderInputsView(model: model) }
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
                    if let warning = model.diagnosticWarning { Text(warning).font(.caption).foregroundStyle(.orange) }
                    if let plan = model.plan { preview(plan) }
                    else if let report = model.report { result(report) }
                    else if !model.busy { welcome }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            Divider()
            HStack {
                Label("Solo carpetas vacías · Archivos y carpetas principales protegidos", systemImage: "checkmark.shield")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("GPL v3+").font(.caption).foregroundStyle(.secondary)
            }
            if let updates = model.updates {
                UpdateFooterView(updates: updates, folderWorkBusy: model.busy)
                    .task { await updates.initialCheck() }
            } else { Text("v\(BrandAssets.version)").font(.caption).foregroundStyle(.secondary) }
        }
        .padding(24)
        .frame(minWidth: 800, minHeight: 720)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $model.showConfirmation, onDismiss: model.cancelApproval) { ApprovalView(model: model) }
        .sheet(isPresented: $model.showHistory) { HistoryView(model: model) }
        .sheet(isPresented: $model.showSettings) { SettingsView(model: model) }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in model.maintainIfIdle() }
    }

    private var dropZone: some View {
        HStack(spacing: 16) {
            Image(systemName: model.root == nil ? "tray.and.arrow.down" : "folder.fill")
                .font(.system(size: 30)).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 5) {
                Text(model.inputURLs.isEmpty ? "Arrastra carpetas o accesos directos" : "\(model.inputURLs.count) entradas en este lote").font(.title3.bold())
                Text("Puedes arrastrar varias a la vez. Revisarás sus rutas reales antes de mover nada.")
                    .font(.callout).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
            }
            Spacer()
            Button(model.inputURLs.isEmpty ? "Elegir carpetas…" : "Cambiar lote…", action: model.choose)
                .disabled(!model.canWork).accessibilityIdentifier("chooseFolderButton")
        }
        .padding(20).frame(maxWidth: .infinity, minHeight: 94)
        .background(Color.accentColor.opacity(targeted ? 0.14 : 0.055), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.accentColor.opacity(targeted ? 0.8 : 0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6])))
        .dropDestination(for: URL.self) { urls, _ in
            guard !urls.isEmpty, model.canWork else { return false }
            model.select(urls); return true
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
        }.buttonStyle(.plain).disabled(!model.canWork).accessibilityIdentifier(mode.rawValue + "Mode")
            .accessibilityAddTraits(model.mode == mode ? .isSelected : [])
    }

    private func preview(_ plan: CleanupBatch) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(model.selection.selectedIDs.count.formatted()) de \(plan.candidates.count.formatted()) seleccionadas")
                    .font(.title3.bold()).accessibilityIdentifier("selectionCount")
                Spacer()
                Text("\(plan.scannedDirectories.formatted()) revisadas · \(plan.passes) niveles").font(.caption).foregroundStyle(.secondary)
            }
            if !plan.issues.isEmpty {
                DisclosureGroup("\(plan.issues.count) rutas no se pudieron revisar: se conservan") {
                    ScrollView { ForEach(plan.issues) { issue in Text(issue.path + ": " + issue.message).font(.caption).textSelection(.enabled) } }.frame(maxHeight: 80)
                }.foregroundStyle(.orange)
            }
            if !plan.candidates.isEmpty {
                HStack {
                    Button("Seleccionar todas (\(plan.candidates.count))", action: model.selectAll)
                        .accessibilityIdentifier("selectAllButton")
                    Button("Deseleccionar todas", action: model.selectNone)
                        .disabled(model.selection.selectedIDs.isEmpty).accessibilityIdentifier("selectNoneButton")
                    Spacer()
                }
                TextField("Filtrar por ruta (la selección se mantiene)", text: $filter)
                    .textFieldStyle(.roundedBorder).accessibilityIdentifier("filterCandidates")
                if !filter.isEmpty {
                    Text("El filtro solo oculta filas. Seleccionar todas incluye las \(plan.candidates.count) carpetas del análisis.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                List(plan.candidates.filter { filter.isEmpty || $0.path.localizedCaseInsensitiveContains(filter) }) { candidate in
                    HStack {
                        Toggle(candidate.relativePath, isOn: Binding(
                            get: { model.selection.selectedIDs.contains(candidate.id) },
                            set: { model.setSelected(candidate.id, $0) }
                        )).toggleStyle(.checkbox).labelsHidden()
                            .accessibilityLabel("Seleccionar " + candidate.path)
                            .accessibilityIdentifier("selectCandidate:" + candidate.path)
                        Image(systemName: "folder").foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.relativePath)
                            if plan.plans.count > 1 { Text(candidate.rootPath).font(.caption).foregroundStyle(.secondary) }
                        }.textSelection(.enabled)
                        Spacer()
                        Text(candidate.initiallyEmpty ? "Vacía ahora" : "Después de sus hijas · \(candidate.pass)")
                            .font(.caption).foregroundStyle(candidate.initiallyEmpty ? Color.secondary : Color.accentColor)
                    }.padding(.vertical, 2)
                }.listStyle(.bordered).frame(height: 240).accessibilityIdentifier("candidateList")
                if plan.mode == .cascade {
                    Text("Marcar un padre no marca sus hijas. Si queda alguna dentro, el padre se conserva.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack {
                Button("Volver a analizar", action: model.analyze).disabled(!model.canWork)
                Spacer()
                Button(action: model.reviewSelection) {
                    Label("Revisar \(model.selection.selectedIDs.count) seleccionadas…", systemImage: "trash")
                }.buttonStyle(.borderedProminent).disabled(model.selection.selectedIDs.isEmpty || !model.canWork)
                    .accessibilityIdentifier("reviewTrashButton")
            }
        }
    }

    private func result(_ report: CleanupReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("\(report.moved.count.formatted()) carpetas enviadas a la Papelera", systemImage: report.errors.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title3.bold()).foregroundStyle(report.errors.isEmpty ? Color.green : Color.orange)
            Text("\(report.skipped.count) conservadas por contenido o cambios · \(report.errors.count) errores. El registro guarda los destinos de los movimientos confirmados.")
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
            Label("2. Selecciona y aprueba", systemImage: "checklist").font(.headline)
            Text("Todo empieza desmarcado. Elige solo lo que quieras enviar; también puedes seleccionar todas. Los archivos, enlaces y paquetes se conservan.")
            Label("3. Comprueba el resultado", systemImage: "checkmark.shield").font(.headline)
            Text("Cada movimiento se verifica y se registra solo en este Mac.")
        }.foregroundStyle(.secondary).padding(18)
    }
}
