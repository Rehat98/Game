import Foundation
import Observation

@Observable
final class UserStateStore {
    static let defaultsKey = "pictok.state.v1"
    private static let refillInterval: TimeInterval = 4 * 3600   // 4 hours
    private static let maxLives = 5

    private let defaults: UserDefaults
    private let now: () -> Date

    var state: UserState

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        if let data = defaults.data(forKey: Self.defaultsKey),
           let restored = try? JSONDecoder().decode(UserState.self, from: data) {
            self.state = restored
        } else {
            self.state = UserState.fresh(at: now())
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }

    /// Refill lives based on elapsed time since the anchor. Caller passes `now`
    /// explicitly so this is testable.
    func refillLives(now currentTime: Date? = nil) {
        let nowValue = currentTime ?? now()
        guard state.lives < Self.maxLives else {
            // Keep the anchor current so we don't accumulate a huge backlog while maxed.
            state.livesLastRefilledAt = nowValue
            return
        }
        let elapsed = nowValue.timeIntervalSince(state.livesLastRefilledAt)
        guard elapsed >= Self.refillInterval else { return }

        let livesToAdd = min(Int(elapsed / Self.refillInterval),
                             Self.maxLives - state.lives)
        state.lives += livesToAdd
        state.livesLastRefilledAt = state.livesLastRefilledAt
            .addingTimeInterval(Double(livesToAdd) * Self.refillInterval)
    }
}
