//
//  Modified by lihao505 for Agent Notch, 2026.
//  NotchPresentationTimingTests.swift
//  ClaudeIslandTests
//

import CoreGraphics
import XCTest
@testable import Agent_Notch

@MainActor
final class NotchPresentationTimingTests: XCTestCase {
    private func makeViewModel() -> NotchViewModel {
        NotchViewModel(
            deviceNotchRect: CGRect(x: 650, y: 0, width: 212, height: 32),
            screenRect: CGRect(x: 0, y: 0, width: 1512, height: 982),
            windowHeight: 750,
            hasPhysicalNotch: true
        )
    }

    func testNotchMotionUsesInterruptibleSpringAndQuickerCloseProfile() {
        XCTAssertEqual(
            NotchMotionPolicy.opening.response,
            0.38,
            accuracy: 0.001
        )
        XCTAssertEqual(
            NotchMotionPolicy.opening.dampingFraction,
            0.8,
            accuracy: 0.001
        )
        XCTAssertLessThan(
            NotchMotionPolicy.closing.response,
            NotchMotionPolicy.opening.response
        )
        XCTAssertEqual(NotchMotionPolicy.closing.response, 0.30, accuracy: 0.001)
        XCTAssertEqual(
            NotchMotionPolicy.closing.dampingFraction,
            0.9,
            accuracy: 0.001
        )
        XCTAssertEqual(
            NotchMotionPolicy.opening.reducedMotionDuration,
            0.12,
            accuracy: 0.001
        )
        XCTAssertEqual(
            NotchMotionPolicy.closing.reducedMotionDuration,
            0.10,
            accuracy: 0.001
        )
        XCTAssertEqual(
            NotchMotionPolicy.opening.response(atSpeedMultiplier: 0.5),
            0.76,
            accuracy: 0.001
        )
        XCTAssertEqual(
            NotchMotionPolicy.opening.response(atSpeedMultiplier: 2.0),
            0.19,
            accuracy: 0.001
        )
        XCTAssertEqual(
            NotchMotionPolicy.opening.response(atSpeedMultiplier: .infinity),
            NotchMotionPolicy.opening.response,
            accuracy: 0.001
        )
    }

    func testAttentionBounceRespectsMotionPreferences() {
        XCTAssertTrue(
            NotchMotionPolicy.shouldTriggerAttentionBounce(
                reduceMotion: false,
                animationsEnabled: true
            )
        )
        XCTAssertFalse(
            NotchMotionPolicy.shouldTriggerAttentionBounce(
                reduceMotion: true,
                animationsEnabled: true
            )
        )
        XCTAssertFalse(
            NotchMotionPolicy.shouldTriggerAttentionBounce(
                reduceMotion: false,
                animationsEnabled: false
            )
        )

        let profile = NotchMotionPolicy.attentionBounce
        XCTAssertGreaterThanOrEqual(profile.dampingFraction, 0.8)
        XCTAssertEqual(
            profile.response(atSpeedMultiplier: 0.5),
            profile.response * 2,
            accuracy: 0.001
        )
        XCTAssertEqual(
            profile.response(atSpeedMultiplier: 2.0),
            profile.response / 2,
            accuracy: 0.001
        )
    }

    func testNotchAnimationPreferencesPersistAndSanitizeSpeed() async throws {
        let suite = "NotchAnimationPreferencesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let preferences = NotchPreferences(defaults: defaults)
        XCTAssertTrue(preferences.notchAnimationsEnabled)
        XCTAssertEqual(
            preferences.notchAnimationSpeedMultiplier,
            NotchMotionPolicy.defaultSpeedMultiplier,
            accuracy: 0.001
        )

        preferences.notchAnimationsEnabled = false
        preferences.notchAnimationSpeedMultiplier = 1.7

        let restored = NotchPreferences(defaults: defaults)
        XCTAssertFalse(restored.notchAnimationsEnabled)
        XCTAssertEqual(
            restored.notchAnimationSpeedMultiplier,
            1.7,
            accuracy: 0.001
        )

        restored.notchAnimationSpeedMultiplier = .infinity
        XCTAssertEqual(
            restored.notchAnimationSpeedMultiplier,
            NotchMotionPolicy.defaultSpeedMultiplier,
            accuracy: 0.001
        )
        restored.notchAnimationSpeedMultiplier = 10
        XCTAssertEqual(
            restored.notchAnimationSpeedMultiplier,
            NotchMotionPolicy.speedMultiplierRange.upperBound,
            accuracy: 0.001
        )
        restored.notchAnimationSpeedMultiplier = 0
        XCTAssertEqual(
            restored.notchAnimationSpeedMultiplier,
            NotchMotionPolicy.speedMultiplierRange.lowerBound,
            accuracy: 0.001
        )
    }

