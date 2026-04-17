import XCTest
@testable import CodexPetApp

final class PetViewModelTests: XCTestCase {
    func testSystemResourceTextFormatsCpuAndMemoryUsedAndTotal() {
        var snapshot = PetStatusSnapshot()
        snapshot.cpuUsagePercent = 18.4
        snapshot.memoryUsedBytes = 12_381_880_320
        snapshot.memoryTotalBytes = 17_179_869_184

        XCTAssertEqual(snapshot.systemResourceText, "CPU 18% · MEM 11.5/16.0G")
    }

    func testSystemResourceTextHiddenUntilDataArrives() {
        let snapshot = PetStatusSnapshot()

        XCTAssertNil(snapshot.systemResourceText)
    }

    @MainActor
    func testAccessibilityLossClearsStaleUnreadCount() {
        let viewModel = PetViewModel()

        viewModel.syncUnreadSnapshot(
            CodexUnreadSidebarSnapshot(
                unreadCount: 2,
                runningThreadCount: 0,
                activeThreadDisplayText: nil,
                isActiveThreadUnread: false
            ),
            source: "AX"
        )

        XCTAssertEqual(viewModel.unreadThreadCount, 2)

        viewModel.updateAccessibilityTrust(false)

        XCTAssertEqual(viewModel.unreadThreadCount, 0)
    }

    @MainActor
    func testUnavailableUnreadSyncStatusPreservesUnreadCount() {
        let viewModel = PetViewModel()

        viewModel.syncUnreadSnapshot(
            CodexUnreadSidebarSnapshot(
                unreadCount: 2,
                runningThreadCount: 0,
                activeThreadDisplayText: nil,
                isActiveThreadUnread: false
            ),
            source: "AX"
        )

        viewModel.updateUnreadSyncStatus("Unread sync unavailable")

        XCTAssertEqual(viewModel.unreadThreadCount, 2)
    }

    @MainActor
    func testFrontmostZeroUnreadSnapshotClearsFocusedCompletionBonus() {
        let viewModel = PetViewModel()

        viewModel.updateCodexFrontmost(true)
        viewModel.handle(
            event: CodexTurnCompletionEvent(
                timestamp: Date(),
                conversationId: "conv-1",
                turnId: "turn-1",
                source: .directAppServer,
                rawLine: ""
            ),
            shouldAddFocusedThreadBonus: true,
            shouldIncrementDerivedUnread: false,
            focusedThreadDisplayText: "active thread"
        )

        XCTAssertEqual(viewModel.unreadThreadCount, 1)

        viewModel.syncUnreadSnapshot(
            CodexUnreadSidebarSnapshot(
                unreadCount: 0,
                runningThreadCount: 1,
                activeThreadDisplayText: "active thread",
                isActiveThreadUnread: false
            ),
            source: "AX"
        )

        XCTAssertEqual(viewModel.unreadThreadCount, 0)
    }
}
