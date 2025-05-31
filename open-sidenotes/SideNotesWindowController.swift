import Cocoa
import SwiftUI

class SideNotesWindowController: NSWindowController {
    private var monitor: Any?
    private let windowWidth: CGFloat = 400
    private var isShown = false
    private var lastAtRightEdge = false

    init() {
        let screenFrame = NSScreen.main!.frame
        let window = NSWindow(
            contentRect: NSRect(x: screenFrame.maxX, y: 0, width: windowWidth, height: screenFrame.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.98)
        window.level = .floating
        window.hasShadow = true
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let contentView = ContentView()
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: windowWidth, height: screenFrame.height)
        window.contentView = hostingView

        super.init(window: window)

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMove()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func handleMouseMove() {
        let mouseLocation = NSEvent.mouseLocation
        guard let screenFrame = NSScreen.main?.frame else { return }
        let atRightEdge = mouseLocation.x >= screenFrame.maxX - 2
        if atRightEdge && !lastAtRightEdge {
            if isShown {
                hideWindow()
            } else {
                showWindow()
            }
        }
        lastAtRightEdge = atRightEdge
    }

    private func showWindow() {
        guard let window = self.window, !isShown else { return }
        isShown = true
        guard let screenFrame = NSScreen.main?.frame else { return }
        window.setFrame(NSRect(x: screenFrame.maxX, y: 0, width: windowWidth, height: screenFrame.height), display: false)
        window.orderFront(nil)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().setFrame(NSRect(x: screenFrame.maxX - windowWidth, y: 0, width: windowWidth, height: screenFrame.height), display: true)
        }, completionHandler: {
            window.makeKeyAndOrderFront(nil)
        })
    }

    private func hideWindow() {
        guard let window = self.window, isShown else { return }
        isShown = false
        guard let screenFrame = NSScreen.main?.frame else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().setFrame(NSRect(x: screenFrame.maxX, y: 0, width: windowWidth, height: screenFrame.height), display: true)
        }, completionHandler: {
            window.orderOut(nil)
        })
    }
}