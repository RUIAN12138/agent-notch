// Modified by lihao505 for Agent Notch, 2026.
// Startup fixtures keep persistence, bridge snapshots, and transcripts isolated.
import Foundation
import XCTest
@testable import Agent_Notch

@MainActor
private final class RecoveryWatcher: SessionInterruptWatching {
    private(set) var watching = Set<String>()
    private(set) var installationCount = 0

    func startWatching(sessionId: String, cwd: String) {
        if watching.insert(sessionId).inserted { installationCount += 1 }
    }

    func stopWatching(sessionId: String) {
        watching.remove(sessionId)
    }
}

@MainActor
final class SessionStoreWatcherRecoveryTests: XCTestCase {
    private func lifecycleHook(
        _ event: String,
        at time: Date,
        agentId: String? = nil
    ) -> SessionEvent {
        .hookReceived(HookEvent(
            sessionId: "late-child-fixture", cwd: "/tmp/late-child-fixture",
            event: event, status: event == "Stop" ? "waiting_for_input" : "processing",
            observedAt: time.timeIntervalSince1970, source: "claude",
            pid: nil, tty: nil, tool: nil, toolInput: nil, toolUseId: nil,
            notificationType: nil, message: nil, agentId: agentId
        ))
    }

    func testLateSubagentStopCannotReviveCompletedParentOrReinstallWatcher() async throws {
        let watcher = RecoveryWatcher()
        let store = SessionStore(persistenceEnabled: false, fileSyncEnabled: false,
                                 interruptWatcher: watcher)
        let start = Date().addingTimeInterval(-10)
        await store.process(lifecycleHook("UserPromptSubmit", at: start))
        XCTAssertEqual(watcher.watching, ["late-child-fixture"])
        let stop = start.addingTimeInterval(1)
        await store.process(lifecycleHook("Stop", at: stop))
        let beforeChild = await store.session(for: "late-child-fixture")
        XCTAssertNotNil(beforeChild?.completedAt)
        await store.process(lifecycleHook("SubagentStop", at: stop.addingTimeInterval(1)))
        let completed = await store.session(for: "late-child-fixture")
        XCTAssertEqual(completed?.phase, .waitingForInput)
        // The wire carries seconds since 1970, whereas Foundation stores Date
        // relative to its reference epoch. Compare the stored boundary before
        // and after the callback, not an unconverted host timestamp.
        XCTAssertEqual(completed?.completedAt, beforeChild?.completedAt)
        XCTAssertEqual(completed?.lastHookEventAt, beforeChild?.lastHookEventAt)
        XCTAssertTrue(watcher.watching.isEmpty)
        let rejected = await store.lifecycleTrace(for: "late-child-fixture")
        XCTAssertEqual(rejected.last?.reason, .subagentCompletionCannotResume)
        XCTAssertEqual(rejected.last?.hookEventName, .subagentStop)
        XCTAssertEqual(rejected.last?.accepted, false)

        // A genuine new parent turn still resumes, and child completion while
        // that turn is running must neither stop it nor uninstall its watcher.
        await store.process(lifecycleHook("UserPromptSubmit", at: stop.addingTimeInterval(2)))
        await store.process(lifecycleHook("SubagentStop", at: stop.addingTimeInterval(3)))
        let resumed = await store.session(for: "late-child-fixture")
        XCTAssertEqual(resumed?.phase, .processing)
        XCTAssertNil(resumed?.completedAt)
        XCTAssertEqual(watcher.watching, ["late-child-fixture"])
        XCTAssertEqual(watcher.installationCount, 2)
    }

    func testLateSubagentStopCannotReviveInterruptedParent() async {
        let watcher = RecoveryWatcher()
        let store = SessionStore(persistenceEnabled: false, fileSyncEnabled: false,
                                 interruptWatcher: watcher)
        let start = Date().addingTimeInterval(-10)
        await store.process(lifecycleHook("UserPromptSubmit", at: start))
        await store.process(.interruptDetected(sessionId: "late-child-fixture",
                                              observedAt: start.addingTimeInterval(1)))
        await store.process(lifecycleHook("SubagentStop", at: start.addingTimeInterval(2)))
        let interrupted = await store.session(for: "late-child-fixture")
        XCTAssertEqual(interrupted?.phase, .idle)
        XCTAssertTrue(watcher.watching.isEmpty)
        XCTAssertEqual(watcher.installationCount, 1)
    }

