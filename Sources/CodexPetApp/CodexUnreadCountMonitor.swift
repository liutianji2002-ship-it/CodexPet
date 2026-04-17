import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

struct CodexUnreadSidebarSnapshot: Equatable, Sendable {
    let unreadCount: Int
    let runningThreadCount: Int
    let activeThreadDisplayText: String?
    let isActiveThreadUnread: Bool
}

final class CodexUnreadCountMonitor {
    var onSnapshotChange: ((CodexUnreadSidebarSnapshot) -> Void)?
    var onStatusChange: ((String) -> Void)?

    private let codexBundleIdentifier = "com.openai.codex"
    private let queue = DispatchQueue(label: "CodexPet.unread-count-monitor")
    private let foregroundPollingInterval: DispatchTimeInterval = .milliseconds(800)
    private let backgroundPollingInterval: DispatchTimeInterval = .seconds(2)
    private let lowerSnapshotDebounceSeconds: TimeInterval = 2

    private var timer: DispatchSourceTimer?
    private var lastSnapshot: CodexUnreadSidebarSnapshot?
    private var lastStatus: String?
    private var isCodexFrontmost = false
    private var pendingLowerSnapshot: CodexUnreadSidebarSnapshot?
    private var pendingLowerSnapshotObservedAt: Date?

    func start() {
        queue.async { [weak self] in
            guard let self, self.timer == nil else { return }
            self.startTimer(immediate: true)
        }
    }

    func stop() {
        queue.async { [self] in
            self.timer?.cancel()
            self.timer = nil
        }
    }

    func requestRefresh() {
        queue.async { [weak self] in
            self?.poll()
        }
    }

