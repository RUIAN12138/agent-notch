import XCTest
@testable import Agent_Notch

@MainActor
final class CustomAgentAppearanceTests: XCTestCase {
    func testAppearanceValidationTrimsNameAndRejectsUnsafeValues() throws {
        let appearance = try XCTUnwrap(CustomAgentAppearance(
            displayName: "  Acme Coder  ",
            icon: .sparkles
        ))
        XCTAssertEqual(appearance.displayName, "Acme Coder")
        XCTAssertEqual(appearance.icon, .sparkles)

        XCTAssertNil(CustomAgentAppearance(displayName: " \n ", icon: .terminal))
        XCTAssertNil(CustomAgentAppearance(
            displayName: String(repeating: "A", count: 49),
            icon: .terminal
        ))
        XCTAssertNil(CustomAgentAppearance(displayName: "Agent\nInjected", icon: .terminal))
    }

    func testCustomAppearanceUpdatesAndPersistsBySourceID() throws {
        let defaults = makeDefaults()
        let preferences = NotchPreferences(defaults: defaults)
        let source = try XCTUnwrap(AgentSource(rawValue: "my-agent"))

        XCTAssertTrue(preferences.addCustomAgentAppearance(for: source))
        XCTAssertTrue(preferences.updateCustomAgentAppearance(
            for: source,
            displayName: "My Coding Agent",
            icon: .sparkles
        ))
        XCTAssertEqual(preferences.displayName(for: source), "My Coding Agent")
        XCTAssertEqual(preferences.symbolName(for: source), "sparkles")

        let restored = NotchPreferences(defaults: defaults)
        XCTAssertEqual(restored.displayName(for: source), "My Coding Agent")
        XCTAssertEqual(restored.symbolName(for: source), "sparkles")

        restored.removeCustomAgentAppearance(for: source)
        let afterRemoval = NotchPreferences(defaults: defaults)
        XCTAssertEqual(afterRemoval.displayName(for: source), "My Agent")
        XCTAssertEqual(afterRemoval.symbolName(for: source), "terminal")
    }

    func testBuiltInAndInvalidSourcesCannotReceiveCustomAppearance() throws {
        let preferences = NotchPreferences(defaults: makeDefaults())
        let invalidSource = AgentSource(hookValue: "../not-an-agent")

        XCTAssertFalse(preferences.addCustomAgentAppearance(for: .claude))
        XCTAssertFalse(preferences.addCustomAgentAppearance(for: invalidSource))
        XCTAssertFalse(preferences.updateCustomAgentAppearance(
            for: .claude,
            displayName: "Imposter",
            icon: .app
        ))
        XCTAssertEqual(preferences.displayName(for: .claude), "Claude")
        XCTAssertEqual(preferences.symbolName(for: .claude), "sparkles")
        XCTAssertTrue(preferences.customAgentAppearances.isEmpty)
    }

    func testStoredBuiltInProfileIsIgnoredAndUnknownIconFallsBackSafely() throws {
        let defaults = makeDefaults()
        defaults.set([
            "claude": ["displayName": "Not Claude", "icon": "sparkles"],
            "my-agent": ["displayName": "My Agent", "icon": "not-a-symbol"],
        ], forKey: "notchCustomAgentAppearances")

        let preferences = NotchPreferences(defaults: defaults)
        let source = try XCTUnwrap(AgentSource(rawValue: "my-agent"))
        XCTAssertEqual(preferences.customAgentAppearances.count, 1)
        XCTAssertEqual(preferences.displayName(for: .claude), "Claude")
        XCTAssertEqual(preferences.displayName(for: source), "My Agent")
        XCTAssertEqual(preferences.symbolName(for: source), "terminal")
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "AgentNotch.CustomAgentAppearanceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
