//
//  AudioPreviewPlayer.swift
//  Good_Audio_Converter
//
//  Backs the play button on each converted file in ResultsView, so a
//  user can listen before saving. Owns a single AVAudioPlayer at a time
//  — starting a new preview stops whatever was already playing.
//

import AVFoundation
import Observation

@Observable
@MainActor
final class AudioPreviewPlayer: NSObject {
    private(set) var currentlyPlayingID: UUID?
    private var player: AVAudioPlayer?

    func toggle(id: UUID, url: URL) {
        if currentlyPlayingID == id {
            stop()
        } else {
            play(id: id, url: url)
        }
    }

    private func play(id: UUID, url: URL) {
        stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true)
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            guard newPlayer.play() else { return }
            player = newPlayer
            currentlyPlayingID = id
        } catch {
            currentlyPlayingID = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        currentlyPlayingID = nil
    }
}

extension AudioPreviewPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stop()
        }
    }
}
