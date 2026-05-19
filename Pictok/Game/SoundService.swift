import AVFoundation

enum Sound: String {
    case correct, wrong, win, fail

    /// Filename (without extension) of the .wav backing this sound. `.fail`
    /// currently reuses `wrong.wav`; replace with a dedicated asset in Task 29.
    var filename: String {
        switch self {
        case .correct: return "correct"
        case .wrong:   return "wrong"
        case .win:     return "win"
        case .fail:    return "wrong"
        }
    }
}

final class SoundService {
    static let shared = SoundService()
    private var players: [Sound: AVAudioPlayer] = [:]

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for sound in [Sound.correct, .wrong, .win, .fail] {
            if let url = Bundle.main.url(forResource: sound.filename, withExtension: "wav") {
                players[sound] = try? AVAudioPlayer(contentsOf: url)
                players[sound]?.prepareToPlay()
            }
        }
    }

    func play(_ sound: Sound) {
        guard let player = players[sound] else { return }
        player.currentTime = 0
        player.play()
    }
}
