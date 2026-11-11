import AppKit

// Resolution-independent original artwork inspired by the selected Drift concept.
// Transparent macOS icon margins, deep navy rounded tile, one cyan wave.
func drawIcon(size: Int) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
    let scale = Double(size) / 1024
    context.cgContext.scaleBy(x: scale, y: scale)
    let rect = NSRect(x: 80, y: 80, width: 864, height: 864)
    let tile = NSBezierPath(roundedRect: rect, xRadius: 202, yRadius: 202)
    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    NSGradient(starting: NSColor(calibratedRed: 0.018, green: 0.036, blue: 0.105, alpha: 1),
        ending: NSColor(calibratedRed: 0.027, green: 0.063, blue: 0.17, alpha: 1))!.draw(in: rect, angle: 90)
    let wave = NSBezierPath()
    wave.move(to: NSPoint(x: 70, y: 475))
    wave.curve(to: NSPoint(x: 520, y: 514), controlPoint1: NSPoint(x: 245, y: 660), controlPoint2: NSPoint(x: 340, y: 610))
    wave.curve(to: NSPoint(x: 954, y: 548), controlPoint1: NSPoint(x: 700, y: 405), controlPoint2: NSPoint(x: 790, y: 395))
    wave.line(to: NSPoint(x: 954, y: 472))
    wave.curve(to: NSPoint(x: 520, y: 425), controlPoint1: NSPoint(x: 790, y: 325), controlPoint2: NSPoint(x: 700, y: 318))
    wave.curve(to: NSPoint(x: 70, y: 395), controlPoint1: NSPoint(x: 340, y: 520), controlPoint2: NSPoint(x: 245, y: 565))
    wave.close()
    NSGradient(colors: [NSColor(calibratedRed: 0.10, green: 0.77, blue: 0.95, alpha: 1),
        NSColor(calibratedRed: 0.35, green: 0.96, blue: 0.97, alpha: 1),
        NSColor(calibratedRed: 0.10, green: 0.77, blue: 0.95, alpha: 1)])!.draw(in: wave, angle: 0)
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}
let fm = FileManager.default
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Assets")
let set = root.appendingPathComponent("AppIcon.iconset")
try fm.createDirectory(at: set, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let name = "icon_\(base)x\(base)\(factor == 2 ? "@2x" : "").png"
        let bytes = drawIcon(size: base * factor).representation(using: .png, properties: [:])!
        try bytes.write(to: set.appendingPathComponent(name))
    }
}
try drawIcon(size: 1024).representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("AppIcon.png"))
print("Generated Drift icon at all macOS sizes")
