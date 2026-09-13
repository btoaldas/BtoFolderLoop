// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import AppKit

extension Notification.Name { static let openFolder = Notification.Name("BtoFolderLoop.openFolder") }

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard filenames.count == 1, let path = filenames.first else { sender.reply(toOpenOrPrint: .failure); return }
        NotificationCenter.default.post(name: .openFolder, object: URL(fileURLWithPath: path))
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
                .onReceive(NotificationCenter.default.publisher(for: .openFolder)) { notification in
                    if let url = notification.object as? URL { model.select(url) }
                }
                .onOpenURL { model.select($0) }
        }
        .defaultSize(width: 930, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) { Button("Elegir carpeta…", action: model.choose).keyboardShortcut("o").disabled(model.busy) }
            CommandGroup(after: .appInfo) { Text("GPL-3.0-or-later · v0.1.0") }
        }
    }
}
