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

        preferences.expandOnAgentTeamCompletion = true
        let restored = NotchPreferences(defaults: defaults)
        XCTAssertTrue(restored.expandOnAgentTeamCompletion)
        XCTAssertEqual(
            defaults.object(forKey: "notchExpandOnAgentTeamCompletion") as? Bool,
            true
        )
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
        observedAt: Date
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
            message: nil
        )
    }
}
