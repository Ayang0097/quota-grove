import CoreGraphics
import Foundation

struct SnowFlake {
    var position: CGPoint
    var fallSpeed: CGFloat
    var windSpeed: CGFloat
    var driftAmplitude: CGFloat
    var swayPhase: CGFloat
    var swaySpeed: CGFloat
    var size: CGFloat
    var opacity: CGFloat
    var depth: CGFloat
    var rotation: CGFloat
    var rotationSpeed: CGFloat
    var showsCrystalDetail: Bool

    var renderedX: CGFloat {
        position.x + sin(swayPhase) * driftAmplitude
    }

    func bottomFade(in height: CGFloat) -> CGFloat {
        guard height > 0 else { return 0 }
        return min(1, max(0, position.y / min(16, height * 0.22)))
    }
}

struct SnowParticleSystem {
    private(set) var flakes: [SnowFlake] = []
    private var random = SeededSnowRandom(seed: 0x534E_4F57_4752_4F56)

    var isEmpty: Bool { flakes.isEmpty }

    mutating func start(in size: CGSize) {
        flakes.removeAll(keepingCapacity: true)
        guard size.width > 0, size.height > 0 else { return }

        addFlakes(count: 10, depth: 0.08...0.34, in: size)
        addFlakes(count: 7, depth: 0.4...0.72, in: size)
        addFlakes(count: 3, depth: 0.78...1, in: size)
    }

    mutating func advance(by deltaTime: TimeInterval, in size: CGSize) {
        let delta = min(max(deltaTime, 0), 1.0 / 12.0)
        guard delta > 0, size.width > 0, size.height > 0 else { return }

        for index in flakes.indices {
            flakes[index].position.x += flakes[index].windSpeed * delta
            flakes[index].position.y -= flakes[index].fallSpeed * delta
            flakes[index].swayPhase += flakes[index].swaySpeed * delta
            flakes[index].rotation += flakes[index].rotationSpeed * delta

            let horizontalMargin = max(12, flakes[index].size * 4)
            if flakes[index].position.x < -horizontalMargin {
                flakes[index].position.x = size.width + horizontalMargin
            } else if flakes[index].position.x > size.width + horizontalMargin {
                flakes[index].position.x = -horizontalMargin
            }

            if flakes[index].position.y < -flakes[index].size * 3 {
                respawn(flakeAt: index, in: size)
            }
        }
    }

    mutating func removeAll() {
        flakes.removeAll(keepingCapacity: true)
    }

    private mutating func addFlakes(count: Int, depth: ClosedRange<CGFloat>, in size: CGSize) {
        for _ in 0..<count {
            let selectedDepth = random.cgFloat(in: depth)
            flakes.append(makeFlake(depth: selectedDepth, in: size, initial: true))
        }
    }

    private mutating func respawn(flakeAt index: Int, in size: CGSize) {
        let depth = flakes[index].depth
        flakes[index] = makeFlake(depth: depth, in: size, initial: false)
    }

    private mutating func makeFlake(depth: CGFloat, in size: CGSize, initial: Bool) -> SnowFlake {
        let baseSize: CGFloat
        if depth < 0.36 {
            baseSize = 2.4 + depth * 4
        } else if depth < 0.75 {
            baseSize = 4.5 + depth * 6
        } else {
            baseSize = 7 + depth * 9
        }
        let flakeSize = baseSize + random.cgFloat(in: -0.28...0.5)
        let y = initial
            ? random.cgFloat(in: -flakeSize...(size.height + flakeSize * 3))
            : size.height + random.cgFloat(in: 3...(size.height * 0.38 + 8))
        return SnowFlake(
            position: CGPoint(
                x: random.cgFloat(in: -10...(size.width + 10)),
                y: y
            ),
            fallSpeed: 7 + depth * 22 + random.cgFloat(in: -1.5...3.5),
            windSpeed: -(1.8 + depth * 4.8) + random.cgFloat(in: -1.8...2.6),
            driftAmplitude: 1.8 + depth * 6.4 + random.cgFloat(in: 0...2.2),
            swayPhase: random.cgFloat(in: 0...(2 * .pi)),
            swaySpeed: 0.7 + depth * 1.15 + random.cgFloat(in: -0.16...0.24),
            size: max(0.5, flakeSize),
            opacity: 0.18 + depth * 0.58 + random.cgFloat(in: -0.04...0.08),
            depth: depth,
            rotation: random.cgFloat(in: 0...360),
            rotationSpeed: depth < 0.36
                ? random.cgFloat(in: -5...5)
                : random.cgFloat(in: -24...24) * (0.4 + depth * 0.6),
            showsCrystalDetail: depth > 0.76 || (depth > 0.45 && random.unit() < 0.48)
        )
    }
}

private struct SeededSnowRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &* 2_862_933_555_777_941_757 &+ 3_037_000_493
        return state
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func cgFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        range.lowerBound + (range.upperBound - range.lowerBound) * CGFloat(unit())
    }
}
