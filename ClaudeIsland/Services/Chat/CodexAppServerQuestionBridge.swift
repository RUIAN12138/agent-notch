// Copyright (c) OpenAI. All rights reserved.
// Experimental, opt-in client for native Codex request_user_input events.

import Combine
import Foundation

enum CodexAppServerQuestionBridgeState: Equatable {
    case disabled
    case waitingForSession
    case connecting
    case connected
    case unavailable

    func description(language: AppLanguage) -> String {
        switch self {
        case .disabled:
            language.text("Disabled", "已关闭")
        case .waitingForSession:
            language.text("Waiting for an active Codex task", "等待活动中的 Codex 任务")
        case .connecting:
            language.text("Connecting to the existing Codex service…", "正在连接已运行的 Codex 服务…")
        case .connected:
            language.text("Connected to the existing Codex service", "已连接到正在运行的 Codex 服务")
        case .unavailable:
            language.text("Unavailable; answer in Codex instead", "服务不可用，请回到 Codex 中回答")
        }
    }
}

@MainActor
final class CodexAppServerQuestionBridge: ObservableObject {
    static let shared = CodexAppServerQuestionBridge()

    @Published private(set) var activeRequestsBySession: [String: [CodexUserInputRequest]] = [:]
    @Published private(set) var submittingRequestTokens: Set<UUID> = []
    @Published private(set) var state: CodexAppServerQuestionBridgeState = .disabled

    private var proxy: CodexAppServerProxyProcess?
    private var activeThreadIDs: Set<String> = []
    private var desiredThreadIDs: Set<String> = []
    private var resumedThreadIDs: Set<String> = []
    private var pendingClientRequests: [CodexJSONRPCID: ClientRequestPurpose] = [:]
    private var nextClientRequestID: Int64 = 1
    private var stdoutBuffer = Data()
    private var initializationTimeoutTask: Task<Void, Never>?
    private var answerTimeoutTasks: [UUID: Task<Void, Never>] = [:]
    private var requestQueue = CodexUserInputRequestQueue()
    private var enabled = false
    private var attemptedInCurrentEnableCycle = false

    private enum ClientRequestPurpose {
        case initialize
        case resume(threadID: String)
    }

    private init() {}

    func request(for sessionID: String) -> CodexUserInputRequest? {
        requestQueue.firstRequest(for: sessionID)
    }

    func isSubmitting(_ request: CodexUserInputRequest) -> Bool {
        submittingRequestTokens.contains(request.uiToken)
    }

    /// Connect only while the user has explicitly enabled this feature and an
    /// active Codex task exists. `codex app-server proxy` forwards to an
    /// already-running service; this code never launches or restarts one.
    func reconcile(sessions: [SessionState], enabled shouldEnable: Bool) {
        guard shouldEnable else {
            disable()
            return
        }
        enabled = true

        let activeCodexThreads = Set(sessions.compactMap { session -> String? in
            guard session.source == .codex,
                  session.completedAt == nil,
                  session.phase.isActive || session.phase.isWaitingForApproval else {
                return nil
            }
            return session.sessionId
        })
        activeThreadIDs = activeCodexThreads
        desiredThreadIDs = activeThreadIDs.union(activeRequestsBySession.keys)

        guard !desiredThreadIDs.isEmpty else {
            attemptedInCurrentEnableCycle = false
            resumedThreadIDs.removeAll()
            pendingClientRequests.removeAll()
            closeProxy()
            state = .waitingForSession
            return
        }

        if proxy == nil {
            guard !attemptedInCurrentEnableCycle else { return }
            attemptedInCurrentEnableCycle = true
            startProxy()
            return
        }

        resumeNewThreadsIfReady()
    }

    /// Respond to one exact outstanding server request. A failed write leaves
    /// the request available so the user can retry in Codex itself.
    @discardableResult
    func answer(
        sessionID: String,
        expectedToken: UUID,
        answers: [String: [String]]
    ) -> Bool {
        guard enabled,
              state == .connected,
              let request = activeRequestsBySession[sessionID]?.first(where: {
                  $0.uiToken == expectedToken
              }),
              !submittingRequestTokens.contains(expectedToken),
              let line = CodexAppServerQuestionProtocol.answerLine(
                  request: request,
                  answers: answers
              ),
              let proxy else {
            return false
        }

        do {
            try proxy.send(line)
            submittingRequestTokens.insert(expectedToken)
            answerTimeoutTasks[expectedToken]?.cancel()
            answerTimeoutTasks[expectedToken] = Task { [weak self] in
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled, let self,
                      self.submittingRequestTokens.contains(expectedToken) else {
                    return
                }
                self.submittingRequestTokens.remove(expectedToken)
                self.answerTimeoutTasks.removeValue(forKey: expectedToken)
            }
            return true
        } catch {
            return false
        }
    }

