// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var incomingFolders: [URL] = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        if let icon = BrandAssets.icon { NSApplication.shared.applicationIconImage = icon }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard !filenames.isEmpty, filenames.count <= 128 else { sender.reply(toOpenOrPrint: .failure); return }
        incomingFolders = filenames.map { URL(fileURLWithPath: $0) }
        sender.reply(toOpenOrPrint: .success)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct BtoFolderLoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .onReceive(delegate.$incomingFolders) { urls in
                    guard !urls.isEmpty else { return }
                    model.select(urls)
                    delegate.incomingFolders = []
                }
                .onOpenURL { model.select($0) }
        }
        .defaultSize(width: 930, height: 820)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Configuración…", action: model.openSettings).keyboardShortcut(",").disabled(!model.canWork)
            }
            CommandGroup(replacing: .newItem) { Button("Elegir carpetas…", action: model.choose).keyboardShortcut("o").disabled(!model.canWork) }
            CommandGroup(replacing: .appInfo) {
                Button("Acerca de BtoFolderLoop") {
                    var options: [NSApplication.AboutPanelOptionKey: Any] = [
                        .applicationName: "BtoFolderLoop", .applicationVersion: BrandAssets.version,
                        .credits: NSAttributedString(string: "GPL-3.0-or-later · Solo carpetas vacías · Tú decides")
                    ]
                    if let icon = BrandAssets.icon { options[.applicationIcon] = icon }
                    NSApplication.shared.orderFrontStandardAboutPanel(options: options)
                }
            }
        }
    }
}
