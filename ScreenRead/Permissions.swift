import AppKit
import CoreGraphics

enum Permissions {
    /// Non-prompting check — safe to call repeatedly (e.g. while building a menu).
    static var hasScreenRecordingAccess: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Triggers the system Screen Recording prompt the first time it is called
    /// for this build. macOS only shows the dialog once per app identity, so if
    /// the user has previously denied it we point them at System Settings instead.
    @discardableResult
    static func requestScreenRecordingAccessIfNeeded() -> Bool {
        if hasScreenRecordingAccess { return true }
        return CGRequestScreenCaptureAccess()
    }

    static func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    /// Shown when a capture attempt fails because permission is missing.
    static func presentScreenRecordingAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording permission required"
        alert.informativeText = """
        ScreenRead reads text from the pixels on your screen, so macOS requires the \
        Screen Recording permission.

        Open System Settings ▸ Privacy & Security ▸ Screen Recording, enable ScreenRead, \
        then quit and relaunch the app.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openScreenRecordingSettings()
        }
    }
}
