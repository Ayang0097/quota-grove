import CoreGraphics
import Foundation

enum MoonButterflyKind: CaseIterable, Equatable {
    case pearl
    case roseGold
    case garnet
    case silver

    static func forTheme(_ theme: QuotaTheme) -> MoonButterflyKind {
        switch theme {
        case .forest: return .pearl
        case .autumn: return .roseGold
        case .apocalypse: return .garnet
        case .wasteland: return .silver
        }
    }
}

struct MoonButterfly {
    let kind: MoonButterflyKind
    var position: CGPoint
    var velocity: CGVector
    var wingPhase: CGFloat
    let wingSpeed: CGFloat
    var curvePhase: CGFloat
    let curveSpeed: CGFloat
    let curveAmplitude: CGFloat
    var rotation: CGFloat
    let angularVelocity: CGFloat
    let size: CGFloat
    let depth: CGFloat
    var age: TimeInterval
    let lifetime: TimeInterval

    var isVisible: Bool { age >= 0 && age < lifetime }

    var opacity: CGFloat {
        guard isVisible else { return 0 }
        let fadeIn = min(1, age / 0.22)
        let fadeOut = min(1, (lifetime - age) / 0.76)
        return CGFloat(min(fadeIn, fadeOut))
    }

    var renderedPosition: CGPoint {
        CGPoint(
            x: position.x + sin(curvePhase * 0.72) * curveAmplitude * 0.34,
            y: position.y + cos(curvePhase) * curveAmplitude
        )
    }

    var wingSpread: CGFloat { 0.24 + abs(cos(wingPhase)) * 0.76 }
}

struct MoonButterflySystem {
    static let ambientButterflyCount = 8
    static let butterfliesPerPercentagePoint = 5
    static let maximumAnimatedDrop = 4
    static let manualBurstWaveCounts = [2, 6, 12, 7, 3]
    static let manualBurstButterflyCount = manualBurstWaveCounts.reduce(0, +)

    private(set) var butterflies: [MoonButterfly] = []
    private var random = SeededMoonRandom(seed: 0x4D4F_4F4E_4255_5454)

    var isEmpty: Bool { butterflies.isEmpty }
    var visibleCount: Int { butterflies.lazy.filter(\.isVisible).count }

    mutating func emitAmbient(for theme: QuotaTheme, in size: CGSize) {
        appendButterflies(
            count: Self.ambientButterflyCount,
            theme: theme,
            size: size,
            baseDelay: 0,
            delayStep: 0.1,
            burst: false
        )
    }

    mutating func emit(forPercentageDrop drop: Int, theme: QuotaTheme, in size: CGSize) {
        let steps = min(max(0, drop), Self.maximumAnimatedDrop)
        guard steps > 0 else { return }
        appendButterflies(
            count: steps * Self.butterfliesPerPercentagePoint,
            theme: theme,
            size: size,
            baseDelay: 0,
            delayStep: 0.07,
            burst: false
        )
    }

    mutating func emitManualBurst(for theme: QuotaTheme, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        butterflies.removeAll(keepingCapacity: true)
        let waveDelays: [Double] = [0, 0.22, 0.52, 0.9, 1.3]
        for (wave, count) in Self.manualBurstWaveCounts.enumerated() {
            appendButterflies(
                count: count,
                theme: theme,
                size: size,
                baseDelay: waveDelays[wave],
                delayStep: 0.025,
                burst: true
            )
        }
    }

    mutating func advance(by deltaTime: TimeInterval) {
        let delta = min(max(deltaTime, 0), 1.0 / 15.0)
        guard delta > 0 else { return }
        let step = CGFloat(delta)

        for index in butterflies.indices {
            butterflies[index].age += delta
            guard butterflies[index].age >= 0 else { continue }
            butterflies[index].wingPhase += butterflies[index].wingSpeed * step
            butterflies[index].curvePhase += butterflies[index].curveSpeed * step
            let curl = sin(butterflies[index].curvePhase * 1.41 + butterflies[index].depth * .pi) * step

            switch butterflies[index].kind {
            case .pearl:
                butterflies[index].velocity.dy += 1.3 * step
                butterflies[index].velocity.dx += curl * 1.8
            case .roseGold:
                butterflies[index].velocity.dy -= 0.45 * step
                butterflies[index].velocity.dx += curl * 2.4
            case .garnet:
                butterflies[index].velocity.dy += curl * 5.8
                butterflies[index].velocity.dx += curl * 4.6
            case .silver:
                butterflies[index].velocity.dy -= 0.75 * step
                butterflies[index].velocity.dx += curl * 1.1
            }

            butterflies[index].position.x += butterflies[index].velocity.dx * step
            butterflies[index].position.y += butterflies[index].velocity.dy * step
            butterflies[index].rotation += butterflies[index].angularVelocity * step
        }

        butterflies.removeAll { butterfly in
            butterfly.age >= butterfly.lifetime
                || butterfly.position.x < -butterfly.size * 5
                || butterfly.position.y < -butterfly.size * 5
                || butterfly.position.y > 260 + butterfly.size * 5
        }
    }

