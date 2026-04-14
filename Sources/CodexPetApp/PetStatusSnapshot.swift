import Foundation

struct PetStatusSnapshot: Equatable {
    var directStatus = "Direct WS starting"
    var logStatus = "Log monitor starting"
    var unreadSyncStatus = "Unread sync starting"
    var baseUnreadThreadCount = 0
    var focusedCompletionBonusDisplayText: String?
    var totalCompletions = 0
    var isCelebrating = false
    var directActiveThreadCount = 0
    var runtimeActiveThreadCount = 0
    var sidebarRunningThreadCount = 0
    var bubbleOverride: String?
    var subtitleOverride: String?

    var unreadThreadCount: Int {
        baseUnreadThreadCount + focusedCompletionBonusCount
    }

    var combinedActiveThreadCount: Int {
        max(runtimeActiveThreadCount, sidebarRunningThreadCount)
    }

    var isDirectMonitorActive: Bool {
        directStatus == "Direct WS connected" || directStatus == "Direct WS live"
    }

    var isLogMonitorActive: Bool {
        !logStatus.hasPrefix("No Codex log file found") && !logStatus.hasPrefix("Cannot open ")
    }

    var isWorking: Bool {
        combinedActiveThreadCount > 0
    }

    var primaryStatusText: String {
        if isDirectMonitorActive {
            return directStatus
        }
        return logStatus
    }

    var bubbleText: String {
        bubbleOverride ?? workingSummaryText ?? unreadSummaryText
    }

    var subtitle: String {
        subtitleOverride ?? primaryStatusText
    }

    var workingSummaryText: String? {
        guard isWorking else {
            return nil
        }

        if combinedActiveThreadCount <= 1 {
            return "1 thread running"
        }

        return "\(combinedActiveThreadCount) threads running"
    }

    private var unreadSummaryText: String {
        switch unreadThreadCount {
        case 0:
            return "Watching Codex"
        case 1:
            return "1 thread needs you"
        default:
            return "\(unreadThreadCount) threads need you"
        }
    }

    private var focusedCompletionBonusCount: Int {
        focusedCompletionBonusDisplayText == nil ? 0 : 1
    }
}
