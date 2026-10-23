import XCTest
@testable import Agent_Notch

final class AgentTransportTests: XCTestCase {
    func testSourceRoutesToExpectedTransport() {
        XCTAssertEqual(AgentTransportRouter.kind(for: .codex), .codexCLI)
        XCTAssertEqual(
            AgentTransportRouter.kind(for: .codebuddy),
            .codeBuddyCLI
        )
        XCTAssertEqual(AgentTransportRouter.kind(for: .claude), .tmux)
        XCTAssertEqual(AgentTransportRouter.kind(for: .cursor), .tmux)
        XCTAssertEqual(AgentTransportRouter.kind(for: .gemini), .unsupported)
        XCTAssertEqual(AgentTransportRouter.kind(for: .unknown), .unsupported)
        XCTAssertEqual(
            AgentTransportRouter.kind(for: AgentSource(hookValue: "my-agent")),
            .unsupported
        )
        XCTAssertFalse(AgentTransportRouter.isAvailable(for: AgentSource(hookValue: "my-agent")))
    }

    func testCustomSourceIdentityIsPreservedAndDisplaySafe() {
        let source = AgentSource(hookValue: "my-agent_v2")

        XCTAssertEqual(source.rawValue, "my-agent_v2")
        XCTAssertEqual(source.displayName, "My Agent V2")
        XCTAssertTrue(source.isCustom)
        XCTAssertTrue(source.isObservationOnly)
        XCTAssertFalse(source.supportsMessaging)
        XCTAssertFalse(source.supportsTranscriptSync)
        XCTAssertFalse(source.supportsInteractiveDecisions)
        XCTAssertTrue(source.acceptsHookEvent("UserPromptSubmit"))
        XCTAssertFalse(source.acceptsHookEvent(
            "PreToolUse",
            status: "waiting_for_approval"
        ))
        XCTAssertFalse(source.acceptsHookEvent("PermissionRequest"))
        XCTAssertFalse(source.acceptsHookEvent("Notification"))
    }

    func testInvalidOrMissingCustomSourceFallsBackToUnknown() {
        XCTAssertEqual(AgentSource(hookValue: "../escape"), .unknown)
        XCTAssertEqual(AgentSource(hookValue: " "), .unknown)
        XCTAssertEqual(AgentSource(hookValue: nil), .unknown)
    }

    func testObservationOnlySourcesCannotOpenInteractivePermissionSocket() {
        let custom = HookEvent(
            sessionId: "custom-session",
            cwd: "/tmp/custom-agent",
            event: "PermissionRequest",
            status: "waiting_for_approval",
            observedAt: nil,
            source: "my-agent",
            pid: nil,
            tty: nil,
            tool: "Shell",
            toolInput: nil,
            toolUseId: "tool-1",
            notificationType: nil,
            message: nil
        )
        let legacyClaude = HookEvent(
            sessionId: "legacy-session",
            cwd: "/tmp/claude",
            event: "PermissionRequest",
            status: "waiting_for_approval",
            observedAt: nil,
            source: nil,
            pid: nil,
            tty: nil,
            tool: "Bash",
            toolInput: nil,
            toolUseId: "tool-2",
            notificationType: nil,
            message: nil
        )

        XCTAssertFalse(custom.expectsResponse)
        XCTAssertTrue(legacyClaude.expectsResponse)
    }

    func testCodexResumeArgumentsKeepExactSessionIdentity() {
        XCTAssertEqual(
            CodexCLITransport.arguments(sessionId: "codex-session-A"),
            [
                "exec", "resume",
                "--all",
                "--skip-git-repo-check",
                "codex-session-A",
                "-"
            ]
        )
    }

    func testCodeBuddyResumeArgumentsKeepExactSessionIdentity() {
        XCTAssertEqual(
            CodeBuddyCLITransport.arguments(sessionId: "codebuddy-session-B"),
            [
                "--resume", "codebuddy-session-B",
                "--print",
                "--output-format", "text"
            ]
        )
    }
}
