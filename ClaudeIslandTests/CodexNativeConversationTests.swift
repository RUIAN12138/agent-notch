import XCTest
@testable import Agent_Notch

final class CodexNativeConversationTests: XCTestCase {
    private let timestamp = "2026-09-24T08:30:00.000Z"

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-notch-native-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        return root
    }

    private func encoded(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
    }

    private func metadata(sessionId: String, cwd: String) -> [String: Any] {
        [
            "timestamp": timestamp,
            "type": "session_meta",
            "payload": ["id": sessionId, "cwd": cwd]
        ]
    }

    private func itemCompleted(
        id: String,
        type: String,
        text: String,
        phase: String? = nil
    ) -> [String: Any] {
        var item: [String: Any] = [
            "id": id,
            "type": type,
            "content": [[
                "type": type == "AgentMessage" ? "Text" : "text",
                "text": text
            ]]
        ]
        if let phase {
            item["phase"] = phase
        }
        return [
            "timestamp": timestamp,
            "type": "event_msg",
            "payload": ["type": "item_completed", "item": item]
        ]
    }

    private func rolloutURL(root: URL, sessionId: String) throws -> URL {
        let directory = root
            .appendingPathComponent("2026")
            .appendingPathComponent("09")
            .appendingPathComponent("24")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent(
            "rollout-test-\(sessionId).jsonl"
        )
    }

    private func writeLines(
        _ lines: [Data],
        to url: URL,
        trailingNewline: Bool = true,
        options: Data.WritingOptions = []
    ) throws {
        var data = Data()
        for (index, line) in lines.enumerated() {
            data.append(line)
            if index < lines.count - 1 || trailingNewline {
                data.append(0x0A)
            }
        }
        try data.write(to: url, options: options)
    }

    func testParsesCurrentAndLegacyVisibleMessagesOnly() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionId = "current-schema"
        let cwd = "/tmp/current-schema"
        let url = try rolloutURL(root: root, sessionId: sessionId)

        // This row intentionally includes spaces after JSON separators. The
        // fast prefilter must not depend on compact JSONSerialization output.
        let spacedUser = Data("""
        {"timestamp": "\(timestamp)", "type": "event_msg", "payload": {"type": "item_completed", "item": {"id": "user-one", "type": "UserMessage", "content": [{"type": "text", "text": "继续"}]}}}
        """.utf8)
        let assistantWithBlocks: [String: Any] = [
            "timestamp": timestamp,
            "type": "event_msg",
            "payload": [
                "type": "item_completed",
                "item": [
                    "id": "agent-one",
                    "type": "AgentMessage",
                    "phase": "commentary",
                    "content": [
                        ["type": "Text", "text": "第一段"],
                        ["type": "Text", "text": "第二段"]
                    ]
                ]
            ]
        ]
        let duplicateID = itemCompleted(
            id: "agent-one",
            type: "AgentMessage",
            text: "不应重复",
            phase: "commentary"
        )
        let sameTextNewID = itemCompleted(
            id: "user-two",
            type: "UserMessage",
            text: "继续"
        )
        let hiddenAnalysis = itemCompleted(
            id: "analysis-one",
            type: "AgentMessage",
            text: "隐藏分析",
            phase: "analysis"
        )
        let commandItem: [String: Any] = [
            "timestamp": timestamp,
            "type": "event_msg",
            "payload": [
                "type": "item_completed",
                "item": [
                    "id": "command-one",
                    "type": "CommandExecution",
                    "content": [["type": "text", "text": "secret output"]]
                ]
            ]
        ]
        let responseItem: [String: Any] = [
            "timestamp": timestamp,
            "type": "response_item",
            "payload": [
                "type": "message",
                "role": "developer",
                "content": [["type": "input_text", "text": "injected"]]
            ]
        ]
        let legacy: [String: Any] = [
            "timestamp": timestamp,
            "type": "event_msg",
            "payload": [
                "type": "agent_message",
                "phase": "final_answer",
                "message": "旧格式仍可见"
            ]
        ]

        try writeLines([
            try encoded(metadata(sessionId: sessionId, cwd: cwd)),
            spacedUser,
            try encoded(assistantWithBlocks),
            try encoded(duplicateID),
            try encoded(sameTextNewID),
            try encoded(hiddenAnalysis),
            try encoded(commandItem),
            try encoded(responseItem),
            try encoded(legacy)
        ], to: url)

        let parser = ConversationParser(codexSessionsRoot: root)
        let messages = await parser.parseFullConversation(
            sessionId: sessionId,
            cwd: cwd
        )

        XCTAssertEqual(Array(messages.prefix(3)).map(\.id), [
            "native-item-user-one",
            "native-item-agent-one",
            "native-item-user-two"
        ])
        XCTAssertEqual(messages.count, 4)
        XCTAssertTrue(messages[3].id.hasPrefix("native-"))
        XCTAssertFalse(messages[3].id.hasPrefix("native-item-"))
        XCTAssertEqual(messages.map(\.role), [
            .user, .assistant, .user, .assistant
        ])
        XCTAssertEqual(messages.map(\.textContent), [
            "继续", "第一段\n第二段", "继续", "旧格式仍可见"
        ])
    }

    func testPartialRowIsRetriedAfterNewlineArrives() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionId = "partial-row"
        let cwd = "/tmp/partial-row"
        let url = try rolloutURL(root: root, sessionId: sessionId)
        let row = try encoded(itemCompleted(
            id: "partial-user",
            type: "UserMessage",
            text: "完整后再显示"
        ))
        try writeLines([
            try encoded(metadata(sessionId: sessionId, cwd: cwd)),
            row
        ], to: url, trailingNewline: false)

        let parser = ConversationParser(codexSessionsRoot: root)
        let initial = await parser.parseFullConversation(
            sessionId: sessionId,
            cwd: cwd
        )
        XCTAssertTrue(initial.isEmpty)

        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data([0x0A]))
        try handle.close()

        let update = await parser.parseIncremental(
            sessionId: sessionId,
            cwd: cwd
        )
        XCTAssertEqual(update.newMessages.map(\.textContent), ["完整后再显示"])
        XCTAssertEqual(update.newMessages.first?.id, "native-item-partial-user")
    }

    func testMetadataSnapshotDoesNotConsumeTranscriptCursor() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionId = "metadata-cursor"
        let cwd = "/tmp/metadata-cursor"
        let url = try rolloutURL(root: root, sessionId: sessionId)
        try writeLines([
            try encoded(metadata(sessionId: sessionId, cwd: cwd)),
            try encoded(itemCompleted(
                id: "still-visible",
                type: "AgentMessage",
                text: "不会被元数据读取吞掉",
                phase: "final_answer"
            ))
        ], to: url)

        let parser = ConversationParser(codexSessionsRoot: root)
        _ = await parser.parse(sessionId: sessionId, cwd: cwd)
        let update = await parser.parseIncremental(
            sessionId: sessionId,
            cwd: cwd
        )
        XCTAssertEqual(update.newMessages.map(\.textContent), [
            "不会被元数据读取吞掉"
        ])
    }

    func testSameInodeRewriteResetsMessagesUsingAnchor() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionId = "rewrite-anchor"
        let cwd = "/tmp/rewrite-anchor"
        let url = try rolloutURL(root: root, sessionId: sessionId)
        try writeLines([
            try encoded(metadata(sessionId: sessionId, cwd: cwd)),
            try encoded(itemCompleted(
                id: "old-message",
                type: "UserMessage",
                text: "旧消息"
            ))
        ], to: url)

        let parser = ConversationParser(codexSessionsRoot: root)
        let initial = await parser.parseFullConversation(
            sessionId: sessionId,
            cwd: cwd
        )
        XCTAssertEqual(initial.map(\.textContent), ["旧消息"])

        var replacement = Data()
        for line in [
            try encoded(metadata(sessionId: sessionId, cwd: cwd)),
            try encoded(itemCompleted(
                id: "new-message",
                type: "AgentMessage",
                text: "替换后只保留新消息，而且内容更长以越过旧游标",
                phase: "final_answer"
            ))
        ] {
            replacement.append(line)
            replacement.append(0x0A)
        }
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: replacement)
        try handle.close()

        let reparsed = await parser.parseFullConversation(
            sessionId: sessionId,
            cwd: cwd
        )
        XCTAssertEqual(reparsed.map(\.id), ["native-item-new-message"])
        XCTAssertEqual(reparsed.map(\.textContent), [
            "替换后只保留新消息，而且内容更长以越过旧游标"
        ])
    }

    func testRotatedRolloutPathDoesNotReuseOldCursor() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionId = "rotated-rollout"
        let cwd = "/tmp/rotated-rollout"
        let originalURL = try rolloutURL(root: root, sessionId: sessionId)
        try writeLines([
            try encoded(metadata(sessionId: sessionId, cwd: cwd)),
            try encoded(itemCompleted(
                id: "before-rotation",
                type: "UserMessage",
                text: "轮换前"
            ))
        ], to: originalURL)

        let parser = ConversationParser(codexSessionsRoot: root)
        let initial = await parser.parseFullConversation(
            sessionId: sessionId,
            cwd: cwd
        )
        XCTAssertEqual(initial.map(\.textContent), ["轮换前"])
        let directory = originalURL.deletingLastPathComponent()
        let directoryModifiedAt = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: directory.path)[
                .modificationDate
            ] as? Date
        )

        let rotatedURL = directory
            .appendingPathComponent("rollout-rotated-\(sessionId).jsonl")
        try FileManager.default.removeItem(at: originalURL)
        try writeLines([
            try encoded(metadata(sessionId: sessionId, cwd: cwd)),
            try encoded(itemCompleted(
                id: "after-rotation",
                type: "AgentMessage",
                text: "轮换后只保留新文件内容",
                phase: "final_answer"
            ))
        ], to: rotatedURL)
        // Reproduce a coarse timestamp filesystem: the containing directory
        // appears unchanged even though the cached rollout path disappeared.
        try FileManager.default.setAttributes(
            [.modificationDate: directoryModifiedAt],
            ofItemAtPath: directory.path
        )

        let reparsed = await parser.parseFullConversation(
            sessionId: sessionId,
            cwd: cwd
        )
        XCTAssertEqual(reparsed.map(\.id), ["native-item-after-rotation"])
        XCTAssertEqual(reparsed.map(\.textContent), [
            "轮换后只保留新文件内容"
        ])
    }

    func testReusedPathDoesNotLeakTranscriptAcrossSessionIdentities() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = try rolloutURL(root: root, sessionId: "old-owner")
        try writeLines([
            try encoded(metadata(sessionId: "old-owner", cwd: "/tmp/old-owner")),
            try encoded(itemCompleted(id: "old-message", type: "UserMessage", text: "原会话消息"))
        ], to: url)
        let parser = ConversationParser(
            codexSessionsRoot: root,
            claudeProjectsRoot: root.appendingPathComponent("isolated-claude")
        )
        let original = await parser.parseFullConversation(
            sessionId: "old-owner", cwd: "/tmp/old-owner"
        )
        XCTAssertEqual(original.map(\.textContent), ["原会话消息"])

        try writeLines([
            try encoded(metadata(sessionId: "new-owner", cwd: "/tmp/new-owner")),
            try encoded(itemCompleted(id: "new-message", type: "AgentMessage",
                                      text: "替换文件属于新会话", phase: "final_answer"))
        ], to: url, options: .atomic)
        let discovered = await parser.discoverCodexTasks(modifiedAfter: .distantPast)
        XCTAssertEqual(discovered.map(\.sessionId), ["new-owner"])
        let oldMessages = await parser.parseFullConversation(
            sessionId: "old-owner", cwd: "/tmp/old-owner"
        )
        XCTAssertTrue(oldMessages.isEmpty)
        let newMessages = await parser.parseFullConversation(
            sessionId: "new-owner", cwd: "/tmp/new-owner"
        )
        XCTAssertEqual(newMessages.map(\.id), ["native-item-new-message"])
        XCTAssertEqual(newMessages.map(\.textContent), ["替换文件属于新会话"])
    }

    func testLifecycleRecognizesToolCallUntilItsDurableResultArrives() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionId = "long-running-tool"
        let url = try rolloutURL(root: root, sessionId: sessionId)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let startedAt = Date().addingTimeInterval(-20 * 60)
        let startedAtString = formatter.string(from: startedAt)
        let persistedStartedAt = try XCTUnwrap(
            formatter.date(from: startedAtString)
        )
        let taskStarted: [String: Any] = [
            "timestamp": startedAtString,
            "type": "event_msg",
            "payload": ["type": "task_started"]
        ]
        let functionCall: [String: Any] = [
            "timestamp": startedAtString,
            "type": "response_item",
            "payload": [
                "type": "function_call",
                "call_id": "call-long-running",
                "name": "exec_command",
                "arguments": "{}"
            ]
        ]
        try writeLines([
            try encoded(metadata(sessionId: sessionId, cwd: "/tmp/long-tool")),
            try encoded(taskStarted),
            try encoded(functionCall)
        ], to: url)

        let parser = ConversationParser(codexSessionsRoot: root)
        let running = await parser.codexTaskLifecycle(sessionId: sessionId)
        guard case .activeTool(let turnStartedAt, let lastEvidenceAt, let toolStartedAt) = running else {
            return XCTFail("Expected the unmatched tool call to keep the turn active")
        }
        let initialModificationDate = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]
                as? Date
        )
        XCTAssertEqual(turnStartedAt, persistedStartedAt)
        XCTAssertGreaterThanOrEqual(
            try XCTUnwrap(lastEvidenceAt),
            initialModificationDate.addingTimeInterval(-0.01)
        )
        XCTAssertEqual(toolStartedAt, persistedStartedAt)

        let completedAt = Date()
        let completedAtString = formatter.string(from: completedAt)
        let persistedCompletedAt = try XCTUnwrap(
            formatter.date(from: completedAtString)
        )
        let result: [String: Any] = [
            "timestamp": completedAtString,
            "type": "response_item",
            "payload": [
                "type": "function_call_output",
                "call_id": "call-long-running",
                "output": "done"
            ]
        ]
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: encoded(result))
        try handle.write(contentsOf: Data([0x0A]))
        try handle.close()

        let finished = await parser.codexTaskLifecycle(sessionId: sessionId)
        guard case .active(let finishedTurnStartedAt, let finishedEvidenceAt) = finished else {
            return XCTFail("Expected a completed tool result to clear only the tool marker")
        }
        let completedModificationDate = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]
                as? Date
        )
        XCTAssertEqual(finishedTurnStartedAt, persistedStartedAt)
        XCTAssertGreaterThanOrEqual(
            try XCTUnwrap(finishedEvidenceAt),
            completedModificationDate.addingTimeInterval(-0.01)
        )
        XCTAssertGreaterThanOrEqual(
            try XCTUnwrap(finishedEvidenceAt),
            persistedCompletedAt
        )
    }

    func testRecentRolloutWriteKeepsOldTimestampActiveEvidenceFresh() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionId = "active-rollout-recent-write"
        let url = try rolloutURL(root: root, sessionId: sessionId)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let oldStartedAt = Date().addingTimeInterval(-20 * 60)
        let startedAtString = formatter.string(from: oldStartedAt)
        let persistedStartedAt = try XCTUnwrap(
            formatter.date(from: startedAtString)
        )
        let taskStarted: [String: Any] = [
            "timestamp": startedAtString,
            "type": "event_msg",
            "payload": ["type": "task_started"]
        ]
        try writeLines([
            try encoded(metadata(sessionId: sessionId, cwd: "/tmp/active-rollout")),
            try encoded(taskStarted)
        ], to: url)

        let attributes = try FileManager.default.attributesOfItem(
            atPath: url.path
        )
        let fileModifiedAt = try XCTUnwrap(
            attributes[.modificationDate] as? Date
        )
        let parser = ConversationParser(codexSessionsRoot: root)
        let lifecycle = await parser.codexTaskLifecycle(sessionId: sessionId)
        guard case .active(let turnStartedAt, let lastEvidenceAt) = lifecycle else {
            return XCTFail("Expected the native rollout to remain active")
        }

        XCTAssertEqual(turnStartedAt, persistedStartedAt)
        XCTAssertGreaterThanOrEqual(
            try XCTUnwrap(lastEvidenceAt),
            fileModifiedAt.addingTimeInterval(-0.01)
        )

        let current = SessionLifecycleSnapshot(
            source: .codex,
            phase: .processing,
            lastActivity: persistedStartedAt,
            createdAt: persistedStartedAt,
            turnStartedAt: persistedStartedAt
        )
        let receivedAt = fileModifiedAt.addingTimeInterval(30)
        let transition = LifecycleReducer.reduce(
            current: current,
            observation: SessionLifecycleObservation(
                sessionId: sessionId,
                cwd: "/tmp/active-rollout",
                source: .codex,
                origin: .codexPolling,
                evidence: .active(
                    turnStartedAt: turnStartedAt,
                    lastEvidenceAt: lastEvidenceAt
                ),
                observedAt: fileModifiedAt,
                receivedAt: receivedAt
            ),
            allowCreation: false,
            activeStaleInterval: 600,
            missingGracePeriod: 30
        )

        XCTAssertNotEqual(transition.reason, .staleActiveTimedOut)
        guard case .update(let updated) = transition.mutation else {
            return XCTFail("Expected recent rollout activity to refresh the session")
        }
        XCTAssertEqual(updated.phase, .processing)
        XCTAssertNil(updated.completedAt)
        XCTAssertEqual(updated.turnStartedAt, persistedStartedAt)
        XCTAssertEqual(updated.lastActivity, fileModifiedAt)
    }

    func testCancellationEventsRemainInterruptedUntilANewerTurnStarts() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let start = "2026-09-24T08:30:00.000Z"
        let abort = "2026-09-24T08:30:01.000Z"
        let cancellationTypes = [
            "turn_aborted", "task_aborted", "task_cancelled", "task_canceled",
            "turn_cancelled", "turn_canceled", "thread_rolled_back"
        ]

        for type in cancellationTypes {
            let sessionId = "cancelled-\(type)"
            let url = try rolloutURL(root: root, sessionId: sessionId)
            try writeLines([
                try encoded(metadata(sessionId: sessionId, cwd: "/tmp/cancelled")),
                try encoded([
                    "timestamp": start,
                    "type": "event_msg",
                    "payload": ["type": "task_started"]
                ]),
                try encoded([
                    "timestamp": abort,
                    "type": "event_msg",
                    "payload": ["type": type]
                ])
            ], to: url)

            let parser = ConversationParser(codexSessionsRoot: root)
            guard case .interrupted = await parser.codexTaskLifecycle(sessionId: sessionId) else {
                return XCTFail("Expected \(type) to remain an interruption")
            }
        }

        let sessionId = "aborted-then-completed"
        let url = try rolloutURL(root: root, sessionId: sessionId)
        let parser = ConversationParser(codexSessionsRoot: root)
        try writeLines([
            try encoded(metadata(sessionId: sessionId, cwd: "/tmp/cancelled")),
            try encoded([
                "timestamp": start,
                "type": "event_msg",
                "payload": ["type": "task_started"]
            ]),
            try encoded([
                "timestamp": abort,
                "type": "event_msg",
                "payload": ["type": "turn_aborted"]
            ]),
            try encoded([
                "timestamp": "2026-09-24T08:30:02.000Z",
                "type": "event_msg",
                "payload": ["type": "task_complete"]
            ])
        ], to: url)

        guard case .interrupted = await parser.codexTaskLifecycle(sessionId: sessionId) else {
            return XCTFail("A delayed completion row must not rewrite a canceled turn")
        }

        try writeLines([
            try encoded(metadata(sessionId: sessionId, cwd: "/tmp/cancelled")),
            try encoded([
                "timestamp": start,
                "type": "event_msg",
                "payload": ["type": "task_started"]
            ]),
            try encoded([
                "timestamp": abort,
                "type": "event_msg",
                "payload": ["type": "turn_aborted"]
            ]),
            try encoded([
                "timestamp": "2026-09-24T08:30:03.000Z",
                "type": "event_msg",
                "payload": ["type": "task_started"]
            ])
        ], to: url, options: .atomic)

        guard case .active(let turnStartedAt, _) = await parser.codexTaskLifecycle(sessionId: sessionId) else {
            return XCTFail("A newer task_started row should reopen the session")
        }
        XCTAssertEqual(
            turnStartedAt,
            formatter.date(from: "2026-09-24T08:30:03.000Z")
        )
    }

    func testFailureEventsRemainFailedAfterLateSuccessUntilANewerTurnStarts() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let start = "2026-09-24T08:30:00.000Z"
        let failedAt = "2026-09-24T08:30:01.000Z"
        let newerStart = "2026-09-24T08:30:03.000Z"
        let completedAt = "2026-09-24T08:30:04.000Z"

        for type in ["task_failed", "turn_failed"] {
            let sessionId = "failed-\(type)"
            let url = try rolloutURL(root: root, sessionId: sessionId)
            let parser = ConversationParser(codexSessionsRoot: root)
            let rows = [
                try encoded(metadata(sessionId: sessionId, cwd: "/tmp/failed")),
                try encoded([
                    "timestamp": start,
                    "type": "event_msg",
                    "payload": ["type": "task_started"]
                ]),
                try encoded([
                    "timestamp": failedAt,
                    "type": "event_msg",
                    "payload": ["type": type]
                ]),
                try encoded([
                    "timestamp": "2026-09-24T08:30:02.000Z",
                    "type": "event_msg",
                    "payload": ["type": "task_complete"]
                ])
            ]
            try writeLines(rows, to: url)
            guard case .failed = await parser.codexTaskLifecycle(sessionId: sessionId) else {
                return XCTFail("Expected \(type) to remain a failure after a late completion")
            }

            try writeLines(rows + [
                try encoded([
                    "timestamp": newerStart,
                    "type": "event_msg",
                    "payload": ["type": "task_started"]
                ]),
                try encoded([
                    "timestamp": completedAt,
                    "type": "event_msg",
                    "payload": ["type": "task_complete"]
                ])
            ], to: url, options: .atomic)
            guard case .completed = await parser.codexTaskLifecycle(sessionId: sessionId) else {
                return XCTFail("A newer task should be allowed to complete after \(type)")
            }
        }
    }

    func testUnrelatedRolloutWriteDoesNotRefreshActiveEvidence() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionId = "active-rollout-unrelated-write"
        let url = try rolloutURL(root: root, sessionId: sessionId)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let oldStartedAt = Date().addingTimeInterval(-20 * 60)
        let startedAtString = formatter.string(from: oldStartedAt)
        let persistedStartedAt = try XCTUnwrap(
            formatter.date(from: startedAtString)
        )
        let taskStarted: [String: Any] = [
            "timestamp": startedAtString,
            "type": "event_msg",
            "payload": ["type": "task_started"]
        ]
        try writeLines([
            try encoded(metadata(sessionId: sessionId, cwd: "/tmp/quiet-rollout")),
            try encoded(taskStarted)
        ], to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: persistedStartedAt],
            ofItemAtPath: url.path
        )

        let parser = ConversationParser(codexSessionsRoot: root)
        let initialLifecycle = await parser.codexTaskLifecycle(sessionId: sessionId)
        guard case .active(_, let initialEvidenceAt) = initialLifecycle else {
            return XCTFail("Expected an active rollout")
        }
        XCTAssertLessThan(
            abs(try XCTUnwrap(initialEvidenceAt).timeIntervalSince(persistedStartedAt)),
            0.01
        )

        var unrelatedRow = try encoded([
            "timestamp": startedAtString,
            "type": "session_meta",
            "payload": ["id": sessionId, "cwd": "/tmp/quiet-rollout"]
        ])
        unrelatedRow.append(0x0A)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: unrelatedRow)
        try handle.close()

        let lifecycleAfterUnrelatedWrite = await parser.codexTaskLifecycle(
            sessionId: sessionId
        )
        guard case .active(_, let evidenceAtAfterWrite) = lifecycleAfterUnrelatedWrite else {
            return XCTFail("The unrelated row should not close the active rollout")
        }
        XCTAssertLessThan(
            abs(try XCTUnwrap(evidenceAtAfterWrite).timeIntervalSince(persistedStartedAt)),
            0.01
        )
    }
}
