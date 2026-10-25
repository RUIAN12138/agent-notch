//
//  Modified by lihao505 for Agent Notch, 2026.
//  NotchAttentionPolicy.swift
//  ClaudeIsland
//
//  Stable identities and presentation policy for user-attention events.
//

import Foundation

/// A completion is an event generation, not merely a session that currently
/// happens to be idle. Keeping the authoritative completion boundary in the
/// identity prevents PID/title refreshes from replaying the same alert and
/// still lets a very fast next turn surface even if SwiftUI coalesces the
/// intermediate processing snapshot.
struct NotchCompletionToken: Hashable, Sendable {
    let sessionId: String
    let completedAt: Date
}

/// A Claude teammate can finish before the root session. Its increasing
/// generation stays observable when UI snapshots merge several Hook updates.
struct NotchSubagentCompletionToken: Hashable, Sendable {
    let sessionId: String
    let kind: NotchSubagentCompletionKind
    let generation: UInt64
    let completedAt: Date
}

enum NotchSubagentCompletionKind: String, Hashable, Sendable {
    case individual
    case allAgentsFinished
    case rootResponse
}

/// Presentation deduplication uses the same complete identity as permission
/// routing. Tool-use ids are scoped to a session and cannot safely suppress an
/// interaction arriving from a different concurrent agent.
struct NotchInteractionToken: Hashable, Sendable {
    let sessionId: String
    let toolUseId: String
}

enum NotchFollowUpTarget: Hashable, Sendable {
    case interaction(NotchInteractionToken)
    case completion(NotchCompletionToken)

    var sessionId: String {
        switch self {
        case .interaction(let token): token.sessionId
        case .completion(let token): token.sessionId
        }
    }
}

struct NotchFollowUpCandidate: Equatable, Sendable {
    let target: NotchFollowUpTarget
    let occurredAt: Date
}

enum NotchCompletionPanelCollapseDecision: Equatable {
    case collapse
    case deferUntilInteractionResolves
    case discard
}

enum NotchSubagentCompletionDisposition: Equatable {
    case present
    case deferUntilHigherPriorityStateResolves
    case discard
}

enum NotchAttentionPresentationState: Equatable {
    case permission
    case processing
    case approvalRecovery
    case completion
    case idle
}

enum NotchAttentionPolicy {
    static func presentationState(
        hasPendingPermission: Bool,
        isProcessing: Bool,
        hasApprovalRecoveryNotice: Bool = false,
        hasCompletion: Bool
    ) -> NotchAttentionPresentationState {
        if hasPendingPermission { return .permission }
        if isProcessing { return .processing }
        if hasApprovalRecoveryNotice { return .approvalRecovery }
        if hasCompletion { return .completion }
        return .idle
    }

    static func shouldSuppressAutomaticExpansion(
        suppressWhenTerminalFrontmost: Bool,
        terminalIsFrontmost: Bool
    ) -> Bool {
        suppressWhenTerminalFrontmost && terminalIsFrontmost
    }

    static func completionDwellRemaining(
        startedAt: Date,
        duration: TimeInterval,
        now: Date = Date()
    ) -> TimeInterval {
        max(0, startedAt.addingTimeInterval(duration).timeIntervalSince(now))
    }

    static func shouldShowCompactSubagentCompletion(
        startedAt: Date?,
        duration: TimeInterval,
        now: Date = Date()
    ) -> Bool {
        guard let startedAt else { return false }
        return completionDwellRemaining(
            startedAt: startedAt,
            duration: duration,
            now: now
        ) > 0
    }

    static func shouldAutoExpandOnCompletion(
        expandOnTaskCompletion: Bool,
        status: NotchStatus,
        openReason: NotchOpenReason,
        hasPendingAutoExpandedInteraction: Bool
    ) -> Bool {
        guard expandOnTaskCompletion,
              !hasPendingAutoExpandedInteraction else {
            return false
        }

        if status == .closed {
            return true
        }
        return status == .opened && openReason == .notification
    }

    static func shouldAutoExpandOnAgentTeamCompletion(
        expandOnAgentTeamCompletion: Bool,
        status: NotchStatus,
        openReason: NotchOpenReason,
        hasPendingAutoExpandedInteraction: Bool
    ) -> Bool {
        guard expandOnAgentTeamCompletion,
              !hasPendingAutoExpandedInteraction else {
            return false
        }

        if status == .closed {
            return true
        }
        return status == .opened && openReason == .notification
    }