    func testLateSubagentStartCannotReviveCompletedParent() async throws {
        let watcher = RecoveryWatcher()
        let store = SessionStore(persistenceEnabled: false, fileSyncEnabled: false,
                                 interruptWatcher: watcher)
        let start = Date().addingTimeInterval(-10)
        await store.process(lifecycleHook("UserPromptSubmit", at: start))
        let stop = start.addingTimeInterval(1)
        await store.process(lifecycleHook("Stop", at: stop))
        let beforeChild = await store.session(for: "late-child-fixture")
        XCTAssertNotNil(beforeChild?.completedAt)

        await store.process(lifecycleHook(
            "SubagentStart",
            at: stop.addingTimeInterval(1),
            agentId: "late-agent"
        ))

        let completed = await store.session(for: "late-child-fixture")
        XCTAssertEqual(completed?.phase, .waitingForInput)
        XCTAssertEqual(completed?.completedAt, beforeChild?.completedAt)
        XCTAssertEqual(completed?.subagentHookState.activeAgentIDs, [])
        XCTAssertTrue(watcher.watching.isEmpty)
        let rejected = await store.lifecycleTrace(for: "late-child-fixture")
        XCTAssertEqual(rejected.last?.reason, .subagentStartCannotResume)
        XCTAssertEqual(rejected.last?.hookEventName, .subagentStart)
        XCTAssertEqual(rejected.last?.accepted, false)

        await store.process(lifecycleHook(
            "UserPromptSubmit",
            at: stop.addingTimeInterval(2)
        ))
        let resumed = await store.session(for: "late-child-fixture")
        XCTAssertEqual(resumed?.phase, .processing)
        XCTAssertNil(resumed?.completedAt)
        XCTAssertEqual(resumed?.subagentHookState.activeAgentIDs, [])
        XCTAssertEqual(watcher.watching, ["late-child-fixture"])
    }

    private struct Fixture {
        let root: URL
        let id = UUID().uuidString
        let observedAt = Date().addingTimeInterval(-5)
        var snapshot: URL { root.appendingPathComponent("active-sessions.json") }
        var bridge: URL { root.appendingPathComponent("bridge", isDirectory: true) }
        var projects: URL { root.appendingPathComponent("projects", isDirectory: true) }

        init() throws {
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent("agent-notch-watcher-recovery-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: bridge, withIntermediateDirectories: true)
        }

        func writeJSON(_ value: Any, to url: URL) throws {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try JSONSerialization.data(withJSONObject: value).write(to: url)
        }

        func writePersistedSession() throws {
            let timestamp = ISO8601DateFormatter().string(from: observedAt)
            try writeJSON([[
                "sessionId": id, "cwd": root.path, "projectName": "recovery-fixture",
                "source": "claude", "pid": ProcessInfo.processInfo.processIdentifier,
                "phase": "processing", "lastActivity": timestamp,
                "createdAt": timestamp, "lastHookEventAt": timestamp
            ]], to: snapshot)
        }

        func writeBridgeSession(
            subagentAgents: [String: Any]? = nil,
            observedAt: Date? = nil,
            event: String = "PreToolUse",
            status: String = "running_tool"
        ) throws {
            var payload: [String: Any] = [
                "version": 1, "session_id": id, "cwd": root.path,
                "source": "claude", "event": event, "status": status,
                "pid": ProcessInfo.processInfo.processIdentifier,
                "observed_at": (observedAt ?? self.observedAt).timeIntervalSince1970
            ]
            if let subagentAgents {
                payload["subagent_agents"] = subagentAgents
            }
            try writeJSON(payload, to: bridge.appendingPathComponent("fixture.json"))
        }

        func writeTranscript(completed: Bool) throws {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let projectKey = root.path.replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ".", with: "-")
            let url = projects.appendingPathComponent(projectKey)
                .appendingPathComponent("\(id).jsonl")
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let content: [[String: Any]] = completed
                ? [["type": "text", "text": "done"]]
                : [["type": "tool_use", "id": "running-tool", "name": "Bash", "input": [:]]]
            let rows: [[String: Any]] = [
                ["type": "user", "uuid": "user-row",
                 "timestamp": formatter.string(from: observedAt),
                 "message": ["role": "user", "content": "fixture"]],
                ["type": "assistant", "uuid": "assistant-row",
                 "timestamp": formatter.string(from: observedAt.addingTimeInterval(1)),
                 "message": ["role": "assistant", "content": content]]
            ]
            var data = Data()
            for row in rows {
                data.append(try JSONSerialization.data(withJSONObject: row))
                data.append(0x0A)
            }
            try data.write(to: url)
        }

