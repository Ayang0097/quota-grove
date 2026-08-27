import AppKit

final class ThemeBackgroundStore {
    static let shared = ThemeBackgroundStore()

    private var cache: [QuotaTheme: NSImage] = [:]

    func image(for theme: QuotaTheme) -> NSImage? {
        if let cached = cache[theme] { return cached }
        guard let url = assetURL(for: theme), let image = NSImage(contentsOf: url) else { return nil }
        cache[theme] = image
        return image
    }

    private func assetURL(for theme: QuotaTheme) -> URL? {
        let filename: String
        switch theme {
        case .forest: filename = "背景百分之50以上.png"
        case .autumn: filename = "背景百分之50以下.png"
        case .apocalypse: filename = "背景百分之20以下.png"
        case .wasteland: filename = "背景百分之3以下.png"
        }

        if let resourceURL = Bundle.main.resourceURL?
            .appendingPathComponent("Backgrounds", isDirectory: true)
            .appendingPathComponent(filename),
           FileManager.default.fileExists(atPath: resourceURL.path) {
            return resourceURL
        }

        let developmentURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("bg", isDirectory: true)
            .appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: developmentURL.path) ? developmentURL : nil
    }
}
