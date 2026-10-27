import XCTest
@testable import Agent_Notch

@MainActor
final class ChatDraftStoreTests: XCTestCase {
    func testDraftSurvivesViewRecreationAndIsIsolatedBySession() {
        let store = ChatDraftStore()
        store.setDraft("  first draft\n", for: "first")
        store.setDraft("second draft", for: "second")

        // A recreated view resolves its draft by session ID from the same
        // app-lifetime store instead of owning a fresh SwiftUI @State value.
        XCTAssertEqual(store.draft(for: "first"), "  first draft\n")
        XCTAssertEqual(store.draft(for: "second"), "second draft")
        XCTAssertEqual(store.draft(for: "third"), "")
    }

    func testFailedSendRestoresOriginalTextAndBlankInputIsNotConsumed() throws {
        let store = ChatDraftStore()
        store.setDraft(" \n ", for: "session")
        XCTAssertNil(store.takeForSending(sessionId: "session"))
        XCTAssertEqual(store.draft(for: "session"), " \n ")

        store.setDraft("  message\n", for: "session")
        let pending = try XCTUnwrap(store.takeForSending(sessionId: "session"))
        XCTAssertEqual(pending.textToSend, "message")
        XCTAssertEqual(store.draft(for: "session"), "")
        XCTAssertTrue(store.restoreAfterFailure(pending))
        XCTAssertEqual(store.draft(for: "session"), "  message\n")
        XCTAssertFalse(store.restoreAfterFailure(pending))
    }

    func testLateFailureCannotOverwriteNewOrSubsequentlyClearedDraft() throws {
        let store = ChatDraftStore()
        store.setDraft("old", for: "session")
        let pending = try XCTUnwrap(store.takeForSending(sessionId: "session"))
        store.setDraft("new", for: "session")
        XCTAssertFalse(store.restoreAfterFailure(pending))
        XCTAssertEqual(store.draft(for: "session"), "new")

        store.setDraft("", for: "session")
        XCTAssertFalse(store.restoreAfterFailure(pending))
        XCTAssertEqual(store.draft(for: "session"), "")
    }

    func testFailureInOneSessionDoesNotAffectAnotherSession() throws {
        let store = ChatDraftStore()
        store.setDraft("first", for: "first")
        let pending = try XCTUnwrap(store.takeForSending(sessionId: "first"))
        store.setDraft("second", for: "second")

        XCTAssertTrue(store.restoreAfterFailure(pending))
        XCTAssertEqual(store.draft(for: "first"), "first")
        XCTAssertEqual(store.draft(for: "second"), "second")
    }

    func testSendingStateSurvivesRecreationAndRejectsStaleCompletion() throws {
        let store = ChatDraftStore()
        store.setDraft("first", for: "session")
        let first = try XCTUnwrap(store.takeForSending(sessionId: "session"))
        XCTAssertTrue(store.isSending(sessionId: "session"))

        // A recreated composer resolves the same session and cannot issue a
        // second send while the original task is still running.
        store.setDraft("second", for: "session")
        XCTAssertNil(store.takeForSending(sessionId: "session"))
        XCTAssertEqual(store.draft(for: "session"), "second")
        store.finishSending(first)
        let second = try XCTUnwrap(store.takeForSending(sessionId: "session"))
        store.finishSending(first)
        XCTAssertEqual(store.activeSendID(for: "session"), second.id)
        store.finishSending(second)
        XCTAssertFalse(store.isSending(sessionId: "session"))
    }

    func testRecreatedViewCanCancelTheOriginalSend() async throws {
        let store = ChatDraftStore()
        store.setDraft("message", for: "session")
        let pending = try XCTUnwrap(store.takeForSending(sessionId: "session"))
        let sendTask = Task<Void, Never> {
            do { try await Task.sleep(for: .seconds(30)) } catch { }
        }
        store.attach(sendTask, to: pending)
        store.cancelSending(sessionId: "session")
        XCTAssertTrue(sendTask.isCancelled)
        await sendTask.value
        store.finishSending(pending)
        XCTAssertFalse(store.isSending(sessionId: "session"))
    }

    func testStreamingRowsAndErrorsSurviveViewRecreationPerSession() {
        let store = ChatDraftStore()
        let user = ChatHistoryItem(id: "cli-user-1", type: .user("hello"), timestamp: Date())
        store.appendOptimistic(user, for: "first")
        store.upsertAssistant(id: "cli-assistant-1", text: "partial", for: "first")
        store.setError("failed", for: "first")
        XCTAssertEqual(store.optimisticHistory(for: "first").count, 2)
        XCTAssertEqual(store.error(for: "first"), "failed")
        XCTAssertTrue(store.optimisticHistory(for: "second").isEmpty)
        XCTAssertNil(store.error(for: "second"))

        let oldAssistant = store.optimisticHistory(for: "first")[1]
        store.upsertAssistant(id: "cli-assistant-1", text: "partial and more", for: "first")
        store.removeConfirmedOptimistic([
            ChatHistoryConfirmation(optimistic: user, nativeID: "native-user"),
            ChatHistoryConfirmation(optimistic: oldAssistant, nativeID: "native-partial")
        ], for: "first")
        XCTAssertEqual(store.optimisticHistory(for: "first").map(\.id), ["cli-assistant-1"])
        XCTAssertEqual(store.optimisticHistory(for: "first").first?.type, .assistant("partial and more"))
        XCTAssertEqual(store.confirmedNativeIDs(for: "first"), ["native-user"])
    }
}
