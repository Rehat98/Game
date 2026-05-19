import SwiftUI

struct TodayView: View {
    @Bindable var store: UserStateStore
    let puzzle: Puzzle?            // nil = no puzzle for today (out-of-bundle date)
    let puzzleNumber: Int          // 1-based, passed from PictokApp (via loader)
    let onSolveOrFail: () async -> Void   // triggers notification reschedule
    var onPlayEndless: () -> Void = {}

    @State private var showHintMenu = false
    @State private var showResult   = false
    @State private var showHowToPlay = false
    @State private var showPermissionPrompt = false

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
                    StickerButton(title: "Play Endless", icon: "▶️", fill: .pkGreen) {
                        onPlayEndless()
                    }
                    .padding(.top, 12)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showResult) {
            if let puzzle {
                ResultSheet(store: store, puzzle: puzzle, puzzleNumber: puzzleNumber)
            }
        }
        .sheet(isPresented: $showHowToPlay) { HowToPlayView() }
        .sheet(isPresented: $showPermissionPrompt) {
            NotificationPermissionSheet(store: store)
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
            Spacer(minLength: 0)
            KeyboardView(guessed: guessedLetters) { letter in
                handleGuess(letter, in: puzzle)
            }
            StickerButton(title: "Play Endless", icon: "▶️", fill: .pkGreen) {
                onPlayEndless()
            }
            .padding(.top, 12)
        }
        .padding()
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

    private var guessedLetters: Set<Character> {
        Set(store.state.todayWrongGuesses + store.state.todayCorrectGuesses)
    }

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
        let known = knownLetters
        guard let activeIdx = GameEngine.activeWordIndex(answer: puzzle.answer,
                                                         correctGuesses: known) else {
            // Already solved word-by-word — no-op.
            return
        }
        let correct = GameEngine.isCorrect(letter: upper,
                                           inWord: activeIdx,
                                           of: puzzle.answer)
        if correct {
            store.state.todayCorrectGuesses.append(upper)
            HapticsService.correct()
            SoundService.shared.play(.correct)
        } else {
            store.state.todayWrongGuesses.append(upper)
            store.state.lives -= 1
            HapticsService.wrong()
            SoundService.shared.play(.wrong)
        }
        checkEndState(for: puzzle)
        store.save()
    }

    /// Merge of correctGuesses and the hint-revealed letter (if any), used as the
    /// "known letters" input for word-by-word active-word and solve-check logic.
    private var knownLetters: Set<Character> {
        var set = Set(store.state.todayCorrectGuesses)
        if let r = store.state.todayRevealedLetter { set.insert(r) }
        return set
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

    private func checkEndState(for puzzle: Puzzle?) {
        guard let puzzle else { return }
        if GameEngine.isSolvedByWord(answer: puzzle.answer,
                                     correctGuesses: knownLetters) {
            store.state.todaySolved = true
            applySolveSideEffects(for: puzzle)
            HapticsService.solved()
            SoundService.shared.play(.win)
            showResult = true
            Task { await onSolveOrFail() }
        } else if GameEngine.isFailed(lives: store.state.lives) {
            store.state.todayFailed = true
            applyFailSideEffects()
            HapticsService.failed()
            showResult = true
            Task { await onSolveOrFail() }
        }
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

        // First-ever solve → arm the contextual notification permission prompt
        if !store.state.hasEverSolved {
            store.state.hasEverSolved = true
            if !store.state.hasAskedForNotificationPermission {
                showPermissionPrompt = true
            }
        }
    }

    private func applyFailSideEffects() {
        store.state.currentStreak = GameEngine.streakAfterFail(currentStreak: store.state.currentStreak)
        store.state.totalPlayed += 1
    }
}
