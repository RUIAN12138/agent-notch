// Modified by Agent Notch, 2026.
import SwiftUI

struct CustomAgentAppearanceSettings: View {
    @ObservedObject var preferences: NotchPreferences
    @State private var sourceDraft = ""

    private var normalizedSourceDraft: AgentSource? {
        AgentSource(rawValue: sourceDraft.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var canAddSource: Bool {
        guard let source = normalizedSourceDraft,
              source.isCustom,
              preferences.customAgentAppearances[source.rawValue] == nil else {
            return false
        }
        return preferences.customAgentAppearances.count <
            CustomAgentAppearance.maximumProfiles
    }

    private var sortedProfiles: [(sourceID: String, appearance: CustomAgentAppearance)] {
        preferences.customAgentAppearances
            .map { (sourceID: $0.key, appearance: $0.value) }
            .sorted { $0.sourceID.localizedStandardCompare($1.sourceID) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(t("Custom agent identity", "自定义 Agent 外观"))
                    .font(.system(size: 14, weight: .semibold))
                Text(t(
                    "Choose a label and icon for custom sources already sent to Agent Notch.",
                    "为已发送到 Agent Notch 的自定义来源设置名称和图标。"
                ))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    TextField(t("Source ID, e.g. my-agent", "来源 ID，例如 my-agent"), text: $sourceDraft)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .onSubmit(addSource)
                        .accessibilityIdentifier("settings.customAgent.sourceID")

                    Button(action: addSource) {
                        Label(t("Add", "添加"), systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAddSource)
                    .accessibilityIdentifier("settings.customAgent.add")
                }
                .padding(.bottom, 10)

                if sortedProfiles.isEmpty {
                    Text(t(
                        "No custom sources configured. Add the same source ID used by your Agent Bridge events.",
                        "尚未配置自定义来源。请添加 Agent Bridge 事件使用的同一个来源 ID。"
                    ))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                } else {
                    Divider()
                    ForEach(sortedProfiles, id: \.sourceID) { profile in
                        if let source = AgentSource(rawValue: profile.sourceID) {
                            CustomAgentAppearanceRow(
                                source: source,
                                appearance: profile.appearance,
                                language: preferences.language,
                                onUpdate: { displayName, icon in
                                    preferences.updateCustomAgentAppearance(
                                        for: source,
                                        displayName: displayName,
                                        icon: icon
                                    )
                                },
                                onRemove: {
                                    preferences.removeCustomAgentAppearance(for: source)
                                }
                            )
                            .padding(.vertical, 9)
                            .accessibilityIdentifier("settings.customAgent.profile.\(source.rawValue)")
                            Divider()
                        }
                    }
                }

                Text(t(
                    "Display only · does not change hooks, messaging, or approval permissions.",
                    "仅影响显示 · 不会修改 Hook、消息通道或审批权限。"
                ))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 9)
            }
            .padding(14)
            .settingsSurface()
        }
    }

    private func addSource() {
        guard canAddSource, let source = normalizedSourceDraft else { return }
        if preferences.addCustomAgentAppearance(for: source) {
            sourceDraft = ""
        }
    }

    private func t(_ english: String, _ chinese: String) -> String {
        preferences.language.text(english, chinese)
    }
}

private struct CustomAgentAppearanceRow: View {
    let source: AgentSource
    let appearance: CustomAgentAppearance
    let language: AppLanguage
    let onUpdate: (String, CustomAgentIcon) -> Void
    let onRemove: () -> Void

    @State private var displayName: String
    @State private var icon: CustomAgentIcon
    @FocusState private var nameIsFocused: Bool

    init(
        source: AgentSource,
        appearance: CustomAgentAppearance,
        language: AppLanguage,
        onUpdate: @escaping (String, CustomAgentIcon) -> Void,
        onRemove: @escaping () -> Void
    ) {
        self.source = source
        self.appearance = appearance
        self.language = language
        self.onUpdate = onUpdate
        self.onRemove = onRemove
        _displayName = State(initialValue: appearance.displayName)
        _icon = State(initialValue: appearance.icon)
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon.rawValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(source.accentColor)
                .frame(width: 24, height: 24)
                .background(source.accentColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                TextField(t("Display name", "显示名称"), text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, weight: .medium))
                    .focused($nameIsFocused)
                    .onChange(of: displayName) { _, newValue in
                        saveIfValid(displayName: newValue, icon: icon)
                    }
                    .onSubmit {
                        saveIfValid(displayName: displayName, icon: icon)
                    }
                    .accessibilityLabel(t("Display name", "显示名称"))

                Text(source.rawValue)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Picker(t("Icon", "图标"), selection: $icon) {
                ForEach(CustomAgentIcon.allCases) { choice in
                    Label(
                        choice.title(language: language),
                        systemImage: choice.rawValue
                    )
                    .tag(choice)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .onChange(of: icon) { _, newIcon in
                saveIfValid(displayName: displayName, icon: newIcon)
            }
            .accessibilityLabel(t("Agent icon", "Agent 图标"))

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help(t("Remove custom appearance", "移除此自定义外观"))
            .accessibilityLabel(t("Remove custom appearance", "移除此自定义外观"))
        }
        .onChange(of: appearance) { _, updated in
            guard !nameIsFocused else { return }
            displayName = updated.displayName
            icon = updated.icon
        }
    }

    private func saveIfValid(displayName: String, icon: CustomAgentIcon) {
        guard CustomAgentAppearance(displayName: displayName, icon: icon) != nil else {
            return
        }
        onUpdate(displayName, icon)
    }

    private func t(_ english: String, _ chinese: String) -> String {
        language.text(english, chinese)
    }
}
