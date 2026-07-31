import SwiftUI

@main
struct ScreenReadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // ScreenRead is a background agent: it has no main window. This scene
        // exists only to satisfy the App protocol and is never shown — the real
        // settings window is opened from the menu bar via
        // SettingsWindowController.
        Settings {
            EmptyView()
        }
    }
}
