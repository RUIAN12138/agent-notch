//
//  UsageLimitMonitor.swift
//  ClaudeIsland
//
//  Reads subscription rate-limit snapshots emitted by local coding agents.
//  No credentials or network requests are required.
//

import Combine
import Foundation
import UserNotifications

struct UsageLimitWindow: Equatable, Sendable {
    let usedPercent: Double
    let windowMinutes: Int
    let resetsAt: Date

    var remainingPercent: Double {
        max(0, 100 - usedPercent)
    }
}

struct UsageLimitSnapshot: Equatable, Sendable {
    let source: AgentSource
    let planType: String?
    let primary: UsageLimitWindow?
    let secondary: UsageLimitWindow?
    let updatedAt: Date
}

enum UsageLimitWindowKind: String, CaseIterable, Sendable {
    case primary
    case secondary
}

struct UsageLimitThresholdAlert: Equatable, Sendable {
    let window: UsageLimitWindowKind
    let usedPercent: Double
    let thresholdPercent: Int
    let windowMinutes: Int
    let resetsAt: Date
}

enum UsageLimitAlertPolicy {
    static let defaultThreshold = 80

    static func sanitizedThreshold(_ value: Int) -> Int {
        min(100, max(50, value))
    }

    static func thresholdCrossings(
        from previous: UsageLimitSnapshot?,
        to current: UsageLimitSnapshot?,
        thresholdPercent: Int,
        enabled: Bool
    ) -> [UsageLimitThresholdAlert] {
        guard enabled,
              let previous,
              let current,
              previous.source == .codex,
              current.source == .codex else {
            return []
        }

        let threshold = Double(sanitizedThreshold(thresholdPercent))
        let pairs: [(UsageLimitWindowKind, UsageLimitWindow?, UsageLimitWindow?)] = [
            (.primary, previous.primary, current.primary),
            (.secondary, previous.secondary, current.secondary),
        ]

        return pairs.compactMap { kind, oldWindow, newWindow in
            guard let oldWindow,
                  let newWindow,
                  abs(oldWindow.resetsAt.timeIntervalSince(newWindow.resetsAt)) < 60,
                  oldWindow.usedPercent < threshold,
                  newWindow.usedPercent >= threshold else {
                return nil
            }

            return UsageLimitThresholdAlert(
                window: kind,
                usedPercent: newWindow.usedPercent,
                thresholdPercent: Int(threshold),
                windowMinutes: newWindow.windowMinutes,
                resetsAt: newWindow.resetsAt
            )
        }
    }
}

/// Tracks one alert per Codex rate-limit window. The previous snapshot is
/// updated even while alerts are disabled so enabling alerts never produces
/// a retroactive notification for a threshold already reached.
struct UsageLimitAlertTracker {
    private let defaults: UserDefaults
    private(set) var previousSnapshot: UsageLimitSnapshot?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    mutating func observe(
        snapshot: UsageLimitSnapshot?,
        enabled: Bool,
        thresholdPercent: Int
    ) -> [UsageLimitThresholdAlert] {
        defer { previousSnapshot = snapshot }
        guard let snapshot else { return [] }

        let candidates = UsageLimitAlertPolicy.thresholdCrossings(
            from: previousSnapshot,
            to: snapshot,
            thresholdPercent: thresholdPercent,
            enabled: enabled
        )

        return candidates.filter { alert in
            let key = "notchUsageLimitAlert.lastReset.\(alert.window.rawValue)"
            let resetTime = alert.resetsAt.timeIntervalSince1970
            if let lastReset = defaults.object(forKey: key) as? Double,
               abs(lastReset - resetTime) < 60 {
                return false
            }
            defaults.set(resetTime, forKey: key)
            return true
        }
    }

    mutating func resetBaseline() {
        previousSnapshot = nil
    }
}

enum UsageLimitNotificationAuthorization {
    static func requestIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}

