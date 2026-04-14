import AppKit
import ApplicationServices
import Foundation

@MainActor
final class CodexAccessibilityInspector {
    private let bundleIdentifier = "com.openai.codex"
    private let dockBundleIdentifier = "com.apple.dock"
    private let dumpURL = URL(fileURLWithPath: "/tmp/codexpet-codex-ax-dump.txt")

    func dumpSnapshotIfPossible() {
        guard AXIsProcessTrusted() else {
            try? "CodexPet accessibility is not trusted.\n".write(to: dumpURL, atomically: true, encoding: .utf8)
            return
        }

        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            try? "Codex is not running.\n".write(to: dumpURL, atomically: true, encoding: .utf8)
            return
        }

        let root = AXUIElementCreateApplication(app.processIdentifier)
        let lines = dumpTree(from: root, depth: 0, maxDepth: 12, childLimit: 40)
        let header = [
            "pid=\(app.processIdentifier)",
            "bundle=\(bundleIdentifier)",
            "time=\(ISO8601DateFormatter().string(from: Date()))",
            ""
        ]

        var output = header + lines
        output.append("")
        output.append(contentsOf: dockDebugLines(for: app))

        try? output.joined(separator: "\n").write(to: dumpURL, atomically: true, encoding: .utf8)
    }

    private func dumpTree(from element: AXUIElement, depth: Int, maxDepth: Int, childLimit: Int) -> [String] {
        guard depth <= maxDepth else {
            return []
        }

        let indent = String(repeating: "  ", count: depth)
        let role = stringAttribute("AXRole", from: element) ?? "?"
        let subrole = stringAttribute("AXSubrole", from: element)
        let title = stringAttribute("AXTitle", from: element)
        let value = stringValueAttribute("AXValue", from: element)
        let description = stringAttribute("AXDescription", from: element)
        let identifier = stringAttribute("AXIdentifier", from: element)
        let frame = frameString(from: element)

        var parts = ["\(indent)- role=\(role)"]
        if let subrole, !subrole.isEmpty { parts.append("subrole=\(subrole)") }
        if let title, !title.isEmpty { parts.append("title=\(title)") }
        if let value, !value.isEmpty { parts.append("value=\(value)") }
        if let description, !description.isEmpty { parts.append("description=\(description)") }
        if let identifier, !identifier.isEmpty { parts.append("id=\(identifier)") }
        if let frame, !frame.isEmpty { parts.append("frame=\(frame)") }

        var lines = [parts.joined(separator: " | ")]
        let children = childrenAttribute(from: element)
        for child in children.prefix(childLimit) {
            lines.append(contentsOf: dumpTree(from: child, depth: depth + 1, maxDepth: maxDepth, childLimit: childLimit))
        }
        return lines
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

    private func childrenAttribute(from element: AXUIElement) -> [AXUIElement] {
        let attributes = [
            kAXChildrenAttribute as String,
            "AXVisibleChildren",
            "AXContents",
            "AXRows"
        ]

        var children: [AXUIElement] = []
        for attribute in attributes {
            var value: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
            guard error == .success, let values = value as? [AXUIElement] else {
                continue
            }
            children.append(contentsOf: values)
        }
        return children
    }

    private func frameString(from element: AXUIElement) -> String? {
        guard
            let position = pointAttribute(kAXPositionAttribute, from: element),
            let size = sizeAttribute(kAXSizeAttribute, from: element)
        else {
            return nil
        }

        return "{{\(Int(position.x)),\(Int(position.y))},{\(Int(size.width)),\(Int(size.height))}}"
    }

    private func pointAttribute(_ name: String, from element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard error == .success, let value else {
            return nil
        }

        var point = CGPoint.zero
        guard AXValueGetType(value as! AXValue) == .cgPoint, AXValueGetValue(value as! AXValue, .cgPoint, &point) else {
            return nil
        }
        return point
    }

    private func sizeAttribute(_ name: String, from element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard error == .success, let value else {
            return nil
        }

        var size = CGSize.zero
        guard AXValueGetType(value as! AXValue) == .cgSize, AXValueGetValue(value as! AXValue, .cgSize, &size) else {
            return nil
        }
        return size
    }

    private func dockDebugLines(for codexApp: NSRunningApplication) -> [String] {
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: dockBundleIdentifier).first else {
            return ["[dock]", "Dock is not running."]
        }

        let appName = codexApp.localizedName ?? "Codex"
        let dockRoot = AXUIElementCreateApplication(dockApp.processIdentifier)
        let candidates = dumpSearchElements(from: dockRoot, depth: 0, maxDepth: 7, childLimit: 80)

        guard let dockItem = candidates.first(where: { matchesDockItem($0, appName: appName) }) else {
            return [
                "[dock]",
                "Could not find Codex Dock item.",
                "dock-pid=\(dockApp.processIdentifier)"
            ]
        }

        var lines = [
            "[dock]",
            "dock-pid=\(dockApp.processIdentifier)",
            "codex-name=\(appName)"
        ]
        lines.append(contentsOf: describeAttributes(for: dockItem))

        let children = childrenAttribute(from: dockItem)
        if !children.isEmpty {
            lines.append("children=\(children.count)")
            for (index, child) in children.prefix(4).enumerated() {
                lines.append("child[\(index)]")
                lines.append(contentsOf: describeAttributes(for: child).map { "  " + $0 })
            }
        }

        return lines
    }

    private func dumpSearchElements(from element: AXUIElement, depth: Int, maxDepth: Int, childLimit: Int) -> [AXUIElement] {
        guard depth <= maxDepth else {
            return []
        }

        var results = [element]
        for child in childrenAttribute(from: element).prefix(childLimit) {
            results.append(contentsOf: dumpSearchElements(from: child, depth: depth + 1, maxDepth: maxDepth, childLimit: childLimit))
        }
        return results
    }

    private func matchesDockItem(_ element: AXUIElement, appName: String) -> Bool {
        let values = [
            stringAttribute("AXTitle", from: element),
            stringAttribute("AXDescription", from: element),
            stringValueAttribute("AXValue", from: element),
            stringAttribute("AXStatusLabel", from: element),
            stringAttribute("AXIdentifier", from: element)
        ]

        let normalizedName = appName.lowercased()
        return values.contains { value in
            guard let value else { return false }
            return value.lowercased().contains(normalizedName)
        }
    }

    private func describeAttributes(for element: AXUIElement) -> [String] {
        var names: CFArray?
        let error = AXUIElementCopyAttributeNames(element, &names)
        guard error == .success, let names, let attributeNames = names as? [String] else {
            return ["attribute-names-unavailable"]
        }

        var lines: [String] = []
        for name in attributeNames.sorted() {
            guard let valueDescription = describeAttributeValue(name: name, element: element) else {
                continue
            }
            lines.append("\(name)=\(valueDescription)")
        }
        return lines
    }

    private func describeAttributeValue(name: String, element: AXUIElement) -> String? {
        if let string = stringAttribute(name, from: element), !string.isEmpty {
            return string
        }
        if let string = stringValueAttribute(name, from: element), !string.isEmpty {
            return string
        }
        if name == kAXPositionAttribute as String, let point = pointAttribute(name, from: element) {
            return "{\(Int(point.x)),\(Int(point.y))}"
        }
        if name == kAXSizeAttribute as String, let size = sizeAttribute(name, from: element) {
            return "{\(Int(size.width)),\(Int(size.height))}"
        }

        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard error == .success, let value else {
            return nil
        }

        if let array = value as? [Any] {
            return "array[\(array.count)]"
        }
        if CFGetTypeID(value) == AXUIElementGetTypeID() {
            return "AXUIElement"
        }
        return String(describing: value)
    }
}
