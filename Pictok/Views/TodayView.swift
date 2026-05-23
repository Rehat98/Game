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

    @State private var showResult   = false
    @State private var showHowToPlay = false
    @State private var showPermissionPrompt = false
    @State private var showWinCelebration: Bool = false
    @State private var showFailCelebration: Bool = false
    @State private var showFirstSolveBanner: Bool = false
    @State private var streakMilestone: Int? = nil
    @State private var hasShownOneChanceWarning: Bool = false
    @State private var showOneChanceAlert: Bool = false

    var body: some View {
        ZStack {
            Color.pkPaper.ignoresSafeArea()

            if let puzzle {
                content(for: puzzle)
            } else {
                VStack(spacing: 16) {
                    Text("No puzzle for today. Check back tomorrow.")
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

            if showFirstSolveBanner {
                firstSolveBanner
                    .transition(.opacity)
                    .zIndex(11)
            }

            if let milestone = streakMilestone {
                streakMilestoneOverlay(milestone)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(12)
            }
        }
        .onChange(of: store.state.currentStreak) { _, new in
            if [3, 7, 14, 30, 100].contains(new) {
                // Wait for the standard win celebration to clear before showing.
                DispatchQueue.main.asyncAfter(deadline: .now() + WinCelebrationView.totalDuration + 0.3) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        streakMilestone = new
                    }
                }
            }
        }
        .onChange(of: store.state.todaySolved) { _, solved in
            if solved {
                showWinCelebration = true
                // `totalSolved` is already incremented by applySolveSideEffects
                // before this onChange fires, so == 1 means this is the very
                // first solve in the user's lifetime.
                let isFirstSolveEver = store.state.totalSolved == 1
                DispatchQueue.main.asyncAfter(deadline: .now() + WinCelebrationView.totalDuration) {
                    showWinCelebration = false
                    if isFirstSolveEver {
                        withAnimation(.easeIn(duration: 0.25)) {
                            showFirstSolveBanner = true
                        }
                    }
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
            Text("Make it count. One more wrong guess ends the puzzle.")
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
            tutorialOverlay
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

    /// Streak milestone celebration triggered when currentStreak hits a
    /// landmark value (3 / 7 / 14 / 30 / 100). Duolingo-style overlay with
    /// milestone-specific emoji + copy. Tap "Keep going" to dismiss.
    private func streakMilestoneOverlay(_ n: Int) -> some View {
        VStack(spacing: 16) {
            Text(streakMilestoneEmoji(n))
                .font(.system(size: 96))
            Text("\(n)-day streak!")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(Color.pkInk)
            Text(streakMilestoneCopy(n))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.pkInk.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            StickerButton(title: "Keep going", icon: nil, fill: .pkGreen) {
                withAnimation(.easeOut(duration: 0.25)) {
                    streakMilestone = nil
                }
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pkPaper.opacity(0.96).ignoresSafeArea())
    }

    private func streakMilestoneEmoji(_ n: Int) -> String {
        switch n {
        case 3:   return "🌶️"
        case 7:   return "🔥"
        case 14:  return "⚡"
        case 30:  return "💎"
        case 100: return "👑"
        default:  return "🔥"
        }
    }

    private func streakMilestoneCopy(_ n: Int) -> String {
        switch n {
        case 3:   return "Three days in a row.\nYou're catching the habit."
        case 7:   return "A full week.\nThe Pictok ritual is yours."
        case 14:  return "Two weeks straight.\nYour puzzle-brain is sharpening."
        case 30:  return "Thirty days.\nYou're a Pictok mainstay."
        case 100: return "ONE HUNDRED DAYS.\nThat's elite territory."
        default:  return ""
        }
    }

    /// One-time "Day 1 streak" celebration shown after a user's very first
    /// Daily solve. Replaces the standard ResultSheet for a moment so the
    /// milestone lands; tapping "Let's go" dismisses and reveals the sheet
    /// underneath (with the share card).
    private var firstSolveBanner: some View {
        VStack(spacing: 16) {
            Text("🔥")
                .font(.system(size: 96))
            Text("Day 1 streak")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(Color.pkInk)
            Text("Welcome to Pictok.\nNew puzzle every midnight.")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.pkInk.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            StickerButton(title: "Let's go", icon: nil, fill: .pkGreen) {
                withAnimation(.easeOut(duration: 0.25)) {
                    showFirstSolveBanner = false
                }
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pkPaper.opacity(0.96).ignoresSafeArea())
    }

    /// First-launch coaching banner shown only during the ambassador puzzle
    /// (`state.ambassadorActive`). Steps through "tap a letter" → "wrong letters
    /// cost a heart" → "keep going" → "tap Submit". Disappears the moment the
    /// player solves or fails the ambassador (ambassadorActive flips to false).
    @ViewBuilder
    private var tutorialOverlay: some View {
        if let message = tutorialMessage {
            Text(message)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.pkInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.pkYellow.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.pkInk, lineWidth: 2)
                        )
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.25), value: message)
                .id(message) // forces transition when message text changes
        }
    }

    private var tutorialMessage: String? {
        guard store.state.ambassadorActive else { return nil }
        guard puzzle != nil else { return nil }
        if store.state.todaySolved || store.state.todayFailed { return nil }

        let correctCount = store.state.todayCorrectGuesses.count
        let wrongCount = store.state.todayWrongGuesses.count

        if isSubmitReady {
            return "All letters revealed. Tap Submit ✓ to claim your first solve."
        }
        if wrongCount > 0 {
            return "Wrong letters cost a ❤️. Try ones you think ARE in the answer."
        }
        if correctCount > 0 {
            return "Nice. Keep tapping the other letters."
        }
        return "Decode the emojis into the title. Tap any letter to start."
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
            hintMenu
            Button { showHowToPlay = true } label: { Text("⚙️").font(.system(size: 24)) }
        }
    }

    /// Native SwiftUI Menu is more reliable than confirmationDialog inside a
    /// button whose disabled state re-renders often. Picking either option
    /// fires useHint immediately; the menu closes automatically.
    private var hintMenu: some View {
        Menu {
            Button {
                useHint(.category)
            } label: {
                Label("Reveal category (1 heart)", systemImage: "tag")
            }
            .disabled(store.state.lives < 1)

            Button {
                useHint(.letter)
            } label: {
                Label("Reveal a letter (2 hearts)", systemImage: "textformat")
            }
            .disabled(store.state.lives < 2)
        } label: {
            HStack(spacing: 5) {
                Text("💡").font(.system(size: 18))
                Text("Hint")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.pkInk)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .sticker(fill: .pkYellow, cornerRadius: 14, strokeWidth: 2, shadowOffset: 2)
        }
        .disabled(hintDisabled)
        .opacity(hintDisabled ? 0.4 : 1.0)
    }

    /// Hint button is unavailable when:
    /// - The hint has already been used this puzzle
    /// - The puzzle is finished (solved or failed)
    /// - All letters are already revealed (Submit ✓ is the move, not Hint)
    private var hintDisabled: Bool {
        store.state.todayHintUsed != nil
            || store.state.todaySolved
            || store.state.todayFailed
            || isSubmitReady
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
