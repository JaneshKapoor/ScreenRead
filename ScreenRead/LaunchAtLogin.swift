import AppKit
import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                Log.error("Launch at login toggle failed: \(error.localizedDescription)")
                presentFailure(error, enabling: newValue)
            }
        }
    }

    private static func presentFailure(_ error: Error, enabling: Bool) {
        let alert = NSAlert()
        alert.messageText = enabling
            ? "Couldn't enable Launch at Login"
            : "Couldn't disable Launch at Login"
        alert.informativeText = """
        \(error.localizedDescription)

        Login items only work for apps in /Applications. If you're running a build straight \
        from Xcode's DerivedData folder, move ScreenRead.app to /Applications and try again.
        """
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
