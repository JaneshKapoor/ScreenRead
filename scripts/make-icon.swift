import AppKit

// Renders the ScreenRead app icon at every size macOS asks for.
//
// Each size is drawn natively rather than downscaled from one master: the
// viewfinder brackets are thin, and resampling a 1024px render down to 16px
// turns them into grey mush.

let outputDirectory = CommandLine.arguments[1]

/// Apple's macOS icon grid: the rounded square occupies ~82% of the canvas,
/// leaving the rest as the transparent margin the system expects.
let bodyFraction: CGFloat = 0.824
let cornerFraction: CGFloat = 0.2237

func drawIcon(side: CGFloat) -> NSBitmapImageRep {
    let pixels = Int(side)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    let body = side * bodyFraction
    let origin = (side - body) / 2
    let bodyRect = NSRect(x: origin, y: origin, width: body, height: body)
    let radius = body * cornerFraction

    let squircle = NSBezierPath(roundedRect: bodyRect, xRadius: radius, yRadius: radius)
    NSGradient(
        starting: NSColor(srgbRed: 0.43, green: 0.66, blue: 1.00, alpha: 1),
        ending: NSColor(srgbRed: 0.16, green: 0.29, blue: 0.83, alpha: 1)
    )!.draw(in: squircle, angle: -90)

    // A faint inner highlight along the top edge, so the icon reads as a
    // physical tile rather than a flat swatch.
    NSGraphicsContext.current?.saveGraphicsState()
    squircle.setClip()
    NSGradient(
        starting: NSColor(white: 1, alpha: 0.28),
        ending: NSColor(white: 1, alpha: 0)
    )!.draw(in: NSRect(x: origin, y: origin + body * 0.55, width: body, height: body * 0.45), angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    drawGlyph(in: bodyRect)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

/// Viewfinder brackets around three text lines — the same idea as the
/// `text.viewfinder` symbol in the menu bar, redrawn so the stroke weight can be
/// tuned per size instead of inherited from the system font.
func drawGlyph(in rect: NSRect) {
    let side = rect.width
    let stroke = side * 0.062
    let inset = side * 0.20
    let frame = rect.insetBy(dx: inset, dy: inset)
    let armLength = frame.width * 0.30
    let corner = side * 0.055

    NSColor.white.setStroke()
    let brackets = NSBezierPath()
    brackets.lineWidth = stroke
    brackets.lineCapStyle = .round
    brackets.lineJoinStyle = .round

    // Four L-shaped corners, drawn as arcs so the bends match the tile's own radius.
    let corners: [(NSPoint, NSPoint, NSPoint)] = [
        (NSPoint(x: frame.minX, y: frame.maxY - armLength),
         NSPoint(x: frame.minX, y: frame.maxY),
         NSPoint(x: frame.minX + armLength, y: frame.maxY)),
        (NSPoint(x: frame.maxX - armLength, y: frame.maxY),
         NSPoint(x: frame.maxX, y: frame.maxY),
         NSPoint(x: frame.maxX, y: frame.maxY - armLength)),
        (NSPoint(x: frame.maxX, y: frame.minY + armLength),
         NSPoint(x: frame.maxX, y: frame.minY),
         NSPoint(x: frame.maxX - armLength, y: frame.minY)),
        (NSPoint(x: frame.minX + armLength, y: frame.minY),
         NSPoint(x: frame.minX, y: frame.minY),
         NSPoint(x: frame.minX, y: frame.minY + armLength)),
    ]

    for (start, bend, end) in corners {
        brackets.move(to: start)
        brackets.appendArc(from: bend, to: end, radius: corner)
        brackets.line(to: end)
    }
    brackets.stroke()

    // Three text lines, the shortest last, so it reads as a paragraph. The
    // spacing keeps the top and bottom lines clear of the bracket arms, which
    // reach `armLength` in from each corner.
    let lineWidths: [CGFloat] = [1.0, 0.72, 0.44]
    let lineSpacing = frame.height * 0.19
    let lineInset = frame.width * 0.16
    let available = frame.width - lineInset * 2

    NSColor.white.setStroke()
    let lines = NSBezierPath()
    lines.lineWidth = stroke * 0.95
    lines.lineCapStyle = .round

    for (index, fraction) in lineWidths.enumerated() {
        let y = frame.midY + lineSpacing - CGFloat(index) * lineSpacing
        lines.move(to: NSPoint(x: frame.minX + lineInset, y: y))
        lines.line(to: NSPoint(x: frame.minX + lineInset + available * fraction, y: y))
    }
    lines.stroke()
}

let sizes: [(name: String, side: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for (name, side) in sizes {
    let rep = drawIcon(side: CGFloat(side))
    let data = rep.representation(using: .png, properties: [:])!
    let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent("\(name).png")
    try data.write(to: url)
    print("wrote \(name).png (\(side)px)")
}
