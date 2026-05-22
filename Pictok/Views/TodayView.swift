import SwiftUI

struct TodayView: View {
    @Bindable var store: UserStateStore
    let puzzle: Puzzle?            // nil = no puzzle for today (out-of-bundle date)
    let puzzleNumber: Int          // 1-based, passed from PictokApp (via loader)
    /// The puzzle dated to yesterday in the bundle. Used for the post-solve
    /// "Yesterday was…" teaser; nil if yesterday is outside the bundle.
    let yesterdaysPuzzle: Puzzle?
    let onSolveOrFail: () async -> Void   // triggers notification reschedule
    var onPlayEndless: () -> Void = {}

    @AppStorage("pictok.hasSeenHowToPlay") private var hasSeenHowToPlay: Bool = false

    @State private var showHintMenu = false
    @State private var showResult   = false
    @State private var showHowToPlay = false
    @State private var showPermissionPrompt = false
    @State private var showWinCelebration: Bool = false
    @State private var showFailCelebration: Bool = false
    @State private var hasShownOneChanceWarning: Bool = false
    @State private var showOneChanceAlert: Bool = false

    var body: some View {
        ZStack {
            Color.pkPaper.ignoresSafeArea()

            if let puzzle {
                content(for: puzzle)
            } else {
                VStack(spacing: 16) {
                    Text("No puzzle for today — check back tomorrow.")
                        .font(.pkSubtitle)
                        .multilineTextAlignment(.center)
                    StickerButton(title: "Continue Playing", icon: "▶️", fill: .pkGreen) {
                        onPlayEndless()
                    }
                    .padding(.top, 12)
                }
                .padding()
            }

            if showWinCelebration, let puzzle {
                WinCelebrationView(answer: puzzle.answer)
                    .transition(.opacity)
                    .zIndex(10)
            }

            if showFailCelebration, let puzzle {
                FailCelebrationView(answer: puzzle.answer)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .onChange(of: store.state.todaySolved) { _, solved in
            if solved {
                showWinCelebration = true
                DispatchQueue.main.asyncAfter(deadline: .now() + WinCelebrationView.totalDuration) {
                    showWinCelebration = false
                }
            }
        }
        .onChange(of: store.state.todayFailed) { _, failed in
            if failed {
                showFailCelebration = true
                DispatchQueue.main.asyncAfter(deadline: .now() + FailCelebrationView.totalDuration) {
                    showFailCelebration = false
                }
            }
        }
        .sheet(isPresented: $showResult) {
            if let puzzle {
                ResultSheet(store: store, puzzle: puzzle, puzzleNumber: puzzleNumber)
            }
        }
        .sheet(isPresented: $showHowToPlay, onDismiss: { hasSeenHowToPlay = true }) {
            HowToPlayView()
        }
        .sheet(isPresented: $showPermissionPrompt) {
            NotificationPermissionSheet(store: store)
        }
        .alert("One chance left", isPresented: $showOneChanceAlert) {
            Button("OK") { showOneChanceAlert = false }
        } message: {
            Text("Make it count — one more wrong guess ends the puzzle.")
        }
        .onChange(of: puzzle?.id) { _, _ in
            hasShownOneChanceWarning = false
        }
        .task {
            // First-ever app open: surface the rebus explainer so the player
            // doesn't land on raw blanks + emojis with no context.
            if !hasSeenHowToPlay && puzzle != nil {
                showHowToPlay = true
            }
        }
    }

    @ViewBuilder
    private func content(for puzzle: Puzzle) -> some View {
        VStack(spacing: 16) {
            topBar
            EmojiHeader(emoji: puzzle.emoji)
            CategoryChip(category: puzzle.category,
                         subcategory: revealedSubcategory(for: puzzle))
            BlanksView(answer: puzzle.answer,
                       correctGuesses: blanksCorrectGuesses(for: puzzle),
                       revealedLetter: store.state.todayRevealedLetter)
            tomorrowFooter
            Spacer(minLength: 0)
            KeyboardView(
                correctGuesses: Set(store.state.todayCorrectGuesses),
                wrongGuesses: Set(store.state.todayWrongGuesses),
                onGuess: { letter in handleGuess(letter, in: puzzle) }
            )
            if isSubmitReady {
                StickerButton(title: "Submit ✓", icon: nil, fill: .pkGreen) {
                    submitToday()
                }
                .padding(.top, 8)
                .transition(.scale.combined(with: .opacity))
            }
            StickerButton(title: "Continue Playing", icon: "▶️", fill: .pkGreen) {
                onPlayEndless()
            }
            .padding(.top, 12)
        }
        .padding()
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSubmitReady)
        .task {
            // First-time-app entry today: link store to this puzzle.
            if store.state.todayPuzzleId != puzzle.id {
                resetTodayState(for: puzzle.id)
            }
            store.save()
            // If puzzle already finished, surface the result sheet.
            if store.state.todaySolved || store.state.todayFailed {
                showResult = true
            }
        }
    }

    /// Post-solve / post-fail anticipation block: live countdown to the next
    /// daily + a masked teaser for yesterday's puzzle (curiosity hook into the
    /// archive). Hidden while the puzzle is still in-flight.
    @ViewBuilder
    private var tomorrowFooter: some View {
        if store.state.todaySolved || store.state.todayFailed {
            VStack(spacing: 10) {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(countdownText(at: context.date))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.pkInk.opacity(0.6))
                }
                if let yp = yesterdaysPuzzle {
                    VStack(spacing: 4) {
                        Text("Yesterday was")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.pkInk.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(0.8)
                        HStack(spacing: 8) {
                            Text(yp.emoji).font(.system(size: 22))
                            Text(maskAnswer(yp.answer))
                                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Color.pkInk.opacity(0.5))
                                .tracking(2)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.pkInk.opacity(0.18),
                                    style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    )
                }
            }
            .padding(.top, 6)
        }
    }

    private func countdownText(at now: Date) -> String {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!
        let interval = tomorrow.timeIntervalSince(now)
        let h = max(0, Int(interval) / 3600)
        let m = max(0, (Int(interval) % 3600) / 60)
        return "Next puzzle in \(h)h \(m)m"
    }

    private func maskAnswer(_ s: String) -> String {
        s.map { $0 == " " ? "   " : "_" }
            .joined(separator: " ")
    }

    private var topBar: some View {
        HStack {
            HeartsRow(remaining: store.state.lives)
            Spacer()
            Button { showHintMenu = true } label: { Text("💡").font(.system(size: 26)) }
                .disabled(store.state.todayHintUsed != nil || store.state.todaySolved || store.state.todayFailed)
                .confirmationDialog("Pick a hint", isPresented: $showHintMenu) {
                    Button("Reveal category (−1 ❤️)") { useHint(.category) }
                        .disabled(store.state.lives < 1)
                    Button("Reveal a letter (−2 ❤️)") { useHint(.letter) }
                        .disabled(store.state.lives < 2)
                    Button("Cancel", role: .cancel) {}
                }
            Button { showHowToPlay = true } label: { Text("⚙️").font(.system(size: 24)) }
        }
    }

    // MARK: Derived

    /// Correct guesses surfaced to `BlanksView`. When the puzzle is finished
    /// (solved or failed) we expand this to every letter in the answer so the
    /// full solution is revealed in the result state. The hint-revealed letter
    /// is passed separately so it can be shown across all words.
    private func blanksCorrectGuesses(for puzzle: Puzzle) -> Set<Character> {
        var set = Set(store.state.todayCorrectGuesses)
        if store.state.todaySolved || store.state.todayFailed {
            set.formUnion(puzzle.answer.filter { $0.isLetter })
        }
        return set
    }

    private func revealedSubcategory(for puzzle: Puzzle) -> String? {
        store.state.todayHintUsed == .category ? puzzle.subcategory : nil
    }

    // MARK: Actions

    private func resetTodayState(for puzzleId: String) {
        store.state.todayPuzzleId = puzzleId
        store.state.todayWrongGuesses = []
        store.state.todayCorrectGuesses = []
        store.state.todayHintUsed = nil
        store.state.todayRevealedLetter = nil
        store.state.todaySolved = false
        store.state.todayFailed = false
        store.state.lives = 5
    }

    private func handleGuess(_ letter: Character, in puzzle: Puzzle) {
        guard !store.state.todaySolved, !store.state.todayFailed else { return }
        let upper = Character(String(letter).uppercased())
        if Set(store.state.todayCorrectGuesses).contains(upper) ||
           Set(store.state.todayWrongGuesses).contains(upper) { return }

        if GameEngine.isCorrect(letter: upper, in: puzzle) {
            store.state.todayCorrectGuesses.append(upper)
            HapticsService.correct()
            SoundService.shared.play(.correct)
            // Submit-button gating handled by isSubmitReady (rendered in body).
        } else {
            store.state.todayWrongGuesses.append(upper)
            store.state.lives -= 1
            HapticsService.wrong()
            SoundService.shared.play(.wrong)
            if store.state.lives == 1 && !hasShownOneChanceWarning {
                hasShownOneChanceWarning = true
                showOneChanceAlert = true
            }
        }
        store.save()
        checkEndState(for: puzzle)
    }

    private func useHint(_ hint: HintType) {
        guard store.state.todayHintUsed == nil else { return }
        let cost = GameEngine.heartCost(for: hint)
        guard store.state.lives >= cost else { return }
        store.state.lives -= cost
        store.state.todayHintUsed = hint
        if hint == .letter, let puzzle = currentPuzzleSnapshot() {
            store.state.todayRevealedLetter = GameEngine.letterToReveal(
                for: puzzle,
                correctGuesses: Set(store.state.todayCorrectGuesses)
            )
        }
        checkEndState(for: currentPuzzleSnapshot())
        store.save()
    }

    private func currentPuzzleSnapshot() -> Puzzle? { puzzle }

    /// Now handles only the FAIL side. The solve side is gated on the user
    /// tapping the Submit button (see `submitToday()` + `isSubmitReady`).
    private func checkEndState(for puzzle: Puzzle?) {
        guard puzzle != nil else { return }
        guard !store.state.todaySolved, !store.state.todayFailed else { return }
        if GameEngine.isFailed(lives: store.state.lives) {
            store.state.todayFailed = true
            applyFailSideEffects()
            HapticsService.failed()
            showResult = true
            Task { await onSolveOrFail() }
        }
    }

    /// True when every letter in the answer is known (via correct guesses or the
    /// hint-revealed letter) and the puzzle is still active — i.e. the player
    /// can confirm the solve by tapping Submit.
    private var isSubmitReady: Bool {
        guard let puzzle else { return false }
        guard !store.state.todaySolved, !store.state.todayFailed else { return false }
        let correct = Set(store.state.todayCorrectGuesses)
        return GameEngine.isSolved(answer: puzzle.answer,
                                   correctGuesses: correct,
                                   revealedLetter: store.state.todayRevealedLetter)
    }

    /// Confirms a daily solve. Runs the win-side bookkeeping that the old
    /// `checkEndState` used to do automatically; now gated on the Submit button.
    private func submitToday() {
        guard let puzzle else { return }
        guard !store.state.todaySolved, !store.state.todayFailed else { return }
        let correct = Set(store.state.todayCorrectGuesses)
        guard GameEngine.isSolved(answer: puzzle.answer,
                                  correctGuesses: correct,
                                  revealedLetter: store.state.todayRevealedLetter) else { return }
        store.state.todaySolved = true
        applySolveSideEffects(for: puzzle)
        HapticsService.solved()
        showResult = true
        store.save()
        Task { await onSolveOrFail() }
    }

    private func applySolveSideEffects(for puzzle: Puzzle) {
        let today = PuzzleLoader.dateString(for: Date(), timeZone: .current)
        let next = GameEngine.streakAfterSolve(
            today: today,
            lastSolvedDate: store.state.lastSolvedDate,
            currentStreak: store.state.currentStreak,
            streakFreezesAvailable: store.state.streakFreezesAvailable
        )
        store.state.currentStreak = next.streak
        store.state.streakFreezesAvailable = next.freezesAvailable
        store.state.longestStreak = max(store.state.longestStreak, next.streak)
        store.state.lastSolvedDate = today
        store.state.totalSolved += 1
        store.state.lifetimeSolvedCount += 1
        store.state.totalPlayed += 1
        let wrongs = store.state.todayWrongGuesses.count
        store.state.guessDistribution[wrongs, default: 0] += 1

        let hintUsed = store.state.todayHintUsed != nil
        let result: SolveResult = (wrongs == 0 && !hintUsed) ? .perfect : .solved
        appendSolveHistory(date: today, result: result)

        // First-ever solve → arm the contextual notification permission prompt
        if !store.state.hasEverSolved {
            store.state.hasEverSolved = true
            if !store.state.hasAskedForNotificationPermission {
                showPermissionPrompt = true
            }
        }

        // Ambassador session is done; subsequent app launches serve date-based puzzles.
        store.state.ambassadorActive = false
    }

    private func applyFailSideEffects() {
        store.state.currentStreak = GameEngine.streakAfterFail(currentStreak: store.state.currentStreak)
        store.state.totalPlayed += 1
        let today = PuzzleLoader.dateString(for: Date(), timeZone: .current)
        appendSolveHistory(date: today, result: .failed)
        // Ambassador session is done even on a fail; user moves on next launch.
        store.state.ambassadorActive = false
    }

    private func appendSolveHistory(date: String, result: SolveResult) {
        var history = store.state.solveHistory.filter { $0.date != date }
        history.append(SolveRecord(date: date, result: result))
        store.state.solveHistory = history
    }
}
