import AppKit

/// The region the user picked: which display's snapshot, and the rect inside it
/// (view coordinates — top-left origin, points).
struct SnipSelection {
    let snapshot: DisplaySnapshot
    let viewRect: CGRect
}

/// Puts a full-screen selection overlay on every display and reports the region
/// the user drags out. The overlays render the *frozen* snapshots taken just
/// before they appeared, so what the user selects is exactly what gets cropped.
final class SnipOverlayController {
    private var windows: [SnipOverlayWindow] = []
    private var keyMonitor: Any?
    private var completion: ((SnipSelection?) -> Void)?
    private var previousActivationPolicy: NSApplication.ActivationPolicy?

    var isPresenting: Bool { !windows.isEmpty }

    func present(snapshots: [DisplaySnapshot], completion: @escaping (SnipSelection?) -> Void) {
        guard !isPresenting else { return }
        self.completion = completion

        for snapshot in snapshots {
            let window = SnipOverlayWindow(snapshot: snapshot)
            window.selectionView.onSelect = { [weak self] rect in
                self?.finish(with: SnipSelection(snapshot: snapshot, viewRect: rect))
            }
            window.selectionView.onCancel = { [weak self] in
                self?.finish(with: nil)
            }
            windows.append(window)
        }

        // An .accessory app can still take key focus; without activating, the
        // overlay would never receive the Escape key.
        NSApp.activate(ignoringOtherApps: true)

        for window in windows {
            window.orderFrontRegardless()
        }
        windows.first?.makeKeyAndOrderFront(nil)
        NSCursor.crosshair.set()

        // Backstop for Escape in case key focus lands somewhere unexpected.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event } // Escape
            self?.finish(with: nil)
            return nil
        }
    }

    private func finish(with selection: SnipSelection?) {
        guard let completion else { return }
        self.completion = nil
        dismiss()
        completion(selection)
    }

    private func dismiss() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
        NSCursor.arrow.set()

        // Hand focus back to whatever the user was working in, so the very next
        // ⌘V pastes into the app they snipped from rather than into nothing.
        NSApp.deactivate()
    }
}

// MARK: - Window

final class SnipOverlayWindow: NSWindow {
    let selectionView: SnipSelectionView

    init(snapshot: DisplaySnapshot) {
        selectionView = SnipSelectionView(snapshot: snapshot)

        super.init(
            contentRect: snapshot.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Above everything, including full-screen apps and the menu bar.
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        setFrame(snapshot.frame, display: false)
        contentView = selectionView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Selection view

final class SnipSelectionView: NSView {
    var onSelect: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private let snapshot: DisplaySnapshot
    private let backdrop: NSImage
    private var anchorPoint: CGPoint?
    private var selection: CGRect = .zero
    private var hasDragged = false

    /// Anything smaller than this is treated as a stray click, not a selection.
    private let minimumSelectionSide: CGFloat = 5

    init(snapshot: DisplaySnapshot) {
        self.snapshot = snapshot
        self.backdrop = NSImage(cgImage: snapshot.image, size: snapshot.frame.size)
        super.init(frame: CGRect(origin: .zero, size: snapshot.frame.size))
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Top-left origin keeps view coordinates aligned with the snapshot's pixels.
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        backdrop.draw(in: bounds, from: .zero, operation: .copy, fraction: 1.0)

        NSColor.black.withAlphaComponent(0.45).setFill()
        bounds.fill()

        if selection.width >= 1, selection.height >= 1 {
            // Punch the selection back through to full brightness.
            backdrop.draw(
                in: selection,
                from: sourceRect(for: selection),
                operation: .copy,
                fraction: 1.0
            )

            NSColor.controlAccentColor.setStroke()
            let border = NSBezierPath(rect: selection.insetBy(dx: -0.5, dy: -0.5))
            border.lineWidth = 1.5
            border.stroke()

            drawSizeBadge()
        } else {
            drawHint()
        }
    }

    /// `NSImage.draw(from:)` wants a bottom-left-origin rect in image space, but
    /// this view is flipped — so the y axis has to be mirrored.
    private func sourceRect(for rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX,
            y: bounds.height - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private func drawSizeBadge() {
        let scale = snapshot.scale
        let label = "\(Int(selection.width * scale)) × \(Int(selection.height * scale))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = label.size(withAttributes: attributes)
        let padding = CGSize(width: 8, height: 4)

        var badge = CGRect(
            x: selection.minX,
            y: selection.minY - size.height - padding.height * 2 - 6,
            width: size.width + padding.width * 2,
            height: size.height + padding.height * 2
        )
        // Flip below the selection if there is no room above it.
        if badge.minY < 0 { badge.origin.y = selection.maxY + 6 }
        badge.origin.x = min(badge.origin.x, bounds.maxX - badge.width - 4)

        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: badge, xRadius: 4, yRadius: 4).fill()
        label.draw(
            at: CGPoint(x: badge.minX + padding.width, y: badge.minY + padding.height),
            withAttributes: attributes
        )
    }

    private func drawHint() {
        let label = "Drag to select text  ·  Esc to cancel"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = label.size(withAttributes: attributes)
        let padding = CGSize(width: 16, height: 10)
        let pill = CGRect(
            x: bounds.midX - (size.width + padding.width * 2) / 2,
            y: bounds.height * 0.08,
            width: size.width + padding.width * 2,
            height: size.height + padding.height * 2
        )

        NSColor.black.withAlphaComponent(0.65).setFill()
        NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
        label.draw(
            at: CGPoint(x: pill.minX + padding.width, y: pill.minY + padding.height),
            withAttributes: attributes
        )
    }

    // MARK: Cursor

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        anchorPoint = clamped(convert(event.locationInWindow, from: nil))
        hasDragged = false
        selection = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let anchorPoint else { return }
        hasDragged = true
        selection = Self.rect(from: anchorPoint, to: clamped(convert(event.locationInWindow, from: nil)))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let anchorPoint else { return }
        let rect = Self.rect(from: anchorPoint, to: clamped(convert(event.locationInWindow, from: nil)))
        self.anchorPoint = nil
        selection = .zero
        needsDisplay = true

        guard hasDragged,
              rect.width >= minimumSelectionSide,
              rect.height >= minimumSelectionSide else {
            onCancel?()
            return
        }
        onSelect?(rect)
    }

    override func rightMouseDown(with event: NSEvent) {
        onCancel?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: Geometry helpers

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }

    private static func rect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(a.x - b.x),
            height: abs(a.y - b.y)
        )
    }
}
