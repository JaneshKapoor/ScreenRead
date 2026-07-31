import AppKit
import ScreenCaptureKit

/// A frozen, full-resolution screenshot of one display, paired with the AppKit
/// geometry needed to map window coordinates back onto its pixels.
struct DisplaySnapshot {
    let displayID: CGDirectDisplayID
    /// Pixel buffer for the whole display (`frame.size * scale` pixels).
    let image: CGImage
    /// Display bounds in the global AppKit coordinate space (bottom-left origin, points).
    let frame: CGRect
    /// Backing scale factor — 2.0 on Retina.
    let scale: CGFloat
}

enum CaptureError: LocalizedError {
    case screenRecordingDenied
    case noDisplays
    case cropFailed

    var errorDescription: String? {
        switch self {
        case .screenRecordingDenied:
            return "ScreenRead needs Screen Recording permission to read the screen."
        case .noDisplays:
            return "No displays were available to capture."
        case .cropFailed:
            return "The selected region could not be cropped."
        }
    }
}

enum ScreenCapturer {
    /// Grabs every attached display at once, before any overlay is shown.
    ///
    /// Snapshotting first (rather than capturing after the user drags) means the
    /// dimmed selection UI can never end up inside the captured pixels, and the
    /// screen the user selects on is guaranteed to be the screen they saw.
    static func captureAllDisplays() async throws -> [DisplaySnapshot] {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
        } catch {
            Log.error("SCShareableContent failed: \(error.localizedDescription)")
            throw CaptureError.screenRecordingDenied
        }

        guard !content.displays.isEmpty else { throw CaptureError.noDisplays }

        var snapshots: [DisplaySnapshot] = []
        for display in content.displays {
            guard let screen = NSScreen.screen(for: display.displayID) else { continue }

            let scale = screen.backingScaleFactor
            let configuration = SCStreamConfiguration()
            configuration.width = Int((screen.frame.width * scale).rounded())
            configuration.height = Int((screen.frame.height * scale).rounded())
            configuration.captureResolution = .best
            configuration.showsCursor = false
            configuration.scalesToFit = false

            // Exclude ScreenRead's own windows so a leftover HUD never bleeds in.
            let filter = SCContentFilter(display: display, excludingApplications: ownApplications(in: content), exceptingWindows: [])

            do {
                let image = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: configuration
                )
                snapshots.append(
                    DisplaySnapshot(
                        displayID: display.displayID,
                        image: image,
                        frame: screen.frame,
                        scale: scale
                    )
                )
            } catch {
                Log.error("Capture failed for display \(display.displayID): \(error.localizedDescription)")
            }
        }

        guard !snapshots.isEmpty else { throw CaptureError.screenRecordingDenied }
        return snapshots
    }

    private static func ownApplications(in content: SCShareableContent) -> [SCRunningApplication] {
        let pid = ProcessInfo.processInfo.processIdentifier
        return content.applications.filter { $0.processID == pid }
    }

    /// Crops a snapshot to a rect expressed in the snapshot's *view* coordinates
    /// (top-left origin, points), converting to pixels via the backing scale.
    static func crop(_ snapshot: DisplaySnapshot, toViewRect rect: CGRect) throws -> CGImage {
        let scale = CGFloat(snapshot.image.width) / snapshot.frame.width
        let pixelRect = CGRect(
            x: (rect.minX * scale).rounded(.down),
            y: (rect.minY * scale).rounded(.down),
            width: (rect.width * scale).rounded(.up),
            height: (rect.height * scale).rounded(.up)
        )

        let bounds = CGRect(x: 0, y: 0, width: snapshot.image.width, height: snapshot.image.height)
        let clamped = pixelRect.intersection(bounds)

        guard !clamped.isNull, clamped.width >= 1, clamped.height >= 1,
              let cropped = snapshot.image.cropping(to: clamped) else {
            throw CaptureError.cropFailed
        }
        return cropped
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        screens.first { $0.displayID == displayID }
    }
}
