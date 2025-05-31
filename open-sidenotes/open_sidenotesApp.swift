

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
    func applicationDidFinishLaunching(_ notification: Notification) {
        windowController = SideNotesWindowController()
    }
}
