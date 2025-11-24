

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowController = SideNotesWindowController()

        if !OnboardingManager.hasCompletedOnboarding() {
            showOnboarding()
        }
    }

    private func showOnboarding() {
        onboardingWindowController = OnboardingWindowController { [weak self] in
            OnboardingManager.markOnboardingComplete()
            self?.onboardingWindowController = nil
        }
        onboardingWindowController?.show()
    }
}
