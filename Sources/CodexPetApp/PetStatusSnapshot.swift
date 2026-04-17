import Foundation

struct PetStatusSnapshot: Equatable {
    var isAccessibilityTrusted = false
    var directStatus = "Direct WS starting"
    var logStatus = "Log monitor starting"
    var unreadSyncStatus = "Unread sync starting"
    var cpuUsagePercent: Double?
    var memoryUsedBytes: UInt64?
    var memoryTotalBytes: UInt64?
    var baseUnreadThreadCount = 0
    var derivedUnreadThreadCount = 0
    var focusedCompletionBonusDisplayText: String?
    var totalCompletions = 0
    var isCelebrating = false
    var isCodexFrontmost = false
    var directActiveThreadCount = 0
    var runtimeActiveThreadCount = 0
    var sidebarRunningThreadCount = 0
    var bubbleOverride: String?
    var subtitleOverride: String?

    var unreadThreadCount: Int {
        baseUnreadThreadCount + derivedUnreadThreadCount + focusedCompletionBonusCount
    }

    var combinedActiveThreadCount: Int {
        max(directActiveThreadCount, runtimeActiveThreadCount, sidebarRunningThreadCount)
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

    var systemResourceText: String? {
        guard
            let cpuUsagePercent,
            let memoryUsedBytes,
            let memoryTotalBytes,
            memoryTotalBytes > 0
        else {
            return nil
        }

        let cpuText = "CPU \(Int(cpuUsagePercent.rounded()))%"
        let usedGigabytes = Double(memoryUsedBytes) / 1_073_741_824
        let totalGigabytes = Double(memoryTotalBytes) / 1_073_741_824
        let memoryText = String(format: "MEM %.1f/%.1fG", usedGigabytes, totalGigabytes)
        return "\(cpuText) · \(memoryText)"
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
