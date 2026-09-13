// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import BtoFolderLoopCore

struct ApprovalView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { BrandIcon(size: 40); Text("Revisa tu selección").font(.title2.bold()) }
            if let plan = model.pendingApproval {
                Text("\(plan.candidates.count) seleccionadas · \(plan.mode.title) · \(URL(fileURLWithPath: plan.root.path).lastPathComponent)")
                    .font(.headline).accessibilityIdentifier("approvalCount")
                Text("Este es el listado completo que has marcado, incluidas las filas ocultas por el filtro. Solo se enviarán las que estén vacías al comprobarlas.")
                List(plan.candidates) { candidate in
                    Label(candidate.relativePath, systemImage: "folder").textSelection(.enabled)
                }.frame(minHeight: 140, maxHeight: 260).accessibilityIdentifier("approvalList")
                Text("Las carpetas desmarcadas, los archivos y la carpeta principal se conservan. Un padre con contenido no se mueve. La Papelera no se vacía.")
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
