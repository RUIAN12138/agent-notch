//
//  Modified by lihao505 for Agent Notch, 2026.
//  SessionState.swift
//  ClaudeIsland
//
//  Unified state model for a Claude session.
//  Consolidates all state that was previously spread across multiple components.
//

import Foundation

/// Complete state for a single Claude session
/// This is the single source of truth - all state reads and writes go through SessionStore
struct SessionState: Equatable, Identifiable, Sendable {
    // MARK: - Identity

    let sessionId: String
    let cwd: String
    let projectName: String
    var source: AgentSource

    // MARK: - Instance Metadata

    var pid: Int?
    var tty: String?
    var isInTmux: Bool

    // MARK: - State Machine

    /// Current phase in the session lifecycle
    var phase: SessionPhase

    /// Every live approval/question/plan request for this session, in arrival
    /// order. `phase` presents the queue head; the queue prevents parallel
    /// requests from overwriting or hiding one another.
    var pendingInteractions: PendingInteractionQueue

    // MARK: - Chat History

    /// All chat items for this session (replaces ChatHistoryManager.histories)
    var chatItems: [ChatHistoryItem]

    // MARK: - Tool Tracking

    /// Unified tool tracker (replaces 6+ dictionaries in ChatHistoryManager)
    var toolTracker: ToolTracker

    // MARK: - Subagent State

    /// State for Task tools and their nested subagent tools
    var subagentState: SubagentState

    // MARK: - Conversation Info (from JSONL parsing)

    var conversationInfo: ConversationInfo

    // MARK: - Clear Reconciliation

    /// When true, the next file update should reconcile chatItems with parser state
    /// This removes pre-/clear items that no longer exist in the JSONL
    var needsClearReconciliation: Bool
    /// Identity of this in-memory history incarnation. Clear and recreation
    /// invalidate asynchronous reads, but ordinary turns retain valid history.
    var historyGeneration = UUID()
    var needsFullHistorySync = true

    // MARK: - Timestamps

    var lastActivity: Date
    var createdAt: Date
    /// Latest bridge event that was allowed to change the lifecycle phase.
    /// Tool bookkeeping may still accept older events, but their phase cannot
    /// overwrite a newer Stop, permission request, or new-turn signal.
    var lastHookEventAt: Date?
    /// Native Codex boundary for the currently observed turn. Unlike token or
    /// tool activity, this changes only when a genuinely new turn starts.
    var lastCodexTurnStartedAt: Date?
    /// Start of a Codex tool call still lacking a durable result. This lets
    /// lifecycle arbitration tolerate long-running tools without extending the
    /// stale timeout for ordinary turns.
    var codexToolExecutionStartedAt: Date?
    /// Set only after a turn has actually produced its completion signal.
    /// A newly launched session that is merely waiting for its first prompt is
    /// not considered completed.
    var completedAt: Date?
    /// True when `completedAt` is a synthetic boundary produced by a stale
    /// activity timeout rather than an authoritative completion signal.
    /// A later durable Codex tool call may reopen only this kind of boundary.
    var completionWasStaleTimeout: Bool

    /// Latest accepted Claude SubagentStop event. The generation is an
    /// in-memory event cursor so SwiftUI can observe a Hook transition even
    /// when several SessionStore publications are coalesced into one frame.
    var subagentCompletionGeneration: UInt64
    var lastSubagentCompletedAt: Date?
    /// Identity-aware Hook state supports exact pairing of parallel Claude
    /// SubagentStart/SubagentStop events, including app relaunch recovery.
    var subagentHookState: SubagentHookState
    /// Separate cursor for the transition from one-or-more active agents to
    /// none. It is intentionally not inferred from an unmatched Stop event.
    var allSubagentsFinishedGeneration: UInt64
    var lastAllSubagentsFinishedAt: Date?
    /// Cursor for the root response after a turn that actually used subagents.
    var subagentRootResponseGeneration: UInt64
    var lastSubagentRootResponseAt: Date?

