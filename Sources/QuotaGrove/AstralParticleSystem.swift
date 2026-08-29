import CoreGraphics
import Foundation

enum AstralMoteKind: CaseIterable, Equatable {
    case spore
    case stardust
    case ember
    case frost

    static func forTheme(_ theme: QuotaTheme) -> AstralMoteKind {
        switch theme {
        case .forest: return .spore
        case .autumn: return .stardust
        case .apocalypse: return .ember
        case .wasteland: return .frost
        }
    }
}

struct AstralMote {
    let kind: AstralMoteKind
    var position: CGPoint
    var velocity: CGVector
    var swayPhase: CGFloat
    let swaySpeed: CGFloat
    let swayAmplitude: CGFloat
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
        let fadeOut = min(1, (lifetime - age) / 0.58)
        return CGFloat(min(fadeIn, fadeOut))
    }

    var renderedPosition: CGPoint {
        CGPoint(
            x: position.x + sin(swayPhase) * swayAmplitude,
            y: position.y + cos(swayPhase * 0.73) * swayAmplitude * 0.34
        )
    }
}

struct AstralParticleSystem {
    static let ambientMoteCount = 14
    static let motesPerPercentagePoint = 7
    static let maximumAnimatedDrop = 4
    static let manualBurstWaveCounts = [4, 9, 16, 9, 4]
    static let manualBurstMoteCount = manualBurstWaveCounts.reduce(0, +)

    private(set) var motes: [AstralMote] = []
    private var random = SeededAstralRandom(seed: 0x4153_5452_414C_4752)

    var isEmpty: Bool { motes.isEmpty }
    var visibleCount: Int { motes.lazy.filter(\.isVisible).count }

    mutating func emitAmbient(for theme: QuotaTheme, in size: CGSize) {
        appendMotes(
            count: Self.ambientMoteCount,
            theme: theme,
            size: size,
            baseDelay: 0,
            delayStep: 0.055,
            burst: false
        )
    }

    mutating func emit(forPercentageDrop drop: Int, theme: QuotaTheme, in size: CGSize) {
        let steps = min(max(0, drop), Self.maximumAnimatedDrop)
        guard steps > 0 else { return }
        appendMotes(
            count: steps * Self.motesPerPercentagePoint,
            theme: theme,
            size: size,
            baseDelay: 0,
            delayStep: 0.045,
            burst: false
        )
    }

    mutating func emitManualBurst(for theme: QuotaTheme, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        motes.removeAll(keepingCapacity: true)
        let waveDelays: [Double] = [0, 0.16, 0.36, 0.62, 0.9]
        for (wave, count) in Self.manualBurstWaveCounts.enumerated() {
            appendMotes(
                count: count,
                theme: theme,
                size: size,
                baseDelay: waveDelays[wave],
                delayStep: 0.012,
                burst: true
            )
        }
    }

    mutating func advance(by deltaTime: TimeInterval) {
        let delta = min(max(deltaTime, 0), 1.0 / 15.0)
        guard delta > 0 else { return }
        let step = CGFloat(delta)

        for index in motes.indices {
            motes[index].age += delta
            guard motes[index].age >= 0 else { continue }
            motes[index].swayPhase += motes[index].swaySpeed * step
            let turbulence = sin(motes[index].swayPhase * 1.37 + motes[index].depth * .pi) * step

            switch motes[index].kind {
            case .spore:
                motes[index].velocity.dy += (1.8 + motes[index].depth * 1.6) * step
                motes[index].velocity.dx += turbulence * 2.2
            case .stardust:
                motes[index].velocity.dy -= (0.8 + motes[index].depth) * step
                motes[index].velocity.dx += turbulence * 3.0
            case .ember:
                motes[index].velocity.dy += (5.2 + motes[index].depth * 4.8) * step
                motes[index].velocity.dx += turbulence * 5.6
            case .frost:
                motes[index].velocity.dy -= (1.2 + motes[index].depth * 1.8) * step
                motes[index].velocity.dx += turbulence * 1.8
            }

            motes[index].position.x += motes[index].velocity.dx * step
            motes[index].position.y += motes[index].velocity.dy * step
            motes[index].rotation += motes[index].angularVelocity * step
        }

        motes.removeAll { mote in
            mote.age >= mote.lifetime
                || mote.position.x < -mote.size * 4
                || mote.position.y < -mote.size * 4
                || mote.position.y > 260 + mote.size * 4
        }
    }

