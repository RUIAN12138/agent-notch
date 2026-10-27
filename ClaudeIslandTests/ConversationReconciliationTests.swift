import XCTest
@testable import Agent_Notch

final class ConversationReconciliationTests: XCTestCase {
    func testNativeMessageReplacesEquivalentOptimisticMessage() async {
        let timestamp = Date()
        let optimistic = ChatHistoryItem(
            id: "cli-user-test",
            type: .user("continue"),
            timestamp: timestamp
        )
        let native = ChatHistoryItem(
            id: "native-user-test",
            type: .user("continue"),
            timestamp: timestamp.addingTimeInterval(1)
        )

        let result = await MainActor.run {
            ChatHistoryManager.shared.reconcile(
                nativeHistory: [native],
                optimisticHistory: [optimistic]
            )
        }

        XCTAssertEqual(result.map(\.id), ["native-user-test"])
    }

    func testUnmatchedOptimisticMessageSurvivesReconciliation() async {
        let optimistic = ChatHistoryItem(
            id: "cli-assistant-test",
            type: .assistant("streamed reply"),
            timestamp: Date()
        )

        let result = await MainActor.run {
            ChatHistoryManager.shared.reconcile(
                nativeHistory: [],
                optimisticHistory: [optimistic]
            )
        }

        XCTAssertEqual(result.map(\.id), ["cli-assistant-test"])
    }

    func testEarlierNativeMessageCannotHideLaterIdenticalSend() async {
        let native = ChatHistoryItem(id: "native-old", type: .user("yes"), timestamp: Date(timeIntervalSince1970: 100))
        let later = ChatHistoryItem(id: "cli-user-new", type: .user("yes"), timestamp: Date(timeIntervalSince1970: 110))
        let result = await MainActor.run {
            ChatHistoryManager.shared.reconcile(nativeHistory: [native], optimisticHistory: [later])
        }
        XCTAssertEqual(result.map(\.id), ["native-old", "cli-user-new"])
    }

    func testOneNativeMessageCannotConfirmTwoOptimisticSends() async {
        let first = ChatHistoryItem(id: "cli-user-first", type: .user("yes"), timestamp: Date(timeIntervalSince1970: 100))
        let second = ChatHistoryItem(id: "cli-user-second", type: .user("yes"), timestamp: Date(timeIntervalSince1970: 101))
        let native = ChatHistoryItem(id: "native-user", type: .user("yes"), timestamp: Date(timeIntervalSince1970: 102))
        let result = await MainActor.run {
            ChatHistoryManager.shared.reconcile(nativeHistory: [native], optimisticHistory: [first, second])
        }
        XCTAssertEqual(result.map(\.id), ["cli-user-second", "native-user"])
    }

    func testLocalInterruptionSurvivesReconciliation() async {
        let interrupted = ChatHistoryItem(id: "cli-interrupted-test", type: .interrupted, timestamp: Date())
        let result = await MainActor.run {
            ChatHistoryManager.shared.reconcile(nativeHistory: [], optimisticHistory: [interrupted])
        }
        XCTAssertEqual(result.map(\.id), ["cli-interrupted-test"])
    }

    func testPreviouslyClaimedNativeMessageCannotConsumeAnotherIdenticalSend() async {
        let native = ChatHistoryItem(id: "native-user", type: .user("yes"), timestamp: Date(timeIntervalSince1970: 102))
        let later = ChatHistoryItem(id: "cli-user-second", type: .user("yes"), timestamp: Date(timeIntervalSince1970: 101))
        let result = await MainActor.run {
            ChatHistoryManager.shared.reconcile(
                nativeHistory: [native], optimisticHistory: [later],
                excludingConfirmedNativeIDs: ["native-user"]
            )
        }
        XCTAssertEqual(result.map(\.id), ["cli-user-second", "native-user"])
    }
}
