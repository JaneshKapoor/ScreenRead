import SwiftUI

@main
struct ScreenReadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // ScreenRead is a background agent: it has no main window. The Settings
        // scene exists only so the App protocol is satisfied — it is never shown
        // unless the user picks "Settings…" from the menu bar item.
        Settings {
            SettingsView()
        }
    }
}
