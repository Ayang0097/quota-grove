import AppKit
import CoreImage

final class LeafSpriteStore {
    static let shared = LeafSpriteStore()

    private var cache: [String: NSImage] = [:]
    private let ciContext = CIContext(options: [.cacheIntermediates: true])

    func image(for theme: QuotaTheme, variant: Int, softened: Bool) -> NSImage? {
        let filename = "\(theme.rawValue)-\(variant % 3 + 1)"
        let cacheKey = softened ? "\(filename)-soft" : filename
        if let cached = cache[cacheKey] { return cached }
        guard let url = assetURL(filename: filename) else { return nil }

        if let image = processedImage(at: url, theme: theme, softened: softened) {
            cache[cacheKey] = image
            return image
        }

        guard let image = NSImage(contentsOf: url) else { return nil }
        cache[filename] = image
        return image
    }

    private func processedImage(at url: URL, theme: QuotaTheme, softened: Bool) -> NSImage? {
        guard let input = CIImage(contentsOf: url) else { return nil }
        let extent = input.extent
        var output = input
            .applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: 0.04,
                kCIInputSaturationKey: 1.2,
                kCIInputContrastKey: 1.02
            ])
            .applyingFilter("CIColorMonochrome", parameters: [
                kCIInputColorKey: tintColor(for: theme),
                kCIInputIntensityKey: 0.48
            ])
            .applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: 0.28])
        if softened {
            output = output
                .clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 14.0])
                .cropped(to: extent)
        }
        guard let cgImage = ciContext.createCGImage(output, from: extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: extent.width, height: extent.height))
    }

    private func tintColor(for theme: QuotaTheme) -> CIColor {
        switch theme {
        case .forest:
            return CIColor(red: 0.26, green: 0.82, blue: 0.2)
        case .autumn:
            return CIColor(red: 0.94, green: 0.46, blue: 0.08)
        case .apocalypse:
            return CIColor(red: 0.68, green: 0.18, blue: 0.12)
        case .wasteland:
            return CIColor(red: 0.7, green: 0.69, blue: 0.62)
        }
    }

    private func assetURL(filename: String) -> URL? {
        if let bundledURL = Bundle.main.resourceURL?
            .appendingPathComponent("Leaves", isDirectory: true)
            .appendingPathComponent(filename)
            .appendingPathExtension("png"),
           FileManager.default.fileExists(atPath: bundledURL.path) {
            return bundledURL
        }

        let developmentURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Assets/Leaves", isDirectory: true)
            .appendingPathComponent(filename)
            .appendingPathExtension("png")
        return FileManager.default.fileExists(atPath: developmentURL.path) ? developmentURL : nil
    }
}