    func disable() {
        guard enabled || proxy != nil || state != .disabled ||
                !activeRequestsBySession.isEmpty || !submittingRequestTokens.isEmpty else {
            return
        }
        enabled = false
        attemptedInCurrentEnableCycle = false
        activeThreadIDs.removeAll()
        desiredThreadIDs.removeAll()
        resumedThreadIDs.removeAll()
        pendingClientRequests.removeAll()
        clearRequests()
        closeProxy()
        state = .disabled
    }

    private func startProxy() {
        guard let executablePath = AgentExecutableLocator.executablePath(named: "codex") else {
            state = .unavailable
            return
        }

        state = .connecting
        let process = CodexAppServerProxyProcess()
        process.onData = { [weak self] data in
            self?.consume(data)
        }
        process.onTermination = { [weak self] in
            self?.proxyDidTerminate()
        }
        do {
            try process.start(executablePath: executablePath)
            proxy = process
            let requestID = makeClientRequestID()
            pendingClientRequests[requestID] = .initialize
            guard let line = CodexAppServerQuestionProtocol.initializeLine(
                requestID: requestID.integerValue,
                version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
            ) else {
                failConnection()
                return
            }
            try process.send(line)
            initializationTimeoutTask?.cancel()
            initializationTimeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, let self,
                      self.state == .connecting else { return }
                self.failConnection()
            }
        } catch {
            state = .unavailable
            process.stop()
            proxy = nil
        }
    }

    private func consume(_ data: Data) {
        guard !data.isEmpty else { return }
        stdoutBuffer.append(data)
        guard stdoutBuffer.count <= 2 * 1024 * 1024 else {
            failConnection()
            return
        }

        let newline = Data([0x0A])
        while let range = stdoutBuffer.range(of: newline) {
            var line = Data(stdoutBuffer[..<range.lowerBound])
            stdoutBuffer.removeSubrange(...range.lowerBound)
            if line.last == 0x0D { line.removeLast() }
            guard !line.isEmpty else { continue }
            handle(line)
        }
    }

    private func handle(_ line: Data) {
        guard let message = CodexAppServerQuestionProtocol.decodeMessage(line) else {
            return
        }
        switch message {
        case .response(let id, let succeeded):
            handleClientResponse(id: id, succeeded: succeeded)
        case .request(_, let method, _):
            guard method == "item/tool/requestUserInput",
                  let request = CodexAppServerQuestionProtocol.decodeUserInputRequest(line),
                  desiredThreadIDs.contains(request.threadID) else {
                // Do not invent an approval/denial for another app-server
                // request. The Codex client that owns that interaction remains
                // the authority for its decision.
                return
            }
            enqueue(request)
        case .notification(let method, _):
            guard method == "serverRequest/resolved",
                  let resolved = CodexAppServerQuestionProtocol.decodeResolvedNotification(line) else {
                return
            }
            resolve(resolved)
        }
    }

    private func handleClientResponse(id: CodexJSONRPCID, succeeded: Bool) {
        guard let purpose = pendingClientRequests.removeValue(forKey: id) else { return }
        switch purpose {
        case .initialize:
            initializationTimeoutTask?.cancel()
            initializationTimeoutTask = nil
            guard succeeded,
                  let line = CodexAppServerQuestionProtocol.initializedLine(),
                  let proxy else {
                failConnection()
                return
            }
            do {
                try proxy.send(line)
                state = .connected
                resumeNewThreadsIfReady()
            } catch {
                failConnection()
            }
        case .resume(let threadID):
            if succeeded {
                resumedThreadIDs.insert(threadID)
            }
        }
    }

    private func resumeNewThreadsIfReady() {
        guard enabled, state == .connected, let proxy else { return }
        for threadID in desiredThreadIDs.subtracting(resumedThreadIDs) {
            let requestID = makeClientRequestID()
            pendingClientRequests[requestID] = .resume(threadID: threadID)
            guard let line = CodexAppServerQuestionProtocol.resumeLine(
                requestID: requestID.integerValue,
                threadID: threadID
            ) else {
                pendingClientRequests.removeValue(forKey: requestID)
                continue
            }
            do {
                try proxy.send(line)
                // Record the attempt before waiting for a response, preventing
                // rapid session publications from duplicating thread/resume.
                resumedThreadIDs.insert(threadID)
            } catch {
                pendingClientRequests.removeValue(forKey: requestID)
                failConnection()
                return
            }
        }
    }

    private func enqueue(_ request: CodexUserInputRequest) {
        guard requestQueue.enqueue(request) else { return }
        activeRequestsBySession = requestQueue.requestsByThread
    }

    private func resolve(_ resolved: CodexResolvedServerRequest) {
        guard let request = requestQueue.resolve(
            threadID: resolved.threadID,
            requestID: resolved.requestID
        ) else {
            return
        }
        submittingRequestTokens.remove(request.uiToken)
        answerTimeoutTasks.removeValue(forKey: request.uiToken)?.cancel()
        activeRequestsBySession = requestQueue.requestsByThread
        desiredThreadIDs = activeThreadIDs.union(activeRequestsBySession.keys)
    }

    private func makeClientRequestID() -> CodexJSONRPCID {
        defer { nextClientRequestID &+= 1 }
        return .integer(nextClientRequestID)
    }

    private func failConnection() {
        initializationTimeoutTask?.cancel()
        initializationTimeoutTask = nil
        pendingClientRequests.removeAll()
        resumedThreadIDs.removeAll()
        clearRequests()
        closeProxy()
        state = .unavailable
    }

    private func proxyDidTerminate() {
        guard enabled else { return }
        pendingClientRequests.removeAll()
        resumedThreadIDs.removeAll()
        clearRequests()
        let oldProxy = proxy
        proxy = nil
        oldProxy?.stop()
        state = .unavailable
    }

    private func clearRequests() {
        answerTimeoutTasks.values.forEach { $0.cancel() }
        answerTimeoutTasks.removeAll()
        if !submittingRequestTokens.isEmpty {
            submittingRequestTokens.removeAll()
        }
        if !activeRequestsBySession.isEmpty {
            activeRequestsBySession.removeAll()
        }
        requestQueue.removeAll()
    }

    private func closeProxy() {
        initializationTimeoutTask?.cancel()
        initializationTimeoutTask = nil
        let oldProxy = proxy
        proxy = nil
        oldProxy?.stop()
    }
}

