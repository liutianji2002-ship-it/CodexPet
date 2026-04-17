import CoreGraphics
import Foundation

struct SidebarElementSnapshot: Equatable {
    let role: String
    let frame: CGRect?
    let classList: [String]
}

enum SidebarIndicatorHeuristics {
    static func hasRunningMarker(
        rowFrame: CGRect,
        descendants: [SidebarElementSnapshot]
    ) -> Bool {
        descendants.contains { group in
            guard
                group.role == "AXGroup",
                let groupFrame = group.frame,
                groupFrame.midX < rowFrame.midX,
                group.classList.contains(where: { $0.contains("w-5") })
            else {
                return false
            }

            return descendants.contains { child in
                guard
                    child.role == "AXImage",
                    let childFrame = child.frame
                else {
                    return false
                }

                let expandedGroupFrame = groupFrame.insetBy(dx: -4, dy: -4)
                return childFrame.width >= 17 && childFrame.height >= 16
                    && expandedGroupFrame.contains(CGPoint(x: childFrame.midX, y: childFrame.midY))
            }
        }
    }
}
