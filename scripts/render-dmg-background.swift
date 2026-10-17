import AppKit

// Native rendering keeps installer artwork independent of third-party tools.
guard CommandLine.arguments.count == 3,
      let logo = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
    fatalError("Usage: render-dmg-background.swift APPROVED-LOGO.svg OUTPUT.tiff")
}
let size = NSSize(width: 720, height: 440)
func label(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, font: NSFont, color: NSColor = .black, centered: Bool = false) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = centered ? .center : .left
    (text as NSString).draw(in: NSRect(x: x, y: y, width: width, height: 40), withAttributes: [
        .font: font, .foregroundColor: color, .paragraphStyle: paragraph
    ])
}
func drawBackground() {
    NSColor.white.setFill()
    NSRect(origin: .zero, size: size).fill()
let logoScale = min(62 / logo.size.width, 62 / logo.size.height)
let logoSize = NSSize(width: logo.size.width * logoScale, height: logo.size.height * logoScale)
logo.draw(in: NSRect(x: 38 + (62 - logoSize.width) / 2, y: 339 + (62 - logoSize.height) / 2, width: logoSize.width, height: logoSize.height))
label("CommonCopy", x: 116, y: 363, width: 540, font: .systemFont(ofSize: 27, weight: .semibold))
label("Save it once. Paste it forever.", x: 117, y: 337, width: 540, font: .systemFont(ofSize: 13), color: .darkGray)
NSColor(white: 0.75, alpha: 1).setStroke()
let rule = NSBezierPath()
rule.move(to: NSPoint(x: 38, y: 325)); rule.line(to: NSPoint(x: 682, y: 325)); rule.lineWidth = 0.5; rule.stroke()
// Finder places the real draggable app and Applications alias over these panels.
for x: CGFloat in [116, 416] {
    NSColor(white: 0.98, alpha: 1).setFill()
    let panel = NSBezierPath(roundedRect: NSRect(x: x, y: 119, width: 188, height: 180), xRadius: 10, yRadius: 10)
    panel.fill(); NSColor(white: 0.75, alpha: 1).setStroke(); panel.lineWidth = 0.5; panel.stroke()
}
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 332, y: 214)); arrow.line(to: NSPoint(x: 388, y: 214))
arrow.move(to: NSPoint(x: 378, y: 224)); arrow.line(to: NSPoint(x: 388, y: 214)); arrow.line(to: NSPoint(x: 378, y: 204))
NSColor.black.setStroke(); arrow.lineWidth = 1.5; arrow.stroke()
label("Drag CommonCopy into Applications.", x: 38, y: 53, width: 644, font: .systemFont(ofSize: 17, weight: .medium), centered: true)
label("Then open CommonCopy from Applications and eject this disk.", x: 38, y: 24, width: 644, font: .systemFont(ofSize: 12), color: .darkGray, centered: true)
}
// Finder selects the correct representation while retaining a 720 × 440 point layout.
// The previous one-resolution PNG was enlarged on Retina displays.
var representations: [NSImageRep] = []
for scale in [1, 2] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
        pixelsWide: 720 * scale, pixelsHigh: 440 * scale,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    drawBackground()
    NSGraphicsContext.restoreGraphicsState()
    bitmap.size = size
    representations.append(bitmap)
}
guard let tiff = NSBitmapImageRep.representationOfImageReps(in: representations, using: .tiff, properties: [:]) else {
    fatalError("Cannot encode standard and Retina installer artwork")
}
let decoded = NSBitmapImageRep.imageReps(with: tiff).compactMap { $0 as? NSBitmapImageRep }
guard decoded.count == 2, Set(decoded.map({ $0.pixelsWide })) == Set([720, 1440]),
      decoded.allSatisfy({ abs($0.size.width - 720) < 0.1 && abs($0.size.height - 440) < 0.1 }) else {
    fatalError("Installer TIFF lost its resolution or logical-size metadata")
}
try tiff.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
print("Installer artwork: 720x440 and 1440x880 pixels, both 720x440 points.")
