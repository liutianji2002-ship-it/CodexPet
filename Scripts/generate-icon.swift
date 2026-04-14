#!/usr/bin/swift

import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let appBundleDirectory = root.appendingPathComponent("AppBundle", isDirectory: true)
let iconsetDirectory = appBundleDirectory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = appBundleDirectory.appendingPathComponent("AppIcon.icns")

let fileManager = FileManager.default
try? fileManager.removeItem(at: iconsetDirectory)
try? fileManager.removeItem(at: icnsURL)
try fileManager.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

let iconSizes: [(name: String, points: CGFloat, scale: CGFloat)] = [
    ("icon_16x16.png", 16, 1),
    ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1),
    ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1),
    ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1),
    ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1),
    ("icon_512x512@2x.png", 512, 2)
]

for icon in iconSizes {
    let pixelSize = NSSize(width: icon.points * icon.scale, height: icon.points * icon.scale)
    let image = NSImage(size: pixelSize)
    image.lockFocus()
    drawIcon(in: NSRect(origin: .zero, size: pixelSize))
    image.unlockFocus()

    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Failed to render icon \(icon.name)")
    }

    try pngData.write(to: iconsetDirectory.appendingPathComponent(icon.name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDirectory.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    fatalError("iconutil failed with exit code \(process.terminationStatus)")
}

func drawIcon(in rect: NSRect) {
    let scale = rect.width / 1024.0

    let backgroundPath = NSBezierPath(
        roundedRect: rect.insetBy(dx: 36 * scale, dy: 36 * scale),
        xRadius: 230 * scale,
        yRadius: 230 * scale
    )

    let gradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.40, alpha: 1.0),
            NSColor(calibratedRed: 0.95, green: 0.51, blue: 0.18, alpha: 1.0)
        ]
    )!
    gradient.draw(in: backgroundPath, angle: -90)

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 42 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -18 * scale)
    shadow.set()
    NSColor.black.withAlphaComponent(0.10).setFill()
    NSBezierPath(ovalIn: NSRect(x: 292 * scale, y: 180 * scale, width: 440 * scale, height: 92 * scale)).fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    drawTail(scale: scale)
    drawEars(scale: scale)
    drawBody(scale: scale)
    drawScreen(scale: scale)
    drawEyes(scale: scale)
    drawPaws(scale: scale)
    drawBadge(scale: scale)
    drawSparkles(scale: scale)
}

func drawBody(scale: CGFloat) {
    let bodyRect = NSRect(x: 284 * scale, y: 312 * scale, width: 456 * scale, height: 356 * scale)
    let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 94 * scale, yRadius: 94 * scale)
    let bodyGradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.31, alpha: 1.0),
            NSColor(calibratedRed: 0.92, green: 0.44, blue: 0.16, alpha: 1.0)
        ]
    )!
    bodyGradient.draw(in: bodyPath, angle: -90)

    NSColor.white.withAlphaComponent(0.22).setStroke()
    bodyPath.lineWidth = 10 * scale
    bodyPath.stroke()
}

func drawScreen(scale: CGFloat) {
    let screenRect = NSRect(x: 390 * scale, y: 348 * scale, width: 244 * scale, height: 152 * scale)
    let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: 34 * scale, yRadius: 34 * scale)
    NSColor(calibratedRed: 0.16, green: 0.19, blue: 0.25, alpha: 1.0).setFill()
    screenPath.fill()

    let innerRect = screenRect.insetBy(dx: 22 * scale, dy: 20 * scale)
    let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 22 * scale, yRadius: 22 * scale)
    NSColor.white.withAlphaComponent(0.15).setStroke()
    innerPath.lineWidth = 8 * scale
    innerPath.stroke()
}

func drawEyes(scale: CGFloat) {
    let leftEye = NSBezierPath(roundedRect: NSRect(x: 404 * scale, y: 522 * scale, width: 42 * scale, height: 62 * scale), xRadius: 22 * scale, yRadius: 22 * scale)
    let rightEye = NSBezierPath(roundedRect: NSRect(x: 578 * scale, y: 522 * scale, width: 42 * scale, height: 62 * scale), xRadius: 22 * scale, yRadius: 22 * scale)
    NSColor.black.withAlphaComponent(0.82).setFill()
    leftEye.fill()
    rightEye.fill()

    NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.80, alpha: 1.0).setFill()
    NSBezierPath(ovalIn: NSRect(x: 430 * scale, y: 464 * scale, width: 34 * scale, height: 34 * scale)).fill()
    NSBezierPath(ovalIn: NSRect(x: 560 * scale, y: 464 * scale, width: 34 * scale, height: 34 * scale)).fill()
}