    mutating func removeAll() {
        butterflies.removeAll(keepingCapacity: true)
    }

    private mutating func appendButterflies(
        count: Int,
        theme: QuotaTheme,
        size: CGSize,
        baseDelay: Double,
        delayStep: Double,
        burst: Bool
    ) {
        guard count > 0, size.width > 0, size.height > 0 else { return }
        let kind = MoonButterflyKind.forTheme(theme)

        for index in 0..<count {
            let delay = baseDelay + Double(index) * delayStep + random.double(in: 0...0.11)
            let depth = random.cgFloat(in: 0.16...0.98)
            let configuration = initialConfiguration(kind: kind, size: size, burst: burst)
            butterflies.append(MoonButterfly(
                kind: kind,
                position: configuration.position,
                velocity: configuration.velocity,
                wingPhase: random.cgFloat(in: 0...(2 * .pi)),
                wingSpeed: random.cgFloat(in: 7.2...12.4),
                curvePhase: random.cgFloat(in: 0...(2 * .pi)),
                curveSpeed: random.cgFloat(in: 1.2...2.8),
                curveAmplitude: random.cgFloat(in: 1.4...(burst ? 6.8 : 4.2)) * (0.72 + depth * 0.34),
                rotation: random.cgFloat(in: -18...18),
                angularVelocity: random.cgFloat(in: configuration.angularVelocityRange),
                size: random.cgFloat(in: configuration.sizeRange) * (0.72 + depth * 0.46),
                depth: depth,
                age: -delay,
                lifetime: random.double(in: configuration.lifetimeRange)
            ))
        }
    }

    private mutating func initialConfiguration(
        kind: MoonButterflyKind,
        size: CGSize,
        burst: Bool
    ) -> (
        position: CGPoint,
        velocity: CGVector,
        sizeRange: ClosedRange<CGFloat>,
        lifetimeRange: ClosedRange<Double>,
        angularVelocityRange: ClosedRange<CGFloat>
    ) {
        let intensity: CGFloat = burst ? 1.16 : 1
        switch kind {
        case .pearl:
            return (
                CGPoint(
                    x: random.cgFloat(in: size.width * 0.54...size.width * 1.12),
                    y: random.cgFloat(in: -2...size.height * 0.62)
                ),
                CGVector(
                    dx: -random.cgFloat(in: 11...23) * intensity,
                    dy: random.cgFloat(in: 3...10) * intensity
                ),
                3.8...7.2,
                burst ? 4.0...5.6 : 3.5...4.9,
                -7...7
            )
        case .roseGold:
            return (
                CGPoint(
                    x: random.cgFloat(in: size.width * 0.58...size.width * 1.14),
                    y: random.cgFloat(in: size.height * 0.28...size.height * 1.08)
                ),
                CGVector(
                    dx: -random.cgFloat(in: 14...27) * intensity,
                    dy: -random.cgFloat(in: 1...7) * intensity
                ),
                3.6...6.8,
                burst ? 3.7...5.2 : 3.2...4.6,
                -10...10
            )
        case .garnet:
            return (
                CGPoint(
                    x: random.cgFloat(in: size.width * 0.56...size.width * 1.12),
                    y: random.cgFloat(in: size.height * 0.1...size.height * 0.95)
                ),
                CGVector(
                    dx: -random.cgFloat(in: 18...34) * intensity,
                    dy: random.cgFloat(in: -8...9) * intensity
                ),
                3.8...7.4,
                burst ? 3.1...4.5 : 2.7...4.0,
                -18...18
            )
        case .silver:
            return (
                CGPoint(
                    x: random.cgFloat(in: size.width * 0.54...size.width * 1.1),
                    y: random.cgFloat(in: size.height * 0.42...size.height * 1.12)
                ),
                CGVector(
                    dx: -random.cgFloat(in: 8...18) * intensity,
                    dy: -random.cgFloat(in: 1...5) * intensity
                ),
                3.4...6.4,
                burst ? 4.6...6.2 : 4.0...5.5,
                -5...5
            )
        }
    }
}

private struct SeededMoonRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func double(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * unit()
    }

    mutating func cgFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        range.lowerBound + (range.upperBound - range.lowerBound) * CGFloat(unit())
    }
}
