// Ordinary chat drafts are deliberately kept in memory only. The store lives
// beyond a SwiftUI ChatView so closing the notch or rebuilding its window does
// not discard text that has not been sent.
import Combine
import Foundation

struct PendingChatDraft: Equatable, Sendable {
    let sessionId: String
    let textToSend: String
    let id: UUID
    fileprivate let originalText: String
    fileprivate let clearedRevision: UInt64
}

@MainActor
final class ChatDraftStore: ObservableObject {
    static let shared = ChatDraftStore()

    @Published private var drafts: [String: String] = [:]
    @Published private var activeSends: [String: UUID] = [:]
    @Published private var errors: [String: String] = [:]
    @Published private(set) var optimisticHistories: [String: [ChatHistoryItem]] = [:]
    private var revisions: [String: UInt64] = [:]
    private var sendTasks: [String: Task<Void, Never>] = [:]
    private var confirmedNativeIDs: [String: Set<String>] = [:]

    func draft(for sessionId: String) -> String {
        drafts[sessionId] ?? ""
    }

    func setDraft(_ text: String, for sessionId: String) {
        guard text != draft(for: sessionId) else { return }
        revisions[sessionId, default: 0] &+= 1
        if text.isEmpty {
            drafts.removeValue(forKey: sessionId)
        } else {
            drafts[sessionId] = text
        }
    }

    /// Clear only after a nonempty message has been accepted for sending.
    /// Keep the original whitespace for an exact restoration on failure.
    func takeForSending(sessionId: String) -> PendingChatDraft? {
        guard activeSends[sessionId] == nil else { return nil }
        let originalText = draft(for: sessionId)
        let text = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        setDraft("", for: sessionId)
        let sendID = UUID()
        activeSends[sessionId] = sendID
        return PendingChatDraft(
            sessionId: sessionId,
            textToSend: text,
            id: sendID,
            originalText: originalText,
            clearedRevision: revisions[sessionId, default: 0]
        )
    }

    func activeSendID(for sessionId: String) -> UUID? {
        activeSends[sessionId]
    }

    func isSending(sessionId: String) -> Bool {
        activeSends[sessionId] != nil
    }

    func error(for sessionId: String) -> String? {
        errors[sessionId]
    }

    func setError(_ message: String?, for sessionId: String) {
        errors[sessionId] = message
    }

    func optimisticHistory(for sessionId: String) -> [ChatHistoryItem] {
        optimisticHistories[sessionId] ?? []
    }

    func confirmedNativeIDs(for sessionId: String) -> Set<String> {
        confirmedNativeIDs[sessionId] ?? []
    }

    func appendOptimistic(_ item: ChatHistoryItem, for sessionId: String) {
        optimisticHistories[sessionId, default: []].append(item)
    }

    func removeOptimistic(id: String, for sessionId: String) {
        guard var items = optimisticHistories[sessionId] else { return }
        items.removeAll { $0.id == id }
        optimisticHistories[sessionId] = items.isEmpty ? nil : items
    }

    func upsertAssistant(id: String, text: String, for sessionId: String) {
        var items = optimisticHistories[sessionId] ?? []
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index] = ChatHistoryItem(id: id, type: .assistant(text), timestamp: items[index].timestamp)
        } else {
            items.append(ChatHistoryItem(id: id, type: .assistant(text), timestamp: Date()))
        }
        optimisticHistories[sessionId] = items
    }

    /// Drop only the exact optimistic versions that a native snapshot has
    /// confirmed. A streamed row may have advanced since that snapshot.
    func removeConfirmedOptimistic(_ confirmed: [ChatHistoryConfirmation], for sessionId: String) {
        guard !confirmed.isEmpty, var items = optimisticHistories[sessionId] else { return }
        for confirmation in confirmed {
            guard let index = items.firstIndex(of: confirmation.optimistic) else { continue }
            items.remove(at: index)
            // Keep the native ID claimed after pruning. Otherwise one native
            // row could later swallow a second identical optimistic message.
            confirmedNativeIDs[sessionId, default: []].insert(confirmation.nativeID)
        }
        optimisticHistories[sessionId] = items.isEmpty ? nil : items
    }

    func attach(_ task: Task<Void, Never>, to pending: PendingChatDraft) {
        guard activeSends[pending.sessionId] == pending.id else {
            task.cancel()
            return
        }
        sendTasks[pending.sessionId] = task
    }

    func cancelSending(sessionId: String) {
        sendTasks[sessionId]?.cancel()
    }

    func finishSending(_ pending: PendingChatDraft) {
        guard activeSends[pending.sessionId] == pending.id else { return }
        sendTasks.removeValue(forKey: pending.sessionId)
        activeSends.removeValue(forKey: pending.sessionId)
    }

    /// A late failure must not overwrite text edited after the send began,
    /// even if the user subsequently erased that newer text again.
    @discardableResult
    func restoreAfterFailure(_ pending: PendingChatDraft) -> Bool {
        guard revisions[pending.sessionId, default: 0] == pending.clearedRevision,
              draft(for: pending.sessionId).isEmpty else { return false }
        setDraft(pending.originalText, for: pending.sessionId)
        return true
    }
}
