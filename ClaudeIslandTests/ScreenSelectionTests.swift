import AppKit
import XCTest
@testable import Agent_Notch

final class ScreenSelectionTests: XCTestCase {
    private let builtIn = ScreenIdentifier(displayID: 1, localizedName: "MacBook Display")
    private let external = ScreenIdentifier(displayID: 2, localizedName: "Studio Display")
    private let activeExternal = ScreenIdentifier(displayID: 3, localizedName: "Projector")

    func testActiveDisplayModeFollowsMainScreenAndFallsBackToBuiltIn() {
        XCTAssertEqual(
            resolve(.activeDisplay, main: activeExternal),
            activeExternal
        )
        XCTAssertEqual(
            resolve(.activeDisplay, main: nil),
            builtIn
        )
    }

    func testAutomaticModeKeepsBuiltInDisplayPreference() {
        XCTAssertEqual(
            resolve(.automatic, main: activeExternal),
            builtIn
        )
        XCTAssertEqual(
            resolve(.automatic, main: nil),
            builtIn
        )
    }

    func testSpecificScreenStillUsesSavedDisplayAndFallsBackWhenDisconnected() {
        XCTAssertEqual(
            resolve(.specificScreen, saved: external, main: activeExternal),
            external
        )
        XCTAssertEqual(
            resolve(.specificScreen, saved: ScreenIdentifier(displayID: 9, localizedName: "Gone"), main: activeExternal),
            builtIn
        )
    }

    func testSavedDisplayCanBeRecoveredByNameAfterDisplayIDChanges() {
        let reconnected = ScreenIdentifier(displayID: 22, localizedName: "Studio Display")

        XCTAssertEqual(
            ScreenSelectionResolver.resolve(
                mode: .specificScreen,
                savedIdentifier: external,
                availableIdentifiers: [builtIn, reconnected],
                builtInIdentifier: builtIn,
                mainIdentifier: activeExternal
            ),
            reconnected
        )
    }

    func testSelectionModeKeepsExistingPersistedRawValues() {
        for (rawValue, expected) in [
            ("automatic", ScreenSelectionMode.automatic),
            ("specificScreen", ScreenSelectionMode.specificScreen),
            ("activeDisplay", ScreenSelectionMode.activeDisplay)
        ] {
            XCTAssertEqual(ScreenSelectionMode(rawValue: rawValue), expected)
        }
    }

    func testSameNamedDisplaysWithDifferentIDsAreNotTreatedAsSameCurrentDisplay() {
        let first = ScreenIdentifier(displayID: 10, localizedName: "External Display")
        let second = ScreenIdentifier(displayID: 11, localizedName: "External Display")

        XCTAssertFalse(first.identifiesSameDisplay(as: second))
        XCTAssertTrue(first.matches(second), "Saved display matching should retain the reconnect-by-name fallback.")
    }

    private func resolve(
        _ mode: ScreenSelectionMode,
        saved: ScreenIdentifier? = nil,
        main: ScreenIdentifier?
    ) -> ScreenIdentifier? {
        ScreenSelectionResolver.resolve(
            mode: mode,
            savedIdentifier: saved,
            availableIdentifiers: [builtIn, external, activeExternal],
            builtInIdentifier: builtIn,
            mainIdentifier: main
        )
    }
}
