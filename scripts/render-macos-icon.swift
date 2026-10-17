import AppKit

guard CommandLine.arguments.count == 3,
      let logo = NSImage(contentsOfFile: CommandLine.arguments[1]),
      logo.isValid, logo.size.width > 0, logo.size.height > 0 else {
    fatalError("Cannot load the approved SVG logo")
}
// macOS app icons require raster iconsets; use the SVG master at native resolution.
let side = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: CGFloat(side), height: CGFloat(side)).fill()
let scale = min(840 / logo.size.width, 840 / logo.size.height)
let size = NSSize(width: logo.size.width * scale, height: logo.size.height * scale)
logo.draw(in: NSRect(x: (1024-size.width)/2, y: (1024-size.height)/2, width: size.width, height: size.height))
NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot render SVG icon") }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
print("Approved SVG loaded and rendered into the native icon source.")