private enum UsageLimitNotificationScheduler {
    static func schedule(
        _ alert: UsageLimitThresholdAlert,
        language: AppLanguage
    ) {
        let windowLabel: String
        if alert.windowMinutes >= 10_080 {
            windowLabel = language.text("weekly window", "周用量窗口")
        } else {
            let hours = max(1, Int((Double(alert.windowMinutes) / 60).rounded()))
            windowLabel = language.text("\(hours)-hour window", "\(hours) 小时窗口")
        }
        let resetTime = DateFormatter.localizedString(
            from: alert.resetsAt,
            dateStyle: .none,
            timeStyle: .short
        )
        let content = UNMutableNotificationContent()
        content.title = language.text(
            "Codex usage threshold reached",
            "Codex 用量已达到提醒阈值"
        )
        content.body = language.text(
            "Your \(windowLabel) has reached \(Int(alert.usedPercent.rounded()))% (resets at \(resetTime)).",
            "Codex \(windowLabel)已使用 \(Int(alert.usedPercent.rounded()))%，将于 \(resetTime) 重置。"
        )
        content.sound = .default
        content.threadIdentifier = "agent-notch-usage-limits"

        let resetIdentity = Int(alert.resetsAt.timeIntervalSince1970)
        let request = UNNotificationRequest(
            identifier: "usage-limit-\(alert.window.rawValue)-\(resetIdentity)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("Failed to schedule Codex usage alert: %@", error.localizedDescription)
            }
        }
    }
}

@MainActor
final class UsageLimitMonitor: ObservableObject {
    static let shared = UsageLimitMonitor()

    @Published private(set) var snapshot: UsageLimitSnapshot?

    private var timer: Timer?
    private var isRefreshing = false
    private var alertTracker = UsageLimitAlertTracker()

    private init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) {
            _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        Task {
            let latest = await Task.detached(priority: .utility) {
                Self.loadLatestCodexSnapshot()
            }.value
            snapshot = latest
            guard let latest else {
                alertTracker.resetBaseline()
                isRefreshing = false
                return
            }

            let defaults = UserDefaults.standard
            let alerts = alertTracker.observe(
                snapshot: latest,
                enabled: defaults.bool(forKey: "notchUsageLimitAlertsEnabled"),
                thresholdPercent: defaults.object(
                    forKey: "notchUsageLimitAlertThreshold"
                ) as? Int ?? UsageLimitAlertPolicy.defaultThreshold
            )
            let language = AppLanguage(
                rawValue: defaults.string(forKey: "notchLanguage") ?? ""
            ) ?? .english
            alerts.forEach { UsageLimitNotificationScheduler.schedule($0, language: language) }
            isRefreshing = false
        }
    }

    private nonisolated static func loadLatestCodexSnapshot()
        -> UsageLimitSnapshot? {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .contentModificationDateKey,
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }

        var newestURL: URL?
        var newestDate = Date.distantPast
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(
                forKeys: [.isRegularFileKey, .contentModificationDateKey]
            ),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  modified > newestDate else {
                continue
            }
            newestURL = url
            newestDate = modified
        }

        guard let newestURL,
              let rateLimits = lastRateLimits(in: newestURL) else {
            return nil
        }

        let primary = parseWindow(rateLimits["primary"])
        let secondary = parseWindow(rateLimits["secondary"])
        guard primary != nil || secondary != nil else {
            return nil
        }

        return UsageLimitSnapshot(
            source: .codex,
            planType: rateLimits["plan_type"] as? String,
            primary: primary,
            secondary: secondary,
            updatedAt: newestDate
        )
    }

    private nonisolated static func lastRateLimits(
        in url: URL
    ) -> [String: Any]? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer { try? handle.close() }

        let fileSize = (try? handle.seekToEnd()) ?? 0
        let maximumTailBytes: UInt64 = 1_048_576
        let offset = fileSize > maximumTailBytes
            ? fileSize - maximumTailBytes
            : 0
        try? handle.seek(toOffset: offset)
        guard let data = try? handle.readToEnd(),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        var lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        if offset > 0, !lines.isEmpty {
            lines.removeFirst() // The tail may begin in the middle of a row.
        }

        for line in lines.reversed() {
            guard line.contains("\"rate_limits\""),
                  let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data)
                    as? [String: Any],
                  let payload = object["payload"] as? [String: Any],
                  payload["type"] as? String == "token_count",
                  let limits = payload["rate_limits"] as? [String: Any] else {
                continue
            }
            return limits
        }
        return nil
    }

    private nonisolated static func parseWindow(
        _ value: Any?
    ) -> UsageLimitWindow? {
        guard let dictionary = value as? [String: Any],
              let usedPercent = number(dictionary["used_percent"]),
              let windowMinutes = number(dictionary["window_minutes"]),
              let resetsAt = number(dictionary["resets_at"]) else {
            return nil
        }

        return UsageLimitWindow(
            usedPercent: min(100, max(0, usedPercent)),
            windowMinutes: Int(windowMinutes),
            resetsAt: Date(timeIntervalSince1970: resetsAt)
        )
    }

    private nonisolated static func number(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }
}
