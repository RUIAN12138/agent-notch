//
//  AgentSource.swift
//  ClaudeIsland
//
//  Visual identity for coding agents connected through the hook socket.
//

import SwiftUI

/// Stable source identity for built-in and externally configured agents.
/// Custom source values are deliberately identifiers, not transport or
/// permission capabilities: only explicitly supported built-ins can interact.
struct AgentSource: RawRepresentable, Equatable, Hashable, Sendable {
    nonisolated let rawValue: String

    nonisolated static let claude = AgentSource(rawValue: "claude")!
    nonisolated static let codex = AgentSource(rawValue: "codex")!
    nonisolated static let codebuddy = AgentSource(rawValue: "codebuddy")!
    nonisolated static let gemini = AgentSource(rawValue: "gemini")!
    nonisolated static let cursor = AgentSource(rawValue: "cursor")!
    nonisolated static let unknown = AgentSource(rawValue: "unknown")!

    private nonisolated static let builtInSourceNames: Set<String> = [
        "claude", "codex", "codebuddy", "gemini", "cursor", "unknown"
    ]

    private nonisolated static let observationEventNames: Set<String> = [
        "SessionStart",
        "UserPromptSubmit",
        "PreToolUse",
        "PostToolUse",
        "PostToolUseFailure",
        "Stop",
        "StopFailure",
        "SessionEnd"
    ]

    nonisolated init?(rawValue: String) {
        let normalized = rawValue.lowercased()
        let scalars = normalized.unicodeScalars
        guard normalized.utf8.count <= 64,
              let first = scalars.first,
              (97...122).contains(first.value),
              scalars.dropFirst().allSatisfy({ scalar in
                  (97...122).contains(scalar.value) ||
                      (48...57).contains(scalar.value) ||
                      scalar == "_" || scalar == "-"
              }) else {
            return nil
        }
        self.rawValue = normalized
    }

    nonisolated init(hookValue: String?) {
        guard let hookValue,
              let source = AgentSource(rawValue: hookValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            self = .unknown
            return
        }
        self = source
    }

    nonisolated var isCustom: Bool {
        !Self.builtInSourceNames.contains(rawValue)
    }

    nonisolated var isObservationOnly: Bool {
        isCustom || rawValue == Self.gemini.rawValue || rawValue == Self.unknown.rawValue
    }

    nonisolated var supportsMessaging: Bool {
        switch rawValue {
        case Self.claude.rawValue, Self.codex.rawValue,
             Self.codebuddy.rawValue, Self.cursor.rawValue:
            return true
        default:
            return false
        }
    }

    nonisolated var supportsTranscriptSync: Bool {
        !isObservationOnly
    }

    nonisolated var supportsInteractiveDecisions: Bool {
        !isObservationOnly
    }

    nonisolated func acceptsHookEvent(
        _ event: String,
        status: String? = nil
    ) -> Bool {
        guard isObservationOnly else { return true }
        return Self.observationEventNames.contains(event) &&
            status != "waiting_for_approval"
    }

    nonisolated var displayName: String {
        switch rawValue {
        case Self.claude.rawValue: return "Claude"
        case Self.codex.rawValue: return "Codex"
        case Self.codebuddy.rawValue: return "CodeBuddy"
        case Self.gemini.rawValue: return "Gemini"
        case Self.cursor.rawValue: return "Cursor"
        case Self.unknown.rawValue: return "Agent"
        default:
            return rawValue
                .split(whereSeparator: { $0 == "-" || $0 == "_" })
                .map { word in
                    word.prefix(1).uppercased() + word.dropFirst()
                }
                .joined(separator: " ")
        }
    }

    nonisolated var symbolName: String {
        switch rawValue {
        case Self.claude.rawValue: return "sparkles"
        case Self.codex.rawValue: return "chevron.left.forwardslash.chevron.right"
        case Self.codebuddy.rawValue: return "pawprint.fill"
        case Self.gemini.rawValue: return "diamond.fill"
        case Self.cursor.rawValue: return "cursorarrow.rays"
        default: return "terminal"
        }
    }

    nonisolated var accentColor: Color {
        switch rawValue {
        case Self.claude.rawValue:
            return Color(red: 0.85, green: 0.47, blue: 0.34)
        case Self.codex.rawValue:
            return Color(red: 0.06, green: 0.64, blue: 0.50)
        case Self.codebuddy.rawValue:
            return Color(red: 0.94, green: 0.34, blue: 0.30)
        case Self.gemini.rawValue:
            return Color(red: 0.36, green: 0.56, blue: 0.96)
        case Self.cursor.rawValue:
            return Color(red: 0.65, green: 0.48, blue: 0.96)
        default:
            return Color.white.opacity(0.65)
        }
    }
}