    // MARK: - Identifiable

    var id: String { sessionId }

    // MARK: - Initialization

    nonisolated init(
        sessionId: String,
        cwd: String,
        projectName: String? = nil,
        source: AgentSource = .claude,
        pid: Int? = nil,
        tty: String? = nil,
        isInTmux: Bool = false,
        phase: SessionPhase = .idle,
        pendingInteractions: PendingInteractionQueue = PendingInteractionQueue(),
        chatItems: [ChatHistoryItem] = [],
        toolTracker: ToolTracker = ToolTracker(),
        subagentState: SubagentState = SubagentState(),
        conversationInfo: ConversationInfo = ConversationInfo(
            summary: nil, lastMessage: nil, lastMessageRole: nil,
            lastToolName: nil, firstUserMessage: nil, lastUserMessageDate: nil
        ),
        needsClearReconciliation: Bool = false,
        lastActivity: Date = Date(),
        createdAt: Date = Date(),
        lastHookEventAt: Date? = nil,
        lastCodexTurnStartedAt: Date? = nil,
        codexToolExecutionStartedAt: Date? = nil,
        completedAt: Date? = nil,
        completionWasStaleTimeout: Bool = false,
        subagentCompletionGeneration: UInt64 = 0,
        lastSubagentCompletedAt: Date? = nil,
        subagentHookState: SubagentHookState = SubagentHookState(),
        allSubagentsFinishedGeneration: UInt64 = 0,
        lastAllSubagentsFinishedAt: Date? = nil,
        subagentRootResponseGeneration: UInt64 = 0,
        lastSubagentRootResponseAt: Date? = nil
    ) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.projectName = projectName ?? URL(fileURLWithPath: cwd).lastPathComponent
        self.source = source
        self.pid = pid
        self.tty = tty
        self.isInTmux = isInTmux
        self.phase = phase
        self.pendingInteractions = pendingInteractions
        self.chatItems = chatItems
        self.toolTracker = toolTracker
        self.subagentState = subagentState
        self.conversationInfo = conversationInfo
        self.needsClearReconciliation = needsClearReconciliation
        self.lastActivity = lastActivity
        self.createdAt = createdAt
        self.lastHookEventAt = lastHookEventAt
        self.lastCodexTurnStartedAt = lastCodexTurnStartedAt
        self.codexToolExecutionStartedAt = codexToolExecutionStartedAt
        self.completedAt = completedAt
        self.completionWasStaleTimeout = completionWasStaleTimeout
        self.subagentCompletionGeneration = subagentCompletionGeneration
        self.lastSubagentCompletedAt = lastSubagentCompletedAt
        self.subagentHookState = subagentHookState
        self.allSubagentsFinishedGeneration = allSubagentsFinishedGeneration
        self.lastAllSubagentsFinishedAt = lastAllSubagentsFinishedAt
        self.subagentRootResponseGeneration = subagentRootResponseGeneration
        self.lastSubagentRootResponseAt = lastSubagentRootResponseAt
        if let completedAt {
            self.toolTracker.recordTerminalBoundary(completedAt)
        }
    }

    /// Identity-less Hook payloads have no agent key to deduplicate against,
    /// so retain timestamp idempotence for that compatibility path.
    nonisolated mutating func recordSubagentCompletion(at observedAt: Date) {
        guard observedAt > (lastSubagentCompletedAt ?? .distantPast) else {
            return
        }
        subagentCompletionGeneration &+= 1
        lastSubagentCompletedAt = observedAt
    }

    /// Exact agent IDs are deduplicated by `SubagentHookState`; distinct
    /// agents may legitimately finish at the same source timestamp.
    nonisolated mutating func recordMatchedSubagentCompletion(at observedAt: Date) {
        subagentCompletionGeneration &+= 1
        lastSubagentCompletedAt = max(
            lastSubagentCompletedAt ?? .distantPast,
            observedAt
        )
    }

    nonisolated mutating func recordAllSubagentsFinished(at observedAt: Date) {
        allSubagentsFinishedGeneration &+= 1
        lastAllSubagentsFinishedAt = max(
            lastAllSubagentsFinishedAt ?? .distantPast,
            observedAt
        )
    }

    nonisolated mutating func recordSubagentRootResponse(at observedAt: Date) {
        subagentRootResponseGeneration &+= 1
        lastSubagentRootResponseAt = observedAt
    }

    // MARK: - Derived Properties

    /// Whether this session needs user attention
    var needsAttention: Bool {
        phase.needsAttention
    }

    /// The active permission context, if any
    var activePermission: PermissionContext? {
        if case .waitingForApproval(let ctx) = phase {
            return ctx
        }
        return nil
    }

    // MARK: - UI Convenience Properties

    /// Stable identity for SwiftUI (combines PID and sessionId for animation stability)
    var stableId: String {
        if let pid = pid {
            return "\(pid)-\(sessionId)"
        }
        return sessionId
    }

    /// Display title: summary > first user message > project name
    var displayTitle: String {
        conversationInfo.summary ?? conversationInfo.firstUserMessage ?? projectName
    }

    /// Best hint for matching window title
    var windowHint: String {
        conversationInfo.summary ?? projectName
    }

    /// Pending tool name if waiting for approval
    var pendingToolName: String? {
        activePermission?.toolName
    }

    /// Pending tool use ID
    var pendingToolId: String? {
        activePermission?.toolUseId
    }

    /// Formatted pending tool input for display
    var pendingToolInput: String? {
        activePermission?.formattedInput
    }

    /// Last message content
    var lastMessage: String? {
        conversationInfo.lastMessage
    }

    /// Last message role
    var lastMessageRole: String? {
        conversationInfo.lastMessageRole
    }

    /// Last tool name
    var lastToolName: String? {
        conversationInfo.lastToolName
    }

    /// Summary
    var summary: String? {
        conversationInfo.summary
    }

    /// First user message
    var firstUserMessage: String? {
        conversationInfo.firstUserMessage
    }

    /// Last user message date
    var lastUserMessageDate: Date? {
        conversationInfo.lastUserMessageDate
    }

    /// Token usage for this session
    var usage: UsageInfo {
        conversationInfo.usage
    }

    /// Whether the session can be interacted with
    var canInteract: Bool {
        phase.needsAttention
    }
}

