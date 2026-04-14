import AppKit
import CoreGraphics

enum DockEdge {
    case bottom
    case left
    case right
}

enum DockAnchoring {
    static func targetOrigin(for windowSize: CGSize) -> CGPoint? {
        guard let screen = preferredScreen() else {
            return nil
        }

        let edge = dockEdge(for: screen)
        let visibleFrame = screen.visibleFrame
        let frame = screen.frame
        var origin: CGPoint

        switch edge {
        case .bottom:
            let iconArea = dockIconArea(for: screen)
            let anchorX = screen.frame.minX + iconArea.x + iconArea.width * 0.82 - windowSize.width / 2
            origin = CGPoint(x: anchorX, y: visibleFrame.minY + 8)
        case .left:
            origin = CGPoint(
                x: visibleFrame.minX + 10,
                y: frame.minY + min(max(frame.height * 0.11, 24), frame.height - windowSize.height - 24)
            )
        case .right:
            origin = CGPoint(
                x: visibleFrame.maxX - windowSize.width - 10,
                y: frame.minY + min(max(frame.height * 0.11, 24), frame.height - windowSize.height - 24)
            )
        }

        return CGPoint(
            x: min(max(origin.x, frame.minX + 6), frame.maxX - windowSize.width - 6),
            y: min(max(origin.y, frame.minY + 6), frame.maxY - windowSize.height - 6)
        )
    }

    static func preferredScreen() -> NSScreen? {
        if let visibleDockScreen = NSScreen.screens.first(where: { screenHasVisibleDockReservedArea(on: $0) }) {
            return visibleDockScreen
        }

        if let primaryScreen = NSScreen.screens.first(where: { $0.visibleFrame.maxY < $0.frame.maxY }) {
            return primaryScreen
        }

        return NSScreen.screens.first
    }

    private static func dockEdge(for screen: NSScreen) -> DockEdge {
        let visibleFrame = screen.visibleFrame
        let frame = screen.frame

        if visibleFrame.minY > frame.minY {
            return .bottom
        }
        if visibleFrame.minX > frame.minX {
            return .left
        }
        if visibleFrame.maxX < frame.maxX {
            return .right
        }

        let dockDefaults = UserDefaults(suiteName: "com.apple.dock")
        switch dockDefaults?.string(forKey: "orientation") {
        case "left":
            return .left
        case "right":
            return .right
        default:
            return .bottom
        }
    }

    private static func screenHasVisibleDockReservedArea(on screen: NSScreen) -> Bool {
        let visibleFrame = screen.visibleFrame
        let frame = screen.frame
        return visibleFrame.minX > frame.minX
            || visibleFrame.minY > frame.minY
            || visibleFrame.maxX < frame.maxX
    }

    private static func dockIconArea(for screen: NSScreen) -> (x: CGFloat, width: CGFloat) {
        let dockDefaults = UserDefaults(suiteName: "com.apple.dock")
        let tileSize = CGFloat(dockDefaults?.double(forKey: "tilesize") ?? 48)
        let slotWidth = tileSize * 1.25

        var persistentApps = dockDefaults?.array(forKey: "persistent-apps")?.count ?? 0
        var persistentOthers = dockDefaults?.array(forKey: "persistent-others")?.count ?? 0

        if persistentApps == 0 && persistentOthers == 0 {
            persistentApps = 5
            persistentOthers = 3
        }

        let showRecents = dockDefaults?.bool(forKey: "show-recents") ?? true
        let recentApps = showRecents ? (dockDefaults?.array(forKey: "recent-apps")?.count ?? 0) : 0
        let totalIcons = persistentApps + persistentOthers + recentApps

        var dividers = 0
        if persistentApps > 0 && (persistentOthers > 0 || recentApps > 0) {
            dividers += 1
        }
        if persistentOthers > 0 && recentApps > 0 {
            dividers += 1
        }
        if showRecents && recentApps > 0 {
            dividers += 1
        }

        let dividerWidth: CGFloat = 12
        var dockWidth = slotWidth * CGFloat(totalIcons) + CGFloat(dividers) * dividerWidth
        dockWidth *= 1.15

        let screenWidth = screen.frame.width
        let dockX = (screenWidth - dockWidth) / 2
        return (dockX, dockWidth)
    }
}
