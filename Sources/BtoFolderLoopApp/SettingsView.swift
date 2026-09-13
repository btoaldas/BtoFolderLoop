// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { BrandIcon(size: 36); Text("Conservación de registros").font(.title2.bold()) }
            Text("Tú decides cuánto tiempo guardar el diagnóstico y el historial local.").foregroundStyle(.secondary)
            GroupBox("Diagnóstico técnico") {
                VStack(alignment: .leading, spacing: 12) {
                    numberField("Conservar (días)", value: $model.settingsDraft.diagnosticDays, range: 1...3650)
                    numberField("Máximo total (MiB)", value: $model.settingsDraft.diagnosticMiB, range: 1...100)
                    Text("Archivos JSONL de hasta 2 MiB. Los más antiguos caducan por fecha o espacio. No incluyen las rutas de tus carpetas.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }.padding(8)
            }
            GroupBox("Historial de carpetas y movimientos") {
                VStack(alignment: .leading, spacing: 12) {
                    numberField("Conservar (días)", value: $model.settingsDraft.historyDays, range: 1...3650)
                    Text("Al caducar una operación completada se elimina su registro, incluidas las rutas para recuperar carpetas. Los registros sin cerrar, detenidos o con errores se conservan.").font(.callout).fixedSize(horizontal: false, vertical: true)
                }.padding(8)
            }
            Text("Guardar aplica estos plazos a los registros existentes mientras la app esté inactiva. No borra tus archivos, no vacía la Papelera y no toca las carpetas trabajadas.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let error = model.error { Text(error).foregroundStyle(.orange) }
            HStack {
                Button("Restablecer valores propuestos") { model.settingsDraft = .init() }
                Spacer()
                Button("Cancelar") { model.showSettings = false }
                Button("Guardar y aplicar", action: model.saveSettings).buttonStyle(.borderedProminent).disabled(model.busy)
            }
        }.padding(24).frame(width: 650)
    }
    private func numberField(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title); Spacer()
            TextField(title, value: value, format: .number).labelsHidden().textFieldStyle(.roundedBorder).frame(width: 90)
            Stepper(title, value: value, in: range).labelsHidden()
        }
    }
}
