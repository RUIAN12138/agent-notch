import XCTest
@testable import Agent_Notch

@MainActor
final class SubagentCompletionAttentionTests: XCTestCase {
    func testTeamExpansionPreferenceDefaultsOffAndPersists() throws {
        let suite = "SubagentCompletionAttentionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let preferences = NotchPreferences(defaults: defaults)
        XCTAssertFalse(preferences.expandOnAgentTeamCompletion)

        preferences.agentTeamCompletionTiming = .everyCompletion
        let restored = NotchPreferences(defaults: defaults)
        XCTAssertTrue(restored.expandOnAgentTeamCompletion)
        XCTAssertEqual(
            defaults.string(forKey: "notchAgentTeamCompletionTiming"),
            AgentTeamCompletionTiming.everyCompletion.rawValue
        )
    }

    func testLegacyTeamExpansionPreferenceMigratesToPerAgentTiming() throws {
        let suite = "SubagentCompletionAttentionTests.Legacy.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "notchExpandOnAgentTeamCompletion")

        let preferences = NotchPreferences(defaults: defaults)

        XCTAssertEqual(preferences.agentTeamCompletionTiming, .everyCompletion)
        XCTAssertTrue(preferences.expandOnAgentTeamCompletion)
    }

    func testTeamExpansionRespectsOwnershipAndPendingInteractions() {
        func shouldExpand(
            enabled: Bool = true,
            status: NotchStatus = .closed,
            reason: NotchOpenReason = .unknown,
            hasPendingInteraction: Bool = false
        ) -> Bool {
            NotchAttentionPolicy.shouldAutoExpandOnAgentTeamCompletion(
                expandOnAgentTeamCompletion: enabled,
                status: status,
                openReason: reason,
                hasPendingAutoExpandedInteraction: hasPendingInteraction
            )
        }

        XCTAssertFalse(shouldExpand(enabled: false))
        XCTAssertTrue(shouldExpand())
        XCTAssertTrue(shouldExpand(status: .opened, reason: .notification))
        XCTAssertFalse(shouldExpand(status: .opened, reason: .click))
        XCTAssertFalse(shouldExpand(status: .opened, reason: .keyboard))
        XCTAssertFalse(shouldExpand(status: .opened, reason: .hover))
        XCTAssertFalse(shouldExpand(status: .popping, reason: .notification))
        XCTAssertFalse(shouldExpand(hasPendingInteraction: true))
    }

    func testTeamCompletionWaitsBehindApprovalThenPresentsBeforeItsDeadline() throws {
        let completedAt = Date(timeIntervalSince1970: 1_000)
        let trackingStartedAt = completedAt.addingTimeInterval(-1)
        var session = SessionState(
            sessionId: "deferred-team-completion",
            cwd: "/tmp/deferred-team-completion",
            phase: .processing
        )
        session.recordSubagentCompletion(at: completedAt)
        let token = try XCTUnwrap(
            NotchAttentionPolicy.subagentCompletionToken(for: session)
        )

        func disposition(
            now: Date = Date(timeIntervalSince1970: 1_002),
            status: NotchStatus = .opened,
            reason: NotchOpenReason = .notification,
            enabled: Bool = true,
            silenced: Bool = false,
            hasPendingInteraction: Bool = false
        ) -> NotchSubagentCompletionDisposition {
            NotchAttentionPolicy.subagentCompletionDisposition(
                token,
                for: session,
                presentationStartedAt: trackingStartedAt,
                duration: 8,
                now: now,
                isSilenced: silenced,
                expandOnAgentTeamCompletion: enabled,
                status: status,
                openReason: reason,
                hasPendingAutoExpandedInteraction: hasPendingInteraction
            )
        }

        XCTAssertEqual(
            disposition(hasPendingInteraction: true),
            .deferUntilHigherPriorityStateResolves
        )
        XCTAssertEqual(disposition(), .present)
        XCTAssertEqual(
            disposition(status: .popping),
            .deferUntilHigherPriorityStateResolves
        )
        XCTAssertEqual(disposition(reason: .click), .discard)
        XCTAssertEqual(disposition(enabled: false), .discard)
        XCTAssertEqual(disposition(silenced: true), .discard)
        XCTAssertEqual(
            disposition(now: completedAt.addingTimeInterval(8)),
            .discard
        )
    }

