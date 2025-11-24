

import SwiftUI

@main
struct open_sidenotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings {
            SettingsView(onPathChanged: {
                appDelegate.windowController?.window?.contentView = NSHostingView(
                    rootView: ContentView()
                )
            })
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: SideNotesWindowController?
    var onboardingWindowController: OnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowController = SideNotesWindowController()

        if let windowController = windowController {
            ShortcutManager.shared.setup(windowController: windowController)
        }

        if !OnboardingManager.hasCompletedOnboarding() {
            showOnboarding()
        }
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
}