    static func shouldCollapseNotificationPanelAfterCompletion(
        status: NotchStatus,
        openReason: NotchOpenReason,
        hasPendingAutoExpandedInteraction: Bool
    ) -> Bool {
        status == .opened &&
            openReason == .notification &&
            !hasPendingAutoExpandedInteraction
    }

    static func completionPanelCollapseDecision(
        status: NotchStatus,
        openReason: NotchOpenReason,
        hasPendingAutoExpandedInteraction: Bool
    ) -> NotchCompletionPanelCollapseDecision {
        if shouldCollapseNotificationPanelAfterCompletion(
            status: status,
            openReason: openReason,
            hasPendingAutoExpandedInteraction:
                hasPendingAutoExpandedInteraction
        ) {
            return .collapse
        }
        if status == .opened,
           openReason == .notification,
           hasPendingAutoExpandedInteraction {
            return .deferUntilInteractionResolves
        }
        return .discard
    }

    static func interactionToken(
        for session: SessionState
    ) -> NotchInteractionToken? {
        guard let toolUseId = session.pendingToolId else { return nil }
        return NotchInteractionToken(
            sessionId: session.sessionId,
            toolUseId: toolUseId
        )
    }

    /// Compact-question mode suppresses only automatic panel expansion. The
    /// session remains pending and visible in the compact notch/list, while
    /// risk-bearing approvals and plan reviews keep their urgent behavior.
    static func shouldAutoExpandInteraction(
        _ context: PermissionContext,
        expandQuestionsAutomatically: Bool
    ) -> Bool {
        (context.toolName != "AskUserQuestion" &&
            context.toolName != CodexUserInputRequest.toolName) ||
            expandQuestionsAutomatically
    }

    static func hasPendingAutoExpandedInteraction(
        in sessions: [SessionState],
        expandQuestionsAutomatically: Bool
    ) -> Bool {
        sessions.contains { session in
            guard let interaction = session.activePermission else {
                return false
            }
            return shouldAutoExpandInteraction(
                interaction,
                expandQuestionsAutomatically: expandQuestionsAutomatically
            )
        }
    }

    /// Select after applying compact-question policy so a newer quiet question
    /// cannot mask an older risk-bearing approval that arrived in the same
    /// published update.
    static func newestSessionToAutoExpand(
        from sessions: [SessionState],
        excluding previousTokens: Set<NotchInteractionToken>,
        expandQuestionsAutomatically: Bool
    ) -> SessionState? {
        sessions.filter { session in
            guard let token = interactionToken(for: session),
                  !previousTokens.contains(token),
                  let interaction = session.activePermission else {
                return false
            }
            return shouldAutoExpandInteraction(
                interaction,
                expandQuestionsAutomatically: expandQuestionsAutomatically
            )
        }
        .max(by: { $0.lastActivity < $1.lastActivity })
    }

    static func completionToken(
        for session: SessionState
    ) -> NotchCompletionToken? {
        guard session.phase == .waitingForInput,
              let completedAt = session.completedAt else {
            return nil
        }
        return NotchCompletionToken(
            sessionId: session.sessionId,
            completedAt: completedAt
        )
    }

    static func subagentCompletionToken(
        for session: SessionState
    ) -> NotchSubagentCompletionToken? {
        subagentCompletionToken(for: session, timing: .everyCompletion)
    }

    static func subagentCompletionToken(
        for session: SessionState,
        timing: AgentTeamCompletionTiming
    ) -> NotchSubagentCompletionToken? {
        let kind: NotchSubagentCompletionKind
        let generation: UInt64
        let completedAt: Date?
        switch timing {
        case .everyCompletion:
            kind = .individual
            generation = session.subagentCompletionGeneration
            completedAt = session.lastSubagentCompletedAt
        case .allAgentsFinished:
            kind = .allAgentsFinished
            generation = session.allSubagentsFinishedGeneration
            completedAt = session.lastAllSubagentsFinishedAt
        case .rootResponse:
            kind = .rootResponse
            generation = session.subagentRootResponseGeneration
            completedAt = session.lastSubagentRootResponseAt
        case .disabled:
            return nil
        }

        guard generation > 0, let completedAt else {
            return nil
        }
        return NotchSubagentCompletionToken(
            sessionId: session.sessionId,
            kind: kind,
            generation: generation,
            completedAt: completedAt
        )
    }

