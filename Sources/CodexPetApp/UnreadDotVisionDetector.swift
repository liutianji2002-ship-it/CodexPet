import AppKit
import CoreGraphics
import Foundation

enum UnreadDotVisionDetector {
    private static let dotColorThreshold = (
        redUpperBound: CGFloat(0.50),
        greenLowerBound: CGFloat(0.55),
        blueLowerBound: CGFloat(0.85)
    )

    static func unreadDotCount(
        in image: CGImage,
        rowFrames: [CGRect],
        windowFrame: CGRect
    ) -> Int {
        guard
            windowFrame.width > 0,
            windowFrame.height > 0
        else {
            return 0
        }
        let bitmap = NSBitmapImageRep(cgImage: image)

        return rowFrames.reduce(into: 0) { count, rowFrame in
            if hasUnreadDot(in: bitmap, rowFrame: rowFrame, windowFrame: windowFrame) {
                count += 1
            }
        }
    }

    private static func hasUnreadDot(
        in bitmap: NSBitmapImageRep,
        rowFrame: CGRect,
        windowFrame: CGRect
    ) -> Bool {
        let scaleX = CGFloat(bitmap.pixelsWide) / windowFrame.width
        let scaleY = CGFloat(bitmap.pixelsHigh) / windowFrame.height

        let relativeX = rowFrame.minX - windowFrame.minX
        let relativeTop = windowFrame.maxY - rowFrame.maxY

        let sampleRect = CGRect(
            x: (relativeX + 8) * scaleX,
            y: (relativeTop + 5) * scaleY,
            width: 18 * scaleX,
            height: max(14 * scaleY, 1)
        ).integral

        guard sampleRect.width > 0, sampleRect.height > 0 else {
            return false
        }

        var bluePixelCount = 0
        let minX = max(Int(sampleRect.minX), 0)
        let maxX = min(Int(sampleRect.maxX), bitmap.pixelsWide - 1)
        let minTopY = max(Int(sampleRect.minY), 0)
        let maxTopY = min(Int(sampleRect.maxY), bitmap.pixelsHigh - 1)

        for topY in minTopY...maxTopY {
            let bitmapY = bitmap.pixelsHigh - 1 - topY
            for x in minX...maxX {
                guard let color = bitmap.colorAt(x: x, y: bitmapY)?.usingColorSpace(.deviceRGB) else {
                    continue
                }

                if isBlueDotColor(color) {
                    bluePixelCount += 1
                    if bluePixelCount >= 12 {
                        return true
                    }
                }
            }
        }

        return false
    }

    private static func isBlueDotColor(_ color: NSColor) -> Bool {
        color.redComponent < dotColorThreshold.redUpperBound
            && color.greenComponent > dotColorThreshold.greenLowerBound
            && color.blueComponent > dotColorThreshold.blueLowerBound
    }
}
