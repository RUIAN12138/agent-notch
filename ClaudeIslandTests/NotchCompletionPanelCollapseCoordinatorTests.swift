import XCTest
@testable import Agent_Notch

@MainActor
final class NotchCompletionPanelCollapseCoordinatorTests: XCTestCase {
    func testExpiredPanelWaitsForPointerThenCloses() {
        let now = Date(timeIntervalSince1970: 100)
        let coordinator = NotchCompletionPanelCollapseCoordinator(now: { now })
        var hovering = true
        var closed = 0
        coordinator.schedule(startedAt: now.addingTimeInterval(-10), duration: 5) {
            NotchAttentionPolicy.completionPanelCollapseDecision(
                status: .opened, openReason: .notification,
                hasPendingAutoExpandedInteraction: false,
                isPointerOverPanel: hovering
            )
        } onCollapse: { closed += 1 }

        coordinator.deadlineFired(generation: coordinator.generation)
        XCTAssertEqual(closed, 0)
        XCTAssertNotNil(coordinator.startedAt)
        hovering = false
        coordinator.resumeIfNeeded()
        coordinator.deadlineFired(generation: coordinator.generation)
        XCTAssertEqual(closed, 1)
        XCTAssertNil(coordinator.startedAt)
    }

    func testPointerAndApprovalBothMustClearBeforeClosing() {
        let now = Date(timeIntervalSince1970: 100)
        let coordinator = NotchCompletionPanelCollapseCoordinator(now: { now })
        var hovering = true
        var pendingApproval = true
        var closed = 0
        coordinator.schedule(startedAt: now.addingTimeInterval(-10), duration: 5) {
            NotchAttentionPolicy.completionPanelCollapseDecision(
                status: .opened, openReason: .notification,
                hasPendingAutoExpandedInteraction: pendingApproval,
                isPointerOverPanel: hovering
            )
        } onCollapse: { closed += 1 }

        coordinator.deadlineFired(generation: coordinator.generation)
        hovering = false
        coordinator.resumeIfNeeded()
        XCTAssertEqual(closed, 0)
        XCTAssertNotNil(coordinator.startedAt)
        pendingApproval = false
        coordinator.resumeIfNeeded()
        coordinator.deadlineFired(generation: coordinator.generation)
        XCTAssertEqual(closed, 1)
    }

    func testUserOwnershipAndNewerReminderRejectOldDeadline() {
        let now = Date(timeIntervalSince1970: 100)
        let coordinator = NotchCompletionPanelCollapseCoordinator(now: { now })
        var reason = NotchOpenReason.notification
        var closed = 0
        let decision = {
            NotchAttentionPolicy.completionPanelCollapseDecision(
                status: .opened, openReason: reason,
                hasPendingAutoExpandedInteraction: false,
                isPointerOverPanel: false
            )
        }
        coordinator.schedule(startedAt: now, duration: 5, decision: decision) { closed += 1 }
        let oldGeneration = coordinator.generation
        coordinator.schedule(startedAt: now, duration: 5, decision: decision) { closed += 1 }
        coordinator.deadlineFired(generation: oldGeneration)
        XCTAssertEqual(closed, 0)
        reason = .click
        coordinator.deadlineFired(generation: coordinator.generation)
        XCTAssertEqual(closed, 0)
        XCTAssertNil(coordinator.startedAt)
    }

    func testStationaryPointerIsResampledAfterPanelOpens() {
        var pointer = CGPoint(x: 756, y: 900)
        let model = NotchViewModel(
            deviceNotchRect: CGRect(x: 650, y: 0, width: 212, height: 32),
            screenRect: CGRect(x: 0, y: 0, width: 1512, height: 982),
            windowHeight: 750,
            hasPhysicalNotch: true,
            currentPointerLocation: { pointer }
        )
        model.showCompletionPanel()
        XCTAssertTrue(model.refreshPointerHover())
        pointer = CGPoint(x: 10, y: 10)
        XCTAssertFalse(model.refreshPointerHover())
    }
}
