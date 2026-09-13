// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

struct UpdateFooterView: View {
    @ObservedObject var updates: ReleaseUpdater
    var folderWorkBusy: Bool
    var body: some View {
        HStack(spacing: 10) {
            Text("v" + updates.installedVersion.description).font(.caption.bold())
            if updates.checking || updates.installing {
                if let progress = updates.progress { ProgressView(value: progress).frame(width: 70) }
                else { ProgressView().controlSize(.mini) }
            }
            Text(updates.message).font(.caption).foregroundStyle(updates.errorMessage == nil ? Color.secondary : .orange)
                .lineLimit(2).help(updates.errorMessage ?? updates.message)
            Spacer(minLength: 4)
            if let offer = updates.offer { Link("Novedades", destination: offer.pageURL).font(.caption) }
            if updates.canInstall {
                Button { Task { await updates.check() } } label: { Image(systemName: "arrow.clockwise") }
                    .help("Volver a consultar la última versión publicada")
                    .accessibilityLabel("Buscar actualización").accessibilityIdentifier("checkUpdateButton")
                Button("Actualizar y reiniciar", action: updates.install).disabled(folderWorkBusy)
                    .help("Descargar, verificar e instalar el último release y reiniciar la app. Tus datos se conservan.")
                    .accessibilityIdentifier("installUpdateButton")
            } else if !updates.installing {
                Button("Buscar actualización") { Task { await updates.check() } }.disabled(updates.checking)
                    .accessibilityIdentifier("checkUpdateButton")
            }
            if updates.installing, updates.cancelDownload != nil { Button("Cancelar", action: updates.cancel) }
        }.accessibilityIdentifier("updateFooter")
    }
}
