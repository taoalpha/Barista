import SwiftUI
import AppKit

class SettingsWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class SettingsManager: NSObject {
    static let shared = SettingsManager()
    private var settingsWindow: NSWindow?

    func showSettings() {
        // Ensure the app is an accessory app to allow windows but keep it out of the dock
        NSApp.setActivationPolicy(.accessory)
        
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = SettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 350),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Settings"
        window.contentView = NSHostingController(rootView: SettingsView()).view
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        // Ensure it stays on top
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension SettingsManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        self.settingsWindow = nil
    }
}
