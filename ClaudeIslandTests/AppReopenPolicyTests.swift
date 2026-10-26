import XCTest
@testable import Agent_Notch

final class AppReopenPolicyTests: XCTestCase {
    func testReopenBeforeOnboardingCompletesReturnsToOnboarding() {
        XCTAssertEqual(
            AppReopenPolicy.destination(onboardingCompleted: false),
            .onboarding
        )
    }

    func testReopenAfterOnboardingCompletesOpensSettings() {
        XCTAssertEqual(
            AppReopenPolicy.destination(onboardingCompleted: true),
            .settings
        )
    }
}
