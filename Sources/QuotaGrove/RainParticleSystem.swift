import CoreGraphics
import Foundation

struct RainDrop {
    var position: CGPoint
    var fallSpeed: CGFloat
    var windSpeed: CGFloat
    var length: CGFloat
    var lineWidth: CGFloat
    var opacity: CGFloat
    var depth: CGFloat
}

struct RainSplash {
    var position: CGPoint
    var age: TimeInterval
    var lifetime: TimeInterval
    var size: CGFloat

    var progress: CGFloat { min(1, max(0, CGFloat(age / lifetime))) }
    var opacity: CGFloat { 1 - progress }
}

struct RainParticleSystem {
    private(set) var drops: [RainDrop] = []
    private(set) var splashes: [RainSplash] = []
    private var random = SeededRainRandom(seed: 0x5241_494E_4752_4F56)

    var isEmpty: Bool { drops.isEmpty && splashes.isEmpty }

    mutating func start(in size: CGSize) {
        drops.removeAll(keepingCapacity: true)
        splashes.removeAll(keepingCapacity: true)
        guard size.width > 0, size.height > 0 else { return }

        addDrops(count: 26, depth: 0.08...0.34, in: size)
        addDrops(count: 18, depth: 0.4...0.72, in: size)
        addDrops(count: 8, depth: 0.78...1, in: size)
    }

    mutating func advance(by deltaTime: TimeInterval, in size: CGSize) {
        let delta = min(max(deltaTime, 0), 1.0 / 15.0)
        guard delta > 0, size.width > 0, size.height > 0 else { return }

        for index in drops.indices {
            drops[index].position.x += drops[index].windSpeed * delta
            drops[index].position.y -= drops[index].fallSpeed * delta
            if drops[index].position.y < -drops[index].length {
                if drops[index].depth > 0.62,
                   random.unit() < 0.42,
                   drops[index].position.x > 2,
                   drops[index].position.x < size.width - 2 {
                    splashes.append(RainSplash(
                        position: CGPoint(x: drops[index].position.x, y: 4),
                        age: 0,
                        lifetime: random.double(in: 0.22...0.38),
                        size: random.cgFloat(in: 2...5) * (0.7 + drops[index].depth * 0.35)
                    ))
                }
                respawn(dropAt: index, in: size)
            }
        }

        for index in splashes.indices { splashes[index].age += delta }
        splashes.removeAll { $0.age >= $0.lifetime }
        if splashes.count > 20 { splashes.removeFirst(splashes.count - 20) }
    }

    mutating func removeAll() {
        drops.removeAll(keepingCapacity: true)
        splashes.removeAll(keepingCapacity: true)
    }

    private mutating func addDrops(count: Int, depth: ClosedRange<CGFloat>, in size: CGSize) {
        for _ in 0..<count {
            let selectedDepth = random.cgFloat(in: depth)
            drops.append(makeDrop(depth: selectedDepth, in: size, initial: true))
        }
    }

    private mutating func respawn(dropAt index: Int, in size: CGSize) {
        let depth = drops[index].depth
        drops[index] = makeDrop(depth: depth, in: size, initial: false)
    }

    private mutating func makeDrop(depth: CGFloat, in size: CGSize, initial: Bool) -> RainDrop {
        let speed = 58 + depth * 128 + random.cgFloat(in: -12...16)
        let length = 2.6 + depth * 14 + random.cgFloat(in: -1.1...1.8)
        let y = initial
            ? random.cgFloat(in: -length...(size.height + length * 2.4))
            : size.height + random.cgFloat(in: 4...(size.height * 0.72 + 10))
        return RainDrop(
            position: CGPoint(
                x: random.cgFloat(in: -8...(size.width * 1.24)),
                y: y
            ),
            fallSpeed: speed,
            windSpeed: -(22 + depth * 32 + random.cgFloat(in: 0...12)),
            length: max(2.5, length),
            lineWidth: 0.07 + depth * 0.38 + random.cgFloat(in: -0.025...0.04),
            opacity: 0.09 + depth * 0.39 + random.cgFloat(in: -0.02...0.04),
            depth: depth
        )
    }
}

private struct SeededRainRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

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