/// Completed rows are deliberately scarce: one recent result can remain for
/// context, but active work always owns the notch when the list gets busy.
nonisolated enum SessionRetentionPolicy {
    static let completedLifetime: TimeInterval = 5 * 60 * 60
    static let maximumVisibleCompleted = 1
    static let activeCrowdingThreshold = 2
    static let missingCodexGracePeriod: TimeInterval = 30

    /// CodexBar starts short-lived Claude CLI probes to read account status.
    /// They are health checks rather than user conversations and must never
    /// become task cards.
    static func isIgnoredProbe(
        source: AgentSource,
        cwd: String,
        projectName: String
    ) -> Bool {
        source == .claude &&
            projectName == "ClaudeProbe" &&
            cwd.contains("/Application Support/CodexBar/ClaudeProbe")
    }
}

// MARK: - Tool Tracker

/// Unified tool tracking - replaces multiple dictionaries in ChatHistoryManager
struct ToolTracker: Equatable, Sendable {
    /// Latest accepted Stop/interrupt/exit boundary. Unlike completedAt, this
    /// survives the next turn so delayed history cannot recreate old spinners.
    var terminalBoundaryAt: Date?

    /// Tools currently in progress, keyed by tool_use_id
    var inProgress: [String: ToolInProgress]

    /// All tool IDs we've seen (for deduplication)
    var seenIds: Set<String>

