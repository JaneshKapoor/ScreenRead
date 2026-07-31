import AppKit
import CoreGraphics

enum Permissions {
    /// Non-prompting status check.
    ///
    /// Treat this as advisory only — it is safe for displaying status in the
    /// menu, but it must never gate a capture attempt. `CGPreflightScreenCaptureAccess`
    /// reports stale results after the user flips the toggle in System Settings,
    /// so gating on it produces "permission required" alerts for an app that can
    /// actually capture perfectly well.
    static var hasScreenRecordingAccess: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Triggers the system Screen Recording prompt. macOS only offers the dialog
    /// once per app identity; afterwards this returns the stored answer without
    /// showing anything.
    @discardableResult
    static func requestScreenRecordingAccessIfNeeded() -> Bool {
        if hasScreenRecordingAccess { return true }
        return CGRequestScreenCaptureAccess()
    }

    static func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    /// Shown when a capture attempt actually fails.
    static func presentScreenRecordingAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording permission required"
        alert.informativeText = """
        ScreenRead reads text from the pixels on your screen, so macOS requires the \
        Screen Recording permission.

        1. Open System Settings ▸ Privacy & Security ▸ Screen Recording
        2. Turn on ScreenRead
        3. Relaunch ScreenRead — macOS only applies the change on next launch

        If it is already switched on, step 3 is the one that's missing.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit & Relaunch")
        alert.addButton(withTitle: "Later")

        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            openScreenRecordingSettings()
        case .alertSecondButtonReturn:
            relaunch()
        default:
            break
        }
    }

    /// Restarts the app so macOS re-evaluates the TCC grant.
    ///
    /// The relaunch is handed to a detached shell rather than done in-process:
    /// starting a second instance before this one exits would leave the new
    /// process unable to claim ⌘⇧T, since the old one still holds it.
    static func relaunch() {
        let path = Bundle.main.bundleURL.path
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1; open \"\(path)\""]
        do {
            try task.run()
        } catch {
            Log.error("Relaunch failed: \(error.localizedDescription)")
            return
        }
        NSApp.terminate(nil)
    }
}
