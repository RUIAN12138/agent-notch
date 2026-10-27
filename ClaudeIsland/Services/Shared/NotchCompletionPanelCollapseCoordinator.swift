// Modified by lihao505 for Agent Notch, 2026.
import Foundation

/// Owns the original completion deadline while a higher-priority interaction
/// or the pointer temporarily prevents a notification-owned panel closing.
@MainActor
final class NotchCompletionPanelCollapseCoordinator {
    private(set) var startedAt: Date?
    private(set) var generation: UInt64 = 0

    private var duration: TimeInterval = 0
    private var task: Task<Void, Never>?
    private var decision: (() -> NotchCompletionPanelCollapseDecision)?
    private var onCollapse: (() -> Void)?
    private let now: () -> Date

    init(now: @escaping () -> Date = { Date() }) {
        self.now = now
    }

    func schedule(
        startedAt: Date,
        duration: TimeInterval,
        decision: @escaping () -> NotchCompletionPanelCollapseDecision,
        onCollapse: @escaping () -> Void
    ) {
        task?.cancel()
        generation &+= 1
        self.startedAt = startedAt
        self.duration = duration
        self.decision = decision
        self.onCollapse = onCollapse
        scheduleDeadline()
    }

    func reschedule(duration: TimeInterval) {
        guard startedAt != nil else { return }
        task?.cancel()
        generation &+= 1
        self.duration = duration
        scheduleDeadline()
    }

    /// Called when the pointer leaves or a pending interaction changes. A
    /// deferred deadline keeps its original timestamp rather than restarting.
    func resumeIfNeeded() {
        guard task == nil, startedAt != nil, let decision else { return }
        switch decision() {
        case .collapse:
            generation &+= 1
            scheduleDeadline()
        case .deferUntilInteractionResolves:
            break
        case .discard:
            cancel()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        startedAt = nil
        decision = nil
        onCollapse = nil
        generation &+= 1
    }

    private func scheduleDeadline() {
        guard let startedAt else { return }
        let scheduledGeneration = generation
        let remaining = NotchAttentionPolicy.completionDwellRemaining(
            startedAt: startedAt, duration: duration, now: now()
        )
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            self?.deadlineFired(generation: scheduledGeneration)
        }
    }

    /// Split from scheduling so deadline order and stale callbacks can be
    /// exercised deterministically without waiting on wall-clock sleeps.
    func deadlineFired(generation scheduledGeneration: UInt64) {
        guard scheduledGeneration == generation, startedAt != nil,
              let decision else { return }
        task?.cancel()
        task = nil
        switch decision() {
        case .collapse:
            let action = onCollapse
            cancel()
            action?()
        case .deferUntilInteractionResolves:
            break
        case .discard:
            cancel()
        }
    }
}
