import SwiftUI

struct SettingsView: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var hasPermission = Permissions.hasScreenRecordingAccess

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 28))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ScreenRead").font(.title2.weight(.semibold))
                    Text("Snip anything, get the text on your clipboard.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            LabeledContent("Shortcut") {
                Text(Shortcut.default.displayName)
                    .font(.system(.body, design: .monospaced))
            }

            LabeledContent("Screen Recording") {
                HStack(spacing: 6) {
                    Image(systemName: hasPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(hasPermission ? .green : .red)
                    Text(hasPermission ? "Granted" : "Not granted")
                    if !hasPermission {
                        Button("Open Settings…") { Permissions.openScreenRecordingSettings() }
                            .controlSize(.small)
                    }
                }
            }

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    LaunchAtLogin.isEnabled = newValue
                    launchAtLogin = LaunchAtLogin.isEnabled
                }

            Spacer()
        }
        .padding(24)
        .frame(width: 420, height: 260)
        .onAppear { hasPermission = Permissions.hasScreenRecordingAccess }
    }
}
