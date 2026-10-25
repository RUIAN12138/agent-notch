//
//  Modified by lihao505 for Agent Notch, 2026.
//  LifecycleReducerTests.swift
//  ClaudeIslandTests
//

import XCTest
@testable import Agent_Notch

final class LifecycleReducerTests: XCTestCase {
    private let staleInterval: TimeInterval = 600
    private let missingGrace: TimeInterval = 30

    private func observation(
        _ evidence: LifecycleEvidence,
        observedAt: Date,
        receivedAt: Date,
        origin: LifecycleObservationOrigin = .codexPolling,
        requestedPhase: SessionPhase? = nil,
        hookEventName: String? = nil,
        source: AgentSource = .codex
    ) -> SessionLifecycleObservation {
        SessionLifecycleObservation(
            sessionId: "codex-session",
            cwd: "/tmp/project",
            source: source,
            origin: origin,
            evidence: evidence,
            requestedPhase: requestedPhase,
            hookEventName: hookEventName,
            observedAt: observedAt,
            receivedAt: receivedAt
        )
    }

    private func snapshot(
        phase: SessionPhase = .processing,
        lastActivity: Date,
        lastHookEventAt: Date? = nil,
        turnStartedAt: Date? = nil,
        codexToolExecutionStartedAt: Date? = nil,
        completedAt: Date? = nil,
        completionWasStaleTimeout: Bool = false,
        source: AgentSource = .codex
    ) -> SessionLifecycleSnapshot {
        SessionLifecycleSnapshot(
            source: source,
            phase: phase,
            lastActivity: lastActivity,
            createdAt: lastActivity,
            lastHookEventAt: lastHookEventAt,
            turnStartedAt: turnStartedAt,
            codexToolExecutionStartedAt: codexToolExecutionStartedAt,
            completedAt: completedAt,
            completionWasStaleTimeout: completionWasStaleTimeout
        )
    }

    private func reduce(
        current: SessionLifecycleSnapshot?,
        observation: SessionLifecycleObservation,
        allowCreation: Bool = false
    ) -> LifecycleTransition {
        LifecycleReducer.reduce(
            current: current,
            observation: observation,
            allowCreation: allowCreation,
            activeStaleInterval: staleInterval,
            missingGracePeriod: missingGrace
        )
    }

    func testFreshDiscoveryCreatesProcessingGeneration() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let startedAt = now.addingTimeInterval(-2)
        let transition = reduce(
            current: nil,
            observation: observation(
                .active(
                    turnStartedAt: startedAt,
                    lastEvidenceAt: now.addingTimeInterval(-1)
                ),
                observedAt: now,
                receivedAt: now,
                origin: .codexDiscovery
            ),
            allowCreation: true
        )