    func testReducedMotionPixelPolicyKeepsDeterministicStateFrames() {
        XCTAssertFalse(PixelMotionPolicy.shouldAnimate(reduceMotion: true))
        XCTAssertTrue(PixelMotionPolicy.shouldAnimate(reduceMotion: false))
        XCTAssertEqual(
            PixelMotionPolicy.representativeFrameIndex(count: 8),
            4
        )
        XCTAssertEqual(
            PixelMotionPolicy.representativeFrameIndex(
                count: 7,
                preferredIndex: 5
            ),
            5
        )
        XCTAssertEqual(
            PixelMotionPolicy.representativeFrameIndex(
                count: 7,
                preferredIndex: -2
            ),
            0
        )
        XCTAssertEqual(
            PixelMotionPolicy.representativeFrameIndex(
                count: 7,
                preferredIndex: 9
            ),
            6
        )
        XCTAssertNil(PixelMotionPolicy.representativeFrameIndex(count: 0))
        XCTAssertEqual(
            PixelMotionPolicy.reducedMotionOpacity,
            0.6,
            accuracy: 0.001
        )
    }

    func testAttentionPresentationUsesConsistentPriorityForConcurrentStates() {
        func state(
            permission: Bool = false,
            processing: Bool = false,
            approvalRecovery: Bool = false,
            completion: Bool = false
        ) -> NotchAttentionPresentationState {
            NotchAttentionPolicy.presentationState(
                hasPendingPermission: permission,
                isProcessing: processing,
                hasApprovalRecoveryNotice: approvalRecovery,
                hasCompletion: completion
            )
        }

        XCTAssertEqual(
            state(
                permission: true,
                processing: true,
                approvalRecovery: true,
                completion: true
            ),
            .permission
        )
        XCTAssertEqual(
            state(processing: true, approvalRecovery: true, completion: true),
            .processing
        )
        XCTAssertEqual(
            state(approvalRecovery: true, completion: true),
            .approvalRecovery
        )
        XCTAssertEqual(state(completion: true), .completion)
        XCTAssertEqual(state(), .idle)
    }

    func testDeferredHoverCannotReplaceAlreadyOpenedClickPresentation() async {
        XCTAssertFalse(
            NotchViewModel.shouldPerformDeferredHoverOpen(
                isHovering: true,
                status: .opened,
                expandOnHover: true
            )
        )
    }

    func testDeferredHoverRequiresPointerAndPreference() async {
        XCTAssertFalse(
            NotchViewModel.shouldPerformDeferredHoverOpen(
                isHovering: false,
                status: .closed,
                expandOnHover: true
            )
        )
        XCTAssertFalse(
            NotchViewModel.shouldPerformDeferredHoverOpen(
                isHovering: true,
                status: .closed,
                expandOnHover: false
            )
        )
        XCTAssertTrue(
            NotchViewModel.shouldPerformDeferredHoverOpen(
                isHovering: true,
                status: .closed,
                expandOnHover: true
            )
        )
    }

    func testSupersededPointerTransitionCannotRunAfterPointerReturns() async {
        XCTAssertTrue(
            NotchViewModel.isCurrentPointerTransition(
                scheduledGeneration: 4,
                currentGeneration: 4
            )
        )
        XCTAssertFalse(
            NotchViewModel.isCurrentPointerTransition(
                scheduledGeneration: 4,
                currentGeneration: 6
            )
        )
    }

