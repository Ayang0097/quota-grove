import AppKit

enum StashedEdge: String {
    case left
    case right
}

protocol QuotaCardViewDelegate: AnyObject {
    func cardViewDidSingleClick(_ view: QuotaCardView)
    func cardViewDidDoubleClick(_ view: QuotaCardView)
    func cardView(_ view: QuotaCardView, dragTo origin: NSPoint)
    func cardViewDidEndDragging(_ view: QuotaCardView)
    func cardViewPointerEntered(_ view: QuotaCardView)
    func cardViewPointerExited(_ view: QuotaCardView)
    func cardView(_ view: QuotaCardView, showContextMenu event: NSEvent)
}

final class QuotaCardView: NSView {
    weak var delegate: QuotaCardViewDelegate?

    var snapshot: QuotaSnapshot? {
        didSet { updateAccessibility(); needsDisplay = true }
    }
    var isExpanded = false {
        didSet {
            guard oldValue != isExpanded else { return }
            updateAccessibility()
            needsDisplay = true
        }
    }
    var isStashed = false {
        didSet {
            guard oldValue != isStashed else { return }
            updateTrackingAreas()
            updateAccessibility()
            needsDisplay = true
        }
    }
    var stashedEdge: StashedEdge = .right {
        didSet {
            guard oldValue != stashedEdge else { return }
            needsDisplay = true
        }
    }

    private var startMouseLocation = NSPoint.zero
    private var startWindowOrigin = NSPoint.zero
    private var didDrag = false
    private var pendingSingleClick: DispatchWorkItem?
    private var hoverTrackingArea: NSTrackingArea?
    private lazy var codexIcon: NSImage? = {
        if let bundledURL = Bundle.main.url(forResource: "CodexIcon", withExtension: "png"),
           let image = NSImage(contentsOf: bundledURL) {
            return image
        }

        let developmentURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Assets/CodexIcon.png")
        return NSImage(contentsOf: developmentURL)
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        updateAccessibility()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        delegate?.cardViewPointerEntered(self)
    }

    override func mouseExited(with event: NSEvent) {
        delegate?.cardViewPointerExited(self)
    }

    override func mouseDown(with event: NSEvent) {
        pendingSingleClick?.cancel()
        startMouseLocation = NSEvent.mouseLocation
        startWindowOrigin = window?.frame.origin ?? .zero
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        let current = NSEvent.mouseLocation
        let deltaX = current.x - startMouseLocation.x
        let deltaY = current.y - startMouseLocation.y
        if abs(deltaX) > 2 || abs(deltaY) > 2 { didDrag = true }
        guard didDrag else { return }
        delegate?.cardView(
            self,
            dragTo: NSPoint(x: startWindowOrigin.x + deltaX, y: startWindowOrigin.y + deltaY)
        )
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            delegate?.cardViewDidEndDragging(self)
            return
        }

