import AppKit

// Render the approved vector and crisp native type at standard and Retina scale.
guard CommandLine.arguments.count == 3,
      let logo = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
    fatalError("Usage: render-dmg-background.swift APPROVED-LOGO.svg OUTPUT.tiff")
}
let size = NSSize(width: 720, height: 500)
func label(_ text: String, x: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat = 40,
           font: NSFont, color: NSColor = .black, centered: Bool = false) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = centered ? .center : .left
    (text as NSString).draw(in: NSRect(x: x, y: size.height - top - height, width: width, height: height),
        withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
}
func drawBackground() {
    NSColor(white: 0.94, alpha: 1).setFill()
    NSRect(origin: .zero, size: size).fill()
    let card = NSBezierPath(roundedRect: NSRect(x: 16, y: 16, width: 688, height: 468), xRadius: 18, yRadius: 18)
    NSColor.white.setFill()
    card.fill()
    NSColor(white: 0.80, alpha: 1).setStroke()
    card.lineWidth = 0.5
    card.stroke()

    let scale = min(62 / logo.size.width, 76 / logo.size.height)
    let logoSize = NSSize(width: logo.size.width * scale, height: logo.size.height * scale)
    logo.draw(in: NSRect(x: 48 + (62 - logoSize.width) / 2,
        y: 380 + (76 - logoSize.height) / 2, width: logoSize.width, height: logoSize.height))
    label("CommonCopy", x: 128, top: 50, width: 520, font: .systemFont(ofSize: 28, weight: .semibold))
    label("Save it once. Paste it forever.", x: 130, top: 94, width: 520, height: 24,
        font: .systemFont(ofSize: 13), color: .darkGray)
    label("Ready when you are.", x: 54, top: 152, width: 612,
        font: .systemFont(ofSize: 28, weight: .semibold))
    label("Drag CommonCopy into Applications to install.", x: 54, top: 203, width: 612, height: 24,
        font: .systemFont(ofSize: 13))

    // Finder overlays the real draggable application and Applications shortcut.
    for x: CGFloat in [116, 416] {
        let panel = NSBezierPath(roundedRect: NSRect(x: x, y: 84, width: 188, height: 174), xRadius: 12, yRadius: 12)
        NSColor(white: 0.98, alpha: 1).setFill()
        panel.fill()
        NSColor(white: 0.78, alpha: 1).setStroke()
        panel.lineWidth = 0.5
        panel.stroke()
    }
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 332, y: 171)); arrow.line(to: NSPoint(x: 388, y: 171))
    arrow.move(to: NSPoint(x: 378, y: 181)); arrow.line(to: NSPoint(x: 388, y: 171)); arrow.line(to: NSPoint(x: 378, y: 161))
    NSColor.black.setStroke(); arrow.lineWidth = 1.5; arrow.stroke()
    label("Then open CommonCopy from Applications and eject this disk.", x: 54, top: 438, width: 612, height: 22,
        font: .systemFont(ofSize: 12), color: .darkGray)
    label("Provided under the MIT License.", x: 54, top: 464, width: 612, height: 18,
        font: .systemFont(ofSize: 10), color: .darkGray)
}
var representations: [NSImageRep] = []
for scale in [1, 2] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
        pixelsWide: 720 * scale, pixelsHigh: 500 * scale,
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
      decoded.allSatisfy({ abs($0.size.width - 720) < 0.1 && abs($0.size.height - 500) < 0.1 }) else {
    fatalError("Installer TIFF lost its resolution or logical-size metadata")
}
try tiff.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
print("Installer artwork: 720x500 and 1440x1000 pixels, both 720x500 points.")

