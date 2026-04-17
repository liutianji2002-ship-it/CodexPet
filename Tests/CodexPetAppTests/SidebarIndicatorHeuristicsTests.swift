import CoreGraphics
import XCTest
@testable import CodexPetApp

final class SidebarIndicatorHeuristicsTests: XCTestCase {
    func testDetectsRunningMarkerFromLeadingIndicatorGroup() {
        let rowFrame = CGRect(x: 0, y: 0, width: 240, height: 30)
        let descendants = [
            SidebarElementSnapshot(
                role: "AXGroup",
                frame: CGRect(x: 4, y: 5, width: 20, height: 16),
                classList: ["relative", "flex", "w-5", "shrink-0"]
            ),
            SidebarElementSnapshot(
                role: "AXImage",
                frame: CGRect(x: 4, y: 3, width: 20, height: 20),
                classList: ["icon-xs", "shrink-0"]
            ),
            SidebarElementSnapshot(
                role: "AXImage",
                frame: CGRect(x: 7, y: 6, width: 14, height: 14),
                classList: ["icon-2xs"]
            )
        ]

        XCTAssertTrue(
            SidebarIndicatorHeuristics.hasRunningMarker(
                rowFrame: rowFrame,
                descendants: descendants
            )
        )
    }

    func testIgnoresSmallPinnedIconWithoutRunningMarker() {
        let rowFrame = CGRect(x: 0, y: 0, width: 240, height: 30)
        let descendants = [
            SidebarElementSnapshot(
                role: "AXGroup",
                frame: CGRect(x: 4, y: 7, width: 16, height: 20),
                classList: ["relative", "flex", "items-center"]
            ),
            SidebarElementSnapshot(
                role: "AXImage",
                frame: CGRect(x: 6, y: 9, width: 14, height: 14),
                classList: ["icon-2xs", "block", "shrink-0"]
            )
        ]

        XCTAssertFalse(
            SidebarIndicatorHeuristics.hasRunningMarker(
                rowFrame: rowFrame,
                descendants: descendants
            )
        )
    }

    func testIgnoresTrailingImagesOnRightSide() {
        let rowFrame = CGRect(x: 0, y: 0, width: 240, height: 30)
        let descendants = [
            SidebarElementSnapshot(
                role: "AXGroup",
                frame: CGRect(x: 210, y: 0, width: 29, height: 30),
                classList: ["absolute", "right-0"]
            ),
            SidebarElementSnapshot(
                role: "AXImage",
                frame: CGRect(x: 214, y: 7, width: 17, height: 16),
                classList: ["icon-xs"]
            )
        ]

        XCTAssertFalse(
            SidebarIndicatorHeuristics.hasRunningMarker(
                rowFrame: rowFrame,
                descendants: descendants
            )
        )
    }
}