        func store(watcher: RecoveryWatcher) -> SessionStore {
            SessionStore(
                persistenceEnabled: true, fileSyncEnabled: false,
                conversationParser: ConversationParser(
                    codexSessionsRoot: root.appendingPathComponent("codex"),
                    claudeProjectsRoot: projects
                ),
                statusCheckIntervalSeconds: 30,
                persistenceURL: snapshot, bridgeSnapshotDirectory: bridge,
                interruptWatcher: watcher
            )
        }
    }

    private func waitForRestore(
        _ store: SessionStore, id: String, watcher: RecoveryWatcher
    ) async throws -> SessionState {
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if let session = await store.session(for: id), !session.chatItems.isEmpty {
                let expectsWatcher = session.completedAt == nil && session.phase.isActive
                if watcher.watching.contains(id) == expectsWatcher { return session }
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        throw NSError(domain: "WatcherRecovery", code: 1)
    }

    func testPersistedWorkingSessionRestartsWatcherAndStopCleansItUp() async throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try fixture.writePersistedSession()
        try fixture.writeTranscript(completed: false)
        let watcher = RecoveryWatcher()
        let store = fixture.store(watcher: watcher)
        await store.startPeriodicStatusCheck()
        let session = try await waitForRestore(store, id: fixture.id, watcher: watcher)
        await store.stopPeriodicStatusCheck()
        XCTAssertEqual(session.phase, .processing)
        XCTAssertTrue(watcher.watching.contains(fixture.id))

        await store.process(.hookReceived(HookEvent(
            sessionId: fixture.id, cwd: fixture.root.path,
            event: "Stop", status: "idle", observedAt: Date().timeIntervalSince1970,
            source: "claude", pid: nil, tty: nil, tool: nil, toolInput: nil,
            toolUseId: nil, notificationType: nil, message: nil
        )))
        XCTAssertFalse(watcher.watching.contains(fixture.id))
    }

