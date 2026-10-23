//
//  ScreenSelector.swift
//  ClaudeIsland
//
//  Manages screen selection state and persistence
//

import AppKit
import Combine
import Foundation

/// Strategy for selecting which screen to use
enum ScreenSelectionMode: String, Codable {
    case automatic       // Prefer built-in display, fall back to main
    case specificScreen  // User selected a specific screen
    case activeDisplay   // Follow the display containing the active app
}

/// Persistent identifier for a screen
struct ScreenIdentifier: Codable, Equatable, Hashable {
    let displayID: CGDirectDisplayID?
    let localizedName: String

    init(displayID: CGDirectDisplayID?, localizedName: String) {
        self.displayID = displayID
        self.localizedName = localizedName
    }

    /// Create identifier from NSScreen
    init(screen: NSScreen) {
        if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            self.displayID = screenNumber
        } else {
            self.displayID = nil
        }
        self.localizedName = screen.localizedName
    }

    /// Check if this identifier matches a given screen
    func matches(_ screen: NSScreen) -> Bool {
        matches(ScreenIdentifier(screen: screen))
    }

    /// Match a saved identifier, allowing the display ID to change after reconnect.
    func matches(_ other: ScreenIdentifier) -> Bool {
        if let displayID, displayID == other.displayID {
            return true
        }
        return localizedName == other.localizedName
    }

    /// Compare connected displays without confusing two same-named monitors.
    func identifiesSameDisplay(as other: ScreenIdentifier) -> Bool {
        if let displayID, let otherID = other.displayID {
            return displayID == otherID
        }
        return localizedName == other.localizedName
    }
}

/// Pure display-selection policy so fallback behavior can be tested without
/// depending on the displays attached to the test machine.
enum ScreenSelectionResolver {
    static func resolve(
        mode: ScreenSelectionMode,
        savedIdentifier: ScreenIdentifier?,
        availableIdentifiers: [ScreenIdentifier],
        builtInIdentifier: ScreenIdentifier?,
        mainIdentifier: ScreenIdentifier?
    ) -> ScreenIdentifier? {
        switch mode {
        case .automatic:
            return builtInIdentifier ?? mainIdentifier

        case .activeDisplay:
            return mainIdentifier ?? builtInIdentifier

        case .specificScreen:
            if let savedIdentifier,
               let match = availableIdentifiers.first(where: savedIdentifier.matches) {
                return match
            }
            return builtInIdentifier ?? mainIdentifier
        }
    }
}

@MainActor
class ScreenSelector: ObservableObject {
    static let shared = ScreenSelector()

    // MARK: - Published State
    @Published private(set) var availableScreens: [NSScreen] = []
    @Published private(set) var selectedScreen: NSScreen?
    @Published var selectionMode: ScreenSelectionMode = .automatic
    @Published var isPickerExpanded: Bool = false

    // MARK: - UserDefaults Keys
    private let modeKey = "screenSelectionMode"
    private let screenIdentifierKey = "selectedScreenIdentifier"

    // MARK: - Private State
    private var savedIdentifier: ScreenIdentifier?

    private init() {
        loadPreferences()
        refreshScreens()
    }

    // MARK: - Public API

    /// Refresh the available screens list
    func refreshScreens() {
        availableScreens = NSScreen.screens
        selectedScreen = resolveSelectedScreen()
    }

    /// Select a specific screen
    func selectScreen(_ screen: NSScreen) {
        selectionMode = .specificScreen
        savedIdentifier = ScreenIdentifier(screen: screen)
        selectedScreen = screen
        savePreferences()
    }

    /// Reset to automatic selection
    func selectAutomatic() {
        selectionMode = .automatic
        savedIdentifier = nil
        selectedScreen = resolveSelectedScreen()
        savePreferences()
    }

    /// Follow the display containing the active app's key window.
    func selectActiveDisplay() {
        selectionMode = .activeDisplay
        savedIdentifier = nil
        selectedScreen = resolveSelectedScreen()
        savePreferences()
    }

    /// Check if a screen is currently selected
    func isSelected(_ screen: NSScreen) -> Bool {
        guard let selected = selectedScreen else { return false }
        return screenID(of: screen) == screenID(of: selected)
    }

    /// Extra height needed when picker is expanded
    var expandedPickerHeight: CGFloat {
        guard isPickerExpanded else { return 0 }
        // The picker includes the Automatic and Active display options.
        return CGFloat(availableScreens.count + 2) * 40
    }

    // MARK: - Private Methods

    private func screenID(of screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    private func resolveSelectedScreen() -> NSScreen? {
        let identifiers = availableScreens.map(ScreenIdentifier.init(screen:))
        let builtInIdentifier = availableScreens
            .first(where: \.isBuiltinDisplay)
            .map(ScreenIdentifier.init(screen:))
        let mainIdentifier = NSScreen.main.map(ScreenIdentifier.init(screen:))

        guard let resolvedIdentifier = ScreenSelectionResolver.resolve(
            mode: selectionMode,
            savedIdentifier: savedIdentifier,
            availableIdentifiers: identifiers,
            builtInIdentifier: builtInIdentifier,
            mainIdentifier: mainIdentifier
        ) else {
            return nil
        }

        return availableScreens.first {
            ScreenIdentifier(screen: $0).identifiesSameDisplay(as: resolvedIdentifier)
        }
    }

    private func loadPreferences() {
        if let modeString = UserDefaults.standard.string(forKey: modeKey),
           let mode = ScreenSelectionMode(rawValue: modeString) {
            selectionMode = mode
        }

        if let data = UserDefaults.standard.data(forKey: screenIdentifierKey),
           let identifier = try? JSONDecoder().decode(ScreenIdentifier.self, from: data) {
            savedIdentifier = identifier
        }
    }

    private func savePreferences() {
        UserDefaults.standard.set(selectionMode.rawValue, forKey: modeKey)

        if let identifier = savedIdentifier,
           let data = try? JSONEncoder().encode(identifier) {
            UserDefaults.standard.set(data, forKey: screenIdentifierKey)
        } else {
            UserDefaults.standard.removeObject(forKey: screenIdentifierKey)
        }
    }
}
