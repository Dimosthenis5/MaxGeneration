import AVFoundation

/// Original synthesized arcade sound effects (files in Sounds/).
enum SoundFX: String {
    case tap, tick, claim, xp, rank, levelup

    private static var players: [String: AVAudioPlayer] = [:]
    private static var configured = false

    static var enabled: Bool {
        UserDefaults.standard.object(forKey: "soundOn") as? Bool ?? true
    }

    static func play(_ sound: SoundFX) {
        guard enabled else { return }
        configure()
        if let player = players[sound.rawValue] {
            player.currentTime = 0
            player.play()
            return
        }
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.volume = 0.8
        player.prepareToPlay()
        players[sound.rawValue] = player
        player.play()
    }

    private static func configure() {
        guard !configured else { return }
        configured = true
        // Ambient: plays alongside your music and respects the silent switch.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}
