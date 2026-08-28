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

    static func renderRainFrames(
        remainingPercent: Double,
        expanded: Bool,
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
        view.snapshot = .demo(remainingPercent: remainingPercent)
        view.setRainPreviewActive(true)
        view.layoutSubtreeIfNeeded()
        let baseImage = try renderBaseImage(cardView: view, size: size)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let frameCount = max(1, Int(duration * Double(framesPerSecond)))
        let deltaTime = 1.0 / Double(framesPerSecond)
        for frame in 0..<frameCount {
            if frame > 0 { view.advanceRainAnimationForPreview(by: deltaTime) }
            let frameURL = directory.appendingPathComponent(String(format: "frame-%03d.png", frame))
            try writeWeatherEffectFrame(
                baseImage: baseImage,
                cardView: view,
                size: size,
                to: frameURL
            )
        }
    }

    static func renderSnowFrames(
        remainingPercent: Double,
        expanded: Bool,
        framesPerSecond: Int = 30,
        duration: TimeInterval = 6,
        to directory: URL
    ) throws {
        let size = NSSize(
            width: CardWindowController.cardWidth,
            height: expanded ? CardWindowController.expandedHeight : CardWindowController.collapsedHeight
        )
        let view = QuotaCardView(frame: NSRect(origin: .zero, size: size))
        view.isExpanded = expanded
        view.snapshot = .demo(remainingPercent: remainingPercent)
        view.setSnowPreviewActive(true)
        view.layoutSubtreeIfNeeded()
        let baseImage = try renderBaseImage(cardView: view, size: size)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let frameCount = max(1, Int(duration * Double(framesPerSecond)))
        let deltaTime = 1.0 / Double(framesPerSecond)
        for frame in 0..<frameCount {
            if frame > 0 { view.advanceSnowAnimationForPreview(by: deltaTime) }
            let frameURL = directory.appendingPathComponent(String(format: "frame-%03d.png", frame))
            try writeWeatherEffectFrame(
                baseImage: baseImage,
                cardView: view,
                size: size,
                to: frameURL
            )
        }
    }

    private static func renderBaseImage(cardView: QuotaCardView, size: NSSize) throws -> NSImage {
        let bitmap = try makeBitmap(size: size)
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw PreviewError.bitmapCreationFailed
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        cardView.displayBaseForPreview(in: context)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        return image
    }

    private static func writeWeatherEffectFrame(
        baseImage: NSImage,
        cardView: QuotaCardView,
        size: NSSize,
        to url: URL
    ) throws {
        let bitmap = try makeBitmap(size: size)
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw PreviewError.bitmapCreationFailed
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        baseImage.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: size),
            operation: .sourceOver,
            fraction: 1
        )

        cardView.drawVisibleEffectsForPreview()
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        try write(bitmap: bitmap, to: url)
    }

    private static func makeBitmap(size: NSSize) throws -> NSBitmapImageRep {
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
        if let bitmapData = bitmap.bitmapData {
            bitmapData.initialize(repeating: 0, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
        }
        return bitmap
    }

    private static func write(bitmap: NSBitmapImageRep, to url: URL) throws {
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw PreviewError.pngEncodingFailed
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: url, options: .atomic)
    }

    private static func write(view: NSView, size: NSSize, to url: URL) throws {
        view.needsDisplay = true
        for subview in view.subviews { subview.needsDisplay = true }
        let bitmap = try makeBitmap(size: size)
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw PreviewError.bitmapCreationFailed
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        view.displayIgnoringOpacity(view.bounds, in: context)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        try write(bitmap: bitmap, to: url)
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
