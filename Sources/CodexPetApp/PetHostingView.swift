import AppKit
import SwiftUI

final class PetHostingView: NSHostingView<PetView> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        guard bounds.contains(localPoint) else {
            return nil
        }

        guard alpha(at: localPoint) > 0.08 else {
            return nil
        }

        return super.hitTest(point) ?? self
    }

    private func alpha(at point: NSPoint) -> CGFloat {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let width = max(Int(bounds.width * scale), 1)
        let height = max(Int(bounds.height * scale), 1)

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return 1
        }

        bitmap.size = bounds.size
        cacheDisplay(in: bounds, to: bitmap)

        let x = min(max(Int(point.x * scale), 0), width - 1)
        let y = min(max(Int((bounds.height - point.y) * scale), 0), height - 1)
        guard let color = bitmap.colorAt(x: x, y: y) else {
            return 1
        }

        return color.alphaComponent
    }
}
