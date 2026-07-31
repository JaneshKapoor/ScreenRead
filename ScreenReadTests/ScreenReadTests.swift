import AppKit
import Testing
@testable import ScreenRead

/// Renders text into a bitmap so the OCR pipeline can be exercised without
/// touching the screen (and therefore without Screen Recording permission).
private func makeTextImage(
    lines: [String],
    size: CGSize = CGSize(width: 900, height: 400),
    fontSize: CGFloat = 60
) -> CGImage {
    let image = NSImage(size: size)
    image.lockFocus()

    NSColor.white.setFill()
    CGRect(origin: .zero, size: size).fill()

    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .regular),
        .foregroundColor: NSColor.black,
    ]

    // NSImage's focus context is bottom-left origin, so draw the last line lowest.
    for (index, line) in lines.enumerated() {
        let y = size.height - CGFloat(index + 1) * fontSize * 1.6
        line.draw(at: CGPoint(x: 40, y: y), withAttributes: attributes)
    }

    image.unlockFocus()

    var rect = CGRect(origin: .zero, size: size)
    return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
}

private func makeSolidImage(width: Int, height: Int) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

// MARK: - OCR

@MainActor
struct TextRecognizerTests {
    @Test func recognizesASingleLine() throws {
        let image = makeTextImage(lines: ["Hello ScreenRead"])
        let text = try TextRecognizer.recognizeText(in: image)
        #expect(text.contains("Hello"))
        #expect(text.contains("ScreenRead"))
    }

    @Test func preservesTopToBottomReadingOrder() throws {
        let image = makeTextImage(lines: ["First line", "Second line", "Third line"])
        let text = try TextRecognizer.recognizeText(in: image)

        let first = try #require(text.range(of: "First"))
        let second = try #require(text.range(of: "Second"))
        let third = try #require(text.range(of: "Third"))

        #expect(first.lowerBound < second.lowerBound)
        #expect(second.lowerBound < third.lowerBound)
    }

    @Test func splitsSeparateRowsOntoSeparateLines() throws {
        let image = makeTextImage(lines: ["Alpha", "Beta"])
        let text = try TextRecognizer.recognizeText(in: image)
        #expect(text.split(separator: "\n").count == 2)
    }

    @Test func returnsEmptyStringForBlankImage() throws {
        let text = try TextRecognizer.recognizeText(in: makeSolidImage(width: 200, height: 120))
        #expect(text.isEmpty)
    }
}

// MARK: - Crop geometry

struct CropTests {
    /// A 100×50 pt display on a 2× Retina screen → a 200×100 px snapshot.
    private var retinaSnapshot: DisplaySnapshot {
        DisplaySnapshot(
            displayID: 1,
            image: makeSolidImage(width: 200, height: 100),
            frame: CGRect(x: 0, y: 0, width: 100, height: 50),
            scale: 2
        )
    }

    @Test func scalesPointRectIntoPixels() throws {
        let cropped = try ScreenCapturer.crop(
            retinaSnapshot,
            toViewRect: CGRect(x: 10, y: 10, width: 20, height: 20)
        )
        #expect(cropped.width == 40)
        #expect(cropped.height == 40)
    }

    @Test func clampsSelectionToDisplayBounds() throws {
        // A drag that runs past the right/bottom edge must not overflow the buffer.
        let cropped = try ScreenCapturer.crop(
            retinaSnapshot,
            toViewRect: CGRect(x: 80, y: 40, width: 60, height: 60)
        )
        #expect(cropped.width == 40)  // (100 - 80) pt * 2
        #expect(cropped.height == 20) // (50 - 40) pt * 2
    }

    @Test func rejectsAnOffscreenSelection() {
        #expect(throws: CaptureError.self) {
            try ScreenCapturer.crop(
                retinaSnapshot,
                toViewRect: CGRect(x: 500, y: 500, width: 10, height: 10)
            )
        }
    }

    @Test func mapsOneToOneOnANonRetinaDisplay() throws {
        let snapshot = DisplaySnapshot(
            displayID: 2,
            image: makeSolidImage(width: 300, height: 200),
            frame: CGRect(x: 0, y: 0, width: 300, height: 200),
            scale: 1
        )
        let cropped = try ScreenCapturer.crop(
            snapshot,
            toViewRect: CGRect(x: 25, y: 35, width: 50, height: 60)
        )
        #expect(cropped.width == 50)
        #expect(cropped.height == 60)
    }
}

// MARK: - Shortcut

struct ShortcutTests {
    @Test func defaultShortcutIsCommandShiftT() {
        #expect(Shortcut.default.displayName == "⌘⇧T")
        #expect(Shortcut.default.keyCode == 17) // kVK_ANSI_T
    }
}

// MARK: - Overlay orientation

/// Top half red, bottom half blue. CGContext draws y-up, so the higher rect is
/// the top of the resulting image.
private func makeHalvedImage(width: Int, height: Int) -> CGImage {
    let context = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: height / 2, width: width, height: height / 2))
    context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
    return context.makeImage()!
}

@MainActor
struct OverlayOrientationTests {
    /// The overlay must render the snapshot the same way up as the real screen.
    /// Drawing a CGImage into a flipped view without compensating mirrors it,
    /// which shows the user an upside-down screen.
    @Test func backdropIsNotVerticallyMirrored() throws {
        let side = 100
        let snapshot = DisplaySnapshot(
            displayID: 1,
            image: makeHalvedImage(width: side, height: side),
            frame: CGRect(x: 0, y: 0, width: CGFloat(side), height: CGFloat(side)),
            scale: 1
        )

        let view = SnipSelectionView(snapshot: snapshot)
        view.frame = CGRect(x: 0, y: 0, width: CGFloat(side), height: CGFloat(side))

        let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)

        // NSBitmapImageRep pixel coordinates are top-left origin.
        let top = try #require(rep.colorAt(x: side / 2, y: 8))
        let bottom = try #require(rep.colorAt(x: side / 2, y: side - 8))

        #expect(top.redComponent > top.blueComponent, "top of the overlay should be the red half")
        #expect(bottom.blueComponent > bottom.redComponent, "bottom of the overlay should be the blue half")
    }
}
