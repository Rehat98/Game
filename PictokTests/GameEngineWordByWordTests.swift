import XCTest
@testable import Pictok

final class GameEngineWordByWordTests: XCTestCase {

    func test_wordBreakdown_singleWord() {
        let bd = GameEngine.wordBreakdown(answer: "BELOVED")
        XCTAssertEqual(bd.words, ["BELOVED"])
        XCTAssertEqual(bd.connectorIndices, [])
    }

    func test_wordBreakdown_multiWordWithConnectors() {
        let bd = GameEngine.wordBreakdown(answer: "PRIDE AND PREJUDICE")
        XCTAssertEqual(bd.words, ["PRIDE", "AND", "PREJUDICE"])
        XCTAssertEqual(bd.connectorIndices, [1])
    }

    func test_wordBreakdown_multipleConnectors() {
        let bd = GameEngine.wordBreakdown(answer: "CALL OF THE WILD")
        XCTAssertEqual(bd.words, ["CALL", "OF", "THE", "WILD"])
        XCTAssertEqual(bd.connectorIndices, [1, 2])
    }

    func test_activeWordIndex_singleWord_unsolved() {
        let idx = GameEngine.activeWordIndex(answer: "BELOVED", correctGuesses: ["B", "E"])
        XCTAssertEqual(idx, 0)
    }

    func test_activeWordIndex_singleWord_fullySolved_returnsNil() {
        let idx = GameEngine.activeWordIndex(answer: "BEE", correctGuesses: ["B", "E"])
        XCTAssertNil(idx)
    }

    func test_activeWordIndex_skipsConnectors() {
        // "PRIDE AND PREJUDICE" — index 1 is "AND" (connector). Player has solved PRIDE fully.
        let idx = GameEngine.activeWordIndex(answer: "PRIDE AND PREJUDICE",
                                             correctGuesses: ["P", "R", "I", "D", "E"])
        XCTAssertEqual(idx, 2, "Should skip AND and land on PREJUDICE")
    }

    func test_activeWordIndex_returnsFirstUnsolvedNonConnector() {
        // "TOY STORY" — TOY needs T,O,Y. Player has T but not O,Y.
        let idx = GameEngine.activeWordIndex(answer: "TOY STORY", correctGuesses: ["T"])
        XCTAssertEqual(idx, 0)
    }

    func test_activeWordIndex_advancesWhenFirstWordComplete() {
        // "TOY STORY" — player has T,O,Y. TOY is complete; STORY needs S,T,O,R,Y.
        let idx = GameEngine.activeWordIndex(answer: "TOY STORY", correctGuesses: ["T", "O", "Y"])
        XCTAssertEqual(idx, 1)
    }

    func test_isCorrect_inWord_matchesLettersOnlyInActiveWord() {
        // "TOY STORY", active = 0 (TOY). S is in STORY only.
        XCTAssertFalse(GameEngine.isCorrect(letter: "S", inWord: 0, of: "TOY STORY"))
        XCTAssertTrue(GameEngine.isCorrect(letter: "T", inWord: 0, of: "TOY STORY"))
        XCTAssertTrue(GameEngine.isCorrect(letter: "S", inWord: 1, of: "TOY STORY"))
    }

    func test_isCorrect_caseInsensitive() {
        XCTAssertTrue(GameEngine.isCorrect(letter: "t", inWord: 0, of: "TOY STORY"))
    }

    func test_isSolved_byWord_singleWord() {
        XCTAssertTrue(GameEngine.isSolvedByWord(answer: "BEE", correctGuesses: ["B", "E"]))
        XCTAssertFalse(GameEngine.isSolvedByWord(answer: "BEE", correctGuesses: ["B"]))
    }

    func test_isSolved_byWord_multiWordWithConnectors() {
        // PRIDE AND PREJUDICE — connectors auto-solved; need PRIDE + PREJUDICE letters.
        // PRIDE letters: P,R,I,D,E. PREJUDICE letters: P,R,E,J,U,D,I,C,E. Union: P,R,I,D,E,J,U,C.
        let needed: Set<Character> = ["P", "R", "I", "D", "E", "J", "U", "C"]
        XCTAssertTrue(GameEngine.isSolvedByWord(answer: "PRIDE AND PREJUDICE", correctGuesses: needed))
    }

    func test_isPositionRevealed_connectorAlwaysRevealed() {
        // PRIDE AND PREJUDICE — char at index 6 is 'A' (start of AND).
        XCTAssertTrue(GameEngine.isPositionRevealed(answer: "PRIDE AND PREJUDICE",
                                                    position: 6,
                                                    correctGuesses: [],
                                                    activeWordIndex: 0))
    }

    func test_isPositionRevealed_activeWordLetterInGuesses() {
        // TOY STORY — position 0 ('T') with T guessed, active=0.
        XCTAssertTrue(GameEngine.isPositionRevealed(answer: "TOY STORY",
                                                    position: 0,
                                                    correctGuesses: ["T"],
                                                    activeWordIndex: 0))
    }

    func test_isPositionRevealed_futureWordHiddenEvenIfLetterGuessed() {
        // TOY STORY — position 4 ('T' in STORY) with T guessed, active=0.
        XCTAssertFalse(GameEngine.isPositionRevealed(answer: "TOY STORY",
                                                     position: 4,
                                                     correctGuesses: ["T"],
                                                     activeWordIndex: 0),
                       "T in STORY must stay hidden while TOY is the active word")
    }

    func test_isPositionRevealed_pastWordRevealedWithGuess() {
        // TOY STORY — position 0 ('T' in TOY) with T guessed, active=1 (advanced).
        XCTAssertTrue(GameEngine.isPositionRevealed(answer: "TOY STORY",
                                                    position: 0,
                                                    correctGuesses: ["T", "O", "Y"],
                                                    activeWordIndex: 1))
    }

    func test_wordBreakdown_allConnectors_treatsAllAsContent() {
        // Hypothetical future puzzle "IT" (Stephen King) — single connector word.
        let bd = GameEngine.wordBreakdown(answer: "IT")
        XCTAssertEqual(bd.words, ["IT"])
        XCTAssertEqual(bd.connectorIndices, [],
                       "An all-connector answer must not be auto-revealed")
    }

    func test_activeWordIndex_allConnectorAnswer_returnsZeroNotNil() {
        // With no guesses, the player should still have a real first word to solve.
        let idx = GameEngine.activeWordIndex(answer: "IT", correctGuesses: [])
        XCTAssertEqual(idx, 0)
    }

    func test_isSolvedByWord_allConnectorAnswer_requiresLetters() {
        XCTAssertFalse(GameEngine.isSolvedByWord(answer: "IT", correctGuesses: []))
        XCTAssertTrue(GameEngine.isSolvedByWord(answer: "IT", correctGuesses: ["I", "T"]))
    }
}
