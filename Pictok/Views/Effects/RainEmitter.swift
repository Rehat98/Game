import SwiftUI

/// Native SwiftUI raindrop emitter. Particles fall straight down with mild
/// horizontal drift and fade. Used for the fail celebration overlay.
struct RainEmitter: View {
    static let totalDuration: TimeInterval = 2.8
    static let dropCount = 40

    private struct Drop {
        let originX: Double          // 0..1 normalized
        let velocityY: Double        // px/s
        let drift: Double            // small horizontal drift
        let color: Color
        let birthTime: TimeInterval  // seconds from start
        let lifetime: TimeInterval
    }

    let startDate: Date
    private let drops: [Drop]

    init(startDate: Date = Date()) {
        self.startDate = startDate
        self.drops = Self.generateDrops()
    }

    private static func generateDrops() -> [Drop] {
        var ds: [Drop] = []
        for _ in 0..<dropCount {
            ds.append(Drop(
                originX: Double.random(in: 0.05...0.95),
                velocityY: Double.random(in: 220...340),
                drift: Double.random(in: -20...20),
                color: Color.pkBlue.opacity(Double.random(in: 0.5...0.85)),
                birthTime: Double.random(in: 0..<totalDuration),
                lifetime: Double.random(in: 1.0...1.4)
            ))
        }
        return ds
    }

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let now = context.date.timeIntervalSince(startDate)
                for d in drops {
                    let age = now - d.birthTime
                    guard age >= 0, age <= d.lifetime else { continue }
                    let alpha = 1.0 - (age / d.lifetime)
                    let x = d.originX * size.width + d.drift * age
                    let y = d.velocityY * age  // starts at top
                    // Drop = a slim vertical capsule
                    let rect = CGRect(x: x - 1.5, y: y, width: 3, height: 10)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1.5),
                             with: .color(d.color.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Color.pkPaper.ignoresSafeArea()
        RainEmitter()
    }
}
