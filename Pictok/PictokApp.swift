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
        store.save()
        Task { await rescheduleNotification() }
    }

    private func rescheduleNotification() async {
        let solvedToday = store.state.todaySolved &&
            store.state.todayPuzzleId == PuzzleLoader.dateString(for: Date())
        if solvedToday {
            await scheduler.cancelDailyReminder()
        }
        await scheduler.scheduleDailyReminderIfNeeded(
            now: Date(),
            alreadySolvedToday: solvedToday
        )
    }
}

struct RootView: View {
    @Bindable var store: UserStateStore
    let loader: PuzzleLoader?
    let loadError: String?
    let onSolveOrFail: () async -> Void

    var body: some View {
        if let loader {
            let todays = loader.puzzle(for: Date())
            TabView {
                TodayView(
                    store: store,
                    puzzle: todays,
                    puzzleNumber: todays.map { loader.puzzleNumber(for: $0) } ?? 1,
                    onSolveOrFail: onSolveOrFail
                )
                .tabItem { Label("Today", systemImage: "calendar") }

                StatsView(store: store)
                    .tabItem { Label("Stats", systemImage: "chart.bar") }
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