    /// Last JSONL file offset for incremental parsing
    var lastSyncOffset: UInt64

    /// Last sync timestamp
    var lastSyncTime: Date?

    nonisolated init(
        inProgress: [String: ToolInProgress] = [:],
        seenIds: Set<String> = [],
        lastSyncOffset: UInt64 = 0,
        lastSyncTime: Date? = nil,
        terminalBoundaryAt: Date? = nil
    ) {
        self.inProgress = inProgress
        self.seenIds = seenIds
        self.lastSyncOffset = lastSyncOffset
        self.lastSyncTime = lastSyncTime
        self.terminalBoundaryAt = terminalBoundaryAt
    }

    nonisolated mutating func recordTerminalBoundary(_ time: Date) {
        terminalBoundaryAt = max(terminalBoundaryAt ?? .distantPast, time)
    }

    /// Mark a tool ID as seen, returns true if it was new
    nonisolated mutating func markSeen(_ id: String) -> Bool {
        seenIds.insert(id).inserted
    }

    /// Check if a tool ID has been seen
    nonisolated func hasSeen(_ id: String) -> Bool {
        seenIds.contains(id)
    }

    /// Start tracking a tool
    nonisolated mutating func startTool(id: String, name: String) {
        guard markSeen(id) else { return }
        inProgress[id] = ToolInProgress(
            id: id,
            name: name,
            startTime: Date(),
            phase: .running
        )
    }

    /// Complete a tool
    nonisolated mutating func completeTool(id: String, success: Bool) {
        inProgress.removeValue(forKey: id)
    }
}

/// Minimal identity cursor for Claude's SubagentStart/SubagentStop Hook pair.
/// The bridge persists this map in its privacy-minimized session snapshot, so
/// an app launched mid-run still knows which exact agents remain active.
nonisolated struct SubagentHookAgentState: Codable, Equatable, Sendable {
    var isActive: Bool
    var observedAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case isActive = "active"
        case observedAt = "observed_at"
    }
}

nonisolated struct SubagentStopObservation: Equatable, Sendable {
    let shouldPresentIndividualCompletion: Bool
    let completedAllActiveAgents: Bool
}