func drawPaws(scale: CGFloat) {
    NSColor(calibratedRed: 1.0, green: 0.85, blue: 0.78, alpha: 1.0).setFill()
    let left = NSBezierPath(roundedRect: NSRect(x: 372 * scale, y: 274 * scale, width: 112 * scale, height: 50 * scale), xRadius: 24 * scale, yRadius: 24 * scale)
    let right = NSBezierPath(roundedRect: NSRect(x: 540 * scale, y: 274 * scale, width: 112 * scale, height: 50 * scale), xRadius: 24 * scale, yRadius: 24 * scale)
    left.fill()
    right.fill()
}

func drawEars(scale: CGFloat) {
    let left = NSBezierPath()
    left.move(to: CGPoint(x: 332 * scale, y: 648 * scale))
    left.line(to: CGPoint(x: 424 * scale, y: 820 * scale))
    left.line(to: CGPoint(x: 502 * scale, y: 650 * scale))
    left.close()

    let right = NSBezierPath()
    right.move(to: CGPoint(x: 522 * scale, y: 650 * scale))
    right.line(to: CGPoint(x: 600 * scale, y: 820 * scale))
    right.line(to: CGPoint(x: 692 * scale, y: 648 * scale))
    right.close()

    NSColor(calibratedRed: 0.96, green: 0.63, blue: 0.20, alpha: 1.0).setFill()
    left.fill()
    right.fill()

    let innerLeft = NSBezierPath()
    innerLeft.move(to: CGPoint(x: 380 * scale, y: 674 * scale))
    innerLeft.line(to: CGPoint(x: 424 * scale, y: 772 * scale))
    innerLeft.line(to: CGPoint(x: 466 * scale, y: 674 * scale))
    innerLeft.close()

    let innerRight = NSBezierPath()
    innerRight.move(to: CGPoint(x: 558 * scale, y: 674 * scale))
    innerRight.line(to: CGPoint(x: 600 * scale, y: 772 * scale))
    innerRight.line(to: CGPoint(x: 644 * scale, y: 674 * scale))
    innerRight.close()

    NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.78, alpha: 1.0).setFill()
    innerLeft.fill()
    innerRight.fill()
}

func drawTail(scale: CGFloat) {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: 716 * scale, y: 340 * scale))
    path.curve(
        to: CGPoint(x: 856 * scale, y: 594 * scale),
        controlPoint1: CGPoint(x: 858 * scale, y: 318 * scale),
        controlPoint2: CGPoint(x: 902 * scale, y: 470 * scale)
    )
    path.curve(
        to: CGPoint(x: 760 * scale, y: 546 * scale),
        controlPoint1: CGPoint(x: 836 * scale, y: 620 * scale),
        controlPoint2: CGPoint(x: 794 * scale, y: 614 * scale)
    )
    path.curve(
        to: CGPoint(x: 664 * scale, y: 378 * scale),
        controlPoint1: CGPoint(x: 708 * scale, y: 500 * scale),
        controlPoint2: CGPoint(x: 680 * scale, y: 432 * scale)
    )
    path.close()

    NSColor(calibratedRed: 0.91, green: 0.50, blue: 0.18, alpha: 1.0).setFill()
    path.fill()
}

func drawBadge(scale: CGFloat) {
    let badgeRect = NSRect(x: 686 * scale, y: 660 * scale, width: 140 * scale, height: 82 * scale)
    let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 40 * scale, yRadius: 40 * scale)
    NSColor(calibratedRed: 0.88, green: 0.24, blue: 0.18, alpha: 1.0).setFill()
    badgePath.fill()

    let text = NSAttributedString(
        string: "C",
        attributes: [
            .font: NSFont.systemFont(ofSize: 50 * scale, weight: .bold),
            .foregroundColor: NSColor.white
        ]
    )
    let textRect = NSRect(x: 734 * scale, y: 676 * scale, width: 44 * scale, height: 52 * scale)
    text.draw(in: textRect)
}

func drawSparkles(scale: CGFloat) {
    let colors = [
        NSColor.white.withAlphaComponent(0.88),
        NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.46, alpha: 0.92)
    ]
    let positions: [CGPoint] = [
        CGPoint(x: 250, y: 718),
        CGPoint(x: 196, y: 608),
        CGPoint(x: 236, y: 484),
        CGPoint(x: 796, y: 566),
        CGPoint(x: 764, y: 434),
        CGPoint(x: 856, y: 736)
    ]

    for (index, point) in positions.enumerated() {
        let sparkleRect = NSRect(x: point.x * scale, y: point.y * scale, width: 34 * scale, height: 34 * scale)
        let sparkle = NSBezierPath(ovalIn: sparkleRect)
        colors[index % colors.count].setFill()
        sparkle.fill()
    }
}
