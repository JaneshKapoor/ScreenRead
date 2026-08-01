import SwiftUI

/// First-run walkthrough.
///
/// ScreenRead is an `.accessory` app whose entire interface is a menu bar icon,
/// so without this a first launch looks identical to nothing happening — and a
/// reviewer who hasn't granted Screen Recording yet would see an app that
/// appears to do nothing at all. This window states what the app is, where it
/// lives, and what it still needs before it can work.
struct OnboardingView: View {
    @ObservedObject private var hotkeys = HotkeyController.shared
    @State private var hasPermission = Permissions.hasScreenRecordingAccess

    /// Screen Recording status is polled rather than observed: TCC sends no
    /// notification when the user flips the toggle, and `CGPreflightScreenCaptureAccess`
    /// only starts reporting the new answer some time afterwards.
    private let permissionPoll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var onFinish: () -> Void
    var onTryCapture: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider().padding(.vertical, 20)

            VStack(alignment: .leading, spacing: 18) {
                step(
                    number: 1,
                    title: "Press \(hotkeys.shortcut.displayName) anywhere",
                    detail: "A crosshair appears over your screen. Drag a box around any text."
                )
                step(
                    number: 2,
                    title: "Let go",
                    detail: "The text lands on your clipboard, ready to paste. Everything stays on this Mac."
                )
                step(
                    number: 3,
                    title: "Find ScreenRead in the menu bar",
                    // Built by concatenating Text rather than interpolating the
                    // Image into a String: string interpolation would render
                    // SwiftUI's debug description of the Image struct.
                    detail: Text("The ")
                        + Text(Image(systemName: "text.viewfinder"))
                        + Text(" icon at the top of the screen. There's no Dock icon and no window — it just waits for the shortcut.")
                )
            }

            Spacer(minLength: 20)

            permissionPanel

            HStack {
                Spacer()
                Button("Try It Now", action: onTryCapture)
                    .disabled(!hasPermission)
                Button("Done", action: onFinish)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 16)
        }
        .padding(28)
        .frame(width: 520, height: 500, alignment: .topLeading)
        .onReceive(permissionPoll) { _ in
            hasPermission = Permissions.hasScreenRecordingAccess
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text("Welcome to ScreenRead").font(.title.weight(.semibold))
                Text("Snip anything on screen, get the text on your clipboard.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func step(number: Int, title: String, detail: Text) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(.tint))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.semibold))
                detail.font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private func step(number: Int, title: String, detail: String) -> some View {
        step(number: number, title: title, detail: Text(detail))
    }

    @ViewBuilder
    private var permissionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(hasPermission ? "Screen Recording is on" : "Screen Recording is needed")
                    .font(.body.weight(.semibold))
            } icon: {
                Image(systemName: hasPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(hasPermission ? .green : .orange)
            }

            if !hasPermission {
                Text("Reading text off the screen means reading the screen, so macOS asks for this permission first. ScreenRead never records, uploads or stores anything — the pixels go straight to the on-device text recogniser and are discarded.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button("Open System Settings") {
                        Permissions.openScreenRecordingSettings()
                    }
                    Text("then quit and reopen ScreenRead")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