    func testQueuedStatusDeliveryCannotTargetANewerPresentation() {
        let staleOpen = NotchStatusDelivery(
            status: .opened,
            presentationGeneration: 4
        )

        // A status-only check would accept this callback after a quick
        // close/reopen because both the old and new values are `.opened`.
        XCTAssertFalse(staleOpen.matchesCurrentPresentation(
            status: .opened,
            generation: 5
        ))
        XCTAssertFalse(staleOpen.matchesCurrentPresentation(
            status: .closed,
            generation: 4
        ))
        XCTAssertTrue(staleOpen.matchesCurrentPresentation(
            status: .opened,
            generation: 4
        ))
    }

    func testMouseLeaveOnlyCollapsesHoverOwnedPresentation() async {
        XCTAssertTrue(
            NotchViewModel.shouldAutoCollapseOnPointerExit(
                isHovering: false,
                status: .opened,
                openReason: .hover,
                collapseOnMouseLeave: true
            )
        )
        XCTAssertFalse(
            NotchViewModel.shouldAutoCollapseOnPointerExit(
                isHovering: false,
                status: .opened,
                openReason: .click,
                collapseOnMouseLeave: true
            )
        )
        XCTAssertFalse(
            NotchViewModel.shouldAutoCollapseOnPointerExit(
                isHovering: false,
                status: .opened,
                openReason: .notification,
                collapseOnMouseLeave: true
            )
        )
        XCTAssertFalse(
            NotchViewModel.shouldAutoCollapseOnPointerExit(
                isHovering: true,
                status: .opened,
                openReason: .hover,
                collapseOnMouseLeave: true
            )
        )
    }

    func testInteractionClaimsAnAlreadyHoverOpenedPanel() async {
        let viewModel = makeViewModel()
        viewModel.status = .opened
        viewModel.openReason = .hover

        viewModel.claimOpenedPanelInteraction()

        XCTAssertEqual(viewModel.status, .opened)
        XCTAssertEqual(viewModel.openReason, .click)
        XCTAssertFalse(
            NotchViewModel.shouldAutoCollapseOnPointerExit(
                isHovering: false,
                status: viewModel.status,
                openReason: viewModel.openReason,
                collapseOnMouseLeave: true
            )
        )
    }

    func testCompletionIdentityIgnoresMutableProcessMetadata() async {
        let completedAt = Date()
        let first = SessionState(
            sessionId: "completion-generation",
            cwd: "/tmp/project",
            pid: 111,
            phase: .waitingForInput,
            completedAt: completedAt
        )
        let refreshed = SessionState(
            sessionId: "completion-generation",
            cwd: "/tmp/project",
            pid: 222,
            phase: .waitingForInput,
            completedAt: completedAt
        )

        XCTAssertEqual(
            NotchAttentionPolicy.completionToken(for: first),
            NotchAttentionPolicy.completionToken(for: refreshed)
        )
    }

    func testNewCompletionBoundaryCreatesNewAttentionGeneration() async throws {
        let first = SessionState(
            sessionId: "rapid-next-turn",
            cwd: "/tmp/project",
            phase: .waitingForInput,
            completedAt: Date(timeIntervalSince1970: 100)
        )
        let second = SessionState(
            sessionId: "rapid-next-turn",
            cwd: "/tmp/project",
            phase: .waitingForInput,
            completedAt: Date(timeIntervalSince1970: 101)
        )

        XCTAssertNotEqual(
            try XCTUnwrap(NotchAttentionPolicy.completionToken(for: first)),
            try XCTUnwrap(NotchAttentionPolicy.completionToken(for: second))
        )
    }

    func testCompletionPresentationRejectsStartupHistoryAndExpiredEvents() async {
        let presentationStartedAt = Date(timeIntervalSince1970: 100)
        let oldToken = NotchCompletionToken(
            sessionId: "old",
            completedAt: Date(timeIntervalSince1970: 99)
        )
        let expiredToken = NotchCompletionToken(
            sessionId: "expired",
            completedAt: Date(timeIntervalSince1970: 101)
        )
        let freshToken = NotchCompletionToken(
            sessionId: "fresh",
            completedAt: Date(timeIntervalSince1970: 109)
        )

        XCTAssertFalse(NotchAttentionPolicy.shouldPresent(
            oldToken,
            presentationStartedAt: presentationStartedAt,
            duration: 8,
            now: Date(timeIntervalSince1970: 102)
        ))
        XCTAssertFalse(NotchAttentionPolicy.shouldPresent(
            expiredToken,
            presentationStartedAt: presentationStartedAt,
            duration: 8,
            now: Date(timeIntervalSince1970: 110)
        ))
        XCTAssertTrue(NotchAttentionPolicy.shouldPresent(
            freshToken,
            presentationStartedAt: presentationStartedAt,
            duration: 8,
            now: Date(timeIntervalSince1970: 110)
        ))
    }

