import AppKit
import SwiftUI
import XCTest
@testable import Agent_Notch

@MainActor
final class ApprovalInputDetailsRenderingTests: XCTestCase {
    func testExpandedDetailsAtMinimumWidthInChinese() async throws {
        try await render(language: .simplifiedChinese)
    }

    func testExpandedDetailsAtMinimumWidthInEnglish() async throws {
        try await render(language: .english)
    }

    private func render(language: AppLanguage) async throws {
        let permission = PermissionContext(
            toolUseId: "offline-approval", toolName: "Bash",
            toolInput: [
                "command": AnyCodable("printf 'review this command' && echo 'complete tail'"),
                "file_path": AnyCodable("/tmp/project/nested/example.txt")
            ], receivedAt: Date(timeIntervalSince1970: 100)
        )
        var actionCount = 0
        let card = ChatApprovalBar(
            permission: permission, language: language,
            onApproveOnce: { actionCount += 1 },
            onAutoApprove: { actionCount += 1 },
            onDeny: { actionCount += 1 },
            initiallyExpanded: true, initiallyVisible: true
        )
        .frame(width: 456, alignment: .leading)
        .background(Color.black)
        .preferredColorScheme(.dark)
        let host = NSHostingView(rootView: card)
        let bounds = NSRect(x: 0, y: 0, width: 456, height: 300)
        let window = NSWindow(contentRect: bounds, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        defer { window.contentView = nil }
        host.frame = bounds
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        host.layoutSubtreeIfNeeded()
        XCTAssertFalse(window.isVisible)
        XCTAssertLessThanOrEqual(host.fittingSize.height, bounds.height)
        XCTAssertEqual(actionCount, 0, "Rendering must not make a permission decision")
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: bounds))
        host.cacheDisplay(in: bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        XCTAssertGreaterThan(png.count, 1000)
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = "approval-details-\(language.rawValue)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
