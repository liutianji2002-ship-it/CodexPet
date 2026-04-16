import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let accessibilityPermissionManager = AccessibilityPermissionManager()
    private let codexAccessibilityInspector = CodexAccessibilityInspector()
    private let threadTitleResolver = CodexThreadTitleResolver()
    private let viewModel = PetViewModel()
    private let appearanceStore = PetAppearanceStore()
    private var petWindowController: PetWindowController?
    private var petStylePanelController: PetStylePanelController?
    private var logMonitor: CodexTurnCompletionMonitor?
    private var directMonitor: CodexAppServerMonitor?
    private var unreadMonitor: CodexUnreadCountMonitor?
    private var runtimeActivityMonitor: CodexRuntimeActivityMonitor?
    private var statusItem: NSStatusItem?
    private var unreadCountObserver: AnyCancellable?
    private var codexActivationObserver: NSObjectProtocol?
    private var latestUnreadSnapshot: CodexUnreadSidebarSnapshot?
    private var isCodexFrontmost = false
    private var seenCompletionTurnIDs = Set<String>()
    private var seenCompletionTurnOrder: [String] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        accessibilityPermissionManager.requestIfNeeded()
        syncCodexFrontmostState()

        let petWindowController = PetWindowController(viewModel: viewModel, appearanceStore: appearanceStore)
        petWindowController.showWindow(nil)
        petWindowController.reposition()
        self.petWindowController = petWindowController
        self.petStylePanelController = PetStylePanelController(appearanceStore: appearanceStore)

        configureStatusItem()
        bindUnreadCount()
        observeCodexFocus()
        startMonitoring()
        scheduleAccessibilityDump()
    }

    func applicationWillTerminate(_ notification: Notification) {
        unreadMonitor?.stop()
        directMonitor?.stop()
        logMonitor?.stop()
        runtimeActivityMonitor?.stop()
        threadTitleResolver.stop()
        if let codexActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(codexActivationObserver)
        }
    }

    private func startMonitoring() {
        threadTitleResolver.start()

        let unreadMonitor = CodexUnreadCountMonitor()
        unreadMonitor.onStatusChange = { [weak self] status in
            Task { @MainActor [weak self] in
                self?.viewModel.updateUnreadSyncStatus(status)
            }
        }
        unreadMonitor.onSnapshotChange = { [weak self] snapshot in
            Task { @MainActor [weak self] in
                self?.latestUnreadSnapshot = snapshot
                self?.viewModel.syncUnreadSnapshot(snapshot, source: "AX")
            }
        }

        let directMonitor = CodexAppServerMonitor()
        directMonitor.onStatusChange = { [weak self] status in
            Task { @MainActor [weak self] in
                self?.viewModel.updateDirectStatus(status)
            }
        }
        directMonitor.onActiveThreadCountChange = { [weak self] count in
            Task { @MainActor [weak self] in
                self?.viewModel.updateDirectActiveThreadCount(count)
            }
        }
        directMonitor.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleCompletionEvent(event)
            }
        }

        let logMonitor = CodexTurnCompletionMonitor()
        logMonitor.onStatusChange = { [weak self] status in
            Task { @MainActor [weak self] in
                self?.viewModel.updateLogStatus(status)
            }
        }
        logMonitor.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleCompletionEvent(event)
            }
        }

        let runtimeActivityMonitor = CodexRuntimeActivityMonitor()
        runtimeActivityMonitor.onActiveThreadCountChange = { [weak self] count in
            Task { @MainActor [weak self] in
                self?.viewModel.updateRuntimeActiveThreadCount(count)
            }
        }

        unreadMonitor.start()
        directMonitor.start()
        logMonitor.start()
        runtimeActivityMonitor.start()
        self.unreadMonitor = unreadMonitor
        self.directMonitor = directMonitor
        self.logMonitor = logMonitor
        self.runtimeActivityMonitor = runtimeActivityMonitor
    }

    private func handleCompletionEvent(_ event: CodexTurnCompletionEvent) {
        guard markCompletionEventIfNeeded(event.turnId) else {
            return
        }

        let snapshot = latestUnreadSnapshot
        let activeDisplayText = snapshot?.activeThreadDisplayText
        let shouldAddFocusedThreadBonus =
            (snapshot?.isActiveThreadUnread == false)
            && focusedThreadMatchesCompletionEvent(event.conversationId, activeDisplayText: activeDisplayText)
        let shouldIncrementDerivedUnread = !shouldAddFocusedThreadBonus && !isCodexFrontmost

        viewModel.handle(
            event: event,
            shouldAddFocusedThreadBonus: shouldAddFocusedThreadBonus,
            shouldIncrementDerivedUnread: shouldIncrementDerivedUnread,
            focusedThreadDisplayText: activeDisplayText
        )

        if isCodexFrontmost {
            unreadMonitor?.requestRefresh()
        }
    }

    private func focusedThreadMatchesCompletionEvent(_ threadId: String, activeDisplayText: String?) -> Bool {
        guard let activeDisplayText else {
            return false
        }

        if directMonitor?.matchesDisplayText(forThreadId: threadId, against: activeDisplayText) == true {
            return true
        }

        guard let resolvedTitle = threadTitleResolver.title(forThreadId: threadId) else {
            return false
        }

        return fuzzyMatchesDisplayText(resolvedTitle, activeDisplayText)
    }

    private func fuzzyMatchesDisplayText(_ lhs: String?, _ rhs: String?) -> Bool {
        let left = normalizedDisplayText(lhs)
        let right = normalizedDisplayText(rhs)

        guard !left.isEmpty, !right.isEmpty else {
            return false
        }

        if left == right {
            return true
        }

        let shorter: String
        let longer: String
        if left.count <= right.count {
            shorter = left
            longer = right
        } else {
            shorter = right
            longer = left
        }

        return shorter.count >= 4 && longer.contains(shorter)
    }

    private func normalizedDisplayText(_ text: String?) -> String {
        guard let text else {
            return ""
        }

        let replaced = text
            .replacingOccurrences(of: "…", with: " ")
            .replacingOccurrences(of: "...", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .lowercased()

        let scalarView = replaced.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar)
                || CharacterSet.whitespacesAndNewlines.contains(scalar)
                || scalar.properties.isIdeographic
        }

        return String(String.UnicodeScalarView(scalarView))
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "CodexPet"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Pet", action: #selector(showPet), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Pet Style", action: #selector(showPetStylePanel), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Open Codex", action: #selector(openCodex), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Reveal Logs", action: #selector(revealLogs), keyEquivalent: "l"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        self.statusItem = statusItem
    }

    private func bindUnreadCount() {
        unreadCountObserver = viewModel.$snapshot
            .map(\.unreadThreadCount)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                self?.statusItem?.button?.title = count > 0 ? "CodexPet \(count)" : "CodexPet"
            }
    }

    private func scheduleAccessibilityDump() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.codexAccessibilityInspector.dumpSnapshotIfPossible()
        }
    }

    private func observeCodexFocus() {
        codexActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let isCodexFrontmost = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?
                .bundleIdentifier == "com.openai.codex"
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isCodexFrontmost = isCodexFrontmost
                self.viewModel.updateCodexFrontmost(isCodexFrontmost)

                if isCodexFrontmost {
                    self.viewModel.clearFocusedThreadCompletionBonus()
                    self.unreadMonitor?.requestRefresh()
                }
            }
        }
    }

    private func syncCodexFrontmostState() {
        let isCodexFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.openai.codex"
        self.isCodexFrontmost = isCodexFrontmost
        viewModel.updateCodexFrontmost(isCodexFrontmost)
    }

    private func markCompletionEventIfNeeded(_ turnId: String) -> Bool {
        guard seenCompletionTurnIDs.insert(turnId).inserted else {
            return false
        }

        seenCompletionTurnOrder.append(turnId)
        while seenCompletionTurnOrder.count > 100 {
            let removed = seenCompletionTurnOrder.removeFirst()
            seenCompletionTurnIDs.remove(removed)
        }

        return true
    }

    @objc
    private func showPet() {
        petWindowController?.showWindow(nil)
        petWindowController?.reposition()
    }

    @objc
    private func showPetStylePanel() {
        petStylePanelController?.showWindow(nil)
    }

    @objc
    private func openCodex() {
        viewModel.openCodex()
    }

    @objc
    private func revealLogs() {
        viewModel.revealLogs()
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}
