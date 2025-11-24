

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        updateDockIconVisibility()

        windowController = SideNotesWindowController()

        if let windowController = windowController {
            ShortcutManager.shared.setup(windowController: windowController)
        }

        if !OnboardingManager.hasCompletedOnboarding() {
            showOnboarding()
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

    private func showOnboarding() {
        onboardingWindowController = OnboardingWindowController { [weak self] in
            OnboardingManager.markOnboardingComplete()
            self?.onboardingWindowController = nil
        }
        onboardingWindowController?.show()
    }

    func showSettings() {
        print("🔧 showSettings called")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("❌ self is nil")
                return
            }

            print("✅ Creating/showing settings window")
            if self.settingsWindowController == nil {
                print("🆕 Creating new SettingsWindowController")
                self.settingsWindowController = SettingsWindowController { [weak self] in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        self.windowController?.window?.contentView = NSHostingView(
                            rootView: ContentView()
                        )
                    }
                }
            }
            print("📱 Calling show on window controller")
            self.settingsWindowController?.show()
            print("✅ Show called, window should be visible: \(self.settingsWindowController?.window?.isVisible ?? false)")
        }
    }

    @objc private func handleOpenSettings() {
        print("🔔 Notification received: openSettingsWindow")
        showSettings()
    }

    @objc private func dockIconSettingChanged() {
        updateDockIconVisibility()
    }

    private func updateDockIconVisibility() {
        let showDockIcon = ShortcutSettings.shared.showDockIcon
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }
}
