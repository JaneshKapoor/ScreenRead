import AppKit
import SwiftUI

/// Hosts `SettingsView` in a plain AppKit window.
///
/// SwiftUI's `Settings` scene is not used because opening it programmatically
/// relies on an undocumented selector that has been renamed twice across recent
/// macOS releases. An `.accessory` app can show and focus an ordinary window
/// without switching activation policy, so there is no Dock icon flicker.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "ScreenRead Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Hand focus back rather than leaving the user in a windowless app.
        NSApp.deactivate()
    }
}
