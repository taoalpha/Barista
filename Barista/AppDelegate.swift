import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Initialize the manager which sets up the status item
        menuBarManager = MenuBarManager()
    }
}