    func testSoundRevalidationRejectsSupersededCompletion() async throws {
        let completedAt = Date()
        let token = NotchCompletionToken(
            sessionId: "sound-race",
            completedAt: completedAt
        )
        let completed = SessionState(
            sessionId: token.sessionId,
            cwd: "/tmp/project",
            phase: .waitingForInput,
            completedAt: completedAt
        )
        let resumed = SessionState(
            sessionId: token.sessionId,
            cwd: "/tmp/project",
            phase: .processing,
            completedAt: nil
        )

        XCTAssertTrue(NotchAttentionPolicy.isStillCurrent(
            token,
            in: [completed]
        ))
        XCTAssertFalse(NotchAttentionPolicy.isStillCurrent(
            token,
            in: [resumed]
        ))
    }

    func testInteractionIdentityIncludesSession() async throws {
        let context = PermissionContext(
            toolUseId: "shared-tool-id",
            toolName: "Bash",
            toolInput: nil,
            receivedAt: Date()
        )
        let first = SessionState(
            sessionId: "session-a",
            cwd: "/tmp/a",
            phase: .waitingForApproval(context)
        )
        let second = SessionState(
            sessionId: "session-b",
            cwd: "/tmp/b",
            phase: .waitingForApproval(context)
        )

        XCTAssertNotEqual(
            try XCTUnwrap(NotchAttentionPolicy.interactionToken(for: first)),
            try XCTUnwrap(NotchAttentionPolicy.interactionToken(for: second))
        )
    }

    func testCompactQuestionModeDoesNotSuppressApprovalsOrPlans() async {
        func context(_ toolName: String) -> PermissionContext {
            PermissionContext(
                toolUseId: toolName,
                toolName: toolName,
                toolInput: nil,
                receivedAt: Date()
            )
        }

        XCTAssertFalse(NotchAttentionPolicy.shouldAutoExpandInteraction(
            context("AskUserQuestion"),
            expandQuestionsAutomatically: false
        ))
        XCTAssertTrue(NotchAttentionPolicy.shouldAutoExpandInteraction(
            context("AskUserQuestion"),
            expandQuestionsAutomatically: true
        ))
        XCTAssertFalse(NotchAttentionPolicy.shouldAutoExpandInteraction(
            context(CodexUserInputRequest.toolName),
            expandQuestionsAutomatically: false
        ))
        XCTAssertTrue(NotchAttentionPolicy.shouldAutoExpandInteraction(
            context(CodexUserInputRequest.toolName),
            expandQuestionsAutomatically: true
        ))
        XCTAssertTrue(NotchAttentionPolicy.shouldAutoExpandInteraction(
            context("Bash"),
            expandQuestionsAutomatically: false
        ))
        XCTAssertTrue(NotchAttentionPolicy.shouldAutoExpandInteraction(
            context("ExitPlanMode"),
            expandQuestionsAutomatically: false
        ))
    }

