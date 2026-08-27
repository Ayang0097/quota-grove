import AppKit

enum QuotaTheme: String, CaseIterable, Codable {
    case forest
    case autumn
    case apocalypse
    case wasteland

    static func select(for remainingPercent: Double) -> QuotaTheme {
        switch remainingPercent {
        case 50...100:
            return .forest
        case 20..<50:
            return .autumn
        case 3..<20:
            return .apocalypse
        default:
            return .wasteland
        }
    }

    var accent: NSColor {
        switch self {
        case .forest:
            return NSColor(calibratedRed: 0.47, green: 0.88, blue: 0.67, alpha: 1)
        case .autumn:
            return NSColor(calibratedRed: 0.96, green: 0.72, blue: 0.29, alpha: 1)
        case .apocalypse:
            return NSColor(calibratedRed: 0.94, green: 0.29, blue: 0.28, alpha: 1)
        case .wasteland:
            return NSColor(calibratedRed: 0.78, green: 0.29, blue: 0.28, alpha: 1)
        }
    }

    var borderAccent: NSColor {
        switch self {
        case .wasteland:
            return NSColor(calibratedWhite: 0.94, alpha: 1)
        default:
            return accent
        }
    }

    var progressAccent: NSColor {
        switch self {
        case .forest:
            return NSColor(calibratedRed: 0.25, green: 0.86, blue: 0.42, alpha: 1)
        default:
            return accent
        }
    }

    var accessibilityName: String {
        AppText.themeAccessibilityName(self)
    }
}
