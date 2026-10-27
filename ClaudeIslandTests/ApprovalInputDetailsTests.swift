import XCTest
@testable import Agent_Notch

final class ApprovalInputDetailsTests: XCTestCase {
    func testLongCommandAndCompletePathsRemainAvailable() {
        let command = String(repeating: "x", count: 500) + " && destructive-tail"
        let context = PermissionContext(
            toolUseId: "tool", toolName: "Bash",
            toolInput: ["command": AnyCodable(command), "file_path": AnyCodable("/one/same.txt")],
            receivedAt: Date()
        )
        XCTAssertFalse(context.formattedInput?.contains("destructive-tail") ?? true)
        XCTAssertEqual(context.approvalInputDetails.map(\.key), ["command", "file_path"])
        XCTAssertEqual(context.approvalInputDetails[0].value, command)
        XCTAssertEqual(context.approvalInputDetails[1].value, "/one/same.txt")

        let other = PermissionContext(
            toolUseId: "other", toolName: "Read",
            toolInput: ["file_path": AnyCodable("/two/same.txt")], receivedAt: Date()
        )
        XCTAssertEqual(other.approvalInputDetails.first?.value, "/two/same.txt")
    }

    func testStructuredAndEmptyInputAreRepresentedWithoutInventingReasons() {
        let context = PermissionContext(
            toolUseId: "tool", toolName: "Edit",
            toolInput: ["options": AnyCodable(["enabled": true, "count": 2] as [String: Any]),
                        "empty": AnyCodable("")], receivedAt: Date()
        )
        let fields = context.approvalInputDetails
        XCTAssertEqual(fields.map(\.key), ["empty", "options"])
        XCTAssertEqual(fields[0].value, "")
        XCTAssertTrue(fields[1].value.contains("\"enabled\" : true"))
        XCTAssertTrue(fields[1].value.contains("\"count\" : 2"))
        XCTAssertTrue(PermissionContext(toolUseId: "x", toolName: "Read", toolInput: nil, receivedAt: Date()).approvalInputDetails.isEmpty)
    }

    func testPresentationIdentitySeparatesReusedToolIdsAndSessions() {
        let timestamp = Date(timeIntervalSince1970: 100)
        var first = PermissionContext(toolUseId: "same", toolName: "Bash", toolInput: nil, receivedAt: timestamp)
        var second = first
        first.requestID = UUID()
        second.requestID = UUID()
        XCTAssertNotEqual(first.presentationIdentity(sessionId: "A"), second.presentationIdentity(sessionId: "A"))
        XCTAssertNotEqual(first.presentationIdentity(sessionId: "A"), first.presentationIdentity(sessionId: "B"))
        XCTAssertEqual(first.presentationIdentity(sessionId: "A"), first.presentationIdentity(sessionId: "A"))
    }
}