    mutating func removeAll() {
        motes.removeAll(keepingCapacity: true)
    }

    private mutating func appendMotes(
        count: Int,
        theme: QuotaTheme,
        size: CGSize,
        baseDelay: Double,
        delayStep: Double,
        burst: Bool
    ) {
        guard count > 0, size.width > 0, size.height > 0 else { return }
        let kind = AstralMoteKind.forTheme(theme)

        for index in 0..<count {
            let delay = baseDelay + Double(index) * delayStep + random.double(in: 0...0.11)
            let depth = random.cgFloat(in: 0.14...0.98)
            let configuration = initialConfiguration(kind: kind, size: size, depth: depth, burst: burst)
            motes.append(AstralMote(
                kind: kind,
                position: configuration.position,
                velocity: configuration.velocity,
                swayPhase: random.cgFloat(in: 0...(2 * .pi)),
                swaySpeed: random.cgFloat(in: 1.2...3.1),
                swayAmplitude: random.cgFloat(in: 1.2...(burst ? 6.4 : 4.2)) * (0.68 + depth * 0.42),
                rotation: random.cgFloat(in: -90...90),
                angularVelocity: random.cgFloat(in: -54...54),
                size: random.cgFloat(in: configuration.sizeRange) * (0.72 + depth * 0.5),
                depth: depth,
                age: -delay,
                lifetime: random.double(in: configuration.lifetimeRange)
            ))
        }
    }

    private mutating func initialConfiguration(
        kind: AstralMoteKind,
        size: CGSize,
        depth: CGFloat,
        burst: Bool
    ) -> (
        position: CGPoint,
        velocity: CGVector,
        sizeRange: ClosedRange<CGFloat>,
        lifetimeRange: ClosedRange<Double>
    ) {
        let intensity: CGFloat = burst ? 1.24 : 1
        switch kind {
        case .spore:
            return (
                CGPoint(
                    x: random.cgFloat(in: size.width * 0.48...size.width * 1.08),
                    y: random.cgFloat(in: -2...size.height * 0.48)
                ),
                CGVector(
                    dx: -random.cgFloat(in: 4...13) * intensity,
                    dy: random.cgFloat(in: 9...18) * intensity
                ),
                1.4...3.6,
                burst ? 2.8...3.8 : 2.3...3.2
            )
        case .stardust:
            return (
                CGPoint(
                    x: random.cgFloat(in: size.width * 0.62...size.width * 1.12),
                    y: random.cgFloat(in: size.height * 0.34...size.height * 1.08)
                ),
                CGVector(
                    dx: -random.cgFloat(in: 12...25) * intensity,
                    dy: -random.cgFloat(in: 2...9) * intensity
                ),
                1.6...4.2,
                burst ? 2.6...3.6 : 2.2...3.1
            )
        case .ember:
            return (
                CGPoint(
                    x: random.cgFloat(in: size.width * 0.5...size.width * 1.08),
                    y: random.cgFloat(in: -4...size.height * 0.3)
                ),
                CGVector(
                    dx: -random.cgFloat(in: 5...17) * intensity,
                    dy: random.cgFloat(in: 17...34) * intensity
                ),
                1.5...4.0,
                burst ? 2.2...3.2 : 1.8...2.7
            )
        case .frost:
            return (
                CGPoint(
                    x: random.cgFloat(in: size.width * 0.48...size.width * 1.08),
                    y: random.cgFloat(in: size.height * 0.72...size.height * 1.14)
                ),
                CGVector(
                    dx: -random.cgFloat(in: 4...13) * intensity,
                    dy: -random.cgFloat(in: 8...18) * intensity
                ),
                1.8...4.8,
                burst ? 3.0...4.2 : 2.6...3.7
            )
        }
    }
}

private struct SeededAstralRandom {
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