    func updateCodexFrontmost(_ isFrontmost: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.isCodexFrontmost != isFrontmost else { return }

            self.isCodexFrontmost = isFrontmost
            self.restartTimer(immediate: true)
        }
    }

    private func startTimer(immediate: Bool) {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(
            deadline: immediate ? .now() : .now() + pollingInterval,
            repeating: pollingInterval
        )
        timer.setEventHandler { [weak self] in
            self?.poll()
        }
        self.timer = timer
        timer.resume()
    }

    private func restartTimer(immediate: Bool) {
        timer?.cancel()
        timer = nil
        startTimer(immediate: immediate)
    }

    private var pollingInterval: DispatchTimeInterval {
        isCodexFrontmost ? foregroundPollingInterval : backgroundPollingInterval
    }

    private func poll() {
        guard AXIsProcessTrusted() else {
            publishStatus("Unread sync needs Accessibility")
            return
        }

        guard let codexApp = NSRunningApplication.runningApplications(withBundleIdentifier: codexBundleIdentifier).first else {
            publishSnapshot(
                CodexUnreadSidebarSnapshot(
                    unreadCount: 0,
                    runningThreadCount: 0,
                    activeThreadDisplayText: nil,
                    isActiveThreadUnread: false
                )
            )
            publishStatus("Unread sync waiting for Codex")
            return
        }

        guard let snapshot = sidebarSnapshot(for: codexApp) else {
            publishStatus("Unread sync unavailable")
            return
        }

        publishSnapshot(snapshot)
        publishStatus("Unread sync via AX")
    }

    private func sidebarSnapshot(for codexApp: NSRunningApplication) -> CodexUnreadSidebarSnapshot? {
        let appElement = AXUIElementCreateApplication(codexApp.processIdentifier)
        guard let window = mainWindowElement(from: appElement) else {
            return nil
        }
        guard let windowFrame = frame(from: window) else {
            return nil
        }

        let rows = threadRowElements(in: window)
        let axUnreadCount = rows.reduce(into: 0) { count, row in
            if isUnreadThreadRow(row) {
                count += 1
            }
        }
        let unreadCount = visionUnreadCount(for: codexApp, windowFrame: windowFrame, rows: rows) ?? axUnreadCount
        let activeRow = rows.first(where: isActiveThreadRow)
        let runningThreadCount = rows.reduce(into: 0) { count, row in
            if hasSidebarRunningMarker(row) {
                count += 1
            }
        }

        return CodexUnreadSidebarSnapshot(
            unreadCount: unreadCount,
            runningThreadCount: runningThreadCount,
            activeThreadDisplayText: activeRow.flatMap(threadDisplayText),
            isActiveThreadUnread: activeRow.map(isUnreadThreadRow) ?? false
        )
    }

    private func mainWindowElement(from appElement: AXUIElement) -> AXUIElement? {
        if let mainWindow = elementAttribute("AXMainWindow", from: appElement) {
            return mainWindow
        }
        if let focusedWindow = elementAttribute("AXFocusedWindow", from: appElement) {
            return focusedWindow
        }

        let windows = childElements(for: appElement, attributes: ["AXWindows"])
        var largestWindow: AXUIElement?
        var largestArea: CGFloat = 0

        for window in windows {
            guard let frame = frame(from: window) else {
                continue
            }

            let area = frame.width * frame.height
            if area > largestArea {
                largestArea = area
                largestWindow = window
            }
        }

        return largestWindow
    }

    private func threadRowElements(in window: AXUIElement) -> [AXUIElement] {
        var visited = Set<CFHashCode>()
        let elements = descendantElements(from: window, depth: 0, maxDepth: 30, childLimit: 200, visited: &visited)
        if let threadList = elements.first(where: isThreadList) {
            let listRows = childElements(for: threadList).filter(matchesThreadRow)
            if !listRows.isEmpty {
                return listRows
            }
        }
        return elements.filter(matchesThreadRow)
    }

    private func isThreadList(_ element: AXUIElement) -> Bool {
        guard stringAttribute("AXRole", from: element) == "AXList" else {
            return false
        }

        let description = stringAttribute("AXDescription", from: element) ?? ""
        return description == "最近聊天" || description == "最近线程"
    }

    private func matchesThreadRow(_ element: AXUIElement) -> Bool {
        guard stringAttribute("AXRole", from: element) == "AXGroup" else {
            return false
        }

        guard let rowFrame = frame(from: element), rowFrame.width >= 180, rowFrame.height > 0 else {
            return false
        }

        return rowTitleButton(in: element) != nil
    }

    private func isUnreadThreadRow(_ element: AXUIElement) -> Bool {
        let rowChildren = rowDescendants(for: element)
        let rowMidX = frame(from: element)?.midX ?? 0

        let leadingControls = rowChildren.filter { child in
            guard let frame = frame(from: child) else {
                return false
            }
            return frame.midX < rowMidX
        }

        return leadingControls.contains { child in
            guard stringAttribute("AXRole", from: child) == "AXGroup" else {
                return false
            }

            let nested = childElements(for: child)
            return classListContains("text-token-description-foreground", in: child)
                && nested.allSatisfy { nestedChild in
                    let role = stringAttribute("AXRole", from: nestedChild)
                    return role != "AXButton" && role != "AXImage"
                }
        }
    }

    private func visionUnreadCount(
        for codexApp: NSRunningApplication,
        windowFrame: CGRect,
        rows: [AXUIElement]
    ) -> Int? {
        guard let windowID = codexWindowID(for: codexApp, windowFrame: windowFrame) else {
            return nil
        }
        guard let image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            return nil
        }

        let rowFrames = rows.compactMap(frame(from:))
        return UnreadDotVisionDetector.unreadDotCount(
            in: image,
            rowFrames: rowFrames,
            windowFrame: windowFrame
        )
    }

    private func codexWindowID(
        for codexApp: NSRunningApplication,
        windowFrame: CGRect
    ) -> CGWindowID? {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowInfos = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let pid = Int(codexApp.processIdentifier)
        let tolerance: CGFloat = 8

        return windowInfos.first { info in
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int, ownerPID == pid else {
                return false
            }
            guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else {
                return false
            }

            let cgFrame = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )

            return abs(cgFrame.origin.x - windowFrame.origin.x) <= tolerance
                && abs(cgFrame.origin.y - windowFrame.origin.y) <= tolerance
                && abs(cgFrame.width - windowFrame.width) <= tolerance
                && abs(cgFrame.height - windowFrame.height) <= tolerance
        }.flatMap { info in
            info[kCGWindowNumber as String] as? CGWindowID
        }
    }

    private func isActiveThreadRow(_ element: AXUIElement) -> Bool {
        classListContains("bg-token-list-hover-background", in: element)
            || rowDescendants(for: element).contains { classListContains("bg-token-list-hover-background", in: $0) }
    }

    private func isThreadRowTitle(_ title: String) -> Bool {
        title.hasPrefix("归档线程")
            || title.hasPrefix("归档聊天")
            || title.localizedCaseInsensitiveContains("Pin thread")
            || title.localizedCaseInsensitiveContains("Pinned chat")
    }

    private func hasSidebarRunningMarker(_ element: AXUIElement) -> Bool {
        let rowChildren = rowDescendants(for: element)
        let rowMidX = frame(from: element)?.midX ?? 0

        // Keep the old structural heuristic, but scan the whole row container.
        return rowChildren.contains { candidate in
            guard stringAttribute("AXRole", from: candidate) == "AXGroup",
                  let candidateFrame = frame(from: candidate),
                  candidateFrame.midX > rowMidX
            else {
                return false
            }

            return childElements(for: candidate).contains { child in
                stringAttribute("AXRole", from: child) == "AXImage"
            }
        }
    }

    private func threadDisplayText(from element: AXUIElement) -> String? {
        let rowChildren = rowDescendants(for: element)
        for child in rowChildren {
            guard stringAttribute("AXRole", from: child) == "AXStaticText" else {
                continue
            }

            let text = (stringValueAttribute("AXValue", from: child) ?? stringAttribute("AXTitle", from: child) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty, !looksLikeRelativeTime(text) {
                return text
            }
        }
        return nil
    }

    private func rowTitleButton(in element: AXUIElement) -> AXUIElement? {
        if stringAttribute("AXRole", from: element) == "AXButton" {
            let title = stringAttribute("AXTitle", from: element) ?? ""
            return isThreadRowTitle(title) ? element : nil
        }

        return rowDescendants(for: element).first { candidate in
            guard stringAttribute("AXRole", from: candidate) == "AXButton" else {
                return false
            }
            let title = stringAttribute("AXTitle", from: candidate) ?? ""
            return isThreadRowTitle(title)
        }
    }

    private func rowDescendants(for element: AXUIElement) -> [AXUIElement] {
        var visited = Set<CFHashCode>()
        return descendantElements(from: element, depth: 0, maxDepth: 4, childLimit: 80, visited: &visited)
    }

    private func looksLikeRelativeTime(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        let suffixes = ["分", "小时", "天", "周", "个月", "月", "刚刚", "分钟", "min", "hour", "day", "week", "month"]
        return suffixes.contains { trimmed.hasSuffix($0) } || trimmed == "刚刚"
    }

    private func classListContains(_ needle: String, in element: AXUIElement) -> Bool {
        classList(from: element).contains { $0.contains(needle) }
    }

    private func classList(from element: AXUIElement) -> [String] {
        let attributes = ["AXDOMClassList", "AXIdentifier"]
        for attribute in attributes {
            var value: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
            guard error == .success, let value else {
                continue
            }

            if let strings = value as? [String], !strings.isEmpty {
                return strings
            }

            if let string = value as? String, !string.isEmpty {
                return [string]
            }
        }

        return []
    }

    private func descendantElements(
        from element: AXUIElement,
        depth: Int,
        maxDepth: Int,
        childLimit: Int,
        visited: inout Set<CFHashCode>
    ) -> [AXUIElement] {
        guard depth <= maxDepth else {
            return []
        }

        let identifier = CFHash(element)
        guard visited.insert(identifier).inserted else {
            return []
        }

        var items = [element]
        for child in childElements(for: element).prefix(childLimit) {
            items.append(contentsOf: descendantElements(from: child, depth: depth + 1, maxDepth: maxDepth, childLimit: childLimit, visited: &visited))
        }
        return items
    }

    private func childElements(for element: AXUIElement, attributes: [String]? = nil) -> [AXUIElement] {
        let attributes = attributes ?? [
            kAXChildrenAttribute as String,
            "AXVisibleChildren",
            "AXContents",
            "AXRows"
        ]

        var result: [AXUIElement] = []
        var seen = Set<CFHashCode>()

        for attribute in attributes {
            var value: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
            guard error == .success, let children = value as? [AXUIElement] else {
                continue
            }

            for child in children {
                let identifier = CFHash(child)
                guard seen.insert(identifier).inserted else {
                    continue
                }
                result.append(child)
            }
        }
        return result
    }

    private func elementAttribute(_ name: String, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard error == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func stringAttribute(_ name: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard error == .success else {
            return nil
        }
        return value as? String
    }

    private func stringValueAttribute(_ name: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard error == .success, let value else {
            return nil
        }

        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private func frame(from element: AXUIElement) -> CGRect? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, "AXFrame" as CFString, &value)
        guard error == .success, let value else {
            return nil
        }

        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgRect else {
            return nil
        }

        var rect = CGRect.zero
        guard AXValueGetValue(axValue, .cgRect, &rect) else {
            return nil
        }
        return rect
    }

    private func publishSnapshot(_ snapshot: CodexUnreadSidebarSnapshot) {
        guard let lastSnapshot else {
            clearPendingLowerSnapshot()
            self.lastSnapshot = snapshot
            onSnapshotChange?(snapshot)
            return
        }

        guard snapshot != lastSnapshot else {
            clearPendingLowerSnapshot()
            return
        }

        if shouldPublishImmediately(snapshot, comparedTo: lastSnapshot) {
            clearPendingLowerSnapshot()
            self.lastSnapshot = snapshot
            onSnapshotChange?(snapshot)
            return
        }

        if pendingLowerSnapshot != snapshot {
            pendingLowerSnapshot = snapshot
            pendingLowerSnapshotObservedAt = .now
            return
        }

        let observedDuration = Date().timeIntervalSince(pendingLowerSnapshotObservedAt ?? .now)
        guard observedDuration >= lowerSnapshotDebounceSeconds else {
            return
        }

        clearPendingLowerSnapshot()
        self.lastSnapshot = snapshot
        onSnapshotChange?(snapshot)
    }

    private func publishStatus(_ status: String) {
        guard status != lastStatus else { return }
        lastStatus = status
        onStatusChange?(status)
    }

    private func shouldPublishImmediately(
        _ snapshot: CodexUnreadSidebarSnapshot,
        comparedTo lastSnapshot: CodexUnreadSidebarSnapshot
    ) -> Bool {
        if snapshot.unreadCount > lastSnapshot.unreadCount {
            return true
        }

        if snapshot.runningThreadCount > lastSnapshot.runningThreadCount {
            return true
        }

        if snapshot.activeThreadDisplayText != lastSnapshot.activeThreadDisplayText {
            return true
        }

        if snapshot.isActiveThreadUnread != lastSnapshot.isActiveThreadUnread {
            return true
        }

        return false
    }

    private func clearPendingLowerSnapshot() {
        pendingLowerSnapshot = nil
        pendingLowerSnapshotObservedAt = nil
    }
}
