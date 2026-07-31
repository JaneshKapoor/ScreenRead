import AppKit
import Carbon.HIToolbox

/// Registers a system-wide hotkey using the Carbon hotkey API.
///
/// Carbon hotkeys are used deliberately: unlike a `CGEventTap` or
/// `NSEvent.addGlobalMonitorForEvents`, they work without the Accessibility
/// permission and fire even when another app is frontmost.
final class HotkeyManager {
    var onHotkeyPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var selfPtr: UnsafeMutableRawPointer?

    private let hotKeyID = EventHotKeyID(signature: OSType(0x5343_5244), id: 1) // 'SCRD'

    deinit {
        unregister()
    }

    /// - Returns: `true` if the shortcut was claimed successfully.
    @discardableResult
    func register(shortcut: Shortcut) -> Bool {
        unregister()

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        selfPtr = pointer

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData, let event else { return OSStatus(eventNotHandledErr) }

                var firedID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    OSType(kEventParamDirectObject),
                    OSType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &firedID
                )
                guard status == noErr else { return OSStatus(eventNotHandledErr) }

                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                guard firedID.id == manager.hotKeyID.id else { return OSStatus(eventNotHandledErr) }

                DispatchQueue.main.async {
                    manager.onHotkeyPressed?()
                }
                return noErr
            },
            1,
            &spec,
            pointer,
            &eventHandler
        )

        guard handlerStatus == noErr else {
            Log.error("Failed to install hotkey event handler (status \(handlerStatus))")
            return false
        }

        let registerStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            Log.error("Failed to register \(shortcut.displayName) (status \(registerStatus))")
            unregister()
            return false
        }

        Log.info("Registered global shortcut \(shortcut.displayName)")
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        selfPtr = nil
    }
}
