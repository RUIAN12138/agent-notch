// Copyright (c) OpenAI. All rights reserved.
import Foundation
import XCTest
@testable import Agent_Notch

final class CodexAppServerQuestionProtocolTests: XCTestCase {
    private let requestLine = #"{"jsonrpc":"2.0","id":71,"method":"item/tool/requestUserInput","params":{"threadId":"thread-a","turnId":"turn-b","itemId":"item-c","isBlocking":true,"autoResolutionMs":null,"questions":[{"id":"confirm_path","header":"Confirm","question":"Proceed?","isOther":true,"isSecret":false,"options":[{"label":"Yes","description":"Continue."},{"label":"No","description":"Stop."}]}]}}"#

    func testDecodesNativeQuestionAndPreservesAllIdentities() throws {
        let receivedAt = Date(timeIntervalSince1970: 123)
        let token = UUID(uuidString: "3A0D19EA-03AB-4797-9062-A734F46F20E9")!
        let request = try XCTUnwrap(CodexAppServerQuestionProtocol.decodeUserInputRequest(
            Data(requestLine.utf8), receivedAt: receivedAt, uiToken: token
        ))

        XCTAssertEqual(request.requestID, .integer(71))
        XCTAssertEqual(request.threadID, "thread-a")
        XCTAssertEqual(request.turnID, "turn-b")
        XCTAssertEqual(request.itemID, "item-c")
        XCTAssertEqual(request.questions.first?.id, "confirm_path")
        XCTAssertTrue(request.questions.first?.isOther == true)
        XCTAssertFalse(request.questions.first?.isSecret == true)
        XCTAssertEqual(request.receivedAt, receivedAt)
        XCTAssertEqual(request.uiToken, token)
    }

    func testResponseUsesExactRequestIDAndNestedOfficialAnswerShape() throws {
        let request = try XCTUnwrap(CodexAppServerQuestionProtocol.decodeUserInputRequest(
            Data(requestLine.utf8)
        ))
        let line = try XCTUnwrap(CodexAppServerQuestionProtocol.answerLine(
            request: request,
            answers: ["confirm_path": ["Yes"]]
        ))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: line) as? [String: Any])
        XCTAssertEqual((object["id"] as? NSNumber)?.intValue, 71)
        XCTAssertEqual(object["jsonrpc"] as? String, "2.0")
        let result = try XCTUnwrap(object["result"] as? [String: Any])
        let answers = try XCTUnwrap(result["answers"] as? [String: Any])
        let answer = try XCTUnwrap(answers["confirm_path"] as? [String: Any])
        XCTAssertEqual(answer["answers"] as? [String], ["Yes"])
        XCTAssertTrue(line.last == 0x0A)
    }

    func testStringRequestIDsArePreservedWhenAnswering() throws {
        let raw = requestLine.replacingOccurrences(of: #""id":71"#, with: #""id":"server-req-7""#)
        let request = try XCTUnwrap(CodexAppServerQuestionProtocol.decodeUserInputRequest(Data(raw.utf8)))
        XCTAssertEqual(request.requestID, .string("server-req-7"))
        let line = try XCTUnwrap(CodexAppServerQuestionProtocol.answerLine(
            request: request,
            answers: ["confirm_path": ["No"]]
        ))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: line) as? [String: Any])
        XCTAssertEqual(object["id"] as? String, "server-req-7")
    }

    func testResolvedNotificationMatchesThreadAndRequestID() throws {
        let notification = #"{"jsonrpc":"2.0","method":"serverRequest/resolved","params":{"threadId":"thread-a","requestId":"server-req-7"}}"#
        let resolved = try XCTUnwrap(CodexAppServerQuestionProtocol.decodeResolvedNotification(
            Data(notification.utf8)
        ))
        XCTAssertEqual(resolved.threadID, "thread-a")
        XCTAssertEqual(resolved.requestID, .string("server-req-7"))
    }

    func testParallelRequestQueueDeduplicatesReplaysAndResolvesExactIdentity() {
        func request(
            thread: String,
            id: CodexJSONRPCID,
            at time: TimeInterval,
            token: UUID = UUID()
        ) -> CodexUserInputRequest {
            CodexUserInputRequest(
                requestID: id,
                uiToken: token,
                threadID: thread,
                turnID: "turn-\(thread)",
                itemID: "item-\(id)",
                questions: [CodexUserInputQuestion(
                    id: "choice", header: "Choice", question: "Choose?",
                    isOther: false, isSecret: false,
                    options: [CodexUserInputOption(label: "A", description: "")]
                )],
                isBlocking: true,
                autoResolutionMs: nil,
                receivedAt: Date(timeIntervalSince1970: time)
            )
        }

        var queue = CodexUserInputRequestQueue()
        let first = request(thread: "thread-a", id: .integer(1), at: 20)
        let replay = request(thread: "thread-a", id: .integer(1), at: 21)
        let earlierArrival = request(thread: "thread-a", id: .integer(2), at: 10)
        let sameIDOtherThread = request(thread: "thread-b", id: .integer(1), at: 5)

        XCTAssertTrue(queue.enqueue(first))
        XCTAssertFalse(queue.enqueue(replay))
        XCTAssertTrue(queue.enqueue(earlierArrival))
        XCTAssertTrue(queue.enqueue(sameIDOtherThread))
        XCTAssertEqual(queue.requestsByThread["thread-a"], [earlierArrival, first])
        XCTAssertEqual(queue.firstRequest(for: "thread-a"), earlierArrival)

        XCTAssertNil(queue.resolve(threadID: "thread-b", requestID: .integer(2)))
        XCTAssertEqual(queue.resolve(threadID: "thread-a", requestID: .integer(1)), first)
        XCTAssertEqual(queue.firstRequest(for: "thread-a"), earlierArrival)
        XCTAssertEqual(queue.firstRequest(for: "thread-b"), sameIDOtherThread)
        XCTAssertEqual(queue.resolve(threadID: "thread-a", requestID: .integer(2)), earlierArrival)
        XCTAssertNil(queue.firstRequest(for: "thread-a"))
        XCTAssertEqual(queue.firstRequest(for: "thread-b"), sameIDOtherThread)
    }

    func testOtherServerRequestsAndMalformedQuestionIDsAreRejected() {
        let otherRequest = #"{"jsonrpc":"2.0","id":1,"method":"item/commandExecution/requestApproval","params":{}}"#
        XCTAssertNil(CodexAppServerQuestionProtocol.decodeUserInputRequest(Data(otherRequest.utf8)))

        let duplicate = requestLine.replacingOccurrences(
            of: #"{"id":"confirm_path","header":"Confirm","question":"Proceed?","isOther":true,"isSecret":false,"options":[{"label":"Yes","description":"Continue."},{"label":"No","description":"Stop."}]}"#,
            with: #"{"id":"confirm_path","header":"Confirm","question":"Proceed?","isOther":true,"isSecret":false,"options":[{"label":"Yes","description":"Continue."},{"label":"No","description":"Stop."}]},{"id":"confirm_path","header":"Again","question":"Again?","isOther":false,"isSecret":false,"options":[]}"#
        )
        XCTAssertNil(CodexAppServerQuestionProtocol.decodeUserInputRequest(Data(duplicate.utf8)))
    }

    func testOptionalQuestionFlagsDefaultToFalseWhenOmitted() throws {
        let raw = requestLine
            .replacingOccurrences(of: #","isOther":true"#, with: "")
            .replacingOccurrences(of: #","isSecret":false"#, with: "")
        let request = try XCTUnwrap(CodexAppServerQuestionProtocol.decodeUserInputRequest(Data(raw.utf8)))
        let question = try XCTUnwrap(request.questions.first)
        XCTAssertFalse(question.isOther)
        XCTAssertFalse(question.isSecret)
        XCTAssertEqual(question.options?.map(\.label), ["Yes", "No"])
    }

    func testAnswerPolicyRequiresExactQuestionKeysAndKnownOptions() throws {
        let request = try XCTUnwrap(CodexAppServerQuestionProtocol.decodeUserInputRequest(
            Data(requestLine.utf8)
        ))
        XCTAssertTrue(CodexQuestionAnswerPolicy.canSubmit(
            ["confirm_path": ["Yes"]], questions: request.questions
        ))
        XCTAssertTrue(CodexQuestionAnswerPolicy.canSubmit(
            ["confirm_path": ["My own answer"]], questions: request.questions
        ))
        XCTAssertFalse(CodexQuestionAnswerPolicy.canSubmit(
            [:], questions: request.questions
        ))
        XCTAssertFalse(CodexQuestionAnswerPolicy.canSubmit(
            ["confirm_path": [" "]], questions: request.questions
        ))

        let fixedQuestion = CodexUserInputQuestion(
            id: "fixed", header: "Pick", question: "Choose", isOther: false,
            isSecret: false,
            options: [CodexUserInputOption(label: "A", description: "Option A")]
        )
        XCTAssertFalse(CodexQuestionAnswerPolicy.canSubmit(
            ["fixed": ["Forged option"]], questions: [fixedQuestion]
        ))
    }

    func testHandshakeAndResumeAvoidLoadingFullConversationHistory() throws {
        let initializeLine = try XCTUnwrap(CodexAppServerQuestionProtocol.initializeLine(
            requestID: 4, version: "1.2.3"
        ))
        let initialize = try XCTUnwrap(JSONSerialization.jsonObject(with: initializeLine) as? [String: Any])
        XCTAssertEqual(initialize["method"] as? String, "initialize")
        let initializeParams = try XCTUnwrap(initialize["params"] as? [String: Any])
        XCTAssertEqual(initializeParams["clientInfo"] as? [String: String], [
            "name": "agent-notch", "title": "Agent Notch", "version": "1.2.3"
        ])
        XCTAssertEqual((initializeParams["capabilities"] as? [String: Bool])?["experimentalApi"], true)

        let initializedLine = try XCTUnwrap(CodexAppServerQuestionProtocol.initializedLine())
        let initialized = try XCTUnwrap(JSONSerialization.jsonObject(with: initializedLine) as? [String: Any])
        XCTAssertEqual(initialized["method"] as? String, "initialized")
        XCTAssertNil(initialized["params"])

        let resumeLine = try XCTUnwrap(CodexAppServerQuestionProtocol.resumeLine(
            requestID: 5, threadID: "thread-a"
        ))
        let resume = try XCTUnwrap(JSONSerialization.jsonObject(with: resumeLine) as? [String: Any])
        XCTAssertEqual(resume["method"] as? String, "thread/resume")
        let resumeParams = try XCTUnwrap(resume["params"] as? [String: Any])
        XCTAssertEqual(resumeParams["threadId"] as? String, "thread-a")
        XCTAssertEqual(resumeParams["excludeTurns"] as? Bool, true)
    }

    @MainActor
    func testDraftKeepsAnswerKeysAndResetsOnQuestionSchemaChange() throws {
        let request = try XCTUnwrap(CodexAppServerQuestionProtocol.decodeUserInputRequest(
            Data(requestLine.utf8)
        ))
        let draft = CodexUserInputDraft(questions: request.questions)
        draft.selectOption("Yes", at: 0)
        XCTAssertEqual(draft.compiledAnswers, ["confirm_path": ["Yes"]])
        draft.setCustomAnswer("Custom explanation", at: 0)
        XCTAssertEqual(draft.compiledAnswers, ["confirm_path": ["Custom explanation"]])
        draft.setCustomAnswer("\n", at: 0)
        XCTAssertNil(draft.compiledAnswers)

        let noOtherQuestion = CodexUserInputQuestion(
            id: "fixed", header: "Pick", question: "Choose", isOther: false,
            isSecret: false,
            options: [CodexUserInputOption(label: "A", description: "Option A")]
        )
        let restrictedDraft = CodexUserInputDraft(questions: [noOtherQuestion])
        restrictedDraft.setCustomAnswer("Not allowed", at: 0)
        XCTAssertNil(restrictedDraft.compiledAnswers)
    }

    func testQuestionBecomesAQuestionAttentionStateWithoutChangingItsIdentity() throws {
        let request = try XCTUnwrap(CodexAppServerQuestionProtocol.decodeUserInputRequest(
            Data(requestLine.utf8)
        ))
        let original = SessionState(
            sessionId: "thread-a",
            cwd: "/tmp/codex-question",
            source: .codex,
            phase: .processing
        )
        let presented = CodexUserInputPresentation.session(original, request: request)
        let permission = try XCTUnwrap(presented.activePermission)
        XCTAssertTrue(presented.needsAttention)
        XCTAssertEqual(permission.toolName, CodexUserInputRequest.toolName)
        XCTAssertEqual(permission.toolUseId, request.attentionToolUseID)
        XCTAssertEqual(permission.requestID, request.uiToken)
        XCTAssertEqual(presented.sessionId, original.sessionId)

        let unrelated = SessionState(
            sessionId: "claude-session",
            cwd: "/tmp/claude-question",
            source: .claude,
            phase: .processing
        )
        XCTAssertEqual(
            CodexUserInputPresentation.session(unrelated, request: request),
            unrelated
        )

        let existingApproval = PermissionContext(
            toolUseId: "approval-1",
            toolName: "Bash",
            toolInput: nil,
            receivedAt: Date(timeIntervalSince1970: 124)
        )
        let sessionWithApproval = SessionState(
            sessionId: "thread-a",
            cwd: "/tmp/codex-question",
            source: .codex,
            phase: .waitingForApproval(existingApproval)
        )
        XCTAssertEqual(
            CodexUserInputPresentation.session(sessionWithApproval, request: request),
            sessionWithApproval
        )
    }
}
