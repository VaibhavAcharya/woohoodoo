import AppKit

let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let background = NSBezierPath(roundedRect: NSRect(x: 28, y: 28, width: 968, height: 968),
                              xRadius: 220, yRadius: 220)
background.addClip()
NSGradient(starting: NSColor(calibratedRed: 0.20, green: 0.15, blue: 0.43, alpha: 1),
           ending: NSColor(calibratedRed: 0.39, green: 0.27, blue: 0.72, alpha: 1))!
    .draw(in: background, angle: 45)

let tiles: [(NSRect, NSColor)] = [
    (NSRect(x: 232, y: 540, width: 250, height: 250), NSColor(calibratedRed: 1, green: 0.91, blue: 0.79, alpha: 1)),
    (NSRect(x: 542, y: 540, width: 250, height: 250), NSColor(calibratedRed: 0.72, green: 0.89, blue: 0.99, alpha: 1)),
    (NSRect(x: 232, y: 230, width: 250, height: 250), NSColor(calibratedRed: 0.77, green: 0.96, blue: 0.85, alpha: 1)),
    (NSRect(x: 542, y: 230, width: 250, height: 250), NSColor(calibratedRed: 0.99, green: 0.77, blue: 0.85, alpha: 1)),
]

for (frame, color) in tiles {
    let tile = NSBezierPath(roundedRect: frame, xRadius: 60, yRadius: 60)
    color.setFill()
    tile.fill()
}

NSGraphicsContext.restoreGraphicsState()
guard let data = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
