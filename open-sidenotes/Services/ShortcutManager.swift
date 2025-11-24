import Foundation
import Carbon

class ShortcutManager {
    static let shared = ShortcutManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var toggleAction: (() -> Void)?

    private init() {}

    func setup(windowController: SideNotesWindowController) {
        toggleAction = { [weak windowController] in
            windowController?.toggleWindow()
        }
        registerShortcuts()
        observeSettingsChanges()
    }

    private func observeSettingsChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shortcutSettingsChanged),
            name: .shortcutSettingsChanged,
            object: nil
        )
    }

    @objc private func shortcutSettingsChanged() {
        unregisterShortcuts()
        registerShortcuts()
    }

    private func registerShortcuts() {
        guard let shortcut = ShortcutSettings.shared.toggleWindowShortcut else { return }

        let hotKeyID = EventHotKeyID(signature: OSType(0x54474E57), id: 1)

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            self.hotKeyRef = hotKeyRef
            installEventHandler()
        }
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotKeyEvent(event)
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private func handleHotKeyEvent(_ event: EventRef?) {
        toggleAction?()
    }

    private func unregisterShortcuts() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    deinit {
        unregisterShortcuts()
        NotificationCenter.default.removeObserver(self)
    }
}

extension Notification.Name {
    static let shortcutSettingsChanged = Notification.Name("shortcutSettingsChanged")
}
