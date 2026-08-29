import CoreGraphics
import Foundation

enum BeaconBirdKind: CaseIterable, Equatable {
    case azure
    case golden
    case storm
    case frost

    static func forTheme(_ theme: QuotaTheme) -> BeaconBirdKind {
        switch theme {
        case .forest: return .azure
        case .autumn: return .golden
        case .apocalypse: return .storm
        case .wasteland: return .frost
        }
    }
}

struct BeaconBird {
    let kind: BeaconBirdKind
    var position: CGPoint
    var velocity: CGVector
    var flapPhase: CGFloat
    let flapSpeed: CGFloat
    let glideAmplitude: CGFloat
    var bank: CGFloat
    let bankVelocity: CGFloat
    let size: CGFloat
    let depth: CGFloat
    var age: TimeInterval
    let lifetime: TimeInterval

    var isVisible: Bool { age >= 0 && age < lifetime }

    var opacity: CGFloat {
        guard isVisible else { return 0 }
        let fadeIn = min(1, age / 0.18)
        let fadeOut = min(1, (lifetime - age) / 0.72)
        return CGFloat(min(fadeIn, fadeOut))
    }

    var renderedPosition: CGPoint {
        CGPoint(
            x: position.x,
            y: position.y + sin(flapPhase * 0.24 + depth * .pi) * glideAmplitude
        )
    }

    var wingLift: CGFloat { sin(flapPhase) }
}

struct BeaconParticleSystem {
    static let ambientMoteCount = 7
    static let motesPerPercentagePoint = 4
    static let maximumAnimatedDrop = 4
    static let manualBurstWaveCounts = [2, 6, 11, 6, 2]
    static let manualBurstMoteCount = manualBurstWaveCounts.reduce(0, +)

    private(set) var birds: [BeaconBird] = []
    private var random = SeededBeaconRandom(seed: 0x4249_5244_464C_4F43)

    var isEmpty: Bool { birds.isEmpty }
    var visibleCount: Int { birds.lazy.filter(\.isVisible).count }

    mutating func emitAmbient(for theme: QuotaTheme, in size: CGSize) {
        appendBirds(
            count: Self.ambientMoteCount,
            theme: theme,
            size: size,
            baseDelay: 0,
            delayStep: 0.12,
            burst: false
        )
    }

    mutating func emit(forPercentageDrop drop: Int, theme: QuotaTheme, in size: CGSize) {
        let steps = min(max(0, drop), Self.maximumAnimatedDrop)
        guard steps > 0 else { return }
        appendBirds(
            count: steps * Self.motesPerPercentagePoint,
            theme: theme,
            size: size,
            baseDelay: 0,
            delayStep: 0.085,
            burst: false
        )
    }

    mutating func emitManualBurst(for theme: QuotaTheme, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        birds.removeAll(keepingCapacity: true)
        let waveDelays: [Double] = [0, 0.26, 0.58, 0.98, 1.4]
        for (wave, count) in Self.manualBurstWaveCounts.enumerated() {
            appendBirds(
                count: count,
                theme: theme,
                size: size,
                baseDelay: waveDelays[wave],
                delayStep: 0.035,
                burst: true
            )
        }
    }

    mutating func advance(by deltaTime: TimeInterval) {
        let delta = min(max(deltaTime, 0), 1.0 / 15.0)
        guard delta > 0 else { return }
        let step = CGFloat(delta)

        for index in birds.indices {
            birds[index].age += delta
            guard birds[index].age >= 0 else { continue }
            birds[index].flapPhase += birds[index].flapSpeed * step

            let turbulence = sin(
                birds[index].flapPhase * 0.31 + birds[index].depth * .pi
            ) * step
            switch birds[index].kind {
            case .azure:
                birds[index].velocity.dy += turbulence * 1.5
            case .golden:
                birds[index].velocity.dy -= 0.3 * step
                birds[index].velocity.dx += turbulence * 1.8
            case .storm:
                birds[index].velocity.dy += turbulence * 7.4
                birds[index].velocity.dx += turbulence * 4.2
            case .frost:
                birds[index].velocity.dy += turbulence * 0.8
                birds[index].velocity.dx += turbulence * 0.9
            }

            birds[index].position.x += birds[index].velocity.dx * step
            birds[index].position.y += birds[index].velocity.dy * step
            birds[index].bank += birds[index].bankVelocity * step
        }

        birds.removeAll { bird in
            bird.age >= bird.lifetime
                || bird.position.x < -bird.size * 4
                || bird.position.y < -bird.size * 4
                || bird.position.y > 260 + bird.size * 4
        }
    }