    func testOfflineBridgeWorkingSessionRestartsWatcher() async throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try fixture.writeBridgeSession()
        try fixture.writeTranscript(completed: false)
        let watcher = RecoveryWatcher()
        let store = fixture.store(watcher: watcher)
        await store.startPeriodicStatusCheck()
        let session = try await waitForRestore(store, id: fixture.id, watcher: watcher)
        await store.stopPeriodicStatusCheck()
        XCTAssertEqual(session.phase, .processing)
        XCTAssertEqual(session.source, .claude)
        XCTAssertTrue(watcher.watching.contains(fixture.id))
        await store.process(.sessionEnded(sessionId: fixture.id))
        XCTAssertTrue(watcher.watching.isEmpty)
    }

    func testOfflineApprovalSnapshotRestoresNonActionableNoticeUntilFreshHook() async throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try fixture.writeBridgeSession(
            event: "PermissionRequest",
            status: "waiting_for_approval"
        )
        try fixture.writeTranscript(completed: false)
        let watcher = RecoveryWatcher()
        let store = fixture.store(watcher: watcher)
        await store.startPeriodicStatusCheck()
        let recovered = try await waitForRestore(
            store, id: fixture.id, watcher: watcher
        )
        await store.stopPeriodicStatusCheck()

        XCTAssertEqual(recovered.phase, .processing)
        XCTAssertEqual(
            recovered.recoveredApprovalAt?.timeIntervalSince1970 ?? .nan,
            fixture.observedAt.timeIntervalSince1970,
            accuracy: 0.001
        )
        XCTAssertTrue(recovered.hasApprovalRecoveryNotice)
        XCTAssertEqual(
            SessionRowPresentation(session: recovered).interaction,
            .none
        )

        let persistedRows = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(contentsOf: fixture.snapshot)
            ) as? [[String: Any]]
        )
        XCTAssertNotNil(persistedRows.first?["recoveredApprovalAt"])
        try FileManager.default.removeItem(
            at: fixture.bridge.appendingPathComponent("fixture.json")
        )

        let persistedWatcher = RecoveryWatcher()
        let persistedStore = fixture.store(watcher: persistedWatcher)
        await persistedStore.startPeriodicStatusCheck()
        let restoredFromAppSnapshot = try await waitForRestore(
            persistedStore, id: fixture.id, watcher: persistedWatcher
        )
        await persistedStore.stopPeriodicStatusCheck()
        XCTAssertTrue(restoredFromAppSnapshot.hasApprovalRecoveryNotice)
        XCTAssertEqual(
            SessionRowPresentation(session: restoredFromAppSnapshot).interaction,
            .none
        )

        let resumedAt = Date()
        await persistedStore.process(.hookReceived(HookEvent(
            sessionId: fixture.id,
            cwd: fixture.root.path,
            event: "UserPromptSubmit",
            status: "processing",
            observedAt: resumedAt.timeIntervalSince1970,
            source: "claude",
            pid: Int(ProcessInfo.processInfo.processIdentifier),
            tty: nil,
            tool: nil,
            toolInput: nil,
            toolUseId: nil,
            notificationType: nil,
            message: nil
        )))
        let resumed = await persistedStore.session(for: fixture.id)
        XCTAssertEqual(resumed?.phase, .processing)
        XCTAssertFalse(resumed?.hasApprovalRecoveryNotice ?? true)
        await store.process(.sessionEnded(sessionId: fixture.id))
        await persistedStore.process(.sessionEnded(sessionId: fixture.id))
    }

    func testOfflineBridgeSnapshotRestoresActiveSubagentIdentitySet() async throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try fixture.writeBridgeSession(subagentAgents: [
            "agent-a": ["active": true, "observed_at": fixture.observedAt.timeIntervalSince1970],
            "agent-b": ["active": false, "observed_at": fixture.observedAt.timeIntervalSince1970]
        ])
        let bridgeFile = fixture.bridge.appendingPathComponent("fixture.json")
        var payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: bridgeFile))
                as? [String: Any]
        )
        payload["subagent_turn_had_agents"] = true
        payload["subagent_turn_started_at"] =
            fixture.observedAt.addingTimeInterval(-1).timeIntervalSince1970
        try fixture.writeJSON(payload, to: bridgeFile)
        try fixture.writeTranscript(completed: false)
        let watcher = RecoveryWatcher()
        let store = fixture.store(watcher: watcher)
        await store.startPeriodicStatusCheck()
        let session = try await waitForRestore(store, id: fixture.id, watcher: watcher)
        await store.stopPeriodicStatusCheck()

        XCTAssertEqual(session.subagentHookState.activeAgentIDs, ["agent-a"])
        XCTAssertTrue(session.subagentHookState.hasAgentActivityInCurrentTurn)
        XCTAssertEqual(
            session.subagentHookState.rootTurnStartedAt,
            fixture.observedAt.addingTimeInterval(-1).timeIntervalSince1970
        )
        await store.process(.sessionEnded(sessionId: fixture.id))
    }

    func testRemovedSessionBoundarySurvivesRestartWithoutBlockingNewMidToolRestore() async throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let startAt = fixture.observedAt
        let endedAt = startAt.addingTimeInterval(1)
        let initialStore = fixture.store(watcher: RecoveryWatcher())

        await initialStore.process(.hookReceived(HookEvent(
            sessionId: fixture.id, cwd: fixture.root.path,
            event: "UserPromptSubmit", status: "processing",
            observedAt: startAt.timeIntervalSince1970, source: "claude",
            pid: nil, tty: nil, tool: nil, toolInput: nil,
            toolUseId: nil, notificationType: nil, message: nil
        )))
        await initialStore.process(.hookReceived(HookEvent(
            sessionId: fixture.id, cwd: fixture.root.path,
            event: "SessionEnd", status: "ended",
            observedAt: endedAt.timeIntervalSince1970, source: "claude",
            pid: nil, tty: nil, tool: nil, toolInput: nil,
            toolUseId: nil, notificationType: nil, message: nil
        )))
        let removed = await initialStore.session(for: fixture.id)
        XCTAssertNil(removed)

        // Simulate a crash between the durable removal marker and rewriting
        // the ordinary active-session snapshot: the previous active row is
        // still on disk, and the offline bridge file contains an older event.
        // A stale snapshot with a future wall-clock value must not outrank
        // the durable removal marker after a restart.
        let persistedTimestamp = ISO8601DateFormatter().string(
            from: Date().addingTimeInterval(6 * 60)
        )
        try fixture.writeJSON([[
            "sessionId": fixture.id, "cwd": fixture.root.path,
            "projectName": "recovery-fixture", "source": "claude",
            "pid": ProcessInfo.processInfo.processIdentifier,
            "phase": "processing", "lastActivity": persistedTimestamp,
            "createdAt": persistedTimestamp,
            "lastHookEventAt": persistedTimestamp
        ]], to: fixture.snapshot)
        try fixture.writeTranscript(completed: false)
        try fixture.writeBridgeSession(observedAt: endedAt.addingTimeInterval(-0.1))

        let staleWatcher = RecoveryWatcher()
        let staleStore = fixture.store(watcher: staleWatcher)
        await staleStore.startPeriodicStatusCheck()
        try await Task.sleep(nanoseconds: 100_000_000)
        let staleRestore = await staleStore.session(for: fixture.id)
        await staleStore.stopPeriodicStatusCheck()
        XCTAssertNil(staleRestore)
        XCTAssertTrue(staleWatcher.watching.isEmpty)

        // A newer PreToolUse snapshot is a real mid-turn observation even
        // without the earlier UserPromptSubmit being the latest disk row.
        try fixture.writeBridgeSession(
            observedAt: endedAt.addingTimeInterval(2),
            event: "PreToolUse",
            status: "running_tool"
        )
        let resumedWatcher = RecoveryWatcher()
        let resumedStore = fixture.store(watcher: resumedWatcher)
        await resumedStore.startPeriodicStatusCheck()
        let resumed = try await waitForRestore(
            resumedStore, id: fixture.id, watcher: resumedWatcher
        )
        await resumedStore.stopPeriodicStatusCheck()

        XCTAssertEqual(resumed.phase, .processing)
        XCTAssertEqual(resumed.source, .claude)
        XCTAssertTrue(resumedWatcher.watching.contains(fixture.id))
        await resumedStore.process(.sessionEnded(sessionId: fixture.id))
    }

    func testTranscriptCompletionOverridesWorkingSnapshotWithoutStartingWatcher() async throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try fixture.writePersistedSession()
        try fixture.writeTranscript(completed: true)
        let watcher = RecoveryWatcher()
        let store = fixture.store(watcher: watcher)
        await store.startPeriodicStatusCheck()
        let session = try await waitForRestore(store, id: fixture.id, watcher: watcher)
        await store.stopPeriodicStatusCheck()
        XCTAssertEqual(session.phase, .waitingForInput)
        XCTAssertNotNil(session.completedAt)
        XCTAssertTrue(watcher.watching.isEmpty)
        XCTAssertEqual(watcher.installationCount, 0)
    }

    func testMissedStopTranscriptStopsWatcherAndStaleInterruptCannotStopNewTurn() async throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try fixture.writePersistedSession()
        try fixture.writeTranscript(completed: false)
        let watcher = RecoveryWatcher()
        let store = fixture.store(watcher: watcher)
        await store.startPeriodicStatusCheck()
        _ = try await waitForRestore(store, id: fixture.id, watcher: watcher)
        await store.stopPeriodicStatusCheck()
        let completionAt = Date().addingTimeInterval(-1)
        await store.process(.fileUpdated(FileUpdatePayload(
            sessionId: fixture.id, cwd: fixture.root.path,
            messages: [ChatMessage(id: "completed", role: .assistant,
                                   timestamp: completionAt, content: [.text("done")])],
            isIncremental: true, completedToolIds: ["running-tool"],
            toolResults: [:], structuredResults: [:]
        )))
        XCTAssertTrue(watcher.watching.isEmpty)

        let newTurnAt = Date()
        await store.process(.hookReceived(HookEvent(
            sessionId: fixture.id, cwd: fixture.root.path,
            event: "UserPromptSubmit", status: "processing",
            observedAt: newTurnAt.timeIntervalSince1970,
            source: "claude", pid: nil, tty: nil, tool: nil, toolInput: nil,
            toolUseId: nil, notificationType: nil, message: nil
        )))
        await store.process(.interruptDetected(sessionId: fixture.id, observedAt: completionAt))
        let session = await store.session(for: fixture.id)
        XCTAssertEqual(session?.phase, .processing)
        XCTAssertTrue(watcher.watching.contains(fixture.id))
        await store.process(.sessionEnded(sessionId: fixture.id))
    }
}
