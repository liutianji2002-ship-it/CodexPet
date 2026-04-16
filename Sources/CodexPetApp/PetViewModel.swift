import AppKit
import Foundation

@MainActor
final class PetViewModel: ObservableObject {
    @Published private(set) var snapshot = PetStatusSnapshot()

    private var bubbleTask: Task<Void, Never>?
    private var celebrationTask: Task<Void, Never>?
    private let sessionStartedAt = Date()

    var primaryStatusText: String {
        snapshot.primaryStatusText
    }

    var isDirectMonitorActive: Bool {
        snapshot.isDirectMonitorActive
    }

    var isAccessibilityTrusted: Bool {
        snapshot.isAccessibilityTrusted
    }

    var isLogMonitorActive: Bool {
        snapshot.isLogMonitorActive
    }

    var isWorking: Bool {
        snapshot.isWorking
    }

    var bubbleText: String {
        snapshot.bubbleText
    }

    var subtitle: String {
        snapshot.subtitle
    }

    var unreadThreadCount: Int {
        snapshot.unreadThreadCount
    }

    var totalCompletions: Int {
        snapshot.totalCompletions
    }

    var isCelebrating: Bool {
        snapshot.isCelebrating
    }

    func updateDirectStatus(_ status: String) {
        mutateSnapshot {
            $0.directStatus = status
        }
    }

    func updateLogStatus(_ status: String) {
        mutateSnapshot {
            $0.logStatus = status
        }
    }

    func updateUnreadSyncStatus(_ status: String) {
        mutateSnapshot {
            $0.unreadSyncStatus = status
        }
    }

    func updateAccessibilityTrust(_ isTrusted: Bool) {
        mutateSnapshot {
            $0.isAccessibilityTrusted = isTrusted
        }
    }

    func updateCodexFrontmost(_ isFrontmost: Bool) {
        mutateSnapshot {
            $0.isCodexFrontmost = isFrontmost
        }
    }

    func updateDirectActiveThreadCount(_ count: Int) {
        mutateSnapshot {
            $0.directActiveThreadCount = max(0, count)
        }
    }

    func updateRuntimeActiveThreadCount(_ count: Int) {
        mutateSnapshot {
            $0.runtimeActiveThreadCount = max(0, count)
        }
    }

    func syncUnreadSnapshot(_ snapshot: CodexUnreadSidebarSnapshot, source: String) {
        mutateSnapshot {
            $0.baseUnreadThreadCount = max(0, snapshot.unreadCount)
            $0.derivedUnreadThreadCount = 0
            $0.sidebarRunningThreadCount = max(0, snapshot.runningThreadCount)
            if snapshot.isActiveThreadUnread,
               snapshot.activeThreadDisplayText == $0.focusedCompletionBonusDisplayText {
                $0.focusedCompletionBonusDisplayText = nil
            }
            $0.unreadSyncStatus = source
        }
    }

    func handle(
        event: CodexTurnCompletionEvent,
        shouldAddFocusedThreadBonus: Bool,
        shouldIncrementDerivedUnread: Bool,
        focusedThreadDisplayText: String?
    ) {
        guard shouldTrack(event: event) else {
            return
        }

        mutateSnapshot {
            if shouldAddFocusedThreadBonus {
                $0.focusedCompletionBonusDisplayText = focusedThreadDisplayText
            }
            if shouldIncrementDerivedUnread {
                $0.derivedUnreadThreadCount += 1
            }
            $0.totalCompletions += 1
            $0.bubbleOverride = "Thread complete"
            $0.subtitleOverride = "turn \(event.turnId.suffix(6))"
            $0.isCelebrating = true
        }

        celebrationTask?.cancel()
        celebrationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.mutateSnapshot {
                $0.isCelebrating = false
            }
        }

        bubbleTask?.cancel()
        bubbleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.restoreIdleBubble()
        }
    }

    private func restoreIdleBubble() {
        mutateSnapshot {
            $0.bubbleOverride = nil
            $0.subtitleOverride = nil
        }
    }

    func clearFocusedThreadCompletionBonus() {
        guard snapshot.focusedCompletionBonusDisplayText != nil else { return }
        mutateSnapshot {
            $0.focusedCompletionBonusDisplayText = nil
        }
    }

    func openCodex() {
        let bundleIdentifier = "com.openai.codex"

        if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            return
        }

        let codexURL = URL(fileURLWithPath: "/Applications/Codex.app")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: codexURL, configuration: configuration) { app, _ in
            app?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }
    }

    private func shouldTrack(event: CodexTurnCompletionEvent) -> Bool {
        switch event.source {
        case .logTail:
            return event.timestamp >= sessionStartedAt.addingTimeInterval(-2)
        case .directAppServer:
            return true
        }
    }

    func revealLogs() {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/com.openai.codex", isDirectory: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func mutateSnapshot(_ mutate: (inout PetStatusSnapshot) -> Void) {
        var next = snapshot
        mutate(&next)

        if !next.isCelebrating, next.bubbleOverride != nil || next.subtitleOverride != nil {
            next.bubbleOverride = nil
            next.subtitleOverride = nil
        }

        snapshot = next
    }
}
