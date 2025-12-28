import Cocoa
import WebKit

// Usage: swift svg2png.swift <input.svg> <output.png> <size>

guard CommandLine.arguments.count == 4,
      let size = Double(CommandLine.arguments[3]) else {
    print("Usage: swift svg2png.swift <input.svg> <output.png> <size>")
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
let url = URL(fileURLWithPath: inputPath)

// Create an off-screen window/view
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let view = NSView(frame: rect)

// Load the SVG image
guard let image = NSImage(contentsOf: url) else {
    print("Error: Could not load SVG from \(inputPath)")
    exit(1)
}

image.size = NSSize(width: size, height: size)

// Create a bitmap representation
guard let bitmapRep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 32
) else {
    print("Error: Could not create bitmap representation")
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)

// Clear with clear color for transparency
NSColor.clear.set()
rect.fill()

// Draw the image
image.draw(in: rect)

NSGraphicsContext.restoreGraphicsState()

// Save to PNG
guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    print("Error: Could not create PNG data")
    exit(1)
}

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Successfully created \(outputPath)")
} catch {
    print("Error: \(error)")
    exit(1)
}
