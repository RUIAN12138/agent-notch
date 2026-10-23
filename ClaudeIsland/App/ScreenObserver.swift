//
//  Modified by lihao505 for Agent Notch, 2026.
//  ScreenObserver.swift
//  ClaudeIsland
//
//  Monitors screen configuration changes
//

import AppKit

extension Notification.Name {
    /// App-level selection changes are distinct from hardware reconfiguration.
    static let agentNotchScreenSelectionDidChange = Notification.Name(
        "AgentNotch.screenSelectionDidChange"
    )
}

class ScreenObserver {
    private static let activeDisplayDidChangeNotification = Notification.Name(
        "NSWorkspaceActiveDisplayDidChangeNotification"
    )

    private var observer: Any?
    private var selectionObserver: Any?
    private var activeDisplayObserver: Any?
    private let onScreenChange: () -> Void
    private let onActiveDisplayChange: () -> Void
    private var pendingWork: DispatchWorkItem?

    /// Debounce interval to coalesce rapid screen change notifications
    /// (e.g., when waking from sleep, displays reconnect in stages)
    private let debounceInterval: TimeInterval = 0.5

    init(
        onScreenChange: @escaping () -> Void,
        onActiveDisplayChange: @escaping () -> Void
    ) {
        self.onScreenChange = onScreenChange
        self.onActiveDisplayChange = onActiveDisplayChange
        startObserving()
    }

    deinit {
        stopObserving()
    }

    private func startObserving() {
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleScreenChange()
        }

        selectionObserver = NotificationCenter.default.addObserver(
            forName: .agentNotchScreenSelectionDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pendingWork?.cancel()
            self?.pendingWork = nil
            self?.onScreenChange()
        }

        // Boring Notch uses this workspace notification to follow the active
        // display. Keep it separate so fixed-screen mode stays on its selection.
        activeDisplayObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: Self.activeDisplayDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onActiveDisplayChange()
        }
    }

    private func scheduleScreenChange() {
        pendingWork?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.onScreenChange()
        }
        pendingWork = work

        DispatchQueue.main.asyncAfter(
            deadline: .now() + debounceInterval,
            execute: work
        )
    }

    private func stopObserving() {
        pendingWork?.cancel()
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        if let selectionObserver {
            NotificationCenter.default.removeObserver(selectionObserver)
        }
        if let activeDisplayObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activeDisplayObserver)
        }
    }
}
