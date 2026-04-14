import AppKit
import SwiftUI

final class PetWindowController: NSWindowController {
    private var notificationObservers: [NSObjectProtocol] = []

    init(viewModel: PetViewModel, appearanceStore: PetAppearanceStore) {
        let panel = PetPanel(
            contentRect: NSRect(x: 0, y: 0, width: 184, height: 188),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.contentView = PetHostingView(rootView: PetView(viewModel: viewModel, appearanceStore: appearanceStore))

        super.init(window: panel)
        shouldCascadeWindows = false
        observeEnvironmentChanges()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.orderFrontRegardless()
        reposition()
    }

    func reposition() {
        guard let window, let targetOrigin = DockAnchoring.targetOrigin(for: window.frame.size) else {
            return
        }
        window.setFrameOrigin(targetOrigin)
    }

    private func observeEnvironmentChanges() {
        let screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reposition()
        }
        notificationObservers.append(screenObserver)

        let spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reposition()
        }
        notificationObservers.append(spaceObserver)

        let dockObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.dock.prefchanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reposition()
        }
        notificationObservers.append(dockObserver)
    }
}
