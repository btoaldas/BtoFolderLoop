// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

struct FolderInputsView: View {
    @ObservedObject var model: AppModel
    @State private var expanded = true
    var body: some View {
        DisclosureGroup("Rutas reales: \(model.plan?.plans.count ?? 0) carpetas principales · \(model.inputIssues.count) entradas no admitidas", isExpanded: $expanded) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(model.resolvedFolders.enumerated()), id: \.offset) { _, folder in
                        VStack(alignment: .leading, spacing: 2) {
                            if folder.shortcut { Label(folder.input.path, systemImage: "arrow.turn.down.right").font(.caption) }
                            Text(folder.url.path).font(.caption).textSelection(.enabled)
                        }
                    }
                    ForEach(model.inputIssues) { issue in
                        Text(issue.path + ": " + issue.message).font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                    }
                    Text("Las rutas repetidas y las incluidas dentro de otra se revisan una sola vez. Todas las carpetas principales elegidas se conservan, incluidas las anidadas. Los accesos directos originales también se conservan.")
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 105)
        }.accessibilityIdentifier("resolvedFolderInputs")
    }
}
