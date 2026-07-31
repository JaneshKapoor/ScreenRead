import AppKit

/// A brief, non-blocking confirmation toast.
///
/// The whole point of ScreenRead is that a snip lands on the clipboard without
/// breaking your flow, so feedback must never be a modal the user has to dismiss.
@MainActor
enum HUD {
    private static var window: NSWindow?
    private static var dismissWorkItem: DispatchWorkItem?

    static func show(message: String, symbol: String, duration: TimeInterval = 1.8) {
        dismiss(animated: false)

        let content = makeContentView(message: message, symbol: symbol)
        let size = content.fittingSize

        let screen = screenUnderCursor()
        let origin = CGPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.minY + screen.frame.height * 0.12
        )

        let panel = NSPanel(
            contentRect: CGRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = content
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }

        window = panel

        let workItem = DispatchWorkItem { dismiss(animated: true) }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    private static func dismiss(animated: Bool) {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil

        guard let panel = window else { return }
        window = nil

        guard animated else {
            panel.orderOut(nil)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
    }

    private static func makeContentView(message: String, symbol: String) -> NSView {
        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 12
        blur.layer?.masksToBounds = true

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.symbolConfiguration = .init(pointSize: 15, weight: .semibold)
        icon.contentTintColor = .labelColor

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor

        let stack = NSStackView(views: [icon, label])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false

        blur.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: blur.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
            stack.topAnchor.constraint(equalTo: blur.topAnchor),
            stack.bottomAnchor.constraint(equalTo: blur.bottomAnchor),
        ])

        blur.frame = CGRect(origin: .zero, size: stack.fittingSize)
        return blur
    }

    private static func screenUnderCursor() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}