@MainActor
private final class CodexAppServerProxyProcess {
    var onData: ((Data) -> Void)?
    var onTermination: (() -> Void)?

    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var outputContinuation: AsyncStream<Data>.Continuation?
    private var readerTask: Task<Void, Never>?
    private var isStopping = false

    func start(executablePath: String) throws {
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let (stream, continuation) = AsyncStream<Data>.makeStream()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["app-server", "proxy"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        self.process = process
        inputPipe = input
        outputPipe = output
        outputContinuation = continuation
        readerTask = Task { @MainActor [weak self] in
            for await data in stream {
                guard !Task.isCancelled else { break }
                self?.onData?(data)
            }
        }
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isStopping else { return }
                self.onTermination?()
            }
        }

        output.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                continuation.finish()
            } else {
                continuation.yield(data)
            }
        }

        try process.run()
    }

    func send(_ data: Data) throws {
        guard process?.isRunning == true,
              let handle = inputPipe?.fileHandleForWriting else {
            throw AgentTransportError.messagingUnsupported(agentName: "Codex app-server")
        }
        try handle.write(contentsOf: data)
    }

    func stop() {
        guard !isStopping else { return }
        isStopping = true
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputContinuation?.finish()
        readerTask?.cancel()
        if let process, process.isRunning {
            process.terminate()
        }
        try? inputPipe?.fileHandleForWriting.close()
        process?.terminationHandler = nil
        process = nil
        inputPipe = nil
        outputPipe = nil
        outputContinuation = nil
        readerTask = nil
    }
}

private extension CodexJSONRPCID {
    var integerValue: Int64 {
        guard case .integer(let value) = self else { return 0 }
        return value
    }
}