    func testSubagentCompletionTokenUsesHookBoundaryAndExpiresOnDwell() throws {
        let completedAt = Date(timeIntervalSince1970: 100)
        var session = SessionState(
            sessionId: "team-completion",
            cwd: "/tmp/team-completion"
        )

        session.recordSubagentCompletion(at: completedAt)
        let token = try XCTUnwrap(
            NotchAttentionPolicy.subagentCompletionToken(for: session)
        )
        XCTAssertEqual(token.generation, 1)
        XCTAssertEqual(token.completedAt, completedAt)
        XCTAssertTrue(NotchAttentionPolicy.shouldPresent(
            token,
            presentationStartedAt: completedAt.addingTimeInterval(-1),
            duration: 8,
            now: completedAt.addingTimeInterval(2)
        ))
        XCTAssertFalse(NotchAttentionPolicy.shouldPresent(
            token,
            presentationStartedAt: completedAt.addingTimeInterval(1),
            duration: 8,
            now: completedAt.addingTimeInterval(2)
        ))
        XCTAssertFalse(NotchAttentionPolicy.shouldPresent(
            token,
            presentationStartedAt: completedAt.addingTimeInterval(-1),
            duration: 8,
            now: completedAt.addingTimeInterval(8)
        ))

        // A repeated event with the same source timestamp is idempotent.
        session.recordSubagentCompletion(at: completedAt)
        XCTAssertEqual(session.subagentCompletionGeneration, 1)
    }

    func testTrackedAgentsOnlySignalAllFinishedAfterTheLastMatchingStop() {
        var state = SubagentHookState()
        state.observeStart(agentID: "agent-a", at: 10)
        state.observeStart(agentID: "agent-b", at: 11)
        XCTAssertEqual(state.activeAgentIDs, ["agent-a", "agent-b"])

        let firstStop = state.observeStop(agentID: "agent-a", at: 12)
        XCTAssertTrue(firstStop.shouldPresentIndividualCompletion)
        XCTAssertFalse(firstStop.completedAllActiveAgents)
        XCTAssertEqual(state.activeAgentIDs, ["agent-b"])

        let duplicateStop = state.observeStop(agentID: "agent-a", at: 13)
        XCTAssertFalse(duplicateStop.shouldPresentIndividualCompletion)
        XCTAssertFalse(duplicateStop.completedAllActiveAgents)

        // A delayed start from before the stop cannot resurrect the ID.
        state.observeStart(agentID: "agent-a", at: 11.5)
        XCTAssertEqual(state.activeAgentIDs, ["agent-b"])

        let finalStop = state.observeStop(agentID: "agent-b", at: 14)
        XCTAssertTrue(finalStop.shouldPresentIndividualCompletion)
        XCTAssertTrue(finalStop.completedAllActiveAgents)
        XCTAssertTrue(state.activeAgentIDs.isEmpty)

        let delayedDuplicate = state.observeStop(agentID: "agent-b", at: 13.5)
        XCTAssertFalse(delayedDuplicate.shouldPresentIndividualCompletion)
        XCTAssertFalse(delayedDuplicate.completedAllActiveAgents)
    }

