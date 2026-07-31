import AppKit
import Carbon.HIToolbox

/// A global keyboard shortcut, stored as a Carbon virtual key code plus a
/// Carbon modifier mask — the form `RegisterEventHotKey` wants.
struct Shortcut: Equatable, Codable {
    let keyCode: UInt32
    let carbonModifiers: UInt32

    /// ⇧⌘T — what ScreenRead ships with.
    static let `default` = Shortcut(
        keyCode: UInt32(kVK_ANSI_T),
        carbonModifiers: UInt32(cmdKey | shiftKey)
    )

    init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    init(event: NSEvent) {
        self.keyCode = UInt32(event.keyCode)
        self.carbonModifiers = Shortcut.carbonModifiers(from: event.modifierFlags)
    }

    /// Rendered the way macOS writes shortcuts: ⌃⌥⇧⌘ then the key.
    var displayName: String {
        KeyCodeTranslator.modifierSymbols(carbonModifiers) + KeyCodeTranslator.displayName(for: keyCode)
    }

    /// A bare letter or digit would swallow that key system-wide, so plain keys
    /// need at least one modifier. Function keys are exempt: they aren't used
    /// for typing, which makes them legitimate one-press shortcuts.
    var isRegisterable: Bool {
        carbonModifiers != 0 || KeyCodeTranslator.isFunctionKey(keyCode)
    }

    var eventModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbonModifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if carbonModifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if carbonModifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if carbonModifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
    }

    /// The character an `NSMenuItem` needs to display this as an accelerator, or
    /// nil for keys that have no menu representation.
    var menuKeyEquivalent: String? {
        KeyCodeTranslator.menuKeyEquivalent(for: keyCode)
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        return carbon
    }
}

// MARK: - Persistence

enum ShortcutStore {
    private static let defaultsKey = "ScreenReadShortcut"

    static var current: Shortcut {
        get {
            guard let data = UserDefaults.standard.data(forKey: defaultsKey),
                  let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) else {
                return .default
            }
            return shortcut
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}

// MARK: - Key code rendering

enum KeyCodeTranslator {
    private struct SpecialKey {
        let display: String
        /// The literal character `NSMenuItem.keyEquivalent` expects.
        let menuCharacter: String?
    }

    private static let specialKeys: [UInt32: SpecialKey] = [
        UInt32(kVK_Return): SpecialKey(display: "↩", menuCharacter: "\r"),
        UInt32(kVK_ANSI_KeypadEnter): SpecialKey(display: "⌤", menuCharacter: "\u{3}"),
        UInt32(kVK_Tab): SpecialKey(display: "⇥", menuCharacter: "\t"),
        UInt32(kVK_Space): SpecialKey(display: "Space", menuCharacter: " "),
        UInt32(kVK_Delete): SpecialKey(display: "⌫", menuCharacter: "\u{8}"),
        UInt32(kVK_ForwardDelete): SpecialKey(display: "⌦", menuCharacter: "\u{7f}"),
        UInt32(kVK_Escape): SpecialKey(display: "⎋", menuCharacter: "\u{1b}"),
        UInt32(kVK_Home): SpecialKey(display: "↖", menuCharacter: "\u{f729}"),
        UInt32(kVK_End): SpecialKey(display: "↘", menuCharacter: "\u{f72b}"),
        UInt32(kVK_PageUp): SpecialKey(display: "⇞", menuCharacter: "\u{f72c}"),
        UInt32(kVK_PageDown): SpecialKey(display: "⇟", menuCharacter: "\u{f72d}"),
        UInt32(kVK_LeftArrow): SpecialKey(display: "←", menuCharacter: "\u{f702}"),
        UInt32(kVK_RightArrow): SpecialKey(display: "→", menuCharacter: "\u{f703}"),
        UInt32(kVK_UpArrow): SpecialKey(display: "↑", menuCharacter: "\u{f700}"),
        UInt32(kVK_DownArrow): SpecialKey(display: "↓", menuCharacter: "\u{f701}"),
    ]

    /// kVK_F1…kVK_F20 are not contiguous, so they are listed in order and paired
    /// with NSF1FunctionKey (0xF704) upwards.
    private static let functionKeyCodes: [UInt32] = [
        UInt32(kVK_F1), UInt32(kVK_F2), UInt32(kVK_F3), UInt32(kVK_F4),
        UInt32(kVK_F5), UInt32(kVK_F6), UInt32(kVK_F7), UInt32(kVK_F8),
        UInt32(kVK_F9), UInt32(kVK_F10), UInt32(kVK_F11), UInt32(kVK_F12),
        UInt32(kVK_F13), UInt32(kVK_F14), UInt32(kVK_F15), UInt32(kVK_F16),
        UInt32(kVK_F17), UInt32(kVK_F18), UInt32(kVK_F19), UInt32(kVK_F20),
    ]

    static func isFunctionKey(_ keyCode: UInt32) -> Bool {
        functionKeyCodes.contains(keyCode)
    }

    static func modifierSymbols(_ carbonModifiers: UInt32) -> String {
        var symbols = ""
        if carbonModifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        return symbols
    }

    static func displayName(for keyCode: UInt32) -> String {
        if let special = specialKeys[keyCode] { return special.display }
        if let index = functionKeyCodes.firstIndex(of: keyCode) { return "F\(index + 1)" }
        if let character = characterFromKeyboardLayout(keyCode) { return character.uppercased() }
        return "Key \(keyCode)"
    }

    static func menuKeyEquivalent(for keyCode: UInt32) -> String? {
        if let special = specialKeys[keyCode] { return special.menuCharacter }
        if let index = functionKeyCodes.firstIndex(of: keyCode) {
            return String(UnicodeScalar(0xF704 + index)!)
        }
        return characterFromKeyboardLayout(keyCode)?.lowercased()
    }

    /// Resolves a virtual key code against the *current* keyboard layout, so a
    /// French or Dvorak user sees the key they actually pressed rather than the
    /// QWERTY letter sharing that position.
    private static func characterFromKeyboardLayout(_ keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let layoutData = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var characters = [UniChar](repeating: 0, count: 4)
        var length = 0

        let status = layoutData.withUnsafeBytes { raw -> OSStatus in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(
                layout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0, // no modifiers: we want the key's base character
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
        }

        guard status == noErr, length > 0 else { return nil }
        let result = String(utf16CodeUnits: characters, count: length)
        return result.isEmpty ? nil : result
    }
}
