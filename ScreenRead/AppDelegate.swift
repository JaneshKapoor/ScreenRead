import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let hotkeyManager = HotkeyManager()
    private let coordinator = CaptureCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Background agent: no Dock icon, no app switcher entry.
        NSApp.setActivationPolicy(.accessory)

        setUpStatusItem()

        hotkeyManager.onHotkeyPressed = { [weak self] in
            self?.coordinator.beginCapture()
        }

        if !hotkeyManager.register(shortcut: .default) {
            presentHotkeyConflictWarning()
        }

        // Ask for Screen Recording up front so the first ⌘⇧T actually works
        // instead of silently failing on a permission error.
        Permissions.requestScreenRecordingAccessIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "text.viewfinder",
            accessibilityDescription: "ScreenRead"
        )
        item.button?.image?.isTemplate = true
        item.menu = buildMenu()
        statusItem = item
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let capture = NSMenuItem(
            title: "Capture Text",
            action: #selector(captureFromMenu),
            keyEquivalent: "t"
        )
        capture.keyEquivalentModifierMask = [.command, .shift]
        capture.target = self
        menu.addItem(capture)

        menu.addItem(.separator())

        let launchAtLogin = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLogin.target = self
        launchAtLogin.tag = MenuTag.launchAtLogin.rawValue
        menu.addItem(launchAtLogin)

        let permissions = NSMenuItem(
            title: "Screen Recording Permission…",
            action: #selector(openScreenRecordingSettings),
            keyEquivalent: ""
        )
        permissions.target = self
        permissions.tag = MenuTag.permission.rawValue
        menu.addItem(permissions)

        menu.addItem(.separator())

        let about = NSMenuItem(title: "About ScreenRead", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "Quit ScreenRead", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    private enum MenuTag: Int {
        case launchAtLogin = 100
        case permission = 101
    }

    // MARK: - Actions

    @objc private func captureFromMenu() {
        coordinator.beginCapture()
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.isEnabled.toggle()
    }

    @objc private func openScreenRecordingSettings() {
        Permissions.openScreenRecordingSettings()
    }

    @objc private func showAbout() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "ScreenRead",
            .init(rawValue: "Copyright"): "Snip any part of the screen, get the text on your clipboard.",
        ])
        // Drop back to accessory once the panel is dismissed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if NSApp.windows.first(where: { $0.isVisible && $0.title == "About ScreenRead" }) == nil {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func presentHotkeyConflictWarning() {
        let alert = NSAlert()
        alert.messageText = "Couldn't register ⌘⇧T"
        alert.informativeText = """
        Another app is already using ⌘⇧T as a global shortcut, so ScreenRead can't listen for it.

        You can still capture from the menu bar icon. To use the shortcut, quit the conflicting app \
        (or change its shortcut) and relaunch ScreenRead.
        """
        alert.alertStyle = .warning
        alert.runModal()
    }
}

// MARK: - Live menu state

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if let item = menu.item(withTag: MenuTag.launchAtLogin.rawValue) {
            item.state = LaunchAtLogin.isEnabled ? .on : .off
        }
        if let item = menu.item(withTag: MenuTag.permission.rawValue) {
            let granted = Permissions.hasScreenRecordingAccess
            item.title = granted
                ? "Screen Recording: Granted"
                : "Grant Screen Recording Permission…"
            item.isEnabled = !granted
        }
    }
}
