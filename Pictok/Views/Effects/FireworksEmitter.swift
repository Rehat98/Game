import SwiftUI

/// Native SwiftUI particle source. Generates a fixed set of pseudo-random
/// fireworks bursts on init, then renders them every frame via TimelineView
/// + Canvas. No third-party dependencies.
struct FireworksEmitter: View {
    static let totalDuration: TimeInterval = 1.4
    static let burstCount = 6
    static let particlesPerBurst = 30
    static let burstColors: [Color] = [.pkYellow, .pkRed, .pkGreen, .pkBlue]

    private struct Particle {
        let originX: Double          // 0..1 normalized to canvas width
        let originY: Double          // 0..1 normalized to canvas height
        let velocityX: Double        // px/s
        let velocityY: Double        // px/s
        let color: Color
        let isCircle: Bool
        let birthTime: TimeInterval  // seconds from emitter start
        let lifetime: TimeInterval
    }

    let startDate: Date
    private let particles: [Particle]

    init(startDate: Date = Date()) {
        self.startDate = startDate
        self.particles = Self.generateAllParticles()
    }

    private static func generateAllParticles() -> [Particle] {
        var all: [Particle] = []
        for _ in 0..<burstCount {
            let burstTime = Double.random(in: 0..<totalDuration)
            let originX = Double.random(in: 0.15...0.85)
            let originY = Double.random(in: 0.10...0.50)
            let color = burstColors.randomElement()!
            for _ in 0..<particlesPerBurst {
                let angle = Double.random(in: 0..<(2 * .pi))
                let speed = Double.random(in: 80...160)
                all.append(Particle(
                    originX: originX,
                    originY: originY,
                    velocityX: cos(angle) * speed,
                    velocityY: sin(angle) * speed - 50,  // bias upward
                    color: color,
                    isCircle: Bool.random(),
                    birthTime: burstTime,
                    lifetime: 1.2
                ))
            }
        }
        return all
    }

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let now = context.date.timeIntervalSince(startDate)
                let gravity = 200.0
                for p in particles {
                    let age = now - p.birthTime
                    guard age >= 0, age <= p.lifetime else { continue }
                    let alpha = 1.0 - (age / p.lifetime)
                    let x = p.originX * size.width + p.velocityX * age
                    let y = p.originY * size.height + p.velocityY * age + 0.5 * gravity * age * age
                    let s: CGFloat = p.isCircle ? 7 : 8
                    let rect = CGRect(x: x - s/2, y: y - s/2, width: s, height: s)
                    let path = p.isCircle ? Path(ellipseIn: rect) : Path(rect)
                    ctx.fill(path, with: .color(p.color.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Color.pkPaper.ignoresSafeArea()
        FireworksEmitter()
    }
}
