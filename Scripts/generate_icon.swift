import AppKit

func drawIcon(size: Int, outputPath: String) {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: NSColorSpaceName.deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    )!

    guard let ctx = NSGraphicsContext(bitmapImageRep: bitmap) else { return }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    defer { NSGraphicsContext.restoreGraphicsState() }

    let sz = CGFloat(size)
    let rect = NSMakeRect(0, 0, sz, sz)

    // Clip to rounded rect
    let cornerRadius: CGFloat = sz * 0.2
    let clipPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    clipPath.addClip()

    // Space gradient background
    let bgGrad = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.02, green: 0.02, blue: 0.12, alpha: 1),
            NSColor(calibratedRed: 0.06, green: 0.03, blue: 0.18, alpha: 1),
            NSColor(calibratedRed: 0.02, green: 0.01, blue: 0.08, alpha: 1)
        ]
    )!
    bgGrad.draw(in: rect, angle: 45)

    // Stars
    var seed = UInt32(42)
    for _ in 0..<max(8, size / 12) {
        seed = seed &* 1664525 &+ 1013904223
        let sx = CGFloat(Int(seed &- (seed / UInt32(size)) &* UInt32(size)))
        seed = seed &* 1664525 &+ 1013904223
        let sy = CGFloat(Int(seed &- (seed / UInt32(size)) &* UInt32(size)))
        seed = seed &* 1664525 &+ 1013904223
        let sr = CGFloat(0.5 + Double(Int(seed & 2)) * 0.5)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSMakeRect(sx - sr, sy - sr, sr * 2, sr * 2)).fill()
    }

    // Planet
    let pSize = sz * 0.35
    let pX = sz * 0.5, pY = sz * 0.45
    NSColor(calibratedRed: 0.9, green: 0.7, blue: 0.2, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSMakeRect(pX - pSize * 0.5, pY - pSize * 0.5, pSize, pSize)).fill()
    let planetShadow = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.9, green: 0.7, blue: 0.2, alpha: 0),
            NSColor(calibratedRed: 0.6, green: 0.3, blue: 0.1, alpha: 0.8)
        ]
    )!
    planetShadow.draw(in: NSMakeRect(pX - pSize * 0.5, pY - pSize * 0.5, pSize, pSize), angle: 0)

    // Ship silhouette
    let sSz = sz * 0.18, sX = sz * 0.55, sY = sz * 0.6
    let shipPath = NSBezierPath()
    shipPath.move(to: NSMakePoint(sX, sY - sSz))
    shipPath.line(to: NSMakePoint(sX - sSz * 0.7, sY + sSz * 0.5))
    shipPath.line(to: NSMakePoint(sX + sSz * 0.1, sY + sSz * 0.3))
    shipPath.line(to: NSMakePoint(sX + sSz * 0.7, sY + sSz * 0.5))
    shipPath.close()
    NSColor(white: 0.95, alpha: 1).setFill()
    shipPath.fill()

    // Thrust flame
    let flamePath = NSBezierPath()
    flamePath.move(to: NSMakePoint(sX - sSz * 0.3, sY + sSz * 0.5))
    flamePath.line(to: NSMakePoint(sX, sY + sSz * 1.2))
    flamePath.line(to: NSMakePoint(sX + sSz * 0.3, sY + sSz * 0.5))
    flamePath.close()
    let flameGrad = NSGradient(
        colors: [
            NSColor(calibratedRed: 1, green: 0.6, blue: 0.1, alpha: 0.9),
            NSColor(calibratedRed: 1, green: 0.3, blue: 0, alpha: 0.3)
        ]
    )!
    flameGrad.draw(in: NSMakeRect(sX - sSz * 0.3, sY + sSz * 0.5, sSz * 0.6, sSz * 0.7), angle: -90)

    // Title
    if size >= 64 {
        let fSz = sz * 0.22
        let t = "STARFALL"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fSz, weight: .bold),
            .foregroundColor: NSColor(white: 0.95, alpha: 1)
        ]
        let tSz = t.size(withAttributes: attrs)
        t.draw(at: NSMakePoint((sz - tSz.width) / 2, sz * 0.82 - tSz.height), withAttributes: attrs)
    }

    // Export
    if let pngData = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) {
        try! pngData.write(to: URL(fileURLWithPath: outputPath))
        print("  -> \(outputPath)")
    }
}

let dir = "Icon.iconset"
if FileManager.default.fileExists(atPath: dir) {
    try? FileManager.default.removeItem(atPath: dir)
}
try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
print("Generating Starfall app icon...")
for (s, f) in sizes { drawIcon(size: s, outputPath: "\(dir)/\(f)") }
print("\nNext: iconutil -c icns \(dir)")