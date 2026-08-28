import CoreGraphics
import Foundation

enum FallingLeafFocus: Int {
    case crisp
    case soft
    case motion
}

struct FallingLeaf {
    var position: CGPoint
    var velocity: CGVector
    var verticalAcceleration: CGFloat
    var verticalDrag: CGFloat
    var windVelocityX: CGFloat
    var windResponse: CGFloat
    var flutterLift: CGFloat
    var midSpreadX: CGFloat
    var midSpreadY: CGFloat
    var swayPhase: CGFloat
    var swaySpeed: CGFloat
    var swayAmplitude: CGFloat
    var rotation: CGFloat
    var angularVelocity: CGFloat
    var size: CGFloat
    /// 0 is far from the viewer and 1 is closest to the viewer.
    var depth: CGFloat
    var focus: FallingLeafFocus
    var motionTrail: CGFloat
    var age: TimeInterval
    var lifetime: TimeInterval
    var colorVariant: Int
    var textureSeed: Int

    var isVisible: Bool { age >= 0 && age < lifetime }

    var opacity: CGFloat {
        guard isVisible else { return 0 }
        let fadeIn = min(1, age / 0.18)
        let fadeOut = min(1, (lifetime - age) / 0.55)
        return CGFloat(min(fadeIn, fadeOut))
    }

    var renderedX: CGFloat {
        position.x + sin(swayPhase) * swayAmplitude
    }

    func departureProgress(in height: CGFloat) -> CGFloat {
        guard height > 0 else { return 0 }
        let startY = height * 0.34
        let endY = height * 0.02
        let linear = min(1, max(0, (startY - position.y) / max(1, startY - endY)))
        return linear * linear * (3 - 2 * linear)
    }
}

struct LeafParticleSystem {
    static let leavesPerPercentagePoint = 8
    static let maximumAnimatedDrop = 4
    static let manualBurstLeafCount = 48
    static let manualBurstWaveCounts = [4, 10, 19, 10, 5]

    private(set) var leaves: [FallingLeaf] = []
    private var random = SeededLeafRandom(seed: 0x4752_4F56_454C_4541)
    private var windFieldAge: TimeInterval = 0

    var isEmpty: Bool { leaves.isEmpty }
    var visibleCount: Int { leaves.lazy.filter(\.isVisible).count }

    mutating func emit(forPercentageDrop drop: Int, in size: CGSize) {
        let steps = min(max(0, drop), Self.maximumAnimatedDrop)
        guard steps > 0, size.width > 0, size.height > 0 else { return }
        if leaves.isEmpty { windFieldAge = 0 }
        let minimumFallSpeed = min(42, max(24, size.height / 4.4))
        let depthAnchors: [CGFloat] = [0.2, 0.78, 0.38, 0.58, 0.92, 0.28, 0.68, 0.48]
        let focusPattern: [FallingLeafFocus] = [.crisp, .motion, .soft, .motion, .crisp, .motion, .soft, .motion]
        let spriteVariants = [0, 2]

        for step in 0..<steps {
            for leafIndex in 0..<Self.leavesPerPercentagePoint {
                let startDelay = Double(step) * 0.22 + random.double(in: 0...0.16) + Double(leafIndex) * 0.065
                let leafSize = random.cgFloat(in: 8...14)
                let depth = min(1, max(0.1, depthAnchors[leafIndex] + random.cgFloat(in: -0.045...0.045)))
                let focus = focusPattern[leafIndex]
                let motionScale = 0.82 + depth * 0.34
                let spreadLaneX = CGFloat((leafIndex * 3) % 7 - 3) / 3
                let spreadLaneY = CGFloat((leafIndex * 5) % 7 - 3) / 3
                leaves.append(FallingLeaf(
                    position: CGPoint(
                        x: random.cgFloat(in: size.width * 0.60...size.width * 1.12),
                        y: size.height + random.cgFloat(in: -2...24)
                    ),
                    velocity: CGVector(
                        dx: -random.cgFloat(in: 16...30) * (0.86 + depth * 0.26),
                        dy: -random.cgFloat(in: minimumFallSpeed...(minimumFallSpeed + 8)) * motionScale
                    ),
                    verticalAcceleration: random.cgFloat(in: 8...15),
                    verticalDrag: random.cgFloat(in: 0.45...0.75),
                    windVelocityX: -random.cgFloat(in: 22...36),
                    windResponse: random.cgFloat(in: 1.4...2.1),
                    flutterLift: random.cgFloat(in: 3...7),
                    midSpreadX: spreadLaneX * random.cgFloat(in: 4...8),
                    midSpreadY: spreadLaneY * random.cgFloat(in: 6...10),
                    swayPhase: random.cgFloat(in: 0...(2 * .pi)),
                    swaySpeed: random.cgFloat(in: 1.7...3.1),
                    swayAmplitude: random.cgFloat(in: 1.4...4.8) * (0.72 + depth * 0.34),
                    rotation: random.cgFloat(in: -58...58),
                    angularVelocity: random.cgFloat(in: -72...72) * (0.78 + depth * 0.32),
                    size: leafSize,
                    depth: depth,
                    focus: focus,
                    motionTrail: focus == .motion ? random.cgFloat(in: 3.2...7.2) : 0,
                    age: -startDelay,
                    lifetime: random.double(in: 2.35...3.15),
                    colorVariant: spriteVariants[random.int(in: 0..<spriteVariants.count)],
                    textureSeed: random.int(in: 1..<10_000)
                ))
            }
        }
    }

    mutating func emitManualBurst(in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        leaves.removeAll(keepingCapacity: true)
        windFieldAge = 0

        let gravityBase = min(70, max(54, size.height / 2.1))
        let waveStartDelays: [Double] = [0, 0.18, 0.38, 0.66, 0.94]
        let focusPattern: [FallingLeafFocus] = [.crisp, .soft, .motion, .motion]
        let spriteVariants = [0, 2]
        var leafIndex = 0

        for (wave, waveCount) in Self.manualBurstWaveCounts.enumerated() {
            for waveIndex in 0..<waveCount {
                let depth = random.cgFloat(in: 0.14...0.98)
                let focus = focusPattern[leafIndex % focusPattern.count]
                let startDelay = waveStartDelays[wave]
                    + Double(waveIndex) * 0.012
                    + random.double(in: 0...0.12)
                let spreadLaneX = CGFloat((leafIndex * 5) % 9 - 4) / 4
                let spreadLaneY = CGFloat((leafIndex * 7) % 11 - 5) / 5

                leaves.append(FallingLeaf(
                    position: CGPoint(
                        x: random.cgFloat(in: size.width * 0.72...size.width * 1.16),
                        y: size.height + random.cgFloat(in: -10...22)
                    ),
                    velocity: CGVector(
                        dx: -random.cgFloat(in: 8...18) * (0.84 + depth * 0.28),
                        dy: -random.cgFloat(in: 2...8) * (0.82 + depth * 0.28)
                    ),
                    verticalAcceleration: random.cgFloat(in: gravityBase...(gravityBase + 14)) * (0.82 + depth * 0.28),
                    verticalDrag: random.cgFloat(in: 0.78...1.08),
                    windVelocityX: -random.cgFloat(in: 50...76) * (0.84 + depth * 0.28),
                    windResponse: random.cgFloat(in: 1.5...2.4),
                    flutterLift: random.cgFloat(in: 14...26),
                    midSpreadX: spreadLaneX * random.cgFloat(in: 16...28),
                    midSpreadY: spreadLaneY * random.cgFloat(in: 22...38),
                    swayPhase: random.cgFloat(in: 0...(2 * .pi)),
                    swaySpeed: random.cgFloat(in: 1.9...3.9),
                    swayAmplitude: random.cgFloat(in: 3.2...8.8) * (0.7 + depth * 0.38),
                    rotation: random.cgFloat(in: -72...72),
                    angularVelocity: random.cgFloat(in: -38...38) * (0.74 + depth * 0.38),
                    size: random.cgFloat(in: 8.5...16),
                    depth: depth,
                    focus: focus,
                    motionTrail: focus == .motion ? random.cgFloat(in: 2.8...6.2) : 0,
                    age: -startDelay,
                    lifetime: random.double(in: 3.4...4.6),
                    colorVariant: spriteVariants[random.int(in: 0..<spriteVariants.count)],
                    textureSeed: random.int(in: 1..<10_000)
                ))
                leafIndex += 1
            }
        }
    }

    mutating func advance(by deltaTime: TimeInterval) {
        let delta = min(max(deltaTime, 0), 1.0 / 15.0)
        guard delta > 0 else { return }
        windFieldAge += delta
        let gustAge = CGFloat(windFieldAge)
        let gustRise = 1 - exp(-gustAge * 3.4)
        let gustDecay = exp(-max(0, gustAge - 1.2) * 0.72)
        let windEnvelope = 0.22 + 0.78 * gustRise * gustDecay
        let spreadTime = min(1, max(0, (gustAge - 0.55) / 2.0))
        let spreadEnvelope = pow(sin(spreadTime * .pi), 2)

        for index in leaves.indices {
            leaves[index].age += delta
            guard leaves[index].age >= 0 else { continue }
            leaves[index].swayPhase += leaves[index].swaySpeed * delta
            let windFlutter = 1 + sin(leaves[index].swayPhase * 0.82 + leaves[index].depth * 2.4) * 0.12
            let targetWindVelocity = leaves[index].windVelocityX * windEnvelope * windFlutter
                + leaves[index].midSpreadX * spreadEnvelope
            let windBlend = min(1, leaves[index].windResponse * CGFloat(delta))
            leaves[index].velocity.dx += (targetWindVelocity - leaves[index].velocity.dx) * windBlend
            let verticalAirflow = sin(leaves[index].swayPhase * 1.24 + leaves[index].depth * .pi)
                * leaves[index].flutterLift
                + leaves[index].midSpreadY * spreadEnvelope
            leaves[index].velocity.dy -= (leaves[index].verticalAcceleration + verticalAirflow) * delta
            leaves[index].velocity.dy *= max(0, 1 - leaves[index].verticalDrag * CGFloat(delta))
            leaves[index].position.x += leaves[index].velocity.dx * delta
            leaves[index].position.y += leaves[index].velocity.dy * delta
            let flutterRotation = sin(leaves[index].swayPhase) * 18
            leaves[index].rotation += (leaves[index].angularVelocity + flutterRotation) * delta
        }
        leaves.removeAll { leaf in
            leaf.age >= leaf.lifetime || leaf.position.y < -leaf.size * 2
        }
    }

    mutating func removeAll() {
        leaves.removeAll(keepingCapacity: true)
        windFieldAge = 0
    }
}

private struct SeededLeafRandom {
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

    mutating func int(in range: Range<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.count))
    }
}
