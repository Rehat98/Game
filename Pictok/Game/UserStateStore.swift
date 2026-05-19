import Foundation
import Observation

@Observable
final class UserStateStore {
    static let defaultsKey = "pictok.state.v1"

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
}
