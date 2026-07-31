import AppKit

/// Drives one end-to-end capture: snapshot ▸ select ▸ crop ▸ OCR ▸ clipboard.
@MainActor
final class CaptureCoordinator {
    private let overlay = SnipOverlayController()
    private var isBusy = false

    func beginCapture() {
        guard !isBusy, !overlay.isPresenting else { return }

        // Deliberately no preflight check here. CGPreflightScreenCaptureAccess
        // goes stale after the user grants permission, so gating on it shows a
        // "permission required" alert to users who just granted it. Attempt the
        // capture and let the real failure be the signal.
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let snapshots = try await ScreenCapturer.captureAllDisplays()
                presentOverlay(with: snapshots)
            } catch {
                Log.error("Capture failed: \(error.localizedDescription)")
                if case CaptureError.screenRecordingDenied = error {
                    Permissions.presentScreenRecordingAlert()
                } else {
                    HUD.show(message: error.localizedDescription, symbol: "exclamationmark.triangle.fill")
                }
            }
        }
    }

    private func presentOverlay(with snapshots: [DisplaySnapshot]) {
        overlay.present(snapshots: snapshots) { [weak self] selection in
            guard let self, let selection else { return }
            self.process(selection)
        }
    }

    private func process(_ selection: SnipSelection) {
        let cropped: CGImage
        do {
            cropped = try ScreenCapturer.crop(selection.snapshot, toViewRect: selection.viewRect)
        } catch {
            Log.error("Crop failed: \(error.localizedDescription)")
            HUD.show(message: "Couldn't read that region", symbol: "exclamationmark.triangle.fill")
            return
        }

        Task.detached(priority: .userInitiated) {
            let text: String
            do {
                text = try TextRecognizer.recognizeText(in: cropped)
            } catch {
                Log.error("OCR failed: \(error.localizedDescription)")
                await HUD.show(message: "Text recognition failed", symbol: "exclamationmark.triangle.fill")
                return
            }

            await MainActor.run {
                guard !text.isEmpty else {
                    HUD.show(message: "No text found in selection", symbol: "text.magnifyingglass")
                    return
                }

                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)

                Log.info("Copied \(text.count) characters to the clipboard")
                HUD.show(message: Self.summary(for: text), symbol: "doc.on.clipboard.fill")
            }
        }
    }

    private static func summary(for text: String) -> String {
        let characters = text.count
        let unit = characters == 1 ? "character" : "characters"
        return "Copied \(characters) \(unit)"
    }
}
