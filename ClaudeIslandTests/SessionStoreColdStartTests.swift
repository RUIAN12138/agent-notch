//
//  SessionStoreColdStartTests.swift
//  Agent Notch
//
//  Isolated native rollout fixtures: never read the user's agent sessions.
//

import Foundation
import XCTest
@testable import Agent_Notch

final class SessionStoreColdStartTests: XCTestCase {
    private func writeActiveCodexRollout(
        root: URL,
        sessionId: String,
        cwd: String
    ) throws {
        let components = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day],
            from: Date()
        )
        let directory = root
            .appendingPathComponent(String(format: "%04d", components.year!))
            .appendingPathComponent(String(format: "%02d", components.month!))
            .appendingPathComponent(String(format: "%02d", components.day!))
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date())
        let rows: [[String: Any]] = [
            [
                "timestamp": timestamp,
                "type": "session_meta",
                "payload": ["id": sessionId, "cwd": cwd]
            ],
            [
                "timestamp": timestamp,
                "type": "event_msg",
                "payload": ["type": "task_started"]
            ]
        ]
        let data = try rows.reduce(into: Data()) { result, row in
            result.append(try JSONSerialization.data(withJSONObject: row))
            result.append(0x0A)
        }
        try data.write(
            to: directory.appendingPathComponent(
                "rollout-test-\(sessionId).jsonl"
            )
        )
    }

    func testAlreadyRunningCodexTurnIsDiscoveredBeforePeriodicDelay() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-notch-cold-start-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let sessionId = UUID().uuidString
        try writeActiveCodexRollout(
            root: root,
            sessionId: sessionId,
            cwd: root.path
        )
        let store = SessionStore(
            persistenceEnabled: false,
            fileSyncEnabled: false,
            conversationParser: ConversationParser(codexSessionsRoot: root),
            statusCheckIntervalSeconds: 30
        )

        await store.startPeriodicStatusCheck()
        let deadline = Date().addingTimeInterval(3)
        var discovered: SessionState?
        while Date() < deadline {
            discovered = await store.session(for: sessionId)
            if discovered != nil { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        let decisions = await store.lifecycleTrace(for: sessionId)
        await store.stopPeriodicStatusCheck()

        XCTAssertEqual(discovered?.phase, .processing)
        XCTAssertEqual(discovered?.source, .codex)
        XCTAssertTrue(decisions.contains {
            $0.origin == .codexDiscovery &&
                $0.reason == .discoveredActiveTurn && $0.didMutate
        })
    }

    func testRepeatedNativeNoOpPollsDoNotEvictDiscoveryDecision() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-notch-trace-sampling-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let sessionId = UUID().uuidString
        try writeActiveCodexRollout(root: root, sessionId: sessionId, cwd: root.path)
        let store = SessionStore(
            persistenceEnabled: false,
            fileSyncEnabled: false,
            conversationParser: ConversationParser(codexSessionsRoot: root),
            statusCheckIntervalSeconds: 1
        )
        await store.startPeriodicStatusCheck()
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if await store.session(for: sessionId) != nil { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        try await Task.sleep(nanoseconds: 2_250_000_000)
        let decisions = await store.lifecycleTrace(for: sessionId)
        await store.stopPeriodicStatusCheck()

        XCTAssertEqual(decisions.filter { $0.reason == .discoveredActiveTurn }.count, 1)
        XCTAssertEqual(decisions.filter { $0.reason == .alreadyCurrent }.count, 2)
        XCTAssertTrue(decisions.allSatisfy {
            $0.origin == .codexDiscovery || $0.origin == .codexPolling
        })
    }

    func testPersistedCodexFailureRestoresWithoutCompletionTimestamp() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-notch-failed-restore-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let sessionId = UUID().uuidString
        let now = Date()
        let startedAt = now.addingTimeInterval(-3)
        let failedAt = now.addingTimeInterval(-2)
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        let codexRoot = root.appendingPathComponent("codex", isDirectory: true)
        let rolloutDirectory = codexRoot
            .appendingPathComponent(String(format: "%04d", components.year!))
            .appendingPathComponent(String(format: "%02d", components.month!))
            .appendingPathComponent(String(format: "%02d", components.day!))
        try FileManager.default.createDirectory(
            at: rolloutDirectory,
            withIntermediateDirectories: true
        )

        let eventFormatter = ISO8601DateFormatter()
        eventFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let metadata: [String: Any] = [
            "timestamp": eventFormatter.string(from: startedAt),
            "type": "session_meta",
            "payload": ["id": sessionId, "cwd": root.path]
        ]
        let started: [String: Any] = [
            "timestamp": eventFormatter.string(from: startedAt),
            "type": "event_msg",
            "payload": ["type": "task_started"]
        ]
        let failed: [String: Any] = [
            "timestamp": eventFormatter.string(from: failedAt),
            "type": "event_msg",
            "payload": ["type": "task_failed"]
        ]
        let rolloutData = try [metadata, started, failed].reduce(into: Data()) { data, row in
            data.append(try JSONSerialization.data(withJSONObject: row))
            data.append(0x0A)
        }
        try rolloutData.write(
            to: rolloutDirectory.appendingPathComponent("rollout-failed.jsonl")
        )

        let persistenceURL = root.appendingPathComponent("active-sessions.json")
        let persistedDateFormatter = ISO8601DateFormatter()
        let persisted: [[String: Any]] = [[
            "sessionId": sessionId,
            "cwd": root.path,
            "projectName": "failed-restore-fixture",
            "source": "codex",
            "phase": "failed",
            "lastActivity": persistedDateFormatter.string(from: failedAt),
            "createdAt": persistedDateFormatter.string(from: startedAt),
            "lastHookEventAt": persistedDateFormatter.string(from: failedAt),
            "lastCodexTurnStartedAt": persistedDateFormatter.string(from: startedAt)
        ]]
        try JSONSerialization.data(withJSONObject: persisted).write(to: persistenceURL)

        let store = SessionStore(
            persistenceEnabled: true,
            fileSyncEnabled: false,
            conversationParser: ConversationParser(codexSessionsRoot: codexRoot),
            statusCheckIntervalSeconds: 30,
            persistenceURL: persistenceURL,
            bridgeSnapshotDirectory: root.appendingPathComponent("bridge", isDirectory: true)
        )
        await store.startPeriodicStatusCheck()
        let deadline = Date().addingTimeInterval(3)
        var restored: SessionState?
        while Date() < deadline {
            restored = await store.session(for: sessionId)
            if restored?.phase == .failed { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        await store.stopPeriodicStatusCheck()

        XCTAssertEqual(restored?.phase, .failed)
        XCTAssertNil(restored?.completedAt)
    }
}
