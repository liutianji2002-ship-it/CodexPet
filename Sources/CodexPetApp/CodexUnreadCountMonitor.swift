import AppKit
import ApplicationServices
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

    private var timer: DispatchSourceTimer?
    private var lastSnapshot: CodexUnreadSidebarSnapshot?
    private var lastStatus: String?

    func start() {
        queue.async { [weak self] in
            guard let self, self.timer == nil else { return }

            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now(), repeating: .seconds(2))
            timer.setEventHandler { [weak self] in
                self?.poll()
            }
            self.timer = timer
            timer.resume()
        }
    }

    func stop() {
        queue.sync {
            timer?.cancel()
            timer = nil
        }
    }

    func currentSnapshot() -> CodexUnreadSidebarSnapshot? {
        queue.sync {
            lastSnapshot
        }
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

        var visited = Set<CFHashCode>()
        let elements = descendantElements(from: window, depth: 0, maxDepth: 30, childLimit: 200, visited: &visited)
        let rows = elements.filter(matchesThreadRow)
        let unreadCount = rows.reduce(into: 0) { count, row in
            if isUnreadThreadRow(row) {
                count += 1
            }
        }
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
        if let focusedWindow = elementAttribute("AXFocusedWindow", from: appElement) {
            return focusedWindow
        }
        if let mainWindow = elementAttribute("AXMainWindow", from: appElement) {
            return mainWindow
        }
        return childElements(for: appElement, attributes: ["AXWindows"]).first
    }

    private func threadRowElements(in window: AXUIElement) -> [AXUIElement] {
        var visited = Set<CFHashCode>()
        let elements = descendantElements(from: window, depth: 0, maxDepth: 30, childLimit: 200, visited: &visited)
        return elements.filter(matchesThreadRow)
    }

    private func matchesThreadRow(_ element: AXUIElement) -> Bool {
        guard stringAttribute("AXRole", from: element) == "AXButton" else {
            return false
        }

        let title = stringAttribute("AXTitle", from: element) ?? ""
        guard isThreadRowTitle(title) else {
            return false
        }

        guard let frame = frame(from: element), frame.width >= 180, frame.height > 0 else {
            return false
        }

        return true
    }

    private func isUnreadThreadRow(_ element: AXUIElement) -> Bool {
        let title = stringAttribute("AXTitle", from: element) ?? ""

        // Fact from the current "sort by updated time" sidebar:
        // unread rows are still thread buttons, but their AXTitle no longer includes "Pin chat".
        // Read rows keep "Pin chat" in the title.
        return isThreadRowTitle(title) && !title.localizedCaseInsensitiveContains("Pin chat")
    }

    private func isActiveThreadRow(_ element: AXUIElement) -> Bool {
        classListContains("bg-token-list-hover-background", in: element)
    }

    private func isThreadRowTitle(_ title: String) -> Bool {
        title.hasPrefix("归档线程") || title.localizedCaseInsensitiveContains("Pin thread")
    }

    private func hasSidebarRunningMarker(_ element: AXUIElement) -> Bool {
        let rowChildren = childElements(for: element)
        guard rowChildren.count > 1 else {
            return false
        }

        let markerContainer = rowChildren[1]
        let markers = childElements(for: markerContainer)

        // Fact from the current "sort by updated time" sidebar:
        // running rows expose an extra AXGroup in the status slot, and that group
        // directly owns an AXImage (the spinning indicator). Plain unread rows do not.
        return markers.contains { candidate in
            stringAttribute("AXRole", from: candidate) == "AXGroup"
                && childElements(for: candidate).contains { child in
                    stringAttribute("AXRole", from: child) == "AXImage"
                }
        }
    }

    private func threadDisplayText(from element: AXUIElement) -> String? {
        let rowChildren = childElements(for: element)
        for child in rowChildren {
            guard stringAttribute("AXRole", from: child) == "AXStaticText" else {
                continue
            }

            let text = (stringValueAttribute("AXValue", from: child) ?? stringAttribute("AXTitle", from: child) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                return text
            }
        }
        return nil
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
        guard snapshot != lastSnapshot else { return }
        lastSnapshot = snapshot
        onSnapshotChange?(snapshot)
    }

    private func publishStatus(_ status: String) {
        guard status != lastStatus else { return }
        lastStatus = status
        onStatusChange?(status)
    }
}
