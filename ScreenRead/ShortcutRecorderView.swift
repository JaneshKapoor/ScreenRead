import AppKit
import SwiftUI

/// Click to record, then press any combination to rebind the capture shortcut.
///
/// Keys are read through a local event monitor rather than a focused control.
/// A monitor sees the event before menu key equivalents are matched, so
/// combinations macOS would otherwise consume — ⌘Q, ⌘W, ⌘, — can still be
/// recorded instead of quitting the app mid-recording.
struct ShortcutRecorderView: View {
    @ObservedObject var controller: HotkeyController

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var message: Message?

    private struct Message: Identifiable {
        let id = UUID()
        let text: String
        let isError: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button(action: toggleRecording) {
                    Text(isRecording ? "Press keys…" : controller.shortcut.displayName)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .frame(minWidth: 96)
                }
                .buttonStyle(.bordered)
                .tint(isRecording ? .accentColor : nil)

                if isRecording {
                    Button("Cancel", action: stopRecording)
                        .controlSize(.small)
                } else {
                    Button("Reset", action: reset)
                        .controlSize(.small)
                        .disabled(controller.shortcut == .default)
                }
            }

            if let message {
                Label(message.text, systemImage: message.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(message.isError ? Color.red : Color.secondary)
            } else if isRecording {
                Text("Esc cancels. Function keys work on their own; other keys need a modifier.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !controller.isRegistered {
                Label("Another app is using this shortcut", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    // MARK: - Recording

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        guard monitor == nil else { return }
        message = nil
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil // swallow, so the keystroke never reaches the app
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
    }

    private func handle(_ event: NSEvent) {
        // Bare Escape backs out without changing anything.
        if event.keyCode == 53, Shortcut.carbonModifiers(from: event.modifierFlags) == 0 {
            stopRecording()
            return
        }

        let candidate = Shortcut(event: event)
        switch controller.update(to: candidate) {
        case .ok:
            stopRecording()
            message = Message(text: "Shortcut set to \(candidate.displayName)", isError: false)
        case .conflict:
            stopRecording()
            message = Message(
                text: "\(candidate.displayName) is already taken by another app",
                isError: true
            )
        case .needsModifier:
            // Stay in recording mode so they can just try again.
            message = Message(
                text: "Add ⌘, ⌥, ⌃ or ⇧ — or pick a function key",
                isError: true
            )
        }
    }

    private func reset() {
        switch controller.resetToDefault() {
        case .ok:
            message = Message(text: "Reset to \(Shortcut.default.displayName)", isError: false)
        case .conflict:
            message = Message(text: "\(Shortcut.default.displayName) is taken by another app", isError: true)
        case .needsModifier:
            break
        }
    }
}
