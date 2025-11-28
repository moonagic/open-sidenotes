import Cocoa
import SwiftUI

class SettingsWindowController: NSWindowController {
    private let onPathChanged: () -> Void

    init(onPathChanged: @escaping () -> Void) {
        self.onPathChanged = onPathChanged

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .windowBackgroundColor
        window.level = .normal
        window.hasShadow = true
        window.center()
        window.isMovableByWindowBackground = false

        super.init(window: window)

        let settingsView = SettingsView(onPathChanged: onPathChanged)
        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 450, height: 520)
        hostingView.wantsLayer = true
        window.contentView = hostingView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window = window else {
            return
        }

        if !window.isVisible {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
