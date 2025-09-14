import Cocoa
import SwiftUI

// Custom window class that can become key
class SnippingWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

class SnippingWindowController: NSWindowController {
    private var onSelection: ((CGRect) -> Void)?
    
    convenience init(onSelection: @escaping (CGRect) -> Void) {
        let window = SnippingWindow(
            contentRect: NSScreen.main?.frame ?? NSRect.zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.init(window: window)
        self.onSelection = onSelection
        
        setupWindow()
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.level = .screenSaver  // Higher level to ensure it's on top
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        
        // Cover all screens
        if let screen = NSScreen.main {
            window.setFrame(screen.frame, display: true)
        }
        
        let contentView = SnippingOverlayView { [weak self] rect in
            self?.onSelection?(rect)
            self?.close()
        }
        
        window.contentView = NSHostingView(rootView: contentView)
    }
    
    func show() {
        print("🪟 Showing snipping window...")
        
        guard let window = window else {
            print("❌ No window to show")
            return
        }
        
        // Force the app to be active
        NSApp.activate(ignoringOtherApps: true)
        
        // Show the window
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        
        // Ensure the window is key and main
        window.makeKey()
        window.makeMain()
        
        // Force focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.makeKey()
            NSCursor.crosshair.set()
            print("✅ Window shown and focused with crosshair cursor")
        }
    }
}

struct SnippingOverlayView: View {
    let onSelection: (CGRect) -> Void
    @GestureState private var dragRect: CGRect = .zero
    @State private var isActive = false
    @State private var mouseLocation: CGPoint = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.4)
                    .ignoresSafeArea(.all)
                    .contentShape(Rectangle())
                
                // Instructions text
                VStack {
                    Text("Drag to select area for text extraction")
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    
                    Text("Press ESC to cancel")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                        .padding(.top, 4)
                    
                    Spacer()
                }
                .padding(.top, 50)
                
                // Selection rectangle
                if dragRect != .zero {
                    Rectangle()
                        .frame(width: dragRect.width, height: dragRect.height)
                        .position(x: dragRect.midX, y: dragRect.midY)
                        .foregroundStyle(Color.clear)
                        .overlay(
                            Rectangle()
                                .stroke(Color.blue, lineWidth: 3)
                                .shadow(color: .white, radius: 1)
                        )
                        .overlay(
                            // Selection info
                            Text("\(Int(dragRect.width)) × \(Int(dragRect.height))")
                                .foregroundColor(.white)
                                .font(.caption)
                                .padding(4)
                                .background(Color.blue)
                                .cornerRadius(4)
                                .position(x: dragRect.width / 2, y: -20)
                        )
                }
            }
            .gesture(DragGesture(minimumDistance: 0)
                .updating($dragRect) { value, state, _ in
                    state = CGRect(
                        x: min(value.startLocation.x, value.location.x),
                        y: min(value.startLocation.y, value.location.y),
                        width: abs(value.location.x - value.startLocation.x),
                        height: abs(value.location.y - value.startLocation.y)
                    )
                }
                .onEnded { value in
                    let rect = CGRect(
                        x: min(value.startLocation.x, value.location.x),
                        y: min(value.startLocation.y, value.location.y),
                        width: abs(value.location.x - value.startLocation.x),
                        height: abs(value.location.y - value.startLocation.y)
                    )
                    
                    print("🔍 Raw selection: \(rect)")
                    
                    // Only proceed if we have a meaningful selection
                    guard rect.width > 10 && rect.height > 10 else { 
                        print("❌ Selection too small: \(rect.width)x\(rect.height)")
                        return 
                    }
                    
                    // Convert to screen coordinates
                    if let screen = NSScreen.main {
                        let screenRect = screen.frame
                        print("📺 Screen frame: \(screenRect)")
                        
                        // Convert from SwiftUI view coordinates to screen coordinates
                        // The view coordinates are relative to the window, which covers the screen
                        let screenRect_converted = CGRect(
                            x: screenRect.minX + rect.minX,
                            y: screenRect.minY + rect.minY,
                            width: rect.width,
                            height: rect.height
                        )
                        
                        print("✅ Screen-relative rect: \(screenRect_converted)")
                        onSelection(screenRect_converted)
                    } else {
                        print("❌ Could not get main screen")
                        onSelection(rect)
                    }
                }
            )
        }
        .onAppear {
            // Set crosshair cursor
            NSCursor.crosshair.set()
        }
        .onDisappear {
            // Reset cursor
            NSCursor.arrow.set()
        }
        .onKeyPress(.escape) {
            if let window = NSApp.keyWindow {
                window.close()
            }
            return .handled
        }
    }
}