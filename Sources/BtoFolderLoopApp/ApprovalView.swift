// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import BtoFolderLoopCore

struct ApprovalView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { BrandIcon(size: 40); Text("Revisa tu selección").font(.title2.bold()) }
            if let plan = model.pendingApproval {
                Text("\(plan.candidates.count) seleccionadas · \(plan.mode.title) · \(plan.plans.count) carpetas principales")
                    .font(.headline).accessibilityIdentifier("approvalCount")
                Text("Este es el listado completo que has marcado, incluidas las filas ocultas por el filtro. Solo se enviarán las que estén vacías al comprobarlas.")
                List(plan.candidates) { candidate in
                    VStack(alignment: .leading, spacing: 3) {
                        Label(candidate.relativePath, systemImage: "folder")
                        Text(candidate.rootPath).font(.caption).foregroundStyle(.secondary)
                    }.textSelection(.enabled)
                }.frame(minHeight: 140, maxHeight: 260).accessibilityIdentifier("approvalList")
                Text("Las carpetas desmarcadas, archivos, accesos directos y todas las carpetas principales elegidas se conservan. El lote se detiene ante un error. La Papelera no se vacía.")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button("Cancelar", role: .cancel, action: model.cancelApproval).keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("cancelApprovalButton")
                    Spacer()
                    Button("Enviar \(plan.candidates.count) a la Papelera", role: .destructive, action: model.executeApprovedPlan)
                        .accessibilityIdentifier("confirmTrashButton")
                }
            }
        }.padding(24).frame(width: 680, height: 560).interactiveDismissDisabled()
    }
}
