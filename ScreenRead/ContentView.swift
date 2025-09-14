import SwiftUI
import Vision
import AppKit

// MARK: - Main View
struct ContentView: View {
    @StateObject private var hotkeyManager = HotkeyManager()
    @State private var snippingController: SnippingWindowController?
    @State private var hasScreenRecordingPermission = false
    
    var body: some View {
        VStack {
            Text("ScreenRead")
                .font(.largeTitle)
                .padding()
            
            if hasScreenRecordingPermission {
                Button("Capture & Read") {
                    triggerSnipping()
                }
                .padding()
                
                Text("Press Cmd+Shift+T anywhere to capture")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Button("Request Screen Recording Permission") {
                    requestScreenRecordingPermission()
                }
                .padding()
                
                Text("Screen recording permission is required")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .frame(width: 400, height: 200)
        .onAppear {
            checkScreenRecordingPermission()
            hotkeyManager.onHotkeyPressed = {
                print("🔥 ContentView: Hotkey pressed!")
                triggerSnipping()
            }
        }
    }
    
    private func checkScreenRecordingPermission() {
        print("🔍 Checking screen recording permission...")
        
        // For now, assume we have permission and let the system handle it
        hasScreenRecordingPermission = true
        print("✅ Assuming screen recording permission (will be checked at capture time)")
    }
    
    private func requestScreenRecordingPermission() {
        print("🔍 Requesting screen recording permission...")
        
        // Open System Preferences to Screen Recording settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
        
        // Set permission to true so user can try
        hasScreenRecordingPermission = true
    }
    
    private func triggerSnipping() {
        print("🎯 Triggering snipping...")
        
        guard hasScreenRecordingPermission else {
            print("❌ No screen recording permission")
            requestScreenRecordingPermission()
            return
        }
        
        let controller = SnippingWindowController { rect in
            print("📐 Selection received: \(rect)")
            Task {
                await captureAndRecognizeRegion(rect: rect)
            }
        }
        snippingController = controller
        controller.show()
    }
}

// MARK: - Screen Capture with Region Crop
func captureAndRecognizeRegion(rect: CGRect) async {
    print("🚀 Starting capture for region: \(rect)")
    
    // Use CGWindowListCreateImage for direct screen capture
    await MainActor.run {
        captureScreenRegion(rect: rect)
    }
}

// MARK: - Direct Screen Capture
func captureScreenRegion(rect: CGRect) {
    print("📐 Capturing region: \(rect)")
    
    let tempFile = "/tmp/screenread_capture.png"
    
    // Convert rect to screencapture format (x,y,width,height)
    let x = Int(rect.minX)
    let y = Int(rect.minY)
    let width = Int(rect.width)
    let height = Int(rect.height)
    
    print("📐 Capture region: x=\(x), y=\(y), w=\(width), h=\(height)")
    
    // Use screencapture with minimal flags
    let process = Process()
    process.launchPath = "/usr/sbin/screencapture"
    process.arguments = ["-x", "-R", "\(x),\(y),\(width),\(height)", tempFile]
    
    do {
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            print("✅ Screenshot captured successfully")
            
            // Load the image
            if let image = NSImage(contentsOfFile: tempFile),
               let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                print("✅ Loaded image: \(cgImage.width)x\(cgImage.height)")
                recognizeText(from: cgImage)
            } else {
                print("❌ Failed to load captured image")
            }
            
            // Clean up temp file
            try? FileManager.default.removeItem(atPath: tempFile)
        } else {
            print("❌ screencapture failed with status: \(process.terminationStatus)")
            showDevelopmentPermissionAlert()
        }
    } catch {
        print("❌ Failed to run screencapture: \(error)")
        showDevelopmentPermissionAlert()
    }
}

// MARK: - Development Permission Alert
func showDevelopmentPermissionAlert() {
    let alert = NSAlert()
    alert.messageText = "Development Permission Issue"
    alert.informativeText = """
    The screen recording permission keeps getting revoked because the app signature changes with each build during development.
    
    SOLUTION: Run this command in Terminal, then restart the app:
    
    sudo tccutil reset ScreenCapture com.JaneshKapoor.ScreenRead
    
    This is a known issue during Xcode development. The permission will work normally in production builds.
    """
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Copy Command")
    alert.addButton(withTitle: "Open System Settings")
    alert.addButton(withTitle: "Cancel")
    
    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
        // Copy the command to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("sudo tccutil reset ScreenCapture com.JaneshKapoor.ScreenRead", forType: .string)
        
        // Show confirmation
        let confirmAlert = NSAlert()
        confirmAlert.messageText = "Command Copied"
        confirmAlert.informativeText = "The reset command has been copied to your clipboard. Paste it in Terminal and run it."
        confirmAlert.alertStyle = .informational
        confirmAlert.runModal()
    } else if response == .alertSecondButtonReturn {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - OCR
func recognizeText(from image: CGImage) {
    print("🔤 Starting OCR on image: \(image.width)x\(image.height)")
    
    let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
    let request = VNRecognizeTextRequest { (request, error) in
        if let error = error {
            print("❌ OCR Error: \(error)")
            return
        }
        
        guard let observations = request.results as? [VNRecognizedTextObservation] else { 
            print("❌ No OCR observations found")
            return 
        }
        
        print("🔍 Found \(observations.count) text observations")
        
        let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        
        if text.isEmpty {
            print("⚠️ No text extracted from image")
        } else {
            // Copy to clipboard
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            
            print("✅ Extracted Text (\(text.count) characters):\n\(text)")
            
            // Show a notification or alert
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Text Extracted!"
                alert.informativeText = "Copied \(text.count) characters to clipboard"
                alert.alertStyle = .informational
                alert.runModal()
            }
        }
    }
    
    request.recognitionLevel = .accurate
    
    do {
        try requestHandler.perform([request])
    } catch {
        print("❌ OCR Error: \(error)")
    }
}

// MARK: - Helper Extensions
extension NSImage {
    var cgImage: CGImage? {
        var proposedRect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
    }
}