        if event.clickCount >= 2 {
            pendingSingleClick?.cancel()
            delegate?.cardViewDidDoubleClick(self)
            return
        }

        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.delegate?.cardViewDidSingleClick(self)
        }
        pendingSingleClick = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24, execute: task)
    }

    override func rightMouseDown(with event: NSEvent) {
        pendingSingleClick?.cancel()
        delegate?.cardView(self, showContextMenu: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSGraphicsContext.current?.imageInterpolation = .high
        isStashed ? drawStashedBar() : drawCard()
    }

    func refreshClock() {
        needsDisplay = true
    }

    private func drawStashedBar() {
        // Extend the rounded card beyond the screen edge, leaving a single
        // curved slice visible instead of an isolated progress capsule.
        let hiddenExtension: CGFloat = 18
        let shellRect: NSRect
        switch stashedEdge {
        case .right:
            shellRect = NSRect(
                x: 0.5,
                y: 0.5,
                width: bounds.width + hiddenExtension,
                height: bounds.height - 1
            )
        case .left:
            shellRect = NSRect(
                x: -hiddenExtension + 0.5,
                y: 0.5,
                width: bounds.width + hiddenExtension,
                height: bounds.height - 1
            )
        }

        let shell = NSBezierPath(roundedRect: shellRect, xRadius: 18, yRadius: 18)
        NSGraphicsContext.saveGraphicsState()
        shell.addClip()
        drawEnvironment(in: shellRect)
        NSColor(calibratedWhite: 0, alpha: 0.48).setFill()
        shell.fill()
        NSGraphicsContext.restoreGraphicsState()

        currentBorderColor.setStroke()
        shell.lineWidth = 1
        shell.stroke()

        let trackRect = NSRect(
            x: (bounds.width - 5) / 2,
            y: 15,
            width: 5,
            height: bounds.height - 30
        )
        let track = NSBezierPath(roundedRect: trackRect, xRadius: 2.5, yRadius: 2.5)
        NSColor(calibratedWhite: 0.02, alpha: 0.74).setFill()
        track.fill()

        let remaining = CGFloat(snapshot?.remainingPercent ?? 0) / 100
        let fillHeight = max(snapshot == nil ? 0 : 4, trackRect.height * remaining)
        guard fillHeight > 0 else { return }
        let fillRect = NSRect(
            x: trackRect.minX,
            y: trackRect.minY,
            width: trackRect.width,
            height: fillHeight
        )
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: 2.5, yRadius: 2.5)
        NSGraphicsContext.saveGraphicsState()
        fill.addClip()
        let accent = snapshot.map { QuotaTheme.select(for: $0.remainingPercent).accent } ?? .white
        NSGradient(
            starting: accent.blended(withFraction: 0.32, of: .black) ?? accent,
            ending: accent.blended(withFraction: 0.08, of: .black) ?? accent
        )?.draw(in: fillRect, angle: 90)
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.12).setStroke()
        track.lineWidth = 0.7
        track.stroke()
    }

    private func drawCard() {
        let cardRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let clip = NSBezierPath(roundedRect: cardRect, xRadius: 18, yRadius: 18)

        NSGraphicsContext.saveGraphicsState()
        clip.addClip()
        drawEnvironment(in: bounds)
        drawReadabilityOverlay(in: bounds)
        NSGraphicsContext.restoreGraphicsState()

        currentBorderColor.setStroke()
        clip.lineWidth = 1
        clip.stroke()

        drawSummary()
        if isExpanded { drawDetails() }
    }

    private var currentTheme: QuotaTheme {
        snapshot.map { QuotaTheme.select(for: $0.remainingPercent) } ?? .forest
    }

    private var currentBorderColor: NSColor {
        let accent = currentTheme.accent
        return (accent.blended(withFraction: 0.12, of: .black) ?? accent)
            .withAlphaComponent(0.80)
    }

    private func drawEnvironment(in rect: NSRect) {
        if let image = ThemeBackgroundStore.shared.image(for: currentTheme) {
            drawBackgroundImage(image, in: rect)
            return
        }
        switch currentTheme {
        case .forest: drawForest(in: rect)
        case .autumn: drawAutumn(in: rect)
        case .apocalypse: drawApocalypse(in: rect)
        case .wasteland: drawWasteland(in: rect)
        }
    }

    private func drawBackgroundImage(_ image: NSImage, in rect: NSRect) {
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return }
        let targetAspect = rect.width / rect.height
        let sourceAspect = sourceSize.width / sourceSize.height
        var sourceRect = NSRect(origin: .zero, size: sourceSize)

        if sourceAspect > targetAspect {
            sourceRect.size.width = sourceSize.height * targetAspect
            sourceRect.origin.x = isExpanded
                ? max(0, sourceSize.width - sourceRect.width)
                : (sourceSize.width - sourceRect.width) / 2
        } else if sourceAspect < targetAspect {
            sourceRect.size.height = sourceSize.width / targetAspect
            sourceRect.origin.y = (sourceSize.height - sourceRect.height) / 2
        }

        image.draw(
            in: rect,
            from: sourceRect,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    private func drawForest(in rect: NSRect) {
        NSGradient(
            starting: NSColor(calibratedRed: 0.025, green: 0.09, blue: 0.08, alpha: 1),
            ending: NSColor(calibratedRed: 0.08, green: 0.27, blue: 0.19, alpha: 1)
        )?.draw(in: rect, angle: 12)

        let beam = NSBezierPath()
        beam.move(to: NSPoint(x: rect.maxX * 0.82, y: rect.maxY))
        beam.line(to: NSPoint(x: rect.maxX * 0.48, y: 0))
        beam.line(to: NSPoint(x: rect.maxX * 0.76, y: 0))
        beam.close()
        NSColor(calibratedRed: 0.56, green: 0.95, blue: 0.66, alpha: 0.09).setFill()
        beam.fill()

        drawTrunks(in: rect, color: NSColor(calibratedRed: 0.025, green: 0.08, blue: 0.06, alpha: 0.9), count: 7)
        drawCanopy(in: rect, color: NSColor(calibratedRed: 0.06, green: 0.2, blue: 0.12, alpha: 0.95), autumn: false)
    }

    private func drawAutumn(in rect: NSRect) {
        NSGradient(
            starting: NSColor(calibratedRed: 0.12, green: 0.055, blue: 0.035, alpha: 1),
            ending: NSColor(calibratedRed: 0.47, green: 0.25, blue: 0.09, alpha: 1)
        )?.draw(in: rect, angle: 18)

        let glowRect = NSRect(x: rect.maxX - 62, y: rect.maxY - 55, width: 42, height: 42)
        NSColor(calibratedRed: 1, green: 0.69, blue: 0.25, alpha: 0.12).setFill()
        NSBezierPath(ovalIn: glowRect).fill()
        drawTrunks(in: rect, color: NSColor(calibratedRed: 0.12, green: 0.055, blue: 0.025, alpha: 0.88), count: 6)
        drawCanopy(in: rect, color: NSColor(calibratedRed: 0.65, green: 0.3, blue: 0.07, alpha: 0.86), autumn: true)
    }

    private func drawApocalypse(in rect: NSRect) {
        NSGradient(
            starting: NSColor(calibratedRed: 0.055, green: 0.045, blue: 0.055, alpha: 1),
            ending: NSColor(calibratedRed: 0.47, green: 0.09, blue: 0.07, alpha: 1)
        )?.draw(in: rect, angle: 24)

        NSColor(calibratedRed: 0.04, green: 0.035, blue: 0.04, alpha: 0.94).setFill()
        let horizon = NSBezierPath()
        horizon.move(to: .zero)
        horizon.line(to: NSPoint(x: 0, y: rect.height * 0.24))
        horizon.line(to: NSPoint(x: 28, y: rect.height * 0.3))
        horizon.line(to: NSPoint(x: 48, y: rect.height * 0.25))
        horizon.line(to: NSPoint(x: 72, y: rect.height * 0.38))
        horizon.line(to: NSPoint(x: 88, y: rect.height * 0.27))
        horizon.line(to: NSPoint(x: 116, y: rect.height * 0.42))
        horizon.line(to: NSPoint(x: 129, y: rect.height * 0.21))
        horizon.line(to: NSPoint(x: 151, y: rect.height * 0.34))
        horizon.line(to: NSPoint(x: 169, y: rect.height * 0.28))
        horizon.line(to: NSPoint(x: rect.maxX, y: rect.height * 0.4))
        horizon.line(to: NSPoint(x: rect.maxX, y: 0))
        horizon.close()
        horizon.fill()

        NSColor(calibratedRed: 1, green: 0.36, blue: 0.22, alpha: 0.1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 150, y: rect.maxY - 49, width: 32, height: 32)).fill()
    }

    private func drawWasteland(in rect: NSRect) {
        NSGradient(
            starting: NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.125, alpha: 1),
            ending: NSColor(calibratedRed: 0.42, green: 0.4, blue: 0.37, alpha: 1)
        )?.draw(in: rect, angle: 16)

        NSColor(calibratedWhite: 0.08, alpha: 0.8).setFill()
        let ruins: [NSRect] = [
            NSRect(x: 112, y: 0, width: 22, height: rect.height * 0.33),
            NSRect(x: 137, y: 0, width: 16, height: rect.height * 0.48),
            NSRect(x: 157, y: 0, width: 28, height: rect.height * 0.27)
        ]
        ruins.forEach { NSBezierPath(rect: $0).fill() }

        let branch = NSBezierPath()
        branch.move(to: NSPoint(x: 188, y: 4))
        branch.curve(to: NSPoint(x: 168, y: rect.height * 0.72), controlPoint1: NSPoint(x: 183, y: rect.height * 0.35), controlPoint2: NSPoint(x: 174, y: rect.height * 0.58))
        branch.move(to: NSPoint(x: 174, y: rect.height * 0.55))
        branch.line(to: NSPoint(x: 186, y: rect.height * 0.7))
        NSColor(calibratedWhite: 0.08, alpha: 0.72).setStroke()
        branch.lineWidth = 3
        branch.stroke()
    }

    private func drawTrunks(in rect: NSRect, color: NSColor, count: Int) {
        color.setFill()
        for index in 0..<count {
            let x = rect.width * 0.54 + CGFloat(index) * rect.width * 0.075
            let width = CGFloat(5 + (index % 3) * 2)
            NSBezierPath(rect: NSRect(x: x, y: 0, width: width, height: rect.height)).fill()
        }
    }

    private func drawCanopy(in rect: NSRect, color: NSColor, autumn: Bool) {
        let points: [(CGFloat, CGFloat, CGFloat)] = [
            (0.55, 0.78, 0.2), (0.7, 0.9, 0.23), (0.86, 0.75, 0.22),
            (0.98, 0.92, 0.25), (0.62, 0.56, 0.16), (0.83, 0.5, 0.18)
        ]
        for (index, point) in points.enumerated() {
            let diameter = rect.width * point.2
            let leafColor: NSColor
            if autumn {
                leafColor = index.isMultiple(of: 2)
                    ? color
                    : NSColor(calibratedRed: 0.88, green: 0.46, blue: 0.09, alpha: 0.55)
            } else {
                leafColor = color
            }
            leafColor.setFill()
            NSBezierPath(ovalIn: NSRect(
                x: rect.width * point.0 - diameter / 2,
                y: rect.height * point.1 - diameter / 2,
                width: diameter,
                height: diameter
            )).fill()
        }
    }

    private func drawReadabilityOverlay(in rect: NSRect) {
        NSGradient(colors: [
            NSColor(calibratedWhite: 0, alpha: 0.58),
            NSColor(calibratedWhite: 0, alpha: 0.1),
            NSColor(calibratedWhite: 0, alpha: 0.36)
        ])?.draw(in: rect, angle: 0)
        NSColor(calibratedWhite: 0, alpha: isExpanded ? 0.13 : 0.06).setFill()
        NSBezierPath(rect: rect).fill()
    }

    private func drawSummary() {
        let top = bounds.maxY
        let leftInset: CGFloat = 15
        let contentRight: CGFloat = 185
        let title = snapshot?.windowTitle ?? "7 天额度"
        let titleFont = NSFont.systemFont(ofSize: 13, weight: .medium)
        let titleColor = NSColor.white.withAlphaComponent(0.96)
        drawText(title, at: NSPoint(x: leftInset, y: top - 31), font: titleFont, color: titleColor)

        let titleWidth = (title as NSString).size(withAttributes: [.font: titleFont]).width
        let markX = leftInset + titleWidth + 4
        drawCodexIcon(at: NSPoint(x: markX, y: top - 29.5), size: 15)

        let percent = snapshot.map { "\($0.roundedRemaining)%" } ?? "--%"
        let percentFont = NSFont.monospacedDigitSystemFont(ofSize: 23, weight: .bold)

        let resetText = summaryResetText()
        drawText(resetText, at: NSPoint(x: leftInset, y: top - 48), font: .systemFont(ofSize: 10.5, weight: .medium), color: .white.withAlphaComponent(0.62))

        drawText(percent, at: NSPoint(x: contentRight, y: top - 39), font: percentFont, color: .white, alignment: .right)
        drawText("剩余", at: NSPoint(x: contentRight, y: top - 49), font: .systemFont(ofSize: 9.5, weight: .medium), color: .white.withAlphaComponent(0.62), alignment: .right)

        let barRect = NSRect(x: leftInset, y: top - 68, width: contentRight - leftInset, height: 5)
        let track = NSBezierPath(roundedRect: barRect, xRadius: 2.5, yRadius: 2.5)
        NSColor(calibratedWhite: 0, alpha: 0.42).setFill()
        track.fill()

        guard let snapshot else { return }
        let width = max(snapshot.remainingPercent > 0 ? 3 : 0, barRect.width * CGFloat(snapshot.remainingPercent / 100))
        guard width > 0 else { return }
        let fillRect = NSRect(x: barRect.minX, y: barRect.minY, width: width, height: barRect.height)
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: 2.5, yRadius: 2.5)
        NSGraphicsContext.saveGraphicsState()
        fill.addClip()
        let accent = currentTheme.accent
        let leading = accent.blended(withFraction: 0.42, of: .black) ?? accent
        let middle = accent.blended(withFraction: 0.14, of: .black) ?? accent
        let trailing = accent.blended(withFraction: 0.08, of: .white) ?? accent
        NSGradient(colors: [leading, middle, trailing])?.draw(in: fillRect, angle: 0)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawDetails() {
        let top = bounds.maxY
        NSColor.white.withAlphaComponent(0.16).setStroke()
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: 15, y: top - 83))
        divider.line(to: NSPoint(x: 185, y: top - 83))
        divider.lineWidth = 1
        divider.stroke()

        let labelColor = NSColor.white.withAlphaComponent(0.56)
        let valueColor = NSColor.white.withAlphaComponent(0.92)
        let font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .medium)

        let rows: [(String, String, CGFloat)] = [
            ("7 天额度", snapshot.map { "剩余 \($0.roundedRemaining)% · 已用 \($0.roundedUsed)%" } ?? "--", top - 104),
            ("距离重置", exactResetText(), top - 125),
            ("订阅计划", snapshot?.readablePlan ?? "--", top - 146),
            ("数据更新", dataAgeText(), top - 167)
        ]

        for row in rows {
            drawText(row.0, at: NSPoint(x: 15, y: row.2), font: font, color: labelColor)
            drawText(row.1, at: NSPoint(x: 185, y: row.2), font: valueFont, color: valueColor, alignment: .right)
        }
    }

    private func drawCodexIcon(at point: NSPoint, size: CGFloat) {
        guard let codexIcon else {
            drawFallbackMark(at: point, size: size)
            return
        }

        let iconRect = NSRect(x: point.x, y: point.y, width: size, height: size)
        let roundedClip = NSBezierPath(
            roundedRect: iconRect,
            xRadius: size * 0.24,
            yRadius: size * 0.24
        )
        NSGraphicsContext.saveGraphicsState()
        roundedClip.addClip()
        codexIcon.draw(
            in: iconRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawFallbackMark(at point: NSPoint, size: CGFloat) {
        let stroke = NSColor.white.withAlphaComponent(0.92)
        stroke.setStroke()

        let prompt = NSBezierPath()
        prompt.move(to: NSPoint(x: point.x, y: point.y + size * 0.24))
        prompt.line(to: NSPoint(x: point.x + size * 0.28, y: point.y + size * 0.5))
        prompt.line(to: NSPoint(x: point.x, y: point.y + size * 0.76))
        prompt.lineWidth = 1.4
        prompt.lineCapStyle = .round
        prompt.lineJoinStyle = .round
        prompt.stroke()

        let leaf = NSBezierPath()
        leaf.move(to: NSPoint(x: point.x + size * 0.45, y: point.y + size * 0.2))
        leaf.curve(
            to: NSPoint(x: point.x + size * 0.86, y: point.y + size * 0.82),
            controlPoint1: NSPoint(x: point.x + size * 0.82, y: point.y + size * 0.22),
            controlPoint2: NSPoint(x: point.x + size * 0.92, y: point.y + size * 0.56)
        )
        leaf.curve(
            to: NSPoint(x: point.x + size * 0.45, y: point.y + size * 0.2),
            controlPoint1: NSPoint(x: point.x + size * 0.64, y: point.y + size * 0.77),
            controlPoint2: NSPoint(x: point.x + size * 0.45, y: point.y + size * 0.49)
        )
        leaf.lineWidth = 1.2
        leaf.stroke()
    }

    private enum TextAlignment { case left, right }

    private func drawText(_ text: String, at point: NSPoint, font: NSFont, color: NSColor, alignment: TextAlignment = .left) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let origin = alignment == .right ? NSPoint(x: point.x - size.width, y: point.y) : point
        (text as NSString).draw(at: origin, withAttributes: attributes)
    }

    private func summaryResetText() -> String {
        guard let snapshot else { return "等待额度数据" }
        return resetComponents(until: snapshot.resetsAt, suffix: "后重置")
    }

    private func exactResetText() -> String {
        guard let snapshot else { return "--" }
        return resetComponents(until: snapshot.resetsAt, suffix: "")
    }

    private func resetComponents(until date: Date?, suffix: String) -> String {
        guard let date else { return "重置时间未知" }
        let seconds = max(0, Int(date.timeIntervalSinceNow))
        if seconds == 0 { return "即将重置" }
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        if days > 0 { return "\(days) 天 \(hours) 小时\(suffix)" }
        let minutes = max(1, (seconds % 3_600) / 60)
        return "\(hours) 小时 \(minutes) 分钟\(suffix)"
    }

    private func dataAgeText() -> String {
        guard let snapshot else { return "--" }
        let seconds = max(0, Int(Date().timeIntervalSince(snapshot.fetchedAt)))
        let value: String
        switch seconds {
        case 0...4: value = "刚刚"
        case 5..<60: value = "\(seconds) 秒前"
        case 60..<3_600: value = "\(seconds / 60) 分钟前"
        default: value = "\(seconds / 3_600) 小时前"
        }
        return value
    }

    private func updateAccessibility() {
        let title = snapshot?.windowTitle ?? "7 天额度"
        let percent = snapshot.map { "剩余 \($0.roundedRemaining)%" } ?? "等待额度数据"
        let state = snapshot.map { QuotaTheme.select(for: $0.remainingPercent).accessibilityName } ?? "暂无数据"
        let mode = isStashed ? "已收纳，悬停显示完整卡片" : "单击\(isExpanded ? "收起" : "展开")，双击刷新"
        setAccessibilityLabel("\(title)，\(percent)，\(state)。\(mode)。")
        setAccessibilityValue(snapshot?.remainingPercent as NSNumber?)
        setAccessibilityHelp("可拖动卡片；拖到屏幕左侧或右侧可收纳。右键打开菜单。")
    }
}
