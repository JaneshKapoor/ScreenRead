import Cocoa
import Carbon

class HotkeyManager: ObservableObject {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x4B4F4D50), id: 1) // 'KOMP'
    
    var onHotkeyPressed: (() -> Void)?
    
    init() {
        print("🔥 HotkeyManager: Initializing...")
        registerHotkey()
    }
    
    deinit {
        print("🔥 HotkeyManager: Deinitializing...")
        unregisterHotkey()
    }
    
    private func registerHotkey() {
        print("🔥 HotkeyManager: Registering Cmd+Shift+T hotkey...")
        
        // Cmd + Shift + T
        let keyCode = UInt32(kVK_ANSI_T)
        let modifiers = UInt32(cmdKey | shiftKey)
        
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        let eventHandlerCallback: EventHandlerProcPtr = { (nextHandler, theEvent, userData) -> OSStatus in
            print("🔥 HotkeyManager: Event handler called!")
            
            guard let userData = userData else {
                print("❌ HotkeyManager: No user data")
                return OSStatus(eventNotHandledErr)
            }
            
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            
            var hotKeyID = EventHotKeyID()
            let result = GetEventParameter(theEvent, OSType(kEventParamDirectObject), OSType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            if result == noErr && hotKeyID.id == manager.hotKeyID.id {
                print("✅ HotkeyManager: Hotkey matched! Triggering callback...")
                DispatchQueue.main.async {
                    manager.onHotkeyPressed?()
                }
                return OSStatus(noErr)
            }
            
            return OSStatus(eventNotHandledErr)
        }
        
        let installResult = InstallEventHandler(GetApplicationEventTarget(), eventHandlerCallback, 1, &eventSpec, Unmanaged.passRetained(self).toOpaque(), &eventHandler)
        
        if installResult == noErr {
            print("✅ HotkeyManager: Event handler installed successfully")
        } else {
            print("❌ HotkeyManager: Failed to install event handler: \(installResult)")
        }
        
        let registerResult = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        if registerResult == noErr {
            print("✅ HotkeyManager: Hotkey registered successfully")
        } else {
            print("❌ HotkeyManager: Failed to register hotkey: \(registerResult)")
        }
    }
    
    private func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            let result = UnregisterEventHotKey(hotKeyRef)
            print("🔥 HotkeyManager: Unregistered hotkey with result: \(result)")
            self.hotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            let result = RemoveEventHandler(eventHandler)
            print("🔥 HotkeyManager: Removed event handler with result: \(result)")
            self.eventHandler = nil
        }
    }
}