import CoreGraphics
import Foundation

enum AbyssalJellyfishKind: CaseIterable, Equatable {
    case cyan
    case amber
    case garnet
    case silver

    static func forTheme(_ theme: QuotaTheme) -> AbyssalJellyfishKind {
        switch theme {
        case .forest: return .cyan
        case .autumn: return .amber
        case .apocalypse: return .garnet
        case .wasteland: return .silver
        }
    }
}

struct AbyssalJellyfish {
    let kind: AbyssalJellyfishKind
    var position: CGPoint
    var velocity: CGVector
    var pulsePhase: CGFloat
    let pulseSpeed: CGFloat
    var driftPhase: CGFloat
    let driftSpeed: CGFloat
    let driftAmplitude: CGFloat
    var rotation: CGFloat
    let angularVelocity: CGFloat
    let size: CGFloat
    let depth: CGFloat
    let tentaclePhase: CGFloat
    var age: TimeInterval
    let lifetime: TimeInterval

    var isVisible: Bool { age >= 0 && age < lifetime }

    var lifeProgress: CGFloat {
        guard lifetime > 0 else { return 1 }
        return min(1, max(0, CGFloat(age / lifetime)))
    }

    var opacity: CGFloat {
        guard isVisible else { return 0 }
        let fadeIn = min(1, age / 0.34)
        let fadeOut = min(1, (lifetime - age) / 0.82)
        let distanceFade = 1 - pow(max(0, lifeProgress - 0.62) / 0.38, 1.28) * 0.58
        return CGFloat(min(fadeIn, fadeOut)) * distanceFade
    }

    var renderedPosition: CGPoint {
        CGPoint(
            x: position.x + sin(driftPhase * 0.74) * driftAmplitude * 0.42,
            y: position.y + cos(driftPhase) * driftAmplitude
        )
    }

    var pulse: CGFloat { (sin(pulsePhase) + 1) * 0.5 }
    var bellCompression: CGFloat { 0.76 + pulse * 0.24 }
    var tentacleExtension: CGFloat { 0.88 + (1 - pulse) * 0.22 }
    var distanceScale: CGFloat { 1 - max(0, lifeProgress - 0.76) / 0.24 * 0.18 }
}

struct AbyssalJellyfishSystem {
    static let ambientJellyfishCount = 5
    static let jellyfishPerPercentagePoint = 3
    static let maximumAnimatedDrop = 4
    static let manualBurstWaveCounts = [1, 4, 8, 5, 2]
    static let manualBurstJellyfishCount = manualBurstWaveCounts.reduce(0, +)

    private(set) var jellyfish: [AbyssalJellyfish] = []
    private var random = SeededAbyssalRandom(seed: 0x4142_5953_5341_4C52)

    var isEmpty: Bool { jellyfish.isEmpty }
    var visibleCount: Int { jellyfish.lazy.filter(\.isVisible).count }

    mutating func emitAmbient(for theme: QuotaTheme, in size: CGSize) {
        appendJellyfish(
            count: Self.ambientJellyfishCount,
            theme: theme,
            size: size,
            baseDelay: 0,
            delayStep: 0.22,
            burst: false
        )
    }

    mutating func emit(forPercentageDrop drop: Int, theme: QuotaTheme, in size: CGSize) {
        let steps = min(max(0, drop), Self.maximumAnimatedDrop)
        guard steps > 0 else { return }
        appendJellyfish(
            count: steps * Self.jellyfishPerPercentagePoint,
            theme: theme,
            size: size,
            baseDelay: 0,
            delayStep: 0.14,
            burst: false
        )
    }

    mutating func emitManualBurst(for theme: QuotaTheme, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        jellyfish.removeAll(keepingCapacity: true)
        let waveDelays: [Double] = [0, 0.18, 0.42, 0.68, 0.94]
        for (wave, count) in Self.manualBurstWaveCounts.enumerated() {
            appendJellyfish(
                count: count,
                theme: theme,
                size: size,
                baseDelay: waveDelays[wave],
                delayStep: 0.05,
                burst: true
            )
        }
    }

    mutating func advance(by deltaTime: TimeInterval) {
        let delta = min(max(deltaTime, 0), 1.0 / 15.0)
        guard delta > 0 else { return }
        let step = CGFloat(delta)

        for index in jellyfish.indices {
            jellyfish[index].age += delta
            guard jellyfish[index].age >= 0 else { continue }
            jellyfish[index].pulsePhase += jellyfish[index].pulseSpeed * step
            jellyfish[index].driftPhase += jellyfish[index].driftSpeed * step
            let current = sin(jellyfish[index].driftPhase * 1.17 + jellyfish[index].depth * .pi)

            switch jellyfish[index].kind {
            case .cyan:
                jellyfish[index].velocity.dx += current * 0.16 * step
                jellyfish[index].velocity.dy += 0.12 * step
            case .amber:
                jellyfish[index].velocity.dx += current * 0.12 * step
                jellyfish[index].velocity.dy += 0.08 * step
            case .garnet:
                jellyfish[index].velocity.dx += current * 0.42 * step
                jellyfish[index].velocity.dy += sin(jellyfish[index].driftPhase * 0.7) * 0.24 * step
            case .silver:
                jellyfish[index].velocity.dx += current * 0.08 * step
                jellyfish[index].velocity.dy += 0.04 * step
            }

            jellyfish[index].position.x += jellyfish[index].velocity.dx * step
            jellyfish[index].position.y += jellyfish[index].velocity.dy * step
            jellyfish[index].rotation += jellyfish[index].angularVelocity * step
        }

        jellyfish.removeAll { item in
            item.age >= item.lifetime
                || item.position.x < -item.size * 5
                || item.position.y > 270 + item.size * 5
        }
    }

