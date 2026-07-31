import AppKit

enum ShortcutUpdateResult {
    case ok
    /// Another app already owns the combination.
    case conflict
    /// A plain typing key with no modifiers — would swallow that key everywhere.
    case needsModifier
}

/// Owns the registered shortcut and keeps the stored preference, the live Carbon
/// registration and the UI in sync.
///
/// A singleton because the settings window, the menu bar and the app delegate
/// all need the same registration; two `HotkeyManager`s would fight over the
/// same key combination.
@MainActor
final class HotkeyController: ObservableObject {
    static let shared = HotkeyController()

    @Published private(set) var shortcut: Shortcut
    /// True when the current shortcut could not be claimed from the system.
    @Published private(set) var isRegistered = false

    var onTrigger: (() -> Void)?

    private let manager = HotkeyManager()

    private init() {
        shortcut = ShortcutStore.current
        manager.onHotkeyPressed = { [weak self] in
            self?.onTrigger?()
        }
    }

    @discardableResult
    func start() -> Bool {
        isRegistered = manager.register(shortcut: shortcut)
        return isRegistered
    }

    /// Swaps in a new shortcut, rolling back to the previous one if the system
    /// refuses the registration.
    func update(to newShortcut: Shortcut) -> ShortcutUpdateResult {
        guard newShortcut.isRegisterable else { return .needsModifier }

        if newShortcut == shortcut, isRegistered { return .ok }

        guard manager.register(shortcut: newShortcut) else {
            // Put the old one back so the app is never left with no shortcut.
            isRegistered = manager.register(shortcut: shortcut)
            return .conflict
        }

        shortcut = newShortcut
        ShortcutStore.current = newShortcut
        isRegistered = true
        return .ok
    }

    func resetToDefault() -> ShortcutUpdateResult {
        update(to: .default)
    }

    func stop() {
        manager.unregister()
        isRegistered = false
    }
}