    mutating func removeAll() {
        birds.removeAll(keepingCapacity: true)
    }

    private mutating func appendBirds(
        count: Int,
        theme: QuotaTheme,
        size: CGSize,
        baseDelay: Double,
        delayStep: Double,
        burst: Bool
    ) {
        guard count > 0, size.width > 0, size.height > 0 else { return }
        let kind = BeaconBirdKind.forTheme(theme)
        let flockCenter = random.cgFloat(in: size.height * 0.38...size.height * 0.78)

        for index in 0..<count {
            let delay = baseDelay + Double(index) * delayStep + random.double(in: 0...0.1)
            let depth = random.cgFloat(in: 0.18...0.98)
            let configuration = initialConfiguration(
                kind: kind,
                size: size,
                flockCenter: flockCenter,
                birdIndex: index,
                burst: burst
            )
            birds.append(BeaconBird(
                kind: kind,
                position: configuration.position,
                velocity: configuration.velocity,
                flapPhase: random.cgFloat(in: 0...(2 * .pi)),
                flapSpeed: random.cgFloat(in: 5.4...9.2),
                glideAmplitude: random.cgFloat(in: 0.5...(burst ? 2.8 : 1.8)) * (0.7 + depth * 0.35),
                bank: random.cgFloat(in: -8...8),
                bankVelocity: random.cgFloat(in: configuration.bankVelocityRange),
                size: random.cgFloat(in: configuration.sizeRange) * (0.7 + depth * 0.48),
                depth: depth,
                age: -delay,
                lifetime: random.double(in: configuration.lifetimeRange)
            ))
        }
    }

    private mutating func initialConfiguration(
        kind: BeaconBirdKind,
        size: CGSize,
        flockCenter: CGFloat,
        birdIndex: Int,
        burst: Bool
    ) -> (
        position: CGPoint,
        velocity: CGVector,
        sizeRange: ClosedRange<CGFloat>,
        lifetimeRange: ClosedRange<Double>,
        bankVelocityRange: ClosedRange<CGFloat>
    ) {
        let intensity: CGFloat = burst ? 1.16 : 1
        let formationColumn = CGFloat((birdIndex % 5) - 2)
        let formationY = flockCenter + formationColumn * random.cgFloat(in: 3.8...7.4)
        let formationX = size.width * random.cgFloat(in: 0.82...1.16) + abs(formationColumn) * 4.5

        switch kind {
        case .azure:
            return (
                CGPoint(x: formationX, y: formationY),
                CGVector(
                    dx: -random.cgFloat(in: 18...29) * intensity,
                    dy: random.cgFloat(in: -1.5...3.8)
                ),
                3.6...6.8,
                burst ? 4.4...6.2 : 3.9...5.4,
                -3...3
            )
        case .golden:
            return (
                CGPoint(x: formationX, y: formationY + random.cgFloat(in: 0...9)),
                CGVector(
                    dx: -random.cgFloat(in: 20...33) * intensity,
                    dy: -random.cgFloat(in: 0.5...4.2)
                ),
                3.5...6.5,
                burst ? 4.0...5.8 : 3.6...5.0,
                -5...5
            )
        case .storm:
            return (
                CGPoint(x: formationX, y: formationY + random.cgFloat(in: -8...12)),
                CGVector(
                    dx: -random.cgFloat(in: 24...40) * intensity,
                    dy: random.cgFloat(in: -7...7)
                ),
                3.8...7.2,
                burst ? 3.3...4.8 : 2.9...4.2,
                -12...12
            )
        case .frost:
            return (
                CGPoint(x: formationX, y: formationY + random.cgFloat(in: 2...12)),
                CGVector(
                    dx: -random.cgFloat(in: 14...23) * intensity,
                    dy: -random.cgFloat(in: 0.5...3.2)
                ),
                3.4...6.2,
                burst ? 5.0...6.8 : 4.4...6.0,
                -2.5...2.5
            )
        }
    }
}

private struct SeededBeaconRandom {
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