nonisolated struct SubagentHookState: Codable, Equatable, Sendable {
    private(set) var agents: [String: SubagentHookAgentState]
    private(set) var hasAgentActivityInCurrentTurn: Bool
    private(set) var rootTurnStartedAt: TimeInterval?
    private(set) var lastRootResponseAt: TimeInterval?

    init(
        agents: [String: SubagentHookAgentState] = [:],
        hasAgentActivityInCurrentTurn: Bool = false,
        rootTurnStartedAt: TimeInterval? = nil,
        lastRootResponseAt: TimeInterval? = nil
    ) {
        self.agents = agents.filter { id, state in
            !id.isEmpty && id.count <= 256 && state.observedAt.isFinite
        }
        self.hasAgentActivityInCurrentTurn = hasAgentActivityInCurrentTurn
        self.rootTurnStartedAt = rootTurnStartedAt.flatMap {
            $0.isFinite ? $0 : nil
        }
        self.lastRootResponseAt = lastRootResponseAt.flatMap {
            $0.isFinite ? $0 : nil
        }
    }

    var activeAgentIDs: Set<String> {
        Set(agents.compactMap { id, state in
            state.isActive ? id : nil
        })
    }

    private var activeAgentIDsInCurrentRootTurn: Set<String> {
        Set(agents.compactMap { id, state in
            guard state.isActive,
                  isCurrentRootTurnAgentState(state) else {
                return nil
            }
            return id
        })
    }

    mutating func observeStart(agentID: String, at observedAt: TimeInterval) {
        guard isValid(agentID: agentID, observedAt: observedAt),
              isInsideCurrentRootTurn(observedAt),
              observedAt > (agents[agentID]?.observedAt ?? -.infinity) else {
            return
        }
        agents[agentID] = SubagentHookAgentState(
            isActive: true,
            observedAt: observedAt
        )
        hasAgentActivityInCurrentTurn = true
        pruneCompletedAgentsIfNeeded()
    }

    mutating func beginRootTurn(at observedAt: TimeInterval) {
        guard observedAt.isFinite,
              observedAt > (rootTurnStartedAt ?? -.infinity),
              observedAt > (lastRootResponseAt ?? -.infinity) else {
            return
        }
        rootTurnStartedAt = observedAt
        hasAgentActivityInCurrentTurn = false
    }

    mutating func consumeRootResponse(at observedAt: TimeInterval) -> Bool {
        guard observedAt.isFinite,
              observedAt >= (rootTurnStartedAt ?? -.infinity),
              observedAt > (lastRootResponseAt ?? -.infinity) else {
            return false
        }
        let hadAgentActivity = hasAgentActivityInCurrentTurn
        hasAgentActivityInCurrentTurn = false
        lastRootResponseAt = observedAt
        return hadAgentActivity
    }

    mutating func observeStop(
        agentID: String,
        at observedAt: TimeInterval
    ) -> SubagentStopObservation {
        guard isValid(agentID: agentID, observedAt: observedAt),
              observedAt >= (rootTurnStartedAt ?? -.infinity),
              observedAt > (agents[agentID]?.observedAt ?? -.infinity) else {
            return SubagentStopObservation(
                shouldPresentIndividualCompletion: false,
                completedAllActiveAgents: false
            )
        }

        let previous = agents[agentID]
        // A child can outlive its root response. If a new root turn starts
        // before that old child stops, its completion must not count as
        // activity (or "all done") for the new turn.
        let completedCurrentTurnAgent = previous.map {
            $0.isActive && isCurrentRootTurnAgentState($0)
        } ?? false
        let hadAnyActiveAgents = !activeAgentIDsInCurrentRootTurn.isEmpty
        agents[agentID] = SubagentHookAgentState(
            isActive: false,
            observedAt: observedAt
        )
        let hasNoActiveAgents = activeAgentIDsInCurrentRootTurn.isEmpty
        pruneCompletedAgentsIfNeeded()
        let mayNotifyForCurrentTurn = isInsideCurrentRootTurn(observedAt)
        let rootAlreadyRespondedToCurrentTurn: Bool
        if let rootTurnStartedAt {
            rootAlreadyRespondedToCurrentTurn =
                (lastRootResponseAt ?? -.infinity) >= rootTurnStartedAt
        } else {
            rootAlreadyRespondedToCurrentTurn = lastRootResponseAt != nil
        }
        return SubagentStopObservation(
            // An unmatched first Stop is useful for per-agent attention after
            // launching mid-run, but only before a root response. Once the
            // root has responded, require a matched active identity.
            shouldPresentIndividualCompletion:
                mayNotifyForCurrentTurn &&
                    (completedCurrentTurnAgent ||
                        (previous == nil && !rootAlreadyRespondedToCurrentTurn)),
            completedAllActiveAgents:
                mayNotifyForCurrentTurn && completedCurrentTurnAgent &&
                    hadAnyActiveAgents && hasNoActiveAgents
        )
    }

    private func isValid(agentID: String, observedAt: TimeInterval) -> Bool {
        !agentID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            agentID.count <= 256 && observedAt.isFinite
    }

    private func isInsideCurrentRootTurn(_ observedAt: TimeInterval) -> Bool {
        observedAt >= (rootTurnStartedAt ?? -.infinity) &&
            observedAt > (lastRootResponseAt ?? -.infinity)
    }

    private func isCurrentRootTurnAgentState(
        _ state: SubagentHookAgentState
    ) -> Bool {
        guard let rootTurnStartedAt else { return true }
        return state.observedAt >= rootTurnStartedAt
    }

    private mutating func pruneCompletedAgentsIfNeeded() {
        guard agents.count > 512 else { return }
        let completed = agents
            .filter { !$0.value.isActive }
            .sorted { $0.value.observedAt < $1.value.observedAt }
        for (agentID, _) in completed.prefix(agents.count - 512) {
            agents.removeValue(forKey: agentID)
        }
    }
}