    static func shouldPresent(
        _ token: NotchCompletionToken,
        presentationStartedAt: Date,
        duration: TimeInterval,
        now: Date = Date()
    ) -> Bool {
        let age = now.timeIntervalSince(token.completedAt)
        return token.completedAt >= presentationStartedAt &&
            age >= -5 &&
            age < duration
    }

    static func shouldPresent(
        _ token: NotchSubagentCompletionToken,
        presentationStartedAt: Date,
        duration: TimeInterval,
        now: Date = Date()
    ) -> Bool {
        let age = now.timeIntervalSince(token.completedAt)
        return token.completedAt >= presentationStartedAt &&
            age >= -5 &&
            age < duration
    }

    static func subagentCompletionDisposition(
        _ token: NotchSubagentCompletionToken,
        for session: SessionState,
        presentationStartedAt: Date,
        duration: TimeInterval,
        now: Date = Date(),
        isSilenced: Bool,
        expandOnAgentTeamCompletion: Bool,
        status: NotchStatus,
        openReason: NotchOpenReason,
        hasPendingAutoExpandedInteraction: Bool
    ) -> NotchSubagentCompletionDisposition {
        let isRootResponse = token.kind == .rootResponse
        let isAfterRootCompletion = session.completedAt.map {
            token.completedAt > $0
        } ?? true
        // Completion generations survive new prompts. A deferred event from
        // an older turn must not become fresh again when a blocker resolves.
        let isInsideCurrentRootTurn =
            session.subagentHookState.rootTurnStartedAt.map {
                token.completedAt.timeIntervalSince1970 >= $0
            } ?? true
        guard (isRootResponse
                ? session.completedAt == token.completedAt
                : isAfterRootCompletion),
              isInsideCurrentRootTurn,
              shouldPresent(
                token,
                presentationStartedAt: presentationStartedAt,
                duration: duration,
                now: now
              ),
              !isSilenced,
              expandOnAgentTeamCompletion else {
            return .discard
        }

        // A transient notch pop is not a reason to lose an otherwise fresh
        // event. Re-evaluate it once the transition reaches a stable state.
        if hasPendingAutoExpandedInteraction || status == .popping {
            return .deferUntilHigherPriorityStateResolves
        }

        return shouldAutoExpandOnAgentTeamCompletion(
            expandOnAgentTeamCompletion: expandOnAgentTeamCompletion,
            status: status,
            openReason: openReason,
            hasPendingAutoExpandedInteraction: false
        ) ? .present : .discard
    }

    static func isStillCurrent(
        _ token: NotchCompletionToken,
        in sessions: [SessionState]
    ) -> Bool {
        sessions.contains {
            completionToken(for: $0) == token
        }
    }

    /// Pending interactions survive app startup, so they are eligible after a
    /// full reminder delay. Completions deliberately start at this launch's
    /// observation boundary to avoid a burst of historical "done" alerts.
    static func followUpCandidates(
        in sessions: [SessionState],
        completionTrackingStartedAt: Date
    ) -> [NotchFollowUpCandidate] {
        sessions.compactMap { session in
            if let context = session.activePermission,
               let token = interactionToken(for: session) {
                return NotchFollowUpCandidate(
                    target: .interaction(token),
                    occurredAt: context.receivedAt
                )
            }

            guard let token = completionToken(for: session),
                  token.completedAt >= completionTrackingStartedAt else {
                return nil
            }
            return NotchFollowUpCandidate(
                target: .completion(token),
                occurredAt: token.completedAt
            )
        }
    }

    static func isStillCurrent(
        _ target: NotchFollowUpTarget,
        in sessions: [SessionState],
        completionTrackingStartedAt: Date
    ) -> Bool {
        followUpCandidates(
            in: sessions,
            completionTrackingStartedAt: completionTrackingStartedAt
        ).contains { $0.target == target }
    }
}
