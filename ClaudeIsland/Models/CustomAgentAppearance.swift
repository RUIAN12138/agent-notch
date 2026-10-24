// Modified by Agent Notch, 2026.
import Foundation

/// Safe, local presentation choices for custom Agent sources. These values do
/// not grant transport, messaging, or approval capabilities.
enum CustomAgentIcon: String, CaseIterable, Codable, Identifiable, Sendable {
    case terminal
    case code = "curlybraces"
    case sparkles
    case cpu
    case hammer = "hammer.fill"
    case bolt = "bolt.fill"
    case network
    case app = "app.dashed"

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .terminal: language.text("Terminal", "终端")
        case .code: language.text("Code", "代码")
        case .sparkles: language.text("Sparkles", "星光")
        case .cpu: language.text("Processor", "处理器")
        case .hammer: language.text("Build", "构建")
        case .bolt: language.text("Bolt", "闪电")
        case .network: language.text("Network", "网络")
        case .app: language.text("App", "应用")
        }
    }
}

struct CustomAgentAppearance: Codable, Equatable, Sendable {
    let displayName: String
    let icon: CustomAgentIcon

    init?(displayName: String, icon: CustomAgentIcon) {
        let normalizedName = displayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalizedName.isEmpty,
              normalizedName.count <= Self.maximumDisplayNameLength,
              !normalizedName.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0)
              }) else {
            return nil
        }
        self.displayName = normalizedName
        self.icon = icon
    }

    static let maximumDisplayNameLength = 48
    static let maximumProfiles = 32
}
