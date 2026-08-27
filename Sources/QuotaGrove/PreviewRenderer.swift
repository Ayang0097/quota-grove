import AppKit

enum PreviewRenderer {
    static func render(
        remainingPercent: Double,
        expanded: Bool,
        stashed: Bool = false,
        stashedEdge: StashedEdge = .right,
        to url: URL
    ) throws {
        let size = NSSize(
            width: stashed ? CardWindowController.stashedWidth : CardWindowController.cardWidth,
            height: expanded && !stashed ? CardWindowController.expandedHeight : CardWindowController.collapsedHeight
        )
        let view = QuotaCardView(frame: NSRect(origin: .zero, size: size))
        view.snapshot = .demo(remainingPercent: remainingPercent)
        view.isExpanded = expanded
        view.stashedEdge = stashedEdge
        view.isStashed = stashed
        view.layoutSubtreeIfNeeded()

        let scale = 2
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width) * scale,
            pixelsHigh: Int(size.height) * scale,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw PreviewError.bitmapCreationFailed
        }
        bitmap.size = size
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw PreviewError.pngEncodingFailed
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: url, options: .atomic)
    }

    enum PreviewError: LocalizedError {
        case bitmapCreationFailed
        case pngEncodingFailed

        var errorDescription: String? {
            switch self {
            case .bitmapCreationFailed: return "无法创建预览位图"
            case .pngEncodingFailed: return "无法编码预览 PNG"
            }
        }
    }
}
