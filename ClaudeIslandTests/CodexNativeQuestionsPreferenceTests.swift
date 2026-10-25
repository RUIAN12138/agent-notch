import Foundation
import XCTest
@testable import Agent_Notch

@MainActor
final class CodexNativeQuestionsPreferenceTests: XCTestCase {
    func testExperimentalNativeQuestionBridgeIsDisabledByDefaultAndPersistsOptIn() {
        let suite = "CodexNativeQuestionsPreferenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let initial = NotchPreferences(defaults: defaults)
        XCTAssertFalse(initial.codexNativeQuestionsEnabled)

        initial.codexNativeQuestionsEnabled = true
        let restored = NotchPreferences(defaults: defaults)
        XCTAssertTrue(restored.codexNativeQuestionsEnabled)
    }
}
