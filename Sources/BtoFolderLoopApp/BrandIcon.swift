// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import AppKit

enum BrandAssets {
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0" }

    // Resolve packaged or SwiftPM resources without an absolute build-directory fallback.
    static let icon: NSImage? = {
        var locations = [Bundle.main.resourceURL, Bundle.main.bundleURL].compactMap { $0 }
        if var parent = Bundle.main.executableURL?.deletingLastPathComponent() {
            for _ in 0..<5 { locations.append(parent); parent.deleteLastPathComponent() }
        }
        for location in locations {
            let direct = location.appendingPathComponent("BrandIcon.png")
            if let icon = NSImage(contentsOf: direct) { return icon }
            if let bundle = Bundle(url: location.appendingPathComponent("BtoFolderLoop_BtoFolderLoopApp.bundle")),
               let url = bundle.url(forResource: "BrandIcon", withExtension: "png"),
               let icon = NSImage(contentsOf: url) { return icon }
        }
        return nil
    }()
}

struct BrandIcon: View {
    var size: CGFloat
    var body: some View {
        Group {
            if let image = BrandAssets.icon {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
            } else {
                Image(systemName: "folder.badge.minus").resizable().scaledToFit().foregroundStyle(.tint)
            }
        }.frame(width: size, height: size).accessibilityLabel("Icono BtoFolderLoop")
    }
}