/// A tool currently in progress
struct ToolInProgress: Equatable, Sendable {
    let id: String
    let name: String
    let startTime: Date
    var phase: ToolInProgressPhase
}

/// Phase of a tool in progress
enum ToolInProgressPhase: Equatable, Sendable {
    case starting
    case running
    case pendingApproval
}

// MARK: - Subagent State

/// State for Task (subagent) tools
struct SubagentState: Equatable, Sendable {
    /// Active Task tools, keyed by task tool_use_id
    var activeTasks: [String: TaskContext]

    /// Ordered stack of active task IDs (most recent last) - used for proper tool assignment
    /// When multiple Tasks run in parallel, we use insertion order rather than timestamps
    var taskStack: [String]

    /// Mapping of agentId to Task description (for AgentOutputTool display)
    var agentDescriptions: [String: String]

    nonisolated init(activeTasks: [String: TaskContext] = [:], taskStack: [String] = [], agentDescriptions: [String: String] = [:]) {
        self.activeTasks = activeTasks
        self.taskStack = taskStack
        self.agentDescriptions = agentDescriptions
    }

    /// Whether there's an active subagent
    nonisolated var hasActiveSubagent: Bool {
        !activeTasks.isEmpty
    }

    /// Start tracking a Task tool
    nonisolated mutating func startTask(taskToolId: String, description: String? = nil) {
        activeTasks[taskToolId] = TaskContext(
            taskToolId: taskToolId,
            startTime: Date(),
            agentId: nil,
            description: description,
            subagentTools: []
        )
    }

    /// Stop tracking a Task tool
    nonisolated mutating func stopTask(taskToolId: String) {
        activeTasks.removeValue(forKey: taskToolId)
    }

    /// Set the agentId for a Task (called when agent file is discovered)
    nonisolated mutating func setAgentId(_ agentId: String, for taskToolId: String) {
        activeTasks[taskToolId]?.agentId = agentId
        if let description = activeTasks[taskToolId]?.description {
            agentDescriptions[agentId] = description
        }
    }

    /// Add a subagent tool to a specific Task by ID
    nonisolated mutating func addSubagentToolToTask(_ tool: SubagentToolCall, taskId: String) {
        activeTasks[taskId]?.subagentTools.append(tool)
    }

    /// Set all subagent tools for a specific Task (used when updating from agent file)
    nonisolated mutating func setSubagentTools(_ tools: [SubagentToolCall], for taskId: String) {
        activeTasks[taskId]?.subagentTools = tools
    }

    /// Add a subagent tool to the most recent active Task
    nonisolated mutating func addSubagentTool(_ tool: SubagentToolCall) {
        // Find most recent active task (for parallel Task support)
        guard let mostRecentTaskId = activeTasks.keys.max(by: {
            (activeTasks[$0]?.startTime ?? .distantPast) < (activeTasks[$1]?.startTime ?? .distantPast)
        }) else { return }

        activeTasks[mostRecentTaskId]?.subagentTools.append(tool)
    }

    /// Update the status of a subagent tool across all active Tasks
    nonisolated mutating func updateSubagentToolStatus(toolId: String, status: ToolStatus) {
        for taskId in activeTasks.keys {
            if let index = activeTasks[taskId]?.subagentTools.firstIndex(where: { $0.id == toolId }) {
                activeTasks[taskId]?.subagentTools[index].status = status
                return
            }
        }
    }
}

/// Context for an active Task tool
struct TaskContext: Equatable, Sendable {
    let taskToolId: String
    let startTime: Date
    var agentId: String?
    var description: String?
    var subagentTools: [SubagentToolCall]
}
