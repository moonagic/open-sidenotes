

import SwiftUI

@main
struct open_sidenotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: SideNotesWindowController?
    var onboardingWindowController: OnboardingWindowController?
    var settingsWindowController: SettingsWindowController?
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        updateDockIconVisibility()
        setupMenuBar()

        windowController = SideNotesWindowController()

        if let windowController = windowController {
            ShortcutManager.shared.setup(windowController: windowController)
        }

        if !OnboardingManager.hasCompletedOnboarding() {
            showOnboarding()
        } else {
            checkForUpdatesIfNeeded()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dockIconSettingChanged),
            name: .dockIconSettingChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettings),
            name: .openSettingsWindow,
            object: nil
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windowController?.showWindowFromDock()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.post(name: .flushActiveNoteDraft, object: nil)
    }

    private func showOnboarding() {
        onboardingWindowController = OnboardingWindowController { [weak self] in
            OnboardingManager.markOnboardingComplete()
            self?.onboardingWindowController = nil
        }
        onboardingWindowController?.show()
    }

    func showSettings() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }

            if self.settingsWindowController == nil {
                self.settingsWindowController = SettingsWindowController { [weak self] in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        self.windowController?.window?.contentView = NSHostingView(
                            rootView: ContentView()
                        )
                    }
                }
            }
            self.settingsWindowController?.show()
        }
    }

    @objc private func handleOpenSettings() {
        showSettings()
    }

    @objc private func dockIconSettingChanged() {
        updateDockIconVisibility()
    }

    private func updateDockIconVisibility() {
        let showDockIcon = ShortcutSettings.shared.showDockIcon
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }

    private func checkForUpdatesIfNeeded() {
        Task { @MainActor in
            let updateService = GitHubUpdateService.shared
            if updateService.shouldAutoCheck() {
                await updateService.checkForUpdates(silent: true)
            }
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Open Sidenotes")
        }

        let menu = NSMenu()

        menu.addItem(NSMenuItem(
            title: "Toggle Window",
            action: #selector(toggleWindow),
            keyEquivalent: ""
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "Quit Sidenotes",
            action: #selector(quitApp),
            keyEquivalent: "q"
        ))

        statusItem?.menu = menu
    }

    @objc private func toggleWindow() {
        windowController?.toggleWindow()
    }

    @objc private func openSettings() {
        showSettings()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
