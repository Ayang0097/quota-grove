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

        try write(view: view, size: size, to: url)
    }

    static func renderLeafFrames(
        from startPercent: Double,
        to endPercent: Double,
        expanded: Bool,
        manualBurst: Bool = false,
        framesPerSecond: Int = 30,
        duration: TimeInterval = 4,
        to directory: URL
    ) throws {
        let size = NSSize(
            width: CardWindowController.cardWidth,
            height: expanded ? CardWindowController.expandedHeight : CardWindowController.collapsedHeight
        )
        let view = QuotaCardView(frame: NSRect(origin: .zero, size: size))
        view.isExpanded = expanded
        view.snapshot = .demo(remainingPercent: startPercent)
        if manualBurst {
            view.emitManualLeafBurstForPreview()
        } else {
            view.snapshot = .demo(remainingPercent: endPercent)
        }
        view.layoutSubtreeIfNeeded()

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let frameCount = max(1, Int(duration * Double(framesPerSecond)))
        let deltaTime = 1.0 / Double(framesPerSecond)
        for frame in 0..<frameCount {
            if frame > 0 { view.advanceLeafAnimationForPreview(by: deltaTime) }
            let frameURL = directory.appendingPathComponent(String(format: "frame-%03d.png", frame))
            try write(view: view, size: size, to: frameURL)
        }
    }

    private static func write(view: NSView, size: NSSize, to url: URL) throws {

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