    func testLatePreviousTurnAgentEventsCannotRearmCurrentTurnAttention() {
        var state = SubagentHookState()
        state.beginRootTurn(at: 10)
        state.observeStart(agentID: "agent-a", at: 11)
        XCTAssertTrue(state.consumeRootResponse(at: 12))

        // A delayed Start from before the accepted root response must not
        // resurrect this completed turn's teammate-attention marker.
        state.observeStart(agentID: "agent-b", at: 11.5)
        XCTAssertFalse(state.hasAgentActivityInCurrentTurn)
        XCTAssertFalse(state.consumeRootResponse(at: 11.75))

        state.beginRootTurn(at: 13)
        state.observeStart(agentID: "agent-c", at: 14)
        XCTAssertTrue(state.hasAgentActivityInCurrentTurn)
        XCTAssertTrue(state.consumeRootResponse(at: 15))
        XCTAssertFalse(state.hasAgentActivityInCurrentTurn)
    }

    func testAttentionTimingSelectsIndividualOrAllFinishedCursor() throws {
        var session = SessionState(
            sessionId: "team-timing",
            cwd: "/tmp/team-timing"
        )
        session.recordSubagentCompletion(at: Date(timeIntervalSince1970: 10))
        XCTAssertEqual(
            NotchAttentionPolicy.subagentCompletionToken(
                for: session,
                timing: .everyCompletion
            )?.kind,
            .individual
        )
        XCTAssertNil(NotchAttentionPolicy.subagentCompletionToken(
            for: session,
            timing: .allAgentsFinished
        ))

        session.recordAllSubagentsFinished(at: Date(timeIntervalSince1970: 12))
        XCTAssertEqual(
            NotchAttentionPolicy.subagentCompletionToken(
                for: session,
                timing: .allAgentsFinished
            )?.kind,
            .allAgentsFinished
        )
        XCTAssertNil(NotchAttentionPolicy.subagentCompletionToken(
            for: session,
            timing: .rootResponse
        ))

        session.recordSubagentRootResponse(at: Date(timeIntervalSince1970: 13))
        XCTAssertEqual(
            NotchAttentionPolicy.subagentCompletionToken(
                for: session,
                timing: .rootResponse
            )?.kind,
            .rootResponse
        )
    }

