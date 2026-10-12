import SwiftUI
import AVFoundation
import MediaPlayer

@MainActor
final class PlayerManager: ObservableObject {
    let player = AVPlayer()
    @Published var title = ""
    @Published var isActive = false

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        let rc = MPRemoteCommandCenter.shared()
        rc.playCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.player.play() }
            return .success
        }
        rc.pauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.player.pause() }
            return .success
        }
    }

    func play(_ url: URL, title: String) {
        self.title = title
        isActive = true
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.play()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle: title]
    }

    func togglePause() {
        if player.timeControlStatus == .paused { player.play() } else { player.pause() }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        isActive = false
    }
}
