//
//  AgentBadge.swift
//  ClaudeIsland
//

import SwiftUI

struct AgentBadge: View {
    let source: AgentSource
    @ObservedObject private var preferences = NotchPreferences.shared

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: preferences.symbolName(for: source))
                .font(.system(size: 8, weight: .bold))

            Text(preferences.displayName(for: source))
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundColor(source.accentColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(source.accentColor.opacity(0.14))
        .overlay(
            Capsule()
                .strokeBorder(source.accentColor.opacity(0.28), lineWidth: 0.5)
        )
        .clipShape(Capsule())
        .accessibilityLabel("\(preferences.displayName(for: source)) session")
    }
}
