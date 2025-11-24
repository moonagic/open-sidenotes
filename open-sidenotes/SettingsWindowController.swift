import Cocoa
import SwiftUI

class SettingsWindowController: NSWindowController {
    private let onPathChanged: () -> Void

    init(onPathChanged: @escaping () -> Void) {
        self.onPathChanged = onPathChanged
        print("🪟 SettingsWindowController init")

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
        print("🪟 Window created: \(window)")

        super.init(window: window)

        let settingsView = SettingsView(onPathChanged: onPathChanged)
        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 450, height: 520)
        hostingView.wantsLayer = true
        window.contentView = hostingView
        print("🪟 Content view set")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        print("🪟 show() called")
        guard let window = window else {
            print("❌ window is nil!")
            return
        }

        print("🪟 Window exists, isVisible: \(window.isVisible)")
        if !window.isVisible {
            window.center()
            print("🪟 Window centered")
        }

        window.makeKeyAndOrderFront(nil)
        print("🪟 makeKeyAndOrderFront called")
        NSApp.activate(ignoringOtherApps: true)
        print("🪟 NSApp activated, final isVisible: \(window.isVisible)")
    }
}
