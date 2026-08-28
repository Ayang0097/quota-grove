import AppKit

final class RainEffectView: NSView {
    private var particles = RainParticleSystem()
    private var animationTimer: Timer?
    private var previousTick: TimeInterval = 0
    private var previewIsActive = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setAccessibilityElement(false)
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        animationTimer?.invalidate()
    }

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func setAnimating(_ active: Bool) {
        guard active else {
            animationTimer?.invalidate()
            animationTimer = nil
            particles.removeAll()
            isHidden = true
            needsDisplay = true
            return
        }

        isHidden = false
        if particles.isEmpty { particles.start(in: bounds.size) }
        guard animationTimer == nil else { return }

        previousTick = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = ProcessInfo.processInfo.systemUptime
            self.particles.advance(by: now - self.previousTick, in: self.bounds.size)
            self.previousTick = now
            self.needsDisplay = true
        }
        animationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func setPreviewActive(_ active: Bool) {
        previewIsActive = active
        isHidden = !active
        if active {
            particles.start(in: bounds.size)
        } else {
            particles.removeAll()
        }
        needsDisplay = true
    }

    func advancePreview(by deltaTime: TimeInterval) {
        guard previewIsActive else { return }
        particles.advance(by: deltaTime, in: bounds.size)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawForPreview()
    }

    func drawForPreview() {
        guard !particles.isEmpty else { return }

        let clip = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            xRadius: 18,
            yRadius: 18
        )
        NSGraphicsContext.saveGraphicsState()
        clip.addClip()
        drawRain()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawRain() {
        NSColor(calibratedRed: 0.015, green: 0.065, blue: 0.07, alpha: 0.09).setFill()
        bounds.fill()

        let segmentFractions: [CGFloat] = [0, 0.2, 0.52, 0.78, 1]
        let segmentWidthScales: [CGFloat] = [1, 0.72, 0.42, 0.2]
        let segmentOpacityScales: [CGFloat] = [1, 0.66, 0.34, 0.12]
        let layerWidths: [CGFloat] = [0.15, 0.29, 0.5]
        let layerOpacities: [CGFloat] = [0.22, 0.38, 0.56]
        let layerColors: [NSColor] = [
            NSColor(calibratedRed: 0.75, green: 0.86, blue: 0.88, alpha: 1),
            NSColor(calibratedRed: 0.79, green: 0.9, blue: 0.91, alpha: 1),
            NSColor(calibratedRed: 0.84, green: 0.95, blue: 0.96, alpha: 1)
        ]
        let segmentPaths: [[NSBezierPath]] = (0..<3).map { _ in
            (0..<4).map { _ in NSBezierPath() }
        }
        let haloPaths = (0..<3).map { _ in NSBezierPath() }

        for drop in particles.drops {
            let speed = max(1, hypot(drop.windSpeed, drop.fallSpeed))
            let tail = NSPoint(
                x: drop.position.x - drop.windSpeed / speed * drop.length,
                y: drop.position.y + drop.fallSpeed / speed * drop.length
            )
            let direction = CGVector(dx: tail.x - drop.position.x, dy: tail.y - drop.position.y)
            let layer = drop.depth < 0.36 ? 0 : (drop.depth < 0.76 ? 1 : 2)

            for segmentIndex in 0..<4 {
                let startFraction = segmentFractions[segmentIndex]
                let endFraction = segmentFractions[segmentIndex + 1]
                let start = NSPoint(
                    x: drop.position.x + direction.dx * startFraction,
                    y: drop.position.y + direction.dy * startFraction
                )
                let end = NSPoint(
                    x: drop.position.x + direction.dx * endFraction,
                    y: drop.position.y + direction.dy * endFraction
                )
                segmentPaths[layer][segmentIndex].move(to: start)
                segmentPaths[layer][segmentIndex].line(to: end)
            }

            if layer != 1 {
                haloPaths[layer].move(to: drop.position)
                haloPaths[layer].line(to: tail)
            }
        }

        for layer in 0..<3 {
            if layer != 1 {
                let halo = haloPaths[layer]
                halo.lineWidth = layerWidths[layer] * (layer == 2 ? 2.1 : 1.7)
                halo.lineCapStyle = .round
                layerColors[layer].withAlphaComponent(layer == 2 ? 0.052 : 0.012).setStroke()
                halo.stroke()
            }
            for segmentIndex in 0..<4 {
                let path = segmentPaths[layer][segmentIndex]
                path.lineWidth = max(0.06, layerWidths[layer] * segmentWidthScales[segmentIndex])
                path.lineCapStyle = .round
                layerColors[layer]
                    .withAlphaComponent(layerOpacities[layer] * segmentOpacityScales[segmentIndex])
                    .setStroke()
                path.stroke()
            }
        }

        for splash in particles.splashes {
            let progress = splash.progress
            let opacity = splash.opacity
            let width = splash.size * (0.42 + progress * 0.92)
            let rippleRect = NSRect(
                x: splash.position.x - width / 2,
                y: splash.position.y - 0.7,
                width: width,
                height: max(0.8, width * 0.22)
            )
            let ripple = NSBezierPath(ovalIn: rippleRect)
            ripple.lineWidth = 0.45
            NSColor(calibratedRed: 0.72, green: 0.9, blue: 0.9, alpha: 0.26 * opacity).setStroke()
            ripple.stroke()

            if progress < 0.52 {
                let lift = (1 - progress / 0.52) * splash.size * 0.5
                for direction: CGFloat in [-1, 1] {
                    let bead = NSBezierPath()
                    bead.move(to: NSPoint(x: splash.position.x + direction * 0.5, y: splash.position.y + 0.3))
                    bead.line(to: NSPoint(x: splash.position.x + direction * splash.size * 0.24, y: splash.position.y + lift))
                    bead.lineWidth = 0.55
                    bead.lineCapStyle = .round
                    NSColor(calibratedRed: 0.76, green: 0.92, blue: 0.92, alpha: 0.31 * opacity).setStroke()
                    bead.stroke()
                }
            }
        }
    }
}
