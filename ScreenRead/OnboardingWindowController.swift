import AppKit
import SwiftUI

/// Shows `OnboardingView` on first launch, and on demand from the menu bar.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindowController()

    private static let hasCompletedKey = "ScreenReadHasCompletedOnboarding"

    private var window: NSWindow?

    /// What to run when the user taps "Try It Now" — wired to the capture
    /// coordinator by the app delegate.
    var onTryCapture: (() -> Void)?

    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: hasCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasCompletedKey) }
    }

    /// Shows the window only the first time the app is ever run.
    func showIfFirstLaunch() {
        guard !Self.hasCompletedOnboarding else { return }
        show()
    }

    /// Must match the `.frame` on `OnboardingView`.
    static let contentSize = NSSize(width: 520, height: 500)

    /// Builds the window without showing it, so its geometry can be tested.
    ///
    /// The style and size are passed to the initialiser rather than assigned
    /// afterwards. Creating the window with `NSWindow(contentViewController:)`
    /// and then replacing `styleMask` discards the size the window derived from
    /// its content — and this window opens during
    /// `applicationDidFinishLaunching`, before SwiftUI has laid out, so there is
    /// no intrinsic size left to recover it from. That combination collapsed the
    /// window to a 1×28pt sliver.
    static func makeWindow(contentViewController: NSViewController) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = contentViewController
        window.setContentSize(contentSize)
        window.title = "Welcome to ScreenRead"
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    func show() {
        if window == nil {
            let view = OnboardingView(
                onFinish: { [weak self] in self?.finish() },
                onTryCapture: { [weak self] in self?.tryCapture() }
            )
            let window = Self.makeWindow(
                contentViewController: NSHostingController(rootView: view)
            )
            window.delegate = self
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        Self.hasCompletedOnboarding = true
        window?.close()
    }

    /// Closes the window before capturing, so the overlay isn't covering it and
    /// the snapshot isn't full of onboarding text.
    private func tryCapture() {
        Self.hasCompletedOnboarding = true
        window?.close()
        // One run-loop pass so the window is really gone before the screen is
        // snapshotted.
        DispatchQueue.main.async { [weak self] in
            self?.onTryCapture?()
        }
    }

    func windowWillClose(_ notification: Notification) {
        // Dismissing with the red button counts as done — otherwise the window
        // comes back on every launch until the Done button is used.
        Self.hasCompletedOnboarding = true
        NSApp.deactivate()
    }
}
