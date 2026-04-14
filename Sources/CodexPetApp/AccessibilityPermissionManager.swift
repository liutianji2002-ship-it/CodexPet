import AppKit
import ApplicationServices
import Foundation

@MainActor
final class AccessibilityPermissionManager {
    func requestIfNeeded() {
        guard !isTrusted else {
            return
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openAccessibilitySettings()
    }

    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    private func openAccessibilitySettings() {
        guard
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
