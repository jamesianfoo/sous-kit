import AVFoundation

/// Loops the bundled alarm tone while the push-up challenge is running, so opening
/// the app does not become a way to silence the alarm.
final class AlarmSoundPlayer {
    private var player: AVAudioPlayer?

    func play() {
        guard player == nil, let url = Bundle.main.url(forResource: "alarm", withExtension: "wav") else { return }
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, options: [.duckOthers])
        try? audioSession.setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.volume = 1
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
