import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let hotkeys = HotkeyController.shared
    private let coordinator = CaptureCoordinator()
    private let onboarding = OnboardingWindowController.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Background agent: no Dock icon, no app switcher entry.
        NSApp.setActivationPolicy(.accessory)

        setUpStatusItem()

        hotkeys.onTrigger = { [weak self] in
            self?.coordinator.beginCapture()
        }

        if !hotkeys.start() {
            presentHotkeyConflictWarning()
        }

        // Ask for Screen Recording up front so the first capture actually works
        // instead of silently failing on a permission error.
        Permissions.requestScreenRecordingAccessIfNeeded()

        onboarding.onTryCapture = { [weak self] in
            self?.coordinator.beginCapture()
        }
        onboarding.showIfFirstLaunch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeys.stop()
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
            keyEquivalent: ""
        )
        capture.target = self
        capture.tag = MenuTag.capture.rawValue
        menu.addItem(capture)

        menu.addItem(.separator())

        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settings.keyEquivalentModifierMask = [.command]
        settings.target = self
        menu.addItem(settings)

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

        let welcome = NSMenuItem(
            title: "How ScreenRead Works…",
            action: #selector(showOnboarding),
            keyEquivalent: ""
        )
        welcome.target = self
        menu.addItem(welcome)

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
        case capture = 102
    }

    // MARK: - Actions

    @objc private func captureFromMenu() {
        coordinator.beginCapture()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func showOnboarding() {
        onboarding.show()
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
        let shortcut = hotkeys.shortcut.displayName
        let alert = NSAlert()
        alert.messageText = "Couldn't register \(shortcut)"
        alert.informativeText = """
        Another app is already using \(shortcut) as a global shortcut, so ScreenRead can't listen \
        for it.

        Pick a different combination in Settings, or capture from the menu bar icon instead.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings…")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            SettingsWindowController.shared.show()
        }
    }
}

// MARK: - Live menu state

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if let item = menu.item(withTag: MenuTag.capture.rawValue) {
            // Mirror whatever the shortcut is currently bound to.
            let shortcut = hotkeys.shortcut
            item.keyEquivalent = shortcut.menuKeyEquivalent ?? ""
            item.keyEquivalentModifierMask = shortcut.eventModifiers
            item.title = hotkeys.isRegistered
                ? "Capture Text"
                : "Capture Text (shortcut unavailable)"
        }
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