    mutating func removeAll() {
        jellyfish.removeAll(keepingCapacity: true)
    }

    private mutating func appendJellyfish(
        count: Int,
        theme: QuotaTheme,
        size: CGSize,
        baseDelay: Double,
        delayStep: Double,
        burst: Bool
    ) {
        guard count > 0, size.width > 0, size.height > 0 else { return }
        let kind = AbyssalJellyfishKind.forTheme(theme)

        for index in 0..<count {
            let delay = baseDelay + Double(index) * delayStep + random.double(in: 0...0.16)
            let depth = random.cgFloat(in: 0.12...0.98)
            let configuration = initialConfiguration(kind: kind, size: size, burst: burst)
            jellyfish.append(AbyssalJellyfish(
                kind: kind,
                position: configuration.position,
                velocity: configuration.velocity,
                pulsePhase: random.cgFloat(in: 0...(2 * .pi)),
                pulseSpeed: random.cgFloat(in: configuration.pulseSpeedRange),
                driftPhase: random.cgFloat(in: 0...(2 * .pi)),
                driftSpeed: random.cgFloat(in: 0.7...1.45),
                driftAmplitude: random.cgFloat(in: 1.6...(burst ? 5.8 : 4.2)) * (0.7 + depth * 0.38),
                rotation: random.cgFloat(in: -9...9),
                angularVelocity: random.cgFloat(in: configuration.angularVelocityRange),
                size: random.cgFloat(in: configuration.sizeRange) * (0.68 + depth * 0.46),
                depth: depth,
                tentaclePhase: random.cgFloat(in: 0...(2 * .pi)),
                age: -delay,
                lifetime: random.double(in: configuration.lifetimeRange)
            ))
        }
    }

    private mutating func initialConfiguration(
        kind: AbyssalJellyfishKind,
        size: CGSize,
        burst: Bool
    ) -> (
        position: CGPoint,
        velocity: CGVector,
        sizeRange: ClosedRange<CGFloat>,
        lifetimeRange: ClosedRange<Double>,
        pulseSpeedRange: ClosedRange<CGFloat>,
        angularVelocityRange: ClosedRange<CGFloat>
    ) {
        let intensity: CGFloat = burst ? 1.12 : 1
        switch kind {
        case .cyan:
            return (
                CGPoint(x: random.cgFloat(in: size.width * 0.58...size.width * 1.12), y: random.cgFloat(in: -16...size.height * 0.32)),
                CGVector(dx: -random.cgFloat(in: 5.2...10.5) * intensity, dy: random.cgFloat(in: 6.2...10.8) * intensity),
                4.8...9.2,
                burst ? 2.6...3.4 : 4.8...6.4,
                2.2...3.4,
                -2.4...2.4
            )
        case .amber:
            return (
                CGPoint(x: random.cgFloat(in: size.width * 0.62...size.width * 1.1), y: random.cgFloat(in: -18...size.height * 0.28)),
                CGVector(dx: -random.cgFloat(in: 4.4...8.6) * intensity, dy: random.cgFloat(in: 5.2...9.2) * intensity),
                4.6...8.6,
                burst ? 2.8...3.6 : 5.1...6.8,
                1.9...2.9,
                -1.8...1.8
            )
        case .garnet:
            return (
                CGPoint(x: random.cgFloat(in: size.width * 0.56...size.width * 1.14), y: random.cgFloat(in: -18...size.height * 0.38)),
                CGVector(dx: -random.cgFloat(in: 6.8...12.8) * intensity, dy: random.cgFloat(in: 5.8...11.6) * intensity),
                4.8...9.4,
                burst ? 2.4...3.2 : 4.3...5.9,
                2.4...3.8,
                -4.2...4.2
            )
        case .silver:
            return (
                CGPoint(x: random.cgFloat(in: size.width * 0.64...size.width * 1.08), y: random.cgFloat(in: -20...size.height * 0.24)),
                CGVector(dx: -random.cgFloat(in: 3.6...7.2) * intensity, dy: random.cgFloat(in: 4.4...8.2) * intensity),
                4.4...8.2,
                burst ? 3.0...3.8 : 5.8...7.4,
                1.6...2.5,
                -1.2...1.2
            )
        }
    }
}

private struct SeededAbyssalRandom {
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