    func testClaudeHookPayloadDecodesStableAgentIdentity() throws {
        let data = Data(#"{"session_id":"session","cwd":"/tmp","event":"SubagentStart","status":"processing","agent_id":"agent-123"}"#.utf8)
        let event = try JSONDecoder().decode(HookEvent.self, from: data)
        XCTAssertEqual(event.agentId, "agent-123")
    }

    func testStorePairsClaudeAgentIDsAndIgnoresDuplicateStops() async throws {
        let store = SessionStore(
            persistenceEnabled: false,
            fileSyncEnabled: false,
            externalLifecycleEffectsEnabled: false
        )
        let sessionId = "subagent-set-\(UUID().uuidString)"
        let start = Date()

        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "UserPromptSubmit",
            status: "processing",
            observedAt: start
        )))
        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "SubagentStart",
            status: "processing",
            observedAt: start.addingTimeInterval(1),
            agentId: "agent-a"
        )))
        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "SubagentStart",
            status: "processing",
            observedAt: start.addingTimeInterval(2),
            agentId: "agent-b"
        )))
        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "SubagentStop",
            status: "processing",
            observedAt: start.addingTimeInterval(3),
            agentId: "agent-a"
        )))

        let firstSnapshot = await store.session(for: sessionId)
        var session = try XCTUnwrap(firstSnapshot)
        XCTAssertEqual(session.subagentCompletionGeneration, 1)
        XCTAssertEqual(session.allSubagentsFinishedGeneration, 0)
        XCTAssertEqual(session.subagentHookState.activeAgentIDs, ["agent-b"])

        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "SubagentStop",
            status: "processing",
            observedAt: start.addingTimeInterval(4),
            agentId: "agent-b"
        )))
        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "SubagentStop",
            status: "processing",
            observedAt: start.addingTimeInterval(5),
            agentId: "agent-b"
        )))

        let finalSnapshot = await store.session(for: sessionId)
        session = try XCTUnwrap(finalSnapshot)
        XCTAssertEqual(session.subagentCompletionGeneration, 2)
        XCTAssertEqual(session.allSubagentsFinishedGeneration, 1)
        XCTAssertTrue(session.subagentHookState.activeAgentIDs.isEmpty)
    }

    func testDistinctSubagentsCanCompleteAtTheSameSourceTimestamp() async throws {
        let store = SessionStore(
            persistenceEnabled: false,
            fileSyncEnabled: false,
            externalLifecycleEffectsEnabled: false
        )
        let sessionId = "subagent-same-timestamp-\(UUID().uuidString)"
        let start = Date().addingTimeInterval(-10)
        let completionAt = start.addingTimeInterval(2)

        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "UserPromptSubmit",
            status: "processing",
            observedAt: start
        )))
        for agentId in ["agent-a", "agent-b"] {
            await store.process(.hookReceived(hook(
                sessionId: sessionId,
                event: "SubagentStart",
                status: "processing",
                observedAt: start.addingTimeInterval(1),
                agentId: agentId
            )))
        }
        for agentId in ["agent-a", "agent-b"] {
            await store.process(.hookReceived(hook(
                sessionId: sessionId,
                event: "SubagentStop",
                status: "processing",
                observedAt: completionAt,
                agentId: agentId
            )))
        }

        let snapshot = await store.session(for: sessionId)
        let session = try XCTUnwrap(snapshot)
        XCTAssertEqual(session.subagentCompletionGeneration, 2)
        XCTAssertEqual(session.allSubagentsFinishedGeneration, 1)
        XCTAssertEqual(
            try XCTUnwrap(session.lastSubagentCompletedAt)
                .timeIntervalSince(completionAt),
            0,
            accuracy: 0.001
        )
    }

    func testRootResponseTimingOnlyCreatesTeamAttentionAfterSubagentActivity() async throws {
        let store = SessionStore(
            persistenceEnabled: false,
            fileSyncEnabled: false,
            externalLifecycleEffectsEnabled: false
        )
        let sessionId = "subagent-root-response-\(UUID().uuidString)"
        let start = Date()

        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "UserPromptSubmit",
            status: "processing",
            observedAt: start
        )))
        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "Stop",
            status: "waiting_for_input",
            observedAt: start.addingTimeInterval(1)
        )))
        var snapshot = await store.session(for: sessionId)
        var session = try XCTUnwrap(snapshot)
        XCTAssertEqual(session.subagentRootResponseGeneration, 0)

        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "UserPromptSubmit",
            status: "processing",
            observedAt: start.addingTimeInterval(2)
        )))
        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "SubagentStart",
            status: "processing",
            observedAt: start.addingTimeInterval(3),
            agentId: "agent-root-response"
        )))
        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "SubagentStop",
            status: "processing",
            observedAt: start.addingTimeInterval(4),
            agentId: "agent-root-response"
        )))
        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "Stop",
            status: "waiting_for_input",
            observedAt: start.addingTimeInterval(5)
        )))

        snapshot = await store.session(for: sessionId)
        session = try XCTUnwrap(snapshot)
        XCTAssertEqual(session.subagentRootResponseGeneration, 1)
        XCTAssertEqual(
            try XCTUnwrap(session.lastSubagentRootResponseAt)
                .timeIntervalSince(start.addingTimeInterval(5)),
            0,
            accuracy: 0.001
        )
        XCTAssertFalse(session.subagentHookState.hasAgentActivityInCurrentTurn)
    }

    func testMatchedActiveSubagentCanFinishAfterRootWithoutRevivingRootPhase() async throws {
        let store = SessionStore(
            persistenceEnabled: false,
            fileSyncEnabled: false,
            externalLifecycleEffectsEnabled: false
        )
        let sessionId = "subagent-late-finish-\(UUID().uuidString)"
        let start = Date()
        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "UserPromptSubmit",
            status: "processing",
            observedAt: start
        )))
        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "SubagentStart",
            status: "processing",
            observedAt: start.addingTimeInterval(1),
            agentId: "agent-late"
        )))
        let rootStoppedAt = start.addingTimeInterval(2)
        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "Stop",
            status: "waiting_for_input",
            observedAt: rootStoppedAt
        )))
        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "SubagentStop",
            status: "processing",
            observedAt: start.addingTimeInterval(3),
            agentId: "agent-late"
        )))

        let snapshot = await store.session(for: sessionId)
        let session = try XCTUnwrap(snapshot)
        XCTAssertEqual(session.phase, .waitingForInput)
        XCTAssertEqual(
            try XCTUnwrap(session.completedAt).timeIntervalSince(rootStoppedAt),
            0,
            accuracy: 0.001
        )
        XCTAssertEqual(session.subagentCompletionGeneration, 1)
        XCTAssertEqual(session.allSubagentsFinishedGeneration, 1)
        XCTAssertTrue(session.subagentHookState.activeAgentIDs.isEmpty)
    }

    func testSubagentStopIsDistinctFromRootCompletionAndLateStopIsIgnored() async throws {
        let store = SessionStore(
            persistenceEnabled: false,
            fileSyncEnabled: false,
            externalLifecycleEffectsEnabled: false
        )
        let sessionId = "subagent-hook-\(UUID().uuidString)"
        let startedAt = Date()
        let subagentStoppedAt = startedAt.addingTimeInterval(1)

        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "UserPromptSubmit",
            status: "processing",
            observedAt: startedAt
        )))
        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "SubagentStop",
            status: "processing",
            observedAt: subagentStoppedAt
        )))

        var storedSession = await store.session(for: sessionId)
        var session = try XCTUnwrap(storedSession)
        XCTAssertEqual(session.phase, .processing)
        XCTAssertNil(session.completedAt)
        XCTAssertEqual(session.subagentCompletionGeneration, 1)
        XCTAssertEqual(
            try XCTUnwrap(session.lastSubagentCompletedAt).timeIntervalSince1970,
            subagentStoppedAt.timeIntervalSince1970,
            accuracy: 0.001
        )

        // Accepting a parent Stop must end the root turn independently.
        let rootCompletedAt = startedAt.addingTimeInterval(2)
        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "Stop",
            status: "waiting_for_input",
            observedAt: rootCompletedAt
        )))

        // A delayed teammate hook cannot reopen or refresh attention for the
        // already-completed root turn.
        await store.process(.hookReceived(hook(
            sessionId: sessionId,
            event: "SubagentStop",
            status: "processing",
            observedAt: startedAt.addingTimeInterval(3)
        )))
        storedSession = await store.session(for: sessionId)
        session = try XCTUnwrap(storedSession)
        XCTAssertEqual(session.phase, .waitingForInput)
        XCTAssertEqual(
            try XCTUnwrap(session.completedAt).timeIntervalSince1970,
            rootCompletedAt.timeIntervalSince1970,
            accuracy: 0.001
        )
        XCTAssertEqual(session.subagentCompletionGeneration, 1)
        XCTAssertEqual(
            try XCTUnwrap(session.lastSubagentCompletedAt).timeIntervalSince1970,
            subagentStoppedAt.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    private func hook(
        sessionId: String,
        event: String,
        status: String,
        observedAt: Date,
        agentId: String? = nil
    ) -> HookEvent {
        HookEvent(
            sessionId: sessionId,
            cwd: "/tmp/subagent-completion-tests",
            event: event,
            status: status,
            observedAt: observedAt.timeIntervalSince1970,
            source: "claude",
            pid: nil,
            tty: nil,
            tool: nil,
            toolInput: nil,
            toolUseId: nil,
            notificationType: nil,
            message: nil,
            agentId: agentId
        )
    }
}
