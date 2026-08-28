import AppKit

final class SnowEffectView: NSView {
    private var particles = SnowParticleSystem()
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
        NSColor(calibratedRed: 0.12, green: 0.18, blue: 0.22, alpha: 0.045).setFill()
        bounds.fill()

        for flake in particles.flakes.sorted(by: { $0.depth < $1.depth }) {
            draw(flake: flake)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func draw(flake: SnowFlake) {
        let fade = flake.bottomFade(in: bounds.height)
        guard fade > 0 else { return }

        let center = NSPoint(x: flake.renderedX, y: flake.position.y)
        let opacity = flake.opacity * fade
        let radius = flake.size / 2

        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y)
        transform.rotate(byDegrees: flake.rotation)
        transform.concat()

        drawDendriticCrystal(
            radius: max(1.05, radius),
            opacity: opacity,
            depth: flake.depth,
            fineDetail: flake.showsCrystalDetail
        )

        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawDendriticCrystal(
        radius: CGFloat,
        opacity: CGFloat,
        depth: CGFloat,
        fineDetail: Bool
    ) {
        let mainArms = NSBezierPath()
        let branches = NSBezierPath()
        let branchPositions: [CGFloat]
        if depth < 0.36 {
            branchPositions = [0.5, 0.76]
        } else if depth < 0.76 {
            branchPositions = fineDetail ? [0.3, 0.46, 0.62, 0.78] : [0.36, 0.56, 0.76]
        } else {
            branchPositions = [0.24, 0.39, 0.54, 0.69, 0.84]
        }

        for armIndex in 0..<6 {
            let angle = CGFloat(armIndex) * .pi / 3
            let unitX = cos(angle)
            let unitY = sin(angle)
            mainArms.move(to: .zero)
            mainArms.line(to: NSPoint(x: unitX * radius, y: unitY * radius))

            for progress in branchPositions {
                let base = NSPoint(
                    x: unitX * radius * progress,
                    y: unitY * radius * progress
                )
                let branchLength = radius * (0.21 + progress * 0.13)
                for side: CGFloat in [-1, 1] {
                    let branchAngle = angle + side * 0.76
                    let branchX = cos(branchAngle)
                    let branchY = sin(branchAngle)
                    let tip = NSPoint(
                        x: base.x + branchX * branchLength,
                        y: base.y + branchY * branchLength
                    )
                    branches.move(to: base)
                    branches.line(to: tip)

                    if fineDetail, depth > 0.7, progress > 0.42 {
                        let microBase = NSPoint(
                            x: base.x + branchX * branchLength * 0.58,
                            y: base.y + branchY * branchLength * 0.58
                        )
                        let microAngle = branchAngle + side * 0.46
                        let microLength = radius * 0.12
                        branches.move(to: microBase)
                        branches.line(to: NSPoint(
                            x: microBase.x + cos(microAngle) * microLength,
                            y: microBase.y + sin(microAngle) * microLength
                        ))
                    }
                }
            }
        }

        let mainWidth = 0.18 + depth * 0.32
        mainArms.lineCapStyle = .round
        branches.lineCapStyle = .round
        branches.lineJoinStyle = .round

        NSColor(calibratedRed: 0.58, green: 0.82, blue: 0.96, alpha: 0.11 * opacity).setStroke()
        mainArms.lineWidth = mainWidth * 2.5
        branches.lineWidth = mainWidth * 2.05
        mainArms.stroke()
        branches.stroke()

        NSColor(calibratedRed: 0.9, green: 0.97, blue: 1, alpha: (0.64 + depth * 0.24) * opacity).setStroke()
        mainArms.lineWidth = mainWidth
        branches.lineWidth = mainWidth * 0.78
        mainArms.stroke()
        branches.stroke()

        if depth > 0.42 {
            let innerRing = hexagon(radius: max(0.48, radius * 0.17))
            innerRing.lineWidth = mainWidth * 0.72
            NSColor.white.withAlphaComponent(0.56 * opacity).setStroke()
            innerRing.stroke()
        }

        let center = hexagon(radius: max(0.26, radius * 0.085))
        NSColor(calibratedRed: 0.92, green: 0.98, blue: 1, alpha: 0.72 * opacity).setFill()
        center.fill()
    }

    private func hexagon(radius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        for index in 0..<6 {
            let angle = CGFloat(index) * .pi / 3 + .pi / 6
            let point = NSPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            index == 0 ? path.move(to: point) : path.line(to: point)
        }
        path.close()
        return path
    }
}
