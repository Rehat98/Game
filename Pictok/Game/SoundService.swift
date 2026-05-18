import AVFoundation

enum Sound: String {
    case correct, wrong, win
}

final class SoundService {
    static let shared = SoundService()
    private var players: [Sound: AVAudioPlayer] = [:]

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for sound in [Sound.correct, .wrong, .win] {
            if let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") {
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
