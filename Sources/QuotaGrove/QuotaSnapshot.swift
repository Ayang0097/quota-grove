import Foundation

struct QuotaSnapshot: Codable, Equatable {
    let windowMinutes: Int
    let remainingPercent: Double
    let usedPercent: Double
    let resetsAt: Date?
    let fetchedAt: Date
    let source: String
    let planType: String?

    var windowTitle: String {
        if windowMinutes == 10_080 { return "7 天额度" }
        if windowMinutes % 1_440 == 0 { return "\(windowMinutes / 1_440) 天额度" }
        if windowMinutes % 60 == 0 { return "\(windowMinutes / 60) 小时额度" }
        return "\(windowMinutes) 分钟额度"
    }

    var roundedRemaining: Int {
        Int(remainingPercent.rounded())
    }

    var roundedUsed: Int {
        Int(usedPercent.rounded())
    }

    var readablePlan: String {
        guard let planType, !planType.isEmpty else { return "--" }
        let mapping = [
            "free": "Free",
            "plus": "Plus",
            "pro": "Pro",
            "prolite": "Pro Lite",
            "team": "Team",
            "business": "Business",
            "enterprise": "Enterprise",
            "edu": "Edu"
        ]
        return mapping[planType.lowercased()] ?? planType
    }

    static func demo(remainingPercent: Double, expanded: Bool = false) -> QuotaSnapshot {
        let remaining = min(max(remainingPercent, 0), 100)
        return QuotaSnapshot(
            windowMinutes: 10_080,
            remainingPercent: remaining,
            usedPercent: 100 - remaining,
            resetsAt: Date().addingTimeInterval(6 * 86_400 + 19 * 3_600),
            fetchedAt: Date().addingTimeInterval(-7),
            source: "preview",
            planType: "prolite"
        )
    }
}

enum QuotaSnapshotCache {
    private static let key = "QuotaGrove.lastTrustedSnapshot"

    static func load(defaults: UserDefaults = .standard) -> QuotaSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(QuotaSnapshot.self, from: data)
    }

    static func save(_ snapshot: QuotaSnapshot, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }
}