    func testCompactQuestionCannotMaskApprovalInSameUpdate() async throws {
        func session(
            id: String,
            toolUseId: String,
            toolName: String,
            lastActivity: Date
        ) -> SessionState {
            SessionState(
                sessionId: id,
                cwd: "/tmp/\(id)",
                phase: .waitingForApproval(PermissionContext(
                    toolUseId: toolUseId,
                    toolName: toolName,
                    toolInput: nil,
                    receivedAt: lastActivity
                )),
                lastActivity: lastActivity
            )
        }

        let approval = session(
            id: "approval-session",
            toolUseId: "approval",
            toolName: "Bash",
            lastActivity: Date(timeIntervalSince1970: 100)
        )
        let newerQuestion = session(
            id: "question-session",
            toolUseId: "question",
            toolName: "AskUserQuestion",
            lastActivity: Date(timeIntervalSince1970: 101)
        )

        let selected = NotchAttentionPolicy.newestSessionToAutoExpand(
            from: [approval, newerQuestion],
            excluding: [],
            expandQuestionsAutomatically: false
        )
        XCTAssertEqual(try XCTUnwrap(selected).sessionId, approval.sessionId)

        XCTAssertNil(NotchAttentionPolicy.newestSessionToAutoExpand(
            from: [newerQuestion],
            excluding: [],
            expandQuestionsAutomatically: false
        ))
    }

    func testCompletionDoesNotCollapseNotificationPanelWithPendingInteraction() async {
        func interactionSession(id: String, toolName: String) -> SessionState {
            SessionState(
                sessionId: id,
                cwd: "/tmp/\(id)",
                phase: .waitingForApproval(PermissionContext(
                    toolUseId: "tool-\(id)",
                    toolName: toolName,
                    toolInput: nil,
                    receivedAt: Date()
                ))
            )
        }

        let approval = interactionSession(id: "approval", toolName: "Bash")
        let question = interactionSession(
            id: "question",
            toolName: "AskUserQuestion"
        )
        let idle = SessionState(
            sessionId: "idle",
            cwd: "/tmp/idle",
            phase: .idle
        )

        XCTAssertTrue(NotchAttentionPolicy.hasPendingAutoExpandedInteraction(
            in: [approval],
            expandQuestionsAutomatically: false
        ))
        XCTAssertFalse(NotchAttentionPolicy.hasPendingAutoExpandedInteraction(
            in: [question],
            expandQuestionsAutomatically: false
        ))
        XCTAssertTrue(NotchAttentionPolicy.hasPendingAutoExpandedInteraction(
            in: [question],
            expandQuestionsAutomatically: true
        ))
        XCTAssertFalse(NotchAttentionPolicy.hasPendingAutoExpandedInteraction(
            in: [idle],
            expandQuestionsAutomatically: true
        ))

        XCTAssertTrue(
            NotchAttentionPolicy.shouldCollapseNotificationPanelAfterCompletion(
                status: .opened,
                openReason: .notification,
                hasPendingAutoExpandedInteraction: false
            )
        )
        XCTAssertFalse(
            NotchAttentionPolicy.shouldCollapseNotificationPanelAfterCompletion(
                status: .opened,
                openReason: .notification,
                hasPendingAutoExpandedInteraction: true
            )
        )
        XCTAssertFalse(
            NotchAttentionPolicy.shouldCollapseNotificationPanelAfterCompletion(
                status: .opened,
                openReason: .click,
                hasPendingAutoExpandedInteraction: true
            )
        )
        XCTAssertFalse(
            NotchAttentionPolicy.shouldCollapseNotificationPanelAfterCompletion(
                status: .closed,
                openReason: .notification,
                hasPendingAutoExpandedInteraction: false
            )
        )
    }

    func testPresentationDeduplicationIsScopedToSession() async throws {
        let observedAt = Date()
        let sharedContext = PermissionContext(
            toolUseId: "shared-tool-id",
            toolName: "Bash",
            toolInput: nil,
            receivedAt: observedAt
        )
        let first = SessionState(
            sessionId: "session-a",
            cwd: "/tmp/a",
            phase: .waitingForApproval(sharedContext),
            lastActivity: observedAt
        )
        let second = SessionState(
            sessionId: "session-b",
            cwd: "/tmp/b",
            phase: .waitingForApproval(sharedContext),
            lastActivity: observedAt.addingTimeInterval(1)
        )
        let firstToken = try XCTUnwrap(
            NotchAttentionPolicy.interactionToken(for: first)
        )

        let selected = NotchAttentionPolicy.newestSessionToAutoExpand(
            from: [first, second],
            excluding: [firstToken],
            expandQuestionsAutomatically: true
        )
        XCTAssertEqual(try XCTUnwrap(selected).sessionId, second.sessionId)
    }
}