        XCTAssertEqual(transition.reason, .discoveredActiveTurn)
        guard case .create(let next) = transition.mutation else {
            return XCTFail("Expected a created lifecycle snapshot")
        }
        XCTAssertEqual(next.phase, .processing)
        XCTAssertEqual(next.turnStartedAt, startedAt)
        XCTAssertNil(next.completedAt)
    }

    func testInFlightCodexToolSurvivesColdStartAndUsesBoundedTimeout() throws {
        let now = Date(timeIntervalSince1970: 20_000)
        let toolStartedAt = now.addingTimeInterval(-20 * 60)
        let turnStartedAt = toolStartedAt.addingTimeInterval(-30)
        let discovery = reduce(
            current: nil,
            observation: observation(
                .activeTool(
                    turnStartedAt: turnStartedAt,
                    lastEvidenceAt: toolStartedAt,
                    toolStartedAt: toolStartedAt
                ),
                observedAt: toolStartedAt,
                receivedAt: now,
                origin: .codexDiscovery
            ),
            allowCreation: true
        )

        guard case .create(let active) = discovery.mutation else {
            return XCTFail("A recent unresolved tool call should restore as working")
        }
        XCTAssertEqual(active.phase, .processing)
        XCTAssertEqual(active.codexToolExecutionStartedAt, toolStartedAt)

        let stillRunning = reduce(
            current: active,
            observation: observation(
                .active(
                    turnStartedAt: turnStartedAt,
                    lastEvidenceAt: toolStartedAt
                ),
                observedAt: toolStartedAt,
                receivedAt: now.addingTimeInterval(30 * 60),
                origin: .transcript
            )
        )
        XCTAssertEqual(stillRunning.reason, .alreadyCurrent)
        XCTAssertEqual(stillRunning.mutation, .none)
        XCTAssertEqual(active.phase, .processing)

        let timedOut = reduce(
            current: active,
            observation: observation(
                .active(
                    turnStartedAt: turnStartedAt,
                    lastEvidenceAt: toolStartedAt
                ),
                observedAt: toolStartedAt,
                receivedAt: now.addingTimeInterval(
                    LifecycleReducer.codexToolExecutionStaleInterval + 1
                ),
                origin: .transcript
            )
        )
        XCTAssertEqual(timedOut.reason, .staleActiveTimedOut)
        XCTAssertEqual(timedOut.nextSnapshot?.phase, .waitingForInput)
        XCTAssertNil(timedOut.nextSnapshot?.codexToolExecutionStartedAt)
    }

    func testRecentEvidenceRefreshesLongRunningCodexToolTimeout() throws {
        let now = Date(timeIntervalSince1970: 40_000)
        let toolStartedAt = now.addingTimeInterval(-70 * 60)
        let turnStartedAt = toolStartedAt.addingTimeInterval(-30)
        let lastEvidenceAt = now.addingTimeInterval(-5 * 60)
        let current = snapshot(
            lastActivity: toolStartedAt,
            turnStartedAt: turnStartedAt,
            codexToolExecutionStartedAt: toolStartedAt
        )

        let transition = reduce(
            current: current,
            observation: observation(
                .activeTool(
                    turnStartedAt: turnStartedAt,
                    lastEvidenceAt: lastEvidenceAt,
                    toolStartedAt: toolStartedAt
                ),
                observedAt: lastEvidenceAt,
                receivedAt: now
            )
        )

        XCTAssertEqual(transition.reason, .activeTurnAdvanced)
        guard case .update(let next) = transition.mutation else {
            return XCTFail("Recent rollout evidence should refresh the active tool")
        }
        XCTAssertEqual(next.phase, .processing)
        XCTAssertEqual(next.lastActivity, lastEvidenceAt)
        XCTAssertEqual(next.codexToolExecutionStartedAt, toolStartedAt)
    }

    func testDurableRunningToolReopensSessionPreviouslyTimedOutAsStale() throws {
        let toolStartedAt = Date(timeIntervalSince1970: 30_000)
        let staleCompletionAt = toolStartedAt.addingTimeInterval(10 * 60)
        let resumedAt = toolStartedAt.addingTimeInterval(20 * 60)
        let staleTimeout = reduce(
            current: snapshot(
                lastActivity: toolStartedAt,
                turnStartedAt: toolStartedAt.addingTimeInterval(-30)
            ),
            observation: observation(
                .active(
                    turnStartedAt: toolStartedAt.addingTimeInterval(-30),
                    lastEvidenceAt: toolStartedAt
                ),
                observedAt: toolStartedAt,
                receivedAt: staleCompletionAt
            )
        )
        XCTAssertEqual(staleTimeout.reason, .staleActiveTimedOut)
        let current = try XCTUnwrap(staleTimeout.nextSnapshot)
        XCTAssertEqual(current.completedAt, staleCompletionAt)
        XCTAssertTrue(current.completionWasStaleTimeout)

        let resumed = reduce(
            current: current,
            observation: observation(
                .activeTool(
                    turnStartedAt: toolStartedAt.addingTimeInterval(-30),
                    lastEvidenceAt: toolStartedAt,
                    toolStartedAt: toolStartedAt
                ),
                observedAt: toolStartedAt,
                receivedAt: resumedAt
            )
        )

        XCTAssertEqual(resumed.reason, .activeToolReopenedStaleSession)
        guard case .update(let next) = resumed.mutation else {
            return XCTFail("The durable in-flight tool should restore working state")
        }
        XCTAssertEqual(next.phase, .processing)
        XCTAssertNil(next.completedAt)
        XCTAssertFalse(next.completionWasStaleTimeout)
        XCTAssertEqual(next.codexToolExecutionStartedAt, toolStartedAt)
    }

    func testPriorUnmatchedToolCannotReopenAuthoritativelyCompletedTurn() throws {
        let turnStartedAt = Date(timeIntervalSince1970: 31_000)
        let toolStartedAt = turnStartedAt.addingTimeInterval(2)
        let completedAt = toolStartedAt.addingTimeInterval(8)
        let completed = reduce(
            current: snapshot(
                lastActivity: turnStartedAt,
                turnStartedAt: turnStartedAt
            ),
            observation: observation(
                .completed(completedAt),
                observedAt: completedAt,
                receivedAt: completedAt
            )
        )
        let current = try XCTUnwrap(completed.nextSnapshot)

        let delayedToolSnapshot = reduce(
            current: current,
            observation: observation(
                .activeTool(
                    turnStartedAt: turnStartedAt,
                    lastEvidenceAt: completedAt.addingTimeInterval(1),
                    toolStartedAt: toolStartedAt
                ),
                observedAt: completedAt.addingTimeInterval(1),
                receivedAt: completedAt.addingTimeInterval(2)
            )
        )

        XCTAssertEqual(delayedToolSnapshot.reason, .activeWithoutNewGeneration)
        XCTAssertEqual(delayedToolSnapshot.mutation, .none)
        XCTAssertFalse(current.completionWasStaleTimeout)
    }

    func testNativeCompletionPromotesEarlierStaleTimeoutToConfirmedBoundary() throws {
        let turnStartedAt = Date(timeIntervalSince1970: 32_000)
        let staleAt = turnStartedAt.addingTimeInterval(10 * 60)
        let actualCompletionAt = turnStartedAt.addingTimeInterval(5 * 60)
        let timedOut = reduce(
            current: snapshot(lastActivity: turnStartedAt, turnStartedAt: turnStartedAt),
            observation: observation(
                .active(
                    turnStartedAt: turnStartedAt,
                    lastEvidenceAt: turnStartedAt
                ),
                observedAt: turnStartedAt,
                receivedAt: staleAt
            )
        )
        let staleSnapshot = try XCTUnwrap(timedOut.nextSnapshot)

        let confirmed = reduce(
            current: staleSnapshot,
            observation: observation(
                .completed(actualCompletionAt),
                observedAt: actualCompletionAt,
                receivedAt: staleAt.addingTimeInterval(1)
            )
        )

        XCTAssertEqual(confirmed.reason, .nativeCompletion)
        XCTAssertFalse(try XCTUnwrap(confirmed.nextSnapshot).completionWasStaleTimeout)

        let delayedTool = reduce(
            current: try XCTUnwrap(confirmed.nextSnapshot),
            observation: observation(
                .activeTool(
                    turnStartedAt: turnStartedAt,
                    lastEvidenceAt: actualCompletionAt.addingTimeInterval(1),
                    toolStartedAt: turnStartedAt.addingTimeInterval(1)
                ),
                observedAt: actualCompletionAt.addingTimeInterval(1),
                receivedAt: staleAt.addingTimeInterval(2)
            )
        )
        XCTAssertEqual(delayedTool.reason, .activeWithoutNewGeneration)
        XCTAssertEqual(delayedTool.mutation, .none)
    }

    func testStaleDiscoveryCannotCreatePhantomWorkingCard() {
        let now = Date(timeIntervalSince1970: 2_000)
        let transition = reduce(
            current: nil,
            observation: observation(
                .active(
                    turnStartedAt: now.addingTimeInterval(-601),
                    lastEvidenceAt: nil
                ),
                observedAt: now.addingTimeInterval(-601),
                receivedAt: now,
                origin: .codexDiscovery
            ),
            allowCreation: true
        )

        XCTAssertEqual(transition.mutation, .none)
        XCTAssertEqual(transition.reason, .staleDiscovery)
    }

    func testCompletedTurnRequiresNewerGenerationToResume() throws {
        let completedAt = Date(timeIntervalSince1970: 3_000)
        let current = snapshot(
            phase: .waitingForInput,
            lastActivity: completedAt,
            turnStartedAt: completedAt.addingTimeInterval(-10),
            completedAt: completedAt
        )

        let delayedEvidence = reduce(
            current: current,
            observation: observation(
                .active(
                    turnStartedAt: completedAt.addingTimeInterval(-10),
                    lastEvidenceAt: completedAt.addingTimeInterval(1)
                ),
                observedAt: completedAt.addingTimeInterval(1),
                receivedAt: completedAt.addingTimeInterval(2)
            )
        )
        XCTAssertEqual(delayedEvidence.mutation, .none)
        XCTAssertEqual(delayedEvidence.reason, .activeWithoutNewGeneration)

        let nextTurnAt = completedAt.addingTimeInterval(3)
        let resumed = reduce(
            current: current,
            observation: observation(
                .active(
                    turnStartedAt: nextTurnAt,
                    lastEvidenceAt: nextTurnAt
                ),
                observedAt: nextTurnAt,
                receivedAt: nextTurnAt
            )
        )
        XCTAssertEqual(resumed.reason, .newerTurnStarted)
        guard case .update(let next) = resumed.mutation else {
            return XCTFail("Expected the new generation to resume")
        }
        XCTAssertEqual(next.phase, .processing)
        XCTAssertEqual(next.turnStartedAt, nextTurnAt)
        XCTAssertNil(next.completedAt)
    }

    func testLateCompletionCannotCrossNewerHookBoundary() {
        let now = Date(timeIntervalSince1970: 4_000)
        let current = snapshot(
            lastActivity: now,
            lastHookEventAt: now,
            turnStartedAt: now
        )
        let transition = reduce(
            current: current,
            observation: observation(
                .completed(now.addingTimeInterval(-1)),
                observedAt: now,
                receivedAt: now
            )
        )

        XCTAssertEqual(transition.mutation, .none)
        XCTAssertEqual(transition.reason, .completionOlderThanHook)
    }

    func testLateCompletionCannotCrossNewerNativeTurnBoundary() {
        let now = Date(timeIntervalSince1970: 5_000)
        let current = snapshot(
            lastActivity: now,
            turnStartedAt: now
        )
        let transition = reduce(
            current: current,
            observation: observation(
                .completed(now.addingTimeInterval(-1)),
                observedAt: now,
                receivedAt: now
            )
        )

        XCTAssertEqual(transition.mutation, .none)
        XCTAssertEqual(transition.reason, .completionOlderThanTurn)
    }

    func testNativeCompletionProducesExactBoundary() throws {
        let startedAt = Date(timeIntervalSince1970: 6_000)
        let completedAt = startedAt.addingTimeInterval(5)
        let transition = reduce(
            current: snapshot(
                lastActivity: startedAt,
                turnStartedAt: startedAt
            ),
            observation: observation(
                .completed(completedAt),
                observedAt: completedAt,
                receivedAt: completedAt.addingTimeInterval(1)
            )
        )

        XCTAssertEqual(transition.reason, .nativeCompletion)
        guard case .update(let next) = transition.mutation else {
            return XCTFail("Expected a completed snapshot")
        }
        XCTAssertEqual(next.phase, .waitingForInput)
        XCTAssertEqual(next.completedAt, completedAt)
        XCTAssertEqual(next.lastActivity, completedAt)
        XCTAssertFalse(next.completionWasStaleTimeout)
    }

    func testPendingInteractionKeepsPriorityWhileActivityMetadataAdvances() throws {
        let requestAt = Date(timeIntervalSince1970: 7_000)
        let context = PermissionContext(
            toolUseId: "approval",
            toolName: "Bash",
            toolInput: nil,
            receivedAt: requestAt
        )
        let evidenceAt = requestAt.addingTimeInterval(1)
        let transition = reduce(
            current: snapshot(
                phase: .waitingForApproval(context),
                lastActivity: requestAt,
                turnStartedAt: requestAt
            ),
            observation: observation(
                .active(
                    turnStartedAt: requestAt,
                    lastEvidenceAt: evidenceAt
                ),
                observedAt: evidenceAt,
                receivedAt: evidenceAt
            )
        )

        XCTAssertEqual(transition.reason, .interactionHasPriority)
        guard case .update(let next) = transition.mutation else {
            return XCTFail("Expected metadata to advance")
        }
        XCTAssertEqual(next.phase, .waitingForApproval(context))
        XCTAssertEqual(next.lastActivity, evidenceAt)
    }

    func testStaleActiveAndUnknownEvidenceStopInfiniteWorkingState() throws {
        let lastActivity = Date(timeIntervalSince1970: 8_000)
        let now = lastActivity.addingTimeInterval(600)
        let current = snapshot(
            lastActivity: lastActivity,
            turnStartedAt: lastActivity
        )

        let staleActive = reduce(
            current: current,
            observation: observation(
                .active(
                    turnStartedAt: lastActivity,
                    lastEvidenceAt: lastActivity
                ),
                observedAt: lastActivity,
                receivedAt: now
            )
        )
        XCTAssertEqual(staleActive.reason, .staleActiveTimedOut)
        guard case .update(let staleNext) = staleActive.mutation else {
            return XCTFail("Expected stale active state to complete")
        }
        XCTAssertEqual(staleNext.phase, .waitingForInput)
        XCTAssertEqual(staleNext.completedAt, now)
        XCTAssertTrue(staleNext.completionWasStaleTimeout)

        let unknown = reduce(
            current: current,
            observation: observation(
                .unknown,
                observedAt: now,
                receivedAt: now
            )
        )
        XCTAssertEqual(unknown.reason, .unknownActiveTimedOut)
        guard case .update(let unknownNext) = unknown.mutation else {
            return XCTFail("Expected unknown stale state to complete")
        }
        XCTAssertEqual(unknownNext.phase, .waitingForInput)
        XCTAssertEqual(unknownNext.completedAt, now)
        XCTAssertTrue(unknownNext.completionWasStaleTimeout)
    }

    func testMissingSourceHonorsGraceBeforeRemoval() {
        let lastActivity = Date(timeIntervalSince1970: 9_000)
        let current = snapshot(lastActivity: lastActivity)

        let withinGrace = reduce(
            current: current,
            observation: observation(
                .missing,
                observedAt: lastActivity.addingTimeInterval(10),
                receivedAt: lastActivity.addingTimeInterval(29)
            )
        )
        XCTAssertEqual(withinGrace.mutation, .none)
        XCTAssertEqual(withinGrace.reason, .missingWithinGrace)

        let expired = reduce(
            current: current,
            observation: observation(
                .missing,
                observedAt: lastActivity.addingTimeInterval(31),
                receivedAt: lastActivity.addingTimeInterval(30)
            )
        )
        XCTAssertEqual(expired.mutation, .remove)
        XCTAssertEqual(expired.reason, .sourceMissingBeyondGrace)
    }

    func testTraceCapturesDecisionWithoutConversationContent() {
        let now = Date(timeIntervalSince1970: 10_000)
        let current = snapshot(lastActivity: now)
        let source = observation(
            .completed(now),
            observedAt: now,
            receivedAt: now,
            origin: .codexDiscovery
        )
        let transition = reduce(current: current, observation: source)
        let trace = LifecycleTraceEntry(
            observation: source,
            previous: current,
            transition: transition
        )

        XCTAssertEqual(trace.origin, .codexDiscovery)
        XCTAssertEqual(trace.reason, .nativeCompletion)
        XCTAssertTrue(trace.didMutate)
        XCTAssertEqual(trace.previousPhase, .processing)
        XCTAssertEqual(trace.nextPhase, .waitingForInput)
    }

    func testLateHookActivityCannotReviveNativeCompletion() {
        let completedAt = Date(timeIntervalSince1970: 11_000)
        let current = snapshot(
            phase: .waitingForInput,
            lastActivity: completedAt,
            lastHookEventAt: completedAt.addingTimeInterval(-5),
            turnStartedAt: completedAt.addingTimeInterval(-10),
            completedAt: completedAt
        )

        for observedAt in [
            completedAt.addingTimeInterval(-1),
            completedAt
        ] {
            let transition = reduce(
                current: current,
                observation: observation(
                    .hook(.active),
                    observedAt: observedAt,
                    receivedAt: completedAt.addingTimeInterval(1),
                    origin: .hook,
                    requestedPhase: .processing
                )
            )
            XCTAssertEqual(transition.mutation, .none)
            XCTAssertEqual(
                transition.reason,
                .activeWithoutNewGeneration
            )
            XCTAssertFalse(transition.acceptsObservation)
        }
    }

    func testNewerHookActivityResumesCompletedSession() throws {
        let completedAt = Date(timeIntervalSince1970: 12_000)
        let resumedAt = completedAt.addingTimeInterval(1)
        let current = snapshot(
            phase: .waitingForInput,
            lastActivity: completedAt,
            lastHookEventAt: completedAt.addingTimeInterval(-5),
            turnStartedAt: completedAt.addingTimeInterval(-10),
            completedAt: completedAt
        )
        let transition = reduce(
            current: current,
            observation: observation(
                .hook(.active),
                observedAt: resumedAt,
                receivedAt: resumedAt,
                origin: .hook,
                requestedPhase: .processing
            )
        )

        XCTAssertEqual(transition.reason, .hookPhaseAdvanced)
        XCTAssertTrue(transition.acceptsObservation)
        guard case .update(let next) = transition.mutation else {
            return XCTFail("Expected the fresh hook to resume processing")
        }
        XCTAssertEqual(next.phase, .processing)
        XCTAssertEqual(next.lastHookEventAt, resumedAt)
        XCTAssertNil(next.completedAt)
    }

    func testAuthoritativeHookCompletionClosesPendingInteraction() throws {
        let requestAt = Date(timeIntervalSince1970: 13_000)
        let completionAt = requestAt.addingTimeInterval(2)
        let context = PermissionContext(
            toolUseId: "approval",
            toolName: "Bash",
            toolInput: ["command": AnyCodable("secret command")],
            receivedAt: requestAt
        )
        let transition = reduce(
            current: snapshot(
                phase: .waitingForApproval(context),
                lastActivity: requestAt,
                lastHookEventAt: requestAt,
                turnStartedAt: requestAt.addingTimeInterval(-1)
            ),
            observation: observation(
                .hook(.completed),
                observedAt: completionAt,
                receivedAt: completionAt,
                origin: .hook,
                requestedPhase: .waitingForInput
            )
        )

        XCTAssertEqual(transition.reason, .hookCompletion)
        guard case .update(let next) = transition.mutation else {
            return XCTFail("Expected Stop to close the interaction")
        }
        XCTAssertEqual(next.phase, .waitingForInput)
        XCTAssertEqual(next.completedAt, completionAt)
    }

    func testLaterCompletionHooksPreserveFirstTerminalBoundary() throws {
        let completedAt = Date(timeIntervalSince1970: 13_500)
        var current = snapshot(
            phase: .waitingForInput,
            lastActivity: completedAt,
            lastHookEventAt: completedAt,
            turnStartedAt: completedAt.addingTimeInterval(-10),
            completedAt: completedAt
        )
        for (offset, event) in [(60.0, "Notification"), (120.0, "Stop")] {
            let observedAt = completedAt.addingTimeInterval(offset)
            let transition = reduce(
                current: current,
                observation: SessionLifecycleObservation(
                    sessionId: "codex-session", cwd: "/tmp/project",
                    source: .codex, origin: .hook,
                    evidence: .hook(.completed),
                    requestedPhase: .waitingForInput, hookEventName: event,
                    observedAt: observedAt, receivedAt: observedAt
                )
            )
            guard case .update(let next) = transition.mutation else {
                return XCTFail("Expected fresh hook ordering metadata")
            }
            XCTAssertEqual(next.completedAt, completedAt)
            XCTAssertEqual(next.lastHookEventAt, observedAt)
            XCTAssertEqual(next.lastActivity, observedAt)
            XCTAssertEqual(next.phase, .waitingForInput)
            current = next
        }
    }

    func testStopAfterTranscriptCompletionPreservesTerminalBoundary() throws {
        let completedAt = Date(timeIntervalSince1970: 13_600)
        let stopAt = completedAt.addingTimeInterval(2)
        let transition = reduce(
            current: snapshot(
                phase: .waitingForInput,
                lastActivity: completedAt,
                lastHookEventAt: completedAt.addingTimeInterval(-3),
                completedAt: completedAt
            ),
            observation: observation(
                .hook(.completed), observedAt: stopAt, receivedAt: stopAt,
                origin: .hook, requestedPhase: .waitingForInput
            )
        )
        guard case .update(let next) = transition.mutation else {
            return XCTFail("Expected fresh Stop metadata")
        }
        XCTAssertEqual(next.completedAt, completedAt)
        XCTAssertEqual(next.lastHookEventAt, stopAt)
    }

    func testHookRemovalCannotCrossNewerLifecycleBoundary() {
        let activeAt = Date(timeIntervalSince1970: 14_000)
        let current = snapshot(
            lastActivity: activeAt,
            lastHookEventAt: activeAt,
            turnStartedAt: activeAt
        )
        let staleRemoval = reduce(
            current: current,
            observation: observation(
                .hook(.removed),
                observedAt: activeAt.addingTimeInterval(-1),
                receivedAt: activeAt,
                origin: .hook,
                requestedPhase: .ended
            )
        )
        XCTAssertEqual(staleRemoval.mutation, .none)
        XCTAssertEqual(staleRemoval.reason, .hookOlderThanBoundary)

        let freshRemovalAt = activeAt.addingTimeInterval(1)
        let freshRemoval = reduce(
            current: current,
            observation: observation(
                .hook(.removed),
                observedAt: freshRemovalAt,
                receivedAt: freshRemovalAt,
                origin: .hook,
                requestedPhase: .ended
            )
        )
        XCTAssertEqual(freshRemoval.mutation, .remove)
        XCTAssertEqual(freshRemoval.reason, .hookSessionRemoved)
    }

    func testTraceRedactsPermissionContextAndToolInput() {
        let now = Date(timeIntervalSince1970: 15_000)
        let secret = "do-not-retain-this-command"
        let context = PermissionContext(
            toolUseId: "approval",
            toolName: "Bash",
            toolInput: ["command": AnyCodable(secret)],
            receivedAt: now
        )
        let current = snapshot(
            phase: .waitingForApproval(context),
            lastActivity: now,
            lastHookEventAt: now
        )
        let source = observation(
            .hook(.active),
            observedAt: now,
            receivedAt: now,
            origin: .hook,
            requestedPhase: .processing
        )
        let transition = reduce(current: current, observation: source)
        let trace = LifecycleTraceEntry(
            observation: source,
            previous: current,
            transition: transition
        )

        XCTAssertEqual(trace.previousPhase, .waitingForApproval)
        XCTAssertEqual(trace.nextPhase, .waitingForApproval)
        XCTAssertFalse(String(reflecting: trace).contains(secret))
    }

    func testOlderActiveEvidenceCannotRegressTurnBoundary() throws {
        let currentTurnAt = Date(timeIntervalSince1970: 16_000)
        let evidenceAt = currentTurnAt.addingTimeInterval(2)
        let transition = reduce(
            current: snapshot(
                lastActivity: currentTurnAt,
                turnStartedAt: currentTurnAt
            ),
            observation: observation(
                .active(
                    turnStartedAt: currentTurnAt.addingTimeInterval(-10),
                    lastEvidenceAt: evidenceAt
                ),
                observedAt: evidenceAt,
                receivedAt: evidenceAt,
                origin: .transcript
            )
        )

        guard case .update(let next) = transition.mutation else {
            return XCTFail("Expected newer activity metadata to advance")
        }
        XCTAssertEqual(next.lastActivity, evidenceAt)
        XCTAssertEqual(next.turnStartedAt, currentTurnAt)
    }

    func testActiveEvidenceCannotCrossNewerLocalBoundary() {
        let evidenceAt = Date(timeIntervalSince1970: 17_000)
        let localBoundaryAt = evidenceAt.addingTimeInterval(1)
        let transition = reduce(
            current: snapshot(
                phase: .idle,
                lastActivity: localBoundaryAt,
                lastHookEventAt: localBoundaryAt
            ),
            observation: observation(
                .active(
                    turnStartedAt: evidenceAt,
                    lastEvidenceAt: evidenceAt
                ),
                observedAt: evidenceAt,
                receivedAt: localBoundaryAt,
                origin: .transcript
            )
        )

        XCTAssertEqual(transition.mutation, .none)
        XCTAssertEqual(transition.reason, .activeOlderThanHook)
        XCTAssertFalse(transition.acceptsObservation)
    }

    func testSocketFailurePreservesNewerHookActivity() throws {
        let failureAt = Date(timeIntervalSince1970: 18_000)
        let newerHookAt = failureAt.addingTimeInterval(1)
        let transition = reduce(
            current: snapshot(
                phase: .waitingForApproval(PermissionContext(
                    toolUseId: "failed-tool",
                    toolName: "Bash",
                    toolInput: nil,
                    receivedAt: failureAt.addingTimeInterval(-1)
                )),
                lastActivity: newerHookAt,
                lastHookEventAt: newerHookAt
            ),
            observation: observation(
                .interactionResolution(.deliveryFailed),
                observedAt: failureAt,
                receivedAt: newerHookAt,
                origin: .localInteraction,
                requestedPhase: .idle
            )
        )

        XCTAssertEqual(
            transition.reason,
            .localFailurePreservedNewerActivity
        )
        let next = try XCTUnwrap(transition.nextSnapshot)
        XCTAssertEqual(next.phase, .processing)
        XCTAssertEqual(next.lastHookEventAt, newerHookAt)
        XCTAssertNil(next.completedAt)
    }

    func testLocalResolutionCanAdvanceToNextQueuedInteraction() throws {
        let resolvedAt = Date(timeIntervalSince1970: 19_000)
        let nextPermission = PermissionContext(
            toolUseId: "next-tool",
            toolName: "Edit",
            toolInput: nil,
            receivedAt: resolvedAt
        )
        let transition = reduce(
            current: snapshot(
                phase: .processing,
                lastActivity: resolvedAt.addingTimeInterval(-1)
            ),
            observation: observation(
                .interactionResolution(.approved),
                observedAt: resolvedAt,
                receivedAt: resolvedAt,
                origin: .localInteraction,
                requestedPhase: .waitingForApproval(nextPermission)
            )
        )

        XCTAssertEqual(transition.reason, .interactionResolved)
        let next = try XCTUnwrap(transition.nextSnapshot)
        XCTAssertEqual(next.phase, .waitingForApproval(nextPermission))
        XCTAssertEqual(next.lastActivity, resolvedAt)
        XCTAssertEqual(next.lastHookEventAt, resolvedAt)
    }

    func testLocalResolutionCannotCrossNewerCompletion() {
        let resolvedAt = Date(timeIntervalSince1970: 20_000)
        let completedAt = resolvedAt.addingTimeInterval(1)
        let transition = reduce(
            current: snapshot(
                phase: .waitingForInput,
                lastActivity: completedAt,
                lastHookEventAt: completedAt,
                completedAt: completedAt
            ),
            observation: observation(
                .interactionResolution(.approved),
                observedAt: resolvedAt,
                receivedAt: completedAt,
                origin: .localInteraction,
                requestedPhase: .processing
            )
        )

        XCTAssertEqual(transition.mutation, .none)
        XCTAssertEqual(
            transition.reason,
            .interactionOlderThanCompletion
        )
        XCTAssertFalse(transition.acceptsObservation)
    }

    func testInterruptOlderThanHookBoundaryIsRejected() {
        let hookAt = Date(timeIntervalSince1970: 21_000)
        let transition = reduce(
            current: snapshot(
                lastActivity: hookAt,
                lastHookEventAt: hookAt
            ),
            observation: observation(
                .interrupt,
                observedAt: hookAt.addingTimeInterval(-1),
                receivedAt: hookAt,
                origin: .interruptWatcher
            )
        )

        XCTAssertEqual(transition.mutation, .none)
        XCTAssertEqual(transition.reason, .interruptOlderThanBoundary)
        XCTAssertFalse(transition.acceptsObservation)
    }

    func testInterruptOlderThanNativeTurnBoundaryIsRejected() {
        let turnStartedAt = Date(timeIntervalSince1970: 21_500)
        let transition = reduce(
            current: snapshot(
                lastActivity: turnStartedAt,
                turnStartedAt: turnStartedAt
            ),
            observation: observation(
                .interrupt,
                observedAt: turnStartedAt.addingTimeInterval(-1),
                receivedAt: turnStartedAt,
                origin: .interruptWatcher
            )
        )

        XCTAssertEqual(transition.mutation, .none)
        XCTAssertEqual(transition.reason, .interruptOlderThanBoundary)
        XCTAssertFalse(transition.acceptsObservation)
    }

    func testNativeInterruptionDismissesApprovalWithoutRecordingCompletion() throws {
        let startedAt = Date(timeIntervalSince1970: 21_700)
        let interruptedAt = startedAt.addingTimeInterval(2)
        let current = snapshot(
            phase: .waitingForApproval(PermissionContext(
                toolUseId: "pending-tool",
                toolName: "Bash",
                toolInput: nil,
                receivedAt: startedAt.addingTimeInterval(1)
            )),
            lastActivity: startedAt.addingTimeInterval(1),
            turnStartedAt: startedAt,
            codexToolExecutionStartedAt: startedAt.addingTimeInterval(1)
        )

        let transition = reduce(
            current: current,
            observation: observation(
                .interrupted(interruptedAt),
                observedAt: interruptedAt,
                receivedAt: interruptedAt
            )
        )

        XCTAssertEqual(transition.reason, .nativeInterruption)
        let next = try XCTUnwrap(transition.nextSnapshot)
        XCTAssertEqual(next.phase, .interrupted)
        XCTAssertNil(next.completedAt)
        XCTAssertNil(next.codexToolExecutionStartedAt)
        XCTAssertEqual(next.lastHookEventAt, interruptedAt)
    }

    func testNativeFailureDismissesApprovalWithoutRecordingCompletion() throws {
        let startedAt = Date(timeIntervalSince1970: 21_750)
        let failedAt = startedAt.addingTimeInterval(2)
        let current = snapshot(
            phase: .waitingForApproval(PermissionContext(
                toolUseId: "pending-tool",
                toolName: "Bash",
                toolInput: nil,
                receivedAt: startedAt.addingTimeInterval(1)
            )),
            lastActivity: startedAt.addingTimeInterval(1),
            turnStartedAt: startedAt,
            codexToolExecutionStartedAt: startedAt.addingTimeInterval(1)
        )

        let transition = reduce(
            current: current,
            observation: observation(
                .failed(failedAt),
                observedAt: failedAt,
                receivedAt: failedAt
            )
        )

        XCTAssertEqual(transition.reason, .nativeFailure)
        let next = try XCTUnwrap(transition.nextSnapshot)
        XCTAssertEqual(next.phase, .failed)
        XCTAssertNil(next.completedAt)
        XCTAssertNil(next.codexToolExecutionStartedAt)
        XCTAssertEqual(next.lastHookEventAt, failedAt)
    }

    func testFailedGenerationRejectsLateActivityAndCompletionButAllowsNewTurn() throws {
        let startedAt = Date(timeIntervalSince1970: 21_850)
        let failedAt = startedAt.addingTimeInterval(2)
        let current = snapshot(
            phase: .failed,
            lastActivity: failedAt,
            lastHookEventAt: failedAt,
            turnStartedAt: startedAt
        )

        let lateActivity = reduce(
            current: current,
            observation: observation(
                .active(
                    turnStartedAt: startedAt,
                    lastEvidenceAt: startedAt.addingTimeInterval(1)
                ),
                observedAt: startedAt.addingTimeInterval(1),
                receivedAt: failedAt.addingTimeInterval(1)
            )
        )
        XCTAssertEqual(lateActivity.mutation, .none)
        XCTAssertEqual(lateActivity.reason, .activeWithoutNewGeneration)

        let lateCompletion = reduce(
            current: current,
            observation: observation(
                .completed(failedAt.addingTimeInterval(1)),
                observedAt: failedAt.addingTimeInterval(1),
                receivedAt: failedAt.addingTimeInterval(1)
            )
        )
        XCTAssertEqual(lateCompletion.mutation, .none)
        XCTAssertEqual(lateCompletion.reason, .completionAfterFailure)

        let newTurnAt = failedAt.addingTimeInterval(1)
        let newTurn = reduce(
            current: current,
            observation: observation(
                .active(
                    turnStartedAt: newTurnAt,
                    lastEvidenceAt: newTurnAt
                ),
                observedAt: newTurnAt,
                receivedAt: newTurnAt
            )
        )
        XCTAssertEqual(newTurn.nextSnapshot?.phase, .processing)
        XCTAssertNil(newTurn.nextSnapshot?.completedAt)
    }

    func testNativeFailureOlderThanHookBoundaryIsRejected() {
        let hookAt = Date(timeIntervalSince1970: 21_900)
        let transition = reduce(
            current: snapshot(
                lastActivity: hookAt,
                lastHookEventAt: hookAt,
                turnStartedAt: hookAt.addingTimeInterval(-2)
            ),
            observation: observation(
                .failed(hookAt.addingTimeInterval(-1)),
                observedAt: hookAt.addingTimeInterval(-1),
                receivedAt: hookAt
            )
        )

        XCTAssertEqual(transition.mutation, .none)
        XCTAssertEqual(transition.reason, .failureOlderThanBoundary)
        XCTAssertFalse(transition.acceptsObservation)
    }

    func testInterruptedGenerationRejectsLateActivityAndCompletionButAllowsNewTurn() throws {
        let startedAt = Date(timeIntervalSince1970: 21_800)
        let interruptedAt = startedAt.addingTimeInterval(2)
        let current = snapshot(
            phase: .interrupted,
            lastActivity: interruptedAt,
            lastHookEventAt: interruptedAt,
            turnStartedAt: startedAt
        )

        let lateActivity = reduce(
            current: current,
            observation: observation(
                .active(
                    turnStartedAt: startedAt,
                    lastEvidenceAt: startedAt.addingTimeInterval(1)
                ),
                observedAt: startedAt.addingTimeInterval(1),
                receivedAt: interruptedAt.addingTimeInterval(1)
            )
        )
        XCTAssertEqual(lateActivity.mutation, .none)
        XCTAssertEqual(lateActivity.reason, .activeWithoutNewGeneration)

        let lateCompletion = reduce(
            current: current,
            observation: observation(
                .completed(interruptedAt.addingTimeInterval(1)),
                observedAt: interruptedAt.addingTimeInterval(1),
                receivedAt: interruptedAt.addingTimeInterval(1)
            )
        )
        XCTAssertEqual(lateCompletion.mutation, .none)
        XCTAssertEqual(lateCompletion.reason, .completionAfterInterruption)

        let newTurnAt = interruptedAt.addingTimeInterval(1)
        let newTurn = reduce(
            current: current,
            observation: observation(
                .active(
                    turnStartedAt: newTurnAt,
                    lastEvidenceAt: newTurnAt
                ),
                observedAt: newTurnAt,
                receivedAt: newTurnAt
            )
        )
        XCTAssertEqual(newTurn.nextSnapshot?.phase, .processing)
        XCTAssertNil(newTurn.nextSnapshot?.completedAt)
    }

    func testNativeInterruptionOlderThanHookBoundaryIsRejected() {
        let hookAt = Date(timeIntervalSince1970: 21_900)
        let transition = reduce(
            current: snapshot(
                lastActivity: hookAt,
                lastHookEventAt: hookAt,
                turnStartedAt: hookAt.addingTimeInterval(-2)
            ),
            observation: observation(
                .interrupted(hookAt.addingTimeInterval(-1)),
                observedAt: hookAt.addingTimeInterval(-1),
                receivedAt: hookAt
            )
        )

        XCTAssertEqual(transition.mutation, .none)
        XCTAssertEqual(transition.reason, .interruptionOlderThanBoundary)
        XCTAssertFalse(transition.acceptsObservation)
    }

    func testLateHookStopCannotPromoteInterruptionToSuccessfulCompletion() {
        let interruptedAt = Date(timeIntervalSince1970: 21_950)
        let transition = reduce(
            current: snapshot(
                phase: .interrupted,
                lastActivity: interruptedAt,
                lastHookEventAt: interruptedAt,
                turnStartedAt: interruptedAt.addingTimeInterval(-2)
            ),
            observation: observation(
                .hook(.completed),
                observedAt: interruptedAt.addingTimeInterval(1),
                receivedAt: interruptedAt.addingTimeInterval(1),
                origin: .hook,
                requestedPhase: .waitingForInput,
                hookEventName: "Stop"
            )
        )

        XCTAssertEqual(transition.mutation, .none)
        XCTAssertEqual(transition.reason, .completionAfterInterruption)
        XCTAssertFalse(transition.acceptsObservation)
    }

    func testFreshCodexPromptHookCanResumeAnInterruptedSession() {
        let interruptedAt = Date(timeIntervalSince1970: 21_975)
        let promptAt = interruptedAt.addingTimeInterval(1)
        let transition = reduce(
            current: snapshot(
                phase: .interrupted,
                lastActivity: interruptedAt,
                lastHookEventAt: interruptedAt,
                turnStartedAt: interruptedAt.addingTimeInterval(-2)
            ),
            observation: observation(
                .hook(.active),
                observedAt: promptAt,
                receivedAt: promptAt,
                origin: .hook,
                requestedPhase: .processing,
                hookEventName: "UserPromptSubmit"
            )
        )

        XCTAssertEqual(transition.nextSnapshot?.phase, .processing)
        XCTAssertNil(transition.nextSnapshot?.completedAt)
    }

    func testFreshCodexPromptHookCanResumeAFailedSession() {
        let failedAt = Date(timeIntervalSince1970: 21_990)
        let promptAt = failedAt.addingTimeInterval(1)
        let transition = reduce(
            current: snapshot(
                phase: .failed,
                lastActivity: failedAt,
                lastHookEventAt: failedAt,
                turnStartedAt: failedAt.addingTimeInterval(-2)
            ),
            observation: observation(
                .hook(.active),
                observedAt: promptAt,
                receivedAt: promptAt,
                origin: .hook,
                requestedPhase: .processing,
                hookEventName: "UserPromptSubmit"
            )
        )

        XCTAssertEqual(transition.nextSnapshot?.phase, .processing)
        XCTAssertNil(transition.nextSnapshot?.completedAt)
    }

    func testMatchingProcessExitEndsSession() throws {
        let exitedAt = Date(timeIntervalSince1970: 22_000)
        let transition = reduce(
            current: snapshot(
                lastActivity: exitedAt.addingTimeInterval(-1)
            ),
            observation: observation(
                .processExited,
                observedAt: exitedAt,
                receivedAt: exitedAt,
                origin: .processMonitor
            )
        )

        XCTAssertEqual(transition.reason, .processExitAccepted)
        let next = try XCTUnwrap(transition.nextSnapshot)
        XCTAssertEqual(next.phase, .ended)
        XCTAssertEqual(next.completedAt, exitedAt)
    }

    func testObservationOnlyProcessExitRemovesSession() throws {
        let exitedAt = Date(timeIntervalSince1970: 22_100)
        let sources = [
            try XCTUnwrap(AgentSource(rawValue: "custom-coder")),
            AgentSource.gemini,
        ]

        for source in sources {
            let transition = reduce(
                current: snapshot(
                    lastActivity: exitedAt.addingTimeInterval(-1),
                    source: source
                ),
                observation: observation(
                    .processExited,
                    observedAt: exitedAt,
                    receivedAt: exitedAt,
                    origin: .processMonitor,
                    source: source
                )
            )

            XCTAssertEqual(
                transition.reason,
                .observationSourceProcessExited,
                "Expected \(source.rawValue) process exit to remove its card"
            )
            XCTAssertEqual(transition.mutation, .remove)
        }
    }

    func testInterruptWatcherUsesSourceTimestamp() throws {
        let detectedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let line = """
        {"type":"user","timestamp":"2023-11-14T22:13:20.000Z","message":"[Request interrupted by user]"}
        """
        let observedAt = try XCTUnwrap(
            JSONLInterruptWatcher.interruptObservedAt(
                in: line,
                detectedAt: detectedAt
            )
        )

        XCTAssertEqual(
            observedAt.timeIntervalSince1970,
            1_700_000_000,
            accuracy: 0.001
        )
    }

    func testInterruptWatcherRejectsImplausibleFutureTimestamp() throws {
        let detectedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let line = """
        {"type":"user","timestamp":"2099-01-01T00:00:00.000Z","message":"[Request interrupted by user]"}
        """
        let observedAt = try XCTUnwrap(
            JSONLInterruptWatcher.interruptObservedAt(
                in: line,
                detectedAt: detectedAt
            )
        )

        XCTAssertEqual(observedAt, detectedAt)
    }

    func testInterruptWatcherAcceptsWhitespaceAndReorderedJSON() throws {
        let detectedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let line = """
        { "message" : { "content" : "[Request interrupted by user]" }, "timestamp" : "2023-11-14T22:13:20.000Z", "type" : "user" }
        """

        let observedAt = try XCTUnwrap(
            JSONLInterruptWatcher.interruptObservedAt(
                in: line,
                detectedAt: detectedAt
            )
        )
        XCTAssertEqual(
            observedAt.timeIntervalSince1970,
            1_700_000_000,
            accuracy: 0.001
        )
    }

    func testInterruptWatcherRejectsJSONLookingSubstringInPlainText() {
        let line = #"prefix {\"type\":\"user\",\"interrupted\":true} suffix"#
        XCTAssertNil(JSONLInterruptWatcher.interruptObservedAt(
            in: line,
            detectedAt: Date()
        ))
    }

    func testJSONLLineBufferPreservesPartialUTF8Record() throws {
        let line = #"{ "type": "user", "message": "用户中断" }"#
        let bytes = try XCTUnwrap(line.data(using: .utf8))
        let split = bytes.count - 2
        var buffer = JSONLLineBuffer()

        XCTAssertTrue(buffer.append(Data(bytes[..<split])).isEmpty)
        var remainder = Data(bytes[split...])
        remainder.append(0x0A)
        XCTAssertEqual(buffer.append(remainder), [line])
    }

    func testJSONLLineBufferResetsAfterTruncationBoundary() {
        var buffer = JSONLLineBuffer()
        XCTAssertTrue(buffer.append(Data("partial".utf8)).isEmpty)
        buffer.reset()
        XCTAssertEqual(
            buffer.append(Data("{\"fresh\":true}\n".utf8)),
            ["{\"fresh\":true}"]
        )
    }
}
