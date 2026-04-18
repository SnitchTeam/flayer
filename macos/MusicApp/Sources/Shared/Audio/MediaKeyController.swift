#if os(iOS)
import UIKit
#else
import AppKit
#endif
import MediaPlayer

@MainActor
final class MediaKeyController {
    private let player: AudioEngine

    init(player: AudioEngine) {
        self.player = player
        setupRemoteCommands()
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        // Play
        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.player.state == .paused {
                    self.player.resume()
                } else if self.player.state == .stopped, self.player.currentTrack != nil {
                    self.player.togglePlayPause()
                }
                self.updateNowPlaying()
            }
            return .success
        }

        // Pause
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.player.pause()
                self.updateNowPlaying()
            }
            return .success
        }

        // Toggle play/pause
        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.player.togglePlayPause()
                self.updateNowPlaying()
            }
            return .success
        }

        // Next track
        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.player.next()
                self.updateNowPlaying()
            }
            return .success
        }

        // Previous track
        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.player.previous()
                self.updateNowPlaying()
            }
            return .success
        }

        // Seek
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                guard let self else { return }
                self.player.seek(to: posEvent.positionTime)
                self.updateNowPlaying()
            }
            return .success
        }
    }

    func updateNowPlaying() {
        var info = [String: Any]()

        if let track = player.currentTrack {
            info[MPMediaItemPropertyTitle] = track.title
            info[MPMediaItemPropertyArtist] = track.artist
            info[MPMediaItemPropertyAlbumTitle] = track.album
            info[MPMediaItemPropertyPlaybackDuration] = player.duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.position

            // Cover art
            if let path = track.coverArtPath,
               let image = loadImage(contentsOfFile: path) {
                let imageSize = image.size
                let artwork = MPMediaItemArtwork(boundsSize: imageSize) { @Sendable _ in
                    return loadImage(contentsOfFile: path) ?? PlatformImage()
                }
                info[MPMediaItemPropertyArtwork] = artwork
            }
        }

        info[MPNowPlayingInfoPropertyPlaybackRate] = player.state == .playing ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = player.state == .playing ? .playing : (player.state == .paused ? .paused : .stopped)
    }
}
