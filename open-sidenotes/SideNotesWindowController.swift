import Cocoa
import SwiftUI

class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class SideNotesWindowController: NSWindowController {
    private var mouseMoveMonitor: Any?
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private let windowWidth: CGFloat = 400
    private var isShown = false
    private var lastAtRightEdge = false
    private var hideTimer: Timer?

    init() {
        let visibleFrame = NSScreen.main!.visibleFrame
        let window = KeyableWindow(
            contentRect: NSRect(x: visibleFrame.maxX, y: visibleFrame.minY, width: windowWidth, height: visibleFrame.height),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .normal
        window.hasShadow = true
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true

        let contentView = ContentView()
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: windowWidth, height: visibleFrame.height)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 12
        hostingView.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        hostingView.layer?.masksToBounds = true
        window.contentView = hostingView

        super.init(window: window)

        setupEventMonitors()
    }

    private func setupEventMonitors() {
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMove()
        }

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleClickOutside(event)
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
            return event
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        hideTimer?.invalidate()

        if let monitor = mouseMoveMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func handleMouseMove() {
        let mouseLocation = NSEvent.mouseLocation
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return }
        let atRightEdge = mouseLocation.x >= visibleFrame.maxX - 2

        if atRightEdge && !lastAtRightEdge {
            if !isShown {
                showWindow()
            }
            cancelHideTimer()
        } else if isShown && !isMouseInWindow() {
            startHideTimer()
        }

        lastAtRightEdge = atRightEdge
    }

    private func handleClickOutside(_ event: NSEvent) {
        if isShown && !isMouseInWindow() {
            hideWindow()
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == 53 && isShown {
            hideWindow()
        }
        return event
    }

    private func isMouseInWindow() -> Bool {
        guard let window = self.window else { return false }
        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = window.frame
        return windowFrame.contains(mouseLocation)
    }

    private func startHideTimer() {
        cancelHideTimer()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            if self?.isShown == true && self?.isMouseInWindow() == false {
                self?.hideWindow()
            }
        }
    }

    private func cancelHideTimer() {
        hideTimer?.invalidate()
        hideTimer = nil
    }

    private func showWindow() {
        guard let window = self.window, !isShown else { return }
        isShown = true
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return }
        window.setFrame(NSRect(x: visibleFrame.maxX, y: visibleFrame.minY, width: windowWidth, height: visibleFrame.height), display: false)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().setFrame(NSRect(x: visibleFrame.maxX - windowWidth, y: visibleFrame.minY, width: windowWidth, height: visibleFrame.height), display: true)
        })
    }

    private func hideWindow() {
        guard let window = self.window, isShown else { return }
        isShown = false
        cancelHideTimer()
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().setFrame(NSRect(x: visibleFrame.maxX, y: visibleFrame.minY, width: windowWidth, height: visibleFrame.height), display: true)
        }, completionHandler: {
            window.orderOut(nil)
        })
    }
}