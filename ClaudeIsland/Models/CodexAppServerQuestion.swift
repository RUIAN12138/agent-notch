// Agent Notch models and protocol codec for Codex app-server questions.

import CoreFoundation
import Combine
import Foundation

enum CodexJSONRPCID: Codable, Equatable, Hashable, Sendable, CustomStringConvertible {
    case integer(Int64)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
            return
        }
        if let integer = try? container.decode(Int64.self) {
            self = .integer(integer)
            return
        }
        throw DecodingError.typeMismatch(
            CodexJSONRPCID.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "JSON-RPC IDs must be strings or integers."
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .integer(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        }
    }

    var description: String {
        switch self {
        case .integer(let value): String(value)
        case .string(let value): value
        }
    }

    fileprivate var jsonValue: Any {
        switch self {
        case .integer(let value): NSNumber(value: value)
        case .string(let value): value
        }
    }

    fileprivate static func parse(_ value: Any?) -> CodexJSONRPCID? {
        if let string = value as? String {
            return .string(string)
        }
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else {
            return nil
        }
        let type = String(cString: number.objCType)
        guard type != "f", type != "d" else { return nil }
        return .integer(number.int64Value)
    }
}

struct CodexUserInputOption: Decodable, Equatable, Sendable, Identifiable {
    let label: String
    let description: String

    var id: String { label }
}

struct CodexUserInputQuestion: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let header: String
    let question: String
    let isOther: Bool
    let isSecret: Bool
    let options: [CodexUserInputOption]?

    private enum CodingKeys: String, CodingKey {
        case id
        case header
        case question
        case isOther
        case isSecret
        case options
    }

    init(
        id: String,
        header: String,
        question: String,
        isOther: Bool,
        isSecret: Bool,
        options: [CodexUserInputOption]?
    ) {
        self.id = id
        self.header = header
        self.question = question
        self.isOther = isOther
        self.isSecret = isSecret
        self.options = options
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        header = try container.decode(String.self, forKey: .header)
        question = try container.decode(String.self, forKey: .question)
        isOther = try container.decodeIfPresent(Bool.self, forKey: .isOther) ?? false
        isSecret = try container.decodeIfPresent(Bool.self, forKey: .isSecret) ?? false
        options = try container.decodeIfPresent([CodexUserInputOption].self, forKey: .options)
    }

    var selectableOptions: [CodexUserInputOption] { options ?? [] }
    var allowsCustomAnswer: Bool { isOther || selectableOptions.isEmpty }
}

struct CodexUserInputRequest: Equatable, Sendable, Identifiable {
    static let toolName = "CodexRequestUserInput"

    let requestID: CodexJSONRPCID
    let uiToken: UUID
    let threadID: String
    let turnID: String
    let itemID: String
    let questions: [CodexUserInputQuestion]
    let isBlocking: Bool
    let autoResolutionMs: Int?
    let receivedAt: Date

    var id: UUID { uiToken }
    var attentionToolUseID: String { "codex-request-\(uiToken.uuidString)" }
}

struct CodexResolvedServerRequest: Equatable, Sendable {
    let threadID: String
    let requestID: CodexJSONRPCID
}

struct CodexUserInputRequestQueue: Equatable, Sendable {
    private(set) var requestsByThread: [String: [CodexUserInputRequest]] = [:]

    func firstRequest(for threadID: String) -> CodexUserInputRequest? {
        requestsByThread[threadID]?.first
    }

    @discardableResult
    mutating func enqueue(_ request: CodexUserInputRequest) -> Bool {
        var requests = requestsByThread[request.threadID, default: []]
        guard !requests.contains(where: { $0.requestID == request.requestID }) else {
            return false
        }
        requests.append(request)
        requests.sort { $0.receivedAt < $1.receivedAt }
        requestsByThread[request.threadID] = requests
        return true
    }

    @discardableResult
    mutating func resolve(
        threadID: String,
        requestID: CodexJSONRPCID
    ) -> CodexUserInputRequest? {
        guard var requests = requestsByThread[threadID],
              let index = requests.firstIndex(where: { $0.requestID == requestID }) else {
            return nil
        }
        let resolved = requests.remove(at: index)
        if requests.isEmpty {
            requestsByThread.removeValue(forKey: threadID)
        } else {
            requestsByThread[threadID] = requests
        }
        return resolved
    }

    mutating func removeAll() {
        requestsByThread.removeAll()
    }
}

enum CodexUserInputPresentation {
    static func session(
        _ sourceSession: SessionState,
        request: CodexUserInputRequest?
    ) -> SessionState {
        guard sourceSession.source == .codex,
              sourceSession.activePermission == nil,
              let request else {
            return sourceSession
        }
        var presentationSession = sourceSession
        presentationSession.phase = .waitingForApproval(PermissionContext(
            toolUseId: request.attentionToolUseID,
            toolName: CodexUserInputRequest.toolName,
            toolInput: nil,
            receivedAt: request.receivedAt,
            requestID: request.uiToken
        ))
        return presentationSession
    }
}

enum CodexAppServerIncomingMessage {
    case request(id: CodexJSONRPCID, method: String, params: [String: Any])
    case notification(method: String, params: [String: Any])
    case response(id: CodexJSONRPCID, succeeded: Bool)
}

enum CodexQuestionAnswerPolicy {
    static func canSubmit(
        _ answers: [String: [String]],
        questions: [CodexUserInputQuestion]
    ) -> Bool {
        guard !questions.isEmpty else { return false }
        let questionIDs = questions.map(\.id)
        guard questionIDs.allSatisfy({ !$0.isEmpty }),
              Set(questionIDs).count == questionIDs.count,
              Set(answers.keys) == Set(questionIDs) else {
            return false
        }

        return questions.allSatisfy { question in
            guard let values = answers[question.id],
                  !values.isEmpty,
                  values.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                return false
            }

            let optionLabels = Set(question.selectableOptions.map(\.label))
            if values.allSatisfy(optionLabels.contains) {
                return Set(values).count == values.count
            }
            return question.allowsCustomAnswer && values.count == 1
        }
    }
}

enum CodexAppServerQuestionProtocol {
    private struct UserInputParams: Decodable {
        let threadId: String
        let turnId: String
        let itemId: String
        let questions: [CodexUserInputQuestion]
        let isBlocking: Bool
        let autoResolutionMs: Int?
    }

    private struct ResolvedParams: Decodable {
        let threadId: String
        let requestId: CodexJSONRPCID
    }

    static func decodeMessage(_ data: Data) -> CodexAppServerIncomingMessage? {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let envelope = object as? [String: Any] else {
            return nil
        }

        let method = envelope["method"] as? String
        let id = CodexJSONRPCID.parse(envelope["id"])
        if let method, let id, let params = envelope["params"] as? [String: Any] {
            return .request(id: id, method: method, params: params)
        }
        if let method, let params = envelope["params"] as? [String: Any] {
            return .notification(method: method, params: params)
        }
        if let id {
            return .response(
                id: id,
                succeeded: envelope["error"] == nil && envelope["result"] != nil
            )
        }
        return nil
    }

    static func decodeUserInputRequest(
        _ data: Data,
        receivedAt: Date = Date(),
        uiToken: UUID = UUID()
    ) -> CodexUserInputRequest? {
        guard case .request(let requestID, "item/tool/requestUserInput", let rawParams) = decodeMessage(data),
              let paramsData = try? JSONSerialization.data(withJSONObject: rawParams),
              let params = try? JSONDecoder().decode(UserInputParams.self, from: paramsData),
              !params.threadId.isEmpty,
              !params.turnId.isEmpty,
              !params.itemId.isEmpty,
              !params.questions.isEmpty else {
            return nil
        }

        let ids = params.questions.map(\.id)
        guard ids.allSatisfy({ !$0.isEmpty }), Set(ids).count == ids.count else {
            return nil
        }

        return CodexUserInputRequest(
            requestID: requestID,
            uiToken: uiToken,
            threadID: params.threadId,
            turnID: params.turnId,
            itemID: params.itemId,
            questions: params.questions,
            isBlocking: params.isBlocking,
            autoResolutionMs: params.autoResolutionMs,
            receivedAt: receivedAt
        )
    }

