import Foundation

enum QuotaParseError: LocalizedError {
    case noRateLimitWindow
    case invalidUsedPercent

    var errorDescription: String? {
        switch self {
        case .noRateLimitWindow:
            return "额度事件缺少可用窗口"
        case .invalidUsedPercent:
            return "额度事件包含异常百分比"
        }
    }
}

enum QuotaEventParser {
    static func parse(line: Data) throws -> QuotaSnapshot? {
        guard line.range(of: Data("\"rate_limits\"".utf8)) != nil else { return nil }
        guard
            let root = try JSONSerialization.jsonObject(with: line) as? [String: Any],
            let payload = root["payload"] as? [String: Any],
            let limits = payload["rate_limits"] as? [String: Any]
        else {
            return nil
        }

        let windows = ["primary", "secondary"].compactMap { key -> Window? in
            guard let value = limits[key] as? [String: Any] else { return nil }
            return Window(dictionary: value)
        }

        guard !windows.isEmpty else { throw QuotaParseError.noRateLimitWindow }
        let selected = windows.first(where: { $0.windowMinutes == 10_080 })
            ?? windows.max(by: { $0.windowMinutes < $1.windowMinutes })!

        guard selected.usedPercent.isFinite, (0...100).contains(selected.usedPercent) else {
            throw QuotaParseError.invalidUsedPercent
        }

        let timestamp = (root["timestamp"] as? String).flatMap(parseISO8601) ?? Date()
        let resetsAt = selected.resetsAt.map { Date(timeIntervalSince1970: $0) }
        let remaining = 100 - selected.usedPercent

        return QuotaSnapshot(
            windowMinutes: selected.windowMinutes,
            remainingPercent: remaining,
            usedPercent: selected.usedPercent,
            resetsAt: resetsAt,
            fetchedAt: timestamp,
            source: "codex-local-event",
            planType: limits["plan_type"] as? String
        )
    }

    private static func parseISO8601(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private struct Window {
        let usedPercent: Double
        let windowMinutes: Int
        let resetsAt: Double?

        init?(dictionary: [String: Any]) {
            guard
                let used = Self.double(dictionary["used_percent"]),
                let window = Self.int(dictionary["window_minutes"]),
                window > 0
            else {
                return nil
            }
            usedPercent = used
            windowMinutes = window
            resetsAt = Self.double(dictionary["resets_at"])
        }

        private static func double(_ value: Any?) -> Double? {
            if let value = value as? Double { return value }
            if let value = value as? Int { return Double(value) }
            if let value = value as? NSNumber { return value.doubleValue }
            return nil
        }

        private static func int(_ value: Any?) -> Int? {
            if let value = value as? Int { return value }
            if let value = value as? NSNumber { return value.intValue }
            return nil
        }
    }
}
