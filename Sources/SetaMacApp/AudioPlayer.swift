import AVFoundation
import Foundation
import SetaMacCore

@MainActor
final class AudioPlayerController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentTrack: SetaTrack?
    @Published var errorMessage: String?

    var onFinished: (() -> Void)?

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?

    @discardableResult
    func play(track: SetaTrack) -> Bool {
        stop()
        do {
            let url = URL(fileURLWithPath: track.path)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            currentTrack = track
            duration = player?.duration ?? track.durationSec ?? 0
            currentTime = 0
            isPlaying = true
            errorMessage = nil
            startProgressTimer()
            return true
        } catch {
            player = nil
            errorMessage = error.localizedDescription
            isPlaying = false
            currentTrack = nil
            duration = 0
            currentTime = 0
            return false
        }
    }

    func togglePause() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopProgressTimer()
        } else {
            player.play()
            isPlaying = true
            startProgressTimer()
        }
    }

    func stop() {
        stopProgressTimer()
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        currentTrack = nil
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = max(0, min(time, player.duration))
        player.currentTime = clamped
        currentTime = clamped
    }

    func seekRelative(_ delta: TimeInterval) {
        seek(to: currentTime + delta)
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, currentTime / duration))
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            stopProgressTimer()
            currentTime = duration
            if flag {
                onFinished?()
            }
        }
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
                self.duration = player.duration
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}
