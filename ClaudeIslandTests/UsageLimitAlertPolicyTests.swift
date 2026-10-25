// Modified by lihao505 for Agent Notch, 2026.
import XCTest
@testable import Agent_Notch

final class UsageLimitAlertPolicyTests: XCTestCase {
    private let resetAt = Date(timeIntervalSince1970: 1_800_000_000)

    private func snapshot(
        primary: Double?,
        secondary: Double? = nil,
        resetAt: Date? = nil
    ) -> UsageLimitSnapshot {
        let resetAt = resetAt ?? self.resetAt
        func window(_ percent: Double?, minutes: Int) -> UsageLimitWindow? {
            guard let percent else { return nil }
            return UsageLimitWindow(
                usedPercent: percent,
                windowMinutes: minutes,
                resetsAt: resetAt
            )
        }

        return UsageLimitSnapshot(
            source: .codex,
            planType: nil,
            primary: window(primary, minutes: 300),
            secondary: window(secondary, minutes: 10_080),
            updatedAt: resetAt
        )
    }

    func testAlertsOnlyWhenAnObservedWindowCrossesThreshold() {
        let alerts = UsageLimitAlertPolicy.thresholdCrossings(
            from: snapshot(primary: 79, secondary: 78),
            to: snapshot(primary: 80, secondary: 82),
            thresholdPercent: 80,
            enabled: true
        )

        XCTAssertEqual(alerts.map(\.window), [.primary, .secondary])
        XCTAssertEqual(alerts.map(\.thresholdPercent), [80, 80])
        XCTAssertEqual(alerts.map(\.windowMinutes), [300, 10_080])
    }

    func testNoAlertForInitialSnapshotDisabledAlertsOrAlreadyExceededThreshold() {
        XCTAssertTrue(UsageLimitAlertPolicy.thresholdCrossings(
            from: nil,
            to: snapshot(primary: 95),
            thresholdPercent: 80,
            enabled: true
        ).isEmpty)
        XCTAssertTrue(UsageLimitAlertPolicy.thresholdCrossings(
            from: snapshot(primary: 79),
            to: snapshot(primary: 81),
            thresholdPercent: 80,
            enabled: false
        ).isEmpty)
        XCTAssertTrue(UsageLimitAlertPolicy.thresholdCrossings(
            from: snapshot(primary: 81),
            to: snapshot(primary: 90),
            thresholdPercent: 80,
            enabled: true
        ).isEmpty)
    }

    func testResetBoundaryMustRemainTheSameWindow() {
        let alerts = UsageLimitAlertPolicy.thresholdCrossings(
            from: snapshot(primary: 79),
            to: snapshot(
                primary: 81,
                resetAt: resetAt.addingTimeInterval(3_600)
            ),
            thresholdPercent: 80,
            enabled: true
        )

        XCTAssertTrue(alerts.isEmpty)
    }

    func testTrackerDeduplicatesEachWindowUntilItsResetChanges() throws {
        let suite = "UsageLimitAlertPolicyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var tracker = UsageLimitAlertTracker(defaults: defaults)

        XCTAssertTrue(tracker.observe(
            snapshot: snapshot(primary: 79), enabled: true, thresholdPercent: 80
        ).isEmpty)
        XCTAssertEqual(tracker.observe(
            snapshot: snapshot(primary: 81), enabled: true, thresholdPercent: 80
        ).count, 1)
        XCTAssertTrue(tracker.observe(
            snapshot: snapshot(primary: 60), enabled: true, thresholdPercent: 80
        ).isEmpty)
        XCTAssertTrue(tracker.observe(
            snapshot: snapshot(primary: 85), enabled: true, thresholdPercent: 80
        ).isEmpty)

        let newReset = resetAt.addingTimeInterval(3_600)
        XCTAssertTrue(tracker.observe(
            snapshot: snapshot(primary: 70, resetAt: newReset),
            enabled: true,
            thresholdPercent: 80
        ).isEmpty)
        XCTAssertEqual(tracker.observe(
            snapshot: snapshot(primary: 80, resetAt: newReset),
            enabled: true,
            thresholdPercent: 80
        ).count, 1)
    }

    func testDisabledTrackerStillUpdatesBaselineWithoutRetroactiveAlert() throws {
        let suite = "UsageLimitAlertPolicyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var tracker = UsageLimitAlertTracker(defaults: defaults)

        XCTAssertTrue(tracker.observe(
            snapshot: snapshot(primary: 79), enabled: false, thresholdPercent: 80
        ).isEmpty)
        XCTAssertTrue(tracker.observe(
            snapshot: snapshot(primary: 90), enabled: false, thresholdPercent: 80
        ).isEmpty)
        XCTAssertTrue(tracker.observe(
            snapshot: snapshot(primary: 91), enabled: true, thresholdPercent: 80
        ).isEmpty)
    }

    @MainActor
    func testPreferencesDefaultOffAndPersistSanitizedThreshold() throws {
        let suite = "UsageLimitAlertPolicyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let preferences = NotchPreferences(defaults: defaults)
        XCTAssertFalse(preferences.usageLimitAlertsEnabled)
        XCTAssertEqual(preferences.usageLimitAlertThreshold, 80)

        preferences.usageLimitAlertsEnabled = true
        preferences.usageLimitAlertThreshold = 120

        let restored = NotchPreferences(defaults: defaults)
        XCTAssertTrue(restored.usageLimitAlertsEnabled)
        XCTAssertEqual(restored.usageLimitAlertThreshold, 100)
        XCTAssertEqual(defaults.object(forKey: "notchUsageLimitAlertThreshold") as? Int, 100)
    }
}
