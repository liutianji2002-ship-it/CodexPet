import AppKit
import XCTest
@testable import CodexPetApp

final class UnreadDotVisionDetectorTests: XCTestCase {
    func testCountsBlueDotsAcrossRows() {
        let windowFrame = CGRect(x: 0, y: 0, width: 240, height: 120)
        let rows = [
            CGRect(x: 0, y: 80, width: 240, height: 30),
            CGRect(x: 0, y: 45, width: 240, height: 30),
            CGRect(x: 0, y: 10, width: 240, height: 30)
        ]
        let image = makeImage(windowFrame: windowFrame, rows: rows, blueDotRows: [0, 2], grayDotRows: [])

        XCTAssertEqual(
            UnreadDotVisionDetector.unreadDotCount(
                in: image,
                rowFrames: rows,
                windowFrame: windowFrame
            ),
            2
        )
    }

    func testIgnoresGrayIndicators() {
        let windowFrame = CGRect(x: 0, y: 0, width: 240, height: 120)
        let rows = [
            CGRect(x: 0, y: 80, width: 240, height: 30),
            CGRect(x: 0, y: 45, width: 240, height: 30)
        ]
        let image = makeImage(windowFrame: windowFrame, rows: rows, blueDotRows: [], grayDotRows: [0, 1])

        XCTAssertEqual(
            UnreadDotVisionDetector.unreadDotCount(
                in: image,
                rowFrames: rows,
                windowFrame: windowFrame
            ),
            0
        )
    }

    private func makeImage(
        windowFrame: CGRect,
        rows: [CGRect],
        blueDotRows: Set<Int>,
        grayDotRows: Set<Int>
    ) -> CGImage {
        let width = Int(windowFrame.width)
        let height = Int(windowFrame.height)
        let rep = NSBitmapImageRep(
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
        )!
        let context = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context

        NSColor(white: 0.96, alpha: 1).setFill()
        NSBezierPath(rect: CGRect(x: 0, y: 0, width: width, height: height)).fill()

        for (index, row) in rows.enumerated() {
            let localY = row.minY
            let rect = CGRect(x: 0, y: localY, width: row.width, height: row.height)
            NSColor.white.setFill()
            NSBezierPath(rect: rect).fill()

            let dotRect = CGRect(x: 12, y: localY + 7, width: 10, height: 10)
            if blueDotRows.contains(index) {
                NSColor(calibratedRed: 81 / 255, green: 174 / 255, blue: 252 / 255, alpha: 1).setFill()
                NSBezierPath(ovalIn: dotRect).fill()
            } else if grayDotRows.contains(index) {
                NSColor(calibratedWhite: 0.75, alpha: 1).setFill()
                NSBezierPath(ovalIn: dotRect).fill()
            }
        }

        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage!
    }
}