    static func decodeResolvedNotification(_ data: Data) -> CodexResolvedServerRequest? {
        guard case .notification("serverRequest/resolved", let rawParams) = decodeMessage(data),
              let paramsData = try? JSONSerialization.data(withJSONObject: rawParams),
              let params = try? JSONDecoder().decode(ResolvedParams.self, from: paramsData),
              !params.threadId.isEmpty else {
            return nil
        }
        return CodexResolvedServerRequest(
            threadID: params.threadId,
            requestID: params.requestId
        )
    }

    static func answerLine(
        request: CodexUserInputRequest,
        answers: [String: [String]]
    ) -> Data? {
        guard CodexQuestionAnswerPolicy.canSubmit(answers, questions: request.questions) else {
            return nil
        }
        let answerPayload = answers.mapValues { ["answers": $0] }
        let envelope: [String: Any] = [
            "jsonrpc": "2.0",
            "id": request.requestID.jsonValue,
            "result": ["answers": answerPayload]
        ]
        guard var data = try? JSONSerialization.data(
            withJSONObject: envelope,
            options: [.sortedKeys]
        ) else {
            return nil
        }
        data.append(0x0A)
        return data
    }

    static func initializeLine(requestID: Int64, version: String) -> Data? {
        requestLine(
            id: .integer(requestID),
            method: "initialize",
            params: [
                "clientInfo": [
                    "name": "agent-notch",
                    "title": "Agent Notch",
                    "version": version
                ],
                "capabilities": ["experimentalApi": true]
            ]
        )
    }

    static func initializedLine() -> Data? {
        var data = Data(#"{"jsonrpc":"2.0","method":"initialized"}"#.utf8)
        data.append(0x0A)
        return data
    }

    static func resumeLine(requestID: Int64, threadID: String) -> Data? {
        requestLine(
            id: .integer(requestID),
            method: "thread/resume",
            params: ["threadId": threadID, "excludeTurns": true]
        )
    }

    private static func requestLine(
        id: CodexJSONRPCID,
        method: String,
        params: [String: Any]
    ) -> Data? {
        let envelope: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id.jsonValue,
            "method": method,
            "params": params
        ]
        guard var data = try? JSONSerialization.data(withJSONObject: envelope) else {
            return nil
        }
        data.append(0x0A)
        return data
    }

}

@MainActor
final class CodexUserInputDraft: ObservableObject {
    let questions: [CodexUserInputQuestion]
    @Published private(set) var selectedOptions: [Int: String] = [:]
    @Published private(set) var customAnswers: [Int: String] = [:]
    @Published private(set) var currentQuestionIndex = 0

    init(questions: [CodexUserInputQuestion]) {
        self.questions = questions
    }

    func move(by offset: Int) {
        currentQuestionIndex = min(
            max(0, currentQuestionIndex + offset),
            max(0, questions.count - 1)
        )
    }

    func selectOption(_ label: String, at index: Int) {
        guard questions.indices.contains(index),
              questions[index].selectableOptions.contains(where: { $0.label == label }) else {
            return
        }
        selectedOptions[index] = label
        customAnswers[index] = ""
    }

    func setCustomAnswer(_ value: String, at index: Int) {
        guard questions.indices.contains(index),
              questions[index].allowsCustomAnswer else { return }
        customAnswers[index] = value
        if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            selectedOptions[index] = nil
        }
    }

    func answer(at index: Int) -> String {
        guard questions.indices.contains(index) else { return "" }
        let custom = customAnswers[index, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? selectedOptions[index, default: ""] : custom
    }

    var compiledAnswers: [String: [String]]? {
        guard !questions.isEmpty,
              Set(questions.map(\.id)).count == questions.count else { return nil }
        var answers: [String: [String]] = [:]
        for index in questions.indices {
            let value = answer(at: index)
            guard !value.isEmpty else { return nil }
            answers[questions[index].id] = [value]
        }
        return CodexQuestionAnswerPolicy.canSubmit(answers, questions: questions)
            ? answers
            : nil
    }
}
