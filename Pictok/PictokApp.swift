import SwiftUI

@main
struct PictokApp: App {
    @State private var store = UserStateStore()
    @State private var loader: PuzzleLoader? = nil
    @State private var loadError: String? = nil
    private let scheduler = NotificationScheduler()

    var body: some Scene {
        WindowGroup {
            RootView(store: store, loader: loader, loadError: loadError) {
                await rescheduleNotification()
            }
            .task { setup() }
            .onChange(of: scenePhase) { _, new in
                if new == .active { Task { await rescheduleNotification() } }
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase

    private func setup() {
        do {
            loader = try PuzzleLoader.bundled()
            loadError = nil
        } catch {
            loadError = "Failed to load puzzles: \(error.localizedDescription)"
        }
        #if DEBUG
        applyScreenshotPresetIfRequested()
        #endif
        store.save()
        Task { await rescheduleNotification() }
    }

    #if DEBUG
    /// DEBUG-only seeding used to capture App Store screenshots in known states.
    /// Pass via the simulator: `xcrun simctl launch booted com.rehatchugh.pictok --screenshot-state=populated`
    /// Strip these branches before App Store submission if you want a fully release-only binary.
    private func applyScreenshotPresetIfRequested() {
        let args = CommandLine.arguments
        guard let arg = args.first(where: { $0.hasPrefix("--screenshot-state=") }) else { return }
        let preset = String(arg.dropFirst("--screenshot-state=".count))
        let today = PuzzleLoader.dateString(for: Date())
        switch preset {
        case "populated":
            store.state.currentStreak = 7
            store.state.longestStreak = 12
            store.state.lastSolvedDate = "2026-05-18"
            store.state.streakFreezesAvailable = 1
            store.state.totalSolved = 47
            store.state.totalPlayed = 53
            store.state.guessDistribution = [0: 8, 1: 14, 2: 12, 3: 7, 4: 4, 5: 2]
            store.state.lives = 5
            store.state.todayPuzzleId = "puzzle-002"
            store.state.todaySolved = false
            store.state.todayFailed = false
            store.state.hasEverSolved = true
            store.state.hasAskedForNotificationPermission = true
            store.state.ambassadorActive = false
            store.state.solvedPuzzleIds = Set((1...53).filter { ![10, 23, 31, 38, 44, 52].contains($0) }
                .map { String(format: "puzzle-%03d", $0) })
            store.state.failedPuzzleIds = Set(["puzzle-010", "puzzle-023", "puzzle-031",
                                                "puzzle-038", "puzzle-044", "puzzle-052"])
            store.state.lifetimeSolvedCount = 47
        case "midSolve":
            applyScreenshotPresetIfRequested_populatedBase()
            if let loader = self.loader,
               let todays = loader.puzzle(for: Date()) {
                store.state.todayPuzzleId = todays.id
                // Pick the first 3 distinct letters from the answer (in order)
                // so the visible blanks show meaningful progress.
                var seen: Set<Character> = []
                var picks: [Character] = []
                for ch in todays.answer.uppercased() where ch.isLetter && !seen.contains(ch) {
                    seen.insert(ch)
                    picks.append(ch)
                    if picks.count >= 3 { break }
                }
                store.state.todayCorrectGuesses = picks
                store.state.todayWrongGuesses = ["X"]
                store.state.lives = 4
            } else {
                store.state.lives = 4
                store.state.todayCorrectGuesses = ["I"]
                store.state.todayWrongGuesses = ["X"]
            }
        case "nearSubmit":
            // All letters of today's puzzle revealed but not yet submitted —
            // shows the Submit ✓ sticker button mid-screen.
            applyScreenshotPresetIfRequested_populatedBase()
            if let loader = self.loader,
               let todays = loader.puzzle(for: Date()) {
                store.state.todayPuzzleId = todays.id
                let allLetters = Array(Set(todays.answer.uppercased().filter { $0.isLetter }))
                store.state.todayCorrectGuesses = allLetters
                store.state.todayWrongGuesses = []
                store.state.lives = 5
            }
        case "solvedToday":
            applyScreenshotPresetIfRequested_populatedBase()
            store.state.currentStreak = 8
            store.state.lastSolvedDate = today
            store.state.todayCorrectGuesses = ["I", "R", "O", "B", "T"]
            store.state.todayWrongGuesses = []
            store.state.todaySolved = true
            store.state.totalSolved = 48
            store.state.totalPlayed = 54
            store.state.lifetimeSolvedCount = 48
        default:
            break
        }
    }

    private func applyScreenshotPresetIfRequested_populatedBase() {
        store.state.currentStreak = 7
        store.state.longestStreak = 12
        store.state.lastSolvedDate = "2026-05-18"
        store.state.streakFreezesAvailable = 1
        store.state.totalSolved = 47
        store.state.totalPlayed = 53
        store.state.guessDistribution = [0: 8, 1: 14, 2: 12, 3: 7, 4: 4, 5: 2]
        store.state.lives = 5
        store.state.todayPuzzleId = "puzzle-002"
        store.state.todaySolved = false
        store.state.todayFailed = false
        store.state.hasEverSolved = true
        store.state.hasAskedForNotificationPermission = true
        store.state.ambassadorActive = false
        store.state.solvedPuzzleIds = Set((1...53).filter { ![10, 23, 31, 38, 44, 52].contains($0) }
            .map { String(format: "puzzle-%03d", $0) })
        store.state.failedPuzzleIds = Set(["puzzle-010", "puzzle-023", "puzzle-031",
                                            "puzzle-038", "puzzle-044", "puzzle-052"])
        store.state.lifetimeSolvedCount = 47
    }
    #endif

    private func rescheduleNotification() async {
        let solvedToday = store.state.todaySolved &&
            store.state.todayPuzzleId == PuzzleLoader.dateString(for: Date())
        if solvedToday {
            await scheduler.cancelDailyReminder()
        }
        await scheduler.scheduleDailyReminderIfNeeded(
            now: Date(),
            alreadySolvedToday: solvedToday,
            lastValidDate: bundleLastDate()
        )
    }

    /// The last date a Daily puzzle exists for in the bundle, as a Date at
    /// 00:00 UTC. Used to stop scheduling 9 AM reminders once the bundle is
    /// exhausted — otherwise a user opening a stale ping after 2026-07-16
    /// lands on the "No puzzle today" fallback.
    private func bundleLastDate() -> Date? {
        guard let loader else { return nil }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return loader.allPuzzles
            .compactMap { f.date(from: $0.date) }
            .max()
    }
}

struct RootView: View {
    @Bindable var store: UserStateStore
    let loader: PuzzleLoader?
    let loadError: String?
    let onSolveOrFail: () async -> Void

    enum Tab: Hashable { case today, endless, stats }

    @State private var selectedTab: Tab = {
        #if DEBUG
        if CommandLine.arguments.contains("--present-endless") { return .endless }
        if CommandLine.arguments.contains("--present-stats")   { return .stats }
        return .today
        #else
        return .today
        #endif
    }()

    var body: some View {
        if let loader {
            // Ambassador override: a brand-new user gets `puzzle-001` (TOY STORY)
            // as their very first puzzle, regardless of today's actual date — so
            // first impressions land on a vetted clue, not whatever Hard puzzle
            // happens to fall on install day. Cleared on first solve/fail.
            let todays: Puzzle? = store.state.ambassadorActive
                ? loader.allPuzzles.first(where: { $0.id == "puzzle-001" })
                : loader.puzzle(for: Date())
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())
            let yesterdays: Puzzle? = yesterday.flatMap { loader.puzzle(for: $0) }
            TabView(selection: $selectedTab) {
                TodayView(
                    store: store,
                    puzzle: todays,
                    puzzleNumber: todays.map { loader.puzzleNumber(for: $0) } ?? 1,
                    yesterdaysPuzzle: yesterdays,
                    onSolveOrFail: onSolveOrFail,
                    onPlayEndless: { selectedTab = .endless }
                )
                .tabItem { Label("Today", systemImage: "calendar") }
                .tag(Tab.today)

                EndlessView(loader: loader, store: store)
                    .tabItem { Label("Endless", systemImage: "infinity") }
                    .tag(Tab.endless)

                StatsView(store: store, loader: loader)
                    .tabItem { Label("Stats", systemImage: "chart.bar") }
                    .tag(Tab.stats)
            }
            .tint(.pkBlue)
        } else if let loadError {
            VStack(spacing: 12) {
                Text("⚠️").font(.system(size: 64))
                Text(loadError).font(.pkBody).multilineTextAlignment(.center).padding()
            }
        } else {
            ProgressView().background(Color.pkPaper)
        }
    }
}
