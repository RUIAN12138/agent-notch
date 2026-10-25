// Modified by lihao505 for Agent Notch, 2026.
import XCTest
@testable import Agent_Notch

@MainActor
final class NotchCompletionExpansionTests: XCTestCase {
    private func makeViewModel() -> NotchViewModel {
        NotchViewModel(
            deviceNotchRect: CGRect(x: 650, y: 0, width: 212, height: 32),
            screenRect: CGRect(x: 0, y: 0, width: 1512, height: 982),
            windowHeight: 750,
            hasPhysicalNotch: true
        )
    }

    func testCompletionExpansionPreferenceDefaultsOffAndPersists() throws {
        let suite = "NotchCompletionExpansionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let preferences = NotchPreferences(defaults: defaults)
        XCTAssertFalse(preferences.expandOnTaskCompletion)

        for choice in [false, true] {
            preferences.expandOnTaskCompletion = choice
            let restored = NotchPreferences(defaults: defaults)
            XCTAssertEqual(restored.expandOnTaskCompletion, choice)
            XCTAssertEqual(
                defaults.object(forKey: "notchExpandOnTaskCompletion") as? Bool,
                choice
            )
        }
    }

    func testTerminalAutoExpansionSuppressionPreferenceDefaultsOffAndPersists() throws {
        let suite = "NotchTerminalAutoExpansionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let preferences = NotchPreferences(defaults: defaults)
        XCTAssertFalse(preferences.suppressAutoExpansionWhenTerminalFrontmost)

        for choice in [false, true] {
            preferences.suppressAutoExpansionWhenTerminalFrontmost = choice
            let restored = NotchPreferences(defaults: defaults)
            XCTAssertEqual(
                restored.suppressAutoExpansionWhenTerminalFrontmost,
                choice
            )
            XCTAssertEqual(
                defaults.object(
                    forKey: "notchSuppressAutoExpansionWhenTerminalFrontmost"
                ) as? Bool,
                choice
            )
        }
    }

    func testTerminalAutoExpansionSuppressionRequiresEnabledPreferenceAndFrontmostTerminal() {
        XCTAssertFalse(
            NotchAttentionPolicy.shouldSuppressAutomaticExpansion(
                suppressWhenTerminalFrontmost: false,
                terminalIsFrontmost: true
            )
        )
        XCTAssertFalse(
            NotchAttentionPolicy.shouldSuppressAutomaticExpansion(
                suppressWhenTerminalFrontmost: true,
                terminalIsFrontmost: false
            )
        )
        XCTAssertTrue(
            NotchAttentionPolicy.shouldSuppressAutomaticExpansion(
                suppressWhenTerminalFrontmost: true,
                terminalIsFrontmost: true
            )
        )
    }

    func testCompletionExpansionIsOptInAndRespectsPresentationOwnership() {
        func shouldExpand(
            enabled: Bool = true,
            status: NotchStatus = .closed,
            reason: NotchOpenReason = .unknown,
            hasPendingInteraction: Bool = false
        ) -> Bool {
            NotchAttentionPolicy.shouldAutoExpandOnCompletion(
                expandOnTaskCompletion: enabled,
                status: status,
                openReason: reason,
                hasPendingAutoExpandedInteraction: hasPendingInteraction
            )
        }

        XCTAssertFalse(shouldExpand(enabled: false))
        XCTAssertTrue(shouldExpand())
        XCTAssertTrue(shouldExpand(status: .opened, reason: .notification))

        XCTAssertFalse(shouldExpand(status: .opened, reason: .click))
        XCTAssertFalse(shouldExpand(status: .opened, reason: .keyboard))
        XCTAssertFalse(shouldExpand(status: .opened, reason: .hover))
        XCTAssertFalse(shouldExpand(status: .popping, reason: .notification))
        XCTAssertFalse(shouldExpand(hasPendingInteraction: true))
        XCTAssertFalse(shouldExpand(
            status: .opened,
            reason: .notification,
            hasPendingInteraction: true
        ))
    }

    func testExpiredCompletionCollapseDefersForInteractionThenResumes() {
        let blocked = NotchAttentionPolicy.completionPanelCollapseDecision(
            status: .opened,
            openReason: .notification,
            hasPendingAutoExpandedInteraction: true
        )
        XCTAssertEqual(blocked, .deferUntilInteractionResolves)

        let resumed = NotchAttentionPolicy.completionPanelCollapseDecision(
            status: .opened,
            openReason: .notification,
            hasPendingAutoExpandedInteraction: false
        )
        XCTAssertEqual(resumed, .collapse)

        let userOwned = NotchAttentionPolicy.completionPanelCollapseDecision(
            status: .opened,
            openReason: .click,
            hasPendingAutoExpandedInteraction: false
        )
        XCTAssertEqual(userOwned, .discard)
    }

    func testCompletionDwellUsesTheEventTimestampRatherThanDeliveryTime() {
        let completedAt = Date(timeIntervalSince1970: 100)

        XCTAssertEqual(
            NotchAttentionPolicy.completionDwellRemaining(
                startedAt: completedAt,
                duration: 8,
                now: Date(timeIntervalSince1970: 102)
            ),
            6,
            accuracy: 0.001
        )
        XCTAssertEqual(
            NotchAttentionPolicy.completionDwellRemaining(
                startedAt: completedAt,
                duration: 8,
                now: Date(timeIntervalSince1970: 110)
            ),
            0,
            accuracy: 0.001
        )
    }

    func testCompletionPanelResetsNotificationContentButPreservesUserAndSpaceOwnership() {
        let viewModel = makeViewModel()
        let session = SessionState(
            sessionId: "completion-panel",
            cwd: "/tmp/completion-panel"
        )

        viewModel.showCompletionPanel()
        XCTAssertEqual(viewModel.status, .opened)
        XCTAssertEqual(viewModel.openReason, .notification)
        XCTAssertEqual(viewModel.contentType, .instances)

        viewModel.contentType = .chat(session)
        viewModel.showCompletionPanel()
        XCTAssertEqual(viewModel.contentType, .instances)

        viewModel.notchOpen(reason: .click)
        viewModel.contentType = .chat(session)
        viewModel.showCompletionPanel()
        XCTAssertEqual(viewModel.status, .opened)
        XCTAssertEqual(viewModel.openReason, .click)
        XCTAssertEqual(viewModel.contentType, .chat(session))

        viewModel.notchClose()
        viewModel.canPresentOnCurrentSpace = { false }
        viewModel.showCompletionPanel()
        XCTAssertEqual(viewModel.status, .closed)
    }
}
