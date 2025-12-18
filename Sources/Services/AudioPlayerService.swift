import Foundation
import AVFoundation

/// Simple audio player service for previewing tracks
class AudioPlayerService: ObservableObject {
    private var player: AVAudioPlayer?
    
    @Published var isPlaying: Bool = false
    @Published var currentTrackId: String?
    
    func play(url: URL, trackId: String) {
        // Stop any current playback
        stop()
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
            currentTrackId = trackId
            print("[AudioPlayer] ▶️ Playing: \(url.lastPathComponent)")
        } catch {
            print("[AudioPlayer] ❌ Failed to play: \(error)")
        }
    }
    
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTrackId = nil
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        
        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }
}
