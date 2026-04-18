import SwiftUI
import CoreAudio

struct PlayerPillView: View {
    @Environment(AppState.self) private var appState
    var onSwitchToNav: () -> Void

    @State private var showPlaylistPicker = false
    @State private var isFavorite = false
    @State private var showVolume = false

    private var isNavTop: Bool {
        appState.settings.navPosition == "top"
    }

    private var outputDeviceName: String {
        if appState.settings.outputDeviceUID.isEmpty {
            let defaultID = AudioDeviceManager.getDefaultDeviceID()
            return appState.player.availableDevices.first(where: { $0.id == defaultID })?.name ?? Lang.systemDefault
        }
        return appState.player.availableDevices.first(where: { $0.uid == appState.settings.outputDeviceUID })?.name ?? Lang.defaultOutput
    }

    @ViewBuilder
    var body: some View {
        let player = appState.player
        if let track = player.currentTrack {
            VStack(spacing: 10) {
                // Row 1: Artwork + track info + chevron
                HStack(alignment: .top, spacing: 14) {
                    Button {
                        if let albumId = track.albumId,
                           let album = appState.db.getAlbum(id: albumId) {
                            appState.modalAlbum = album
                        }
                    } label: {
                        CoverArtView(path: track.coverArtPath, size: 140)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Button {
                            if let artistId = track.artistId,
                               let artist = appState.db.getArtist(id: artistId) {
                                appState.modalArtist = artist
                            }
                        } label: {
                            Text(track.artist)
                                .font(.system(size: 11))
                                .foregroundStyle(.gray)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)

                        Text(track.album)
                            .font(.system(size: 10))
                            .foregroundStyle(.gray.opacity(0.4))
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            FormatBadge(format: track.format)

                            Text(trackBitrate(track))
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundStyle(.gray.opacity(0.4))
                        }

                        // Favorite + playlist
                        HStack(spacing: 8) {
                            Button(action: { toggleFavorite(track) }) {
                                Image(systemName: isFavorite ? "heart.fill" : "heart")
                                    .font(.system(size: 12))
                                    .foregroundStyle(isFavorite ? .pink : .gray.opacity(0.5))
                            }
                            .buttonStyle(.plain)

                            Button(action: { showPlaylistPicker = true }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.gray.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: onSwitchToNav) {
                        Image(systemName: isNavTop ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                }

                // Row 2: Progress bar
                HStack(spacing: 8) {
                    Text(player.position.formattedDuration)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.gray.opacity(0.6))
                        .frame(width: 32, alignment: .leading)

                    ProgressBarView(
                        progress: player.duration > 0 ? player.position / player.duration : 0,
                        onSeek: { ratio in
                            player.seek(to: ratio * player.duration)
                        }
                    )

                    Text(player.duration.formattedDuration)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.gray.opacity(0.6))
                        .frame(width: 32, alignment: .trailing)
                }

                // Row 3: Transport controls
                HStack(spacing: 0) {
                    Spacer()

                    HStack(spacing: 14) {
                        Button(action: { player.toggleShuffle() }) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 11))
                                .foregroundStyle(player.shuffle ? .white : .gray.opacity(0.5))
                        }
                        .buttonStyle(.plain)

                        Button(action: { player.previous() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.gray)
                        }
                        .buttonStyle(.plain)

                        Button(action: { player.togglePlayPause() }) {
                            Image(systemName: player.state == .playing ? "pause.fill" : "play.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Button(action: { player.next() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.gray)
                        }
                        .buttonStyle(.plain)

                        Button(action: { player.stop() }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.gray.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Volume
                    Button(action: { showVolume.toggle() }) {
                        Image(systemName: volumeIcon(player.volume))
                            .font(.system(size: 12))
                            .foregroundStyle(.gray.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: isNavTop ? .top : .bottom) {
                        if showVolume {
                            VolumeSliderView(volume: Binding(
                                get: { player.volume },
                                set: { player.setVolume($0) }
                            ))
                            .offset(y: isNavTop ? 20 : -20)
                            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: isNavTop ? .top : .bottom)))
                        }
                    }
                }

                // Row 4: EQ + Audio output
                HStack(spacing: 8) {
                    Button(action: toggleEQ) {
                        Text("EQ")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(appState.settings.eqEnabled ? .white : .gray.opacity(0.4))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(appState.settings.eqEnabled ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(appState.settings.eqEnabled ? Color.white.opacity(0.2) : .clear, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)

                    if appState.settings.eqEnabled, let preset = HeadphonePresetDatabase.find(id: appState.settings.eqPresetId) {
                        Text(preset.name)
                            .font(.system(size: 9))
                            .foregroundStyle(.gray.opacity(0.3))
                            .lineLimit(1)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "hifispeaker")
                            .font(.system(size: 9))
                        Text(outputDeviceName)
                            .font(.system(size: 9))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.gray.opacity(0.3))
                }
            }
            .frame(width: 460)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .glassPill()
            .animation(Anim.micro, value: showVolume)
            .zIndex(10)
            .onAppear { checkFavorite(track) }
            .onChange(of: player.currentTrack) { _, newTrack in
                showVolume = false
                if let t = newTrack { checkFavorite(t) }
            }
            .onChange(of: appState.libraryVersion) { _, _ in
                checkFavorite(track)
            }
            .background {
                if showVolume {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture { showVolume = false }
                }
            }
            .sheet(isPresented: $showPlaylistPicker) {
                PlaylistPickerView(track: track)
                    .frame(minWidth: 300, minHeight: 250)
            }
        }
    }

    private func checkFavorite(_ track: Track) {
        guard let trackId = track.id,
              let favId = appState.db.getOrCreateFavorites().id else { return }
        isFavorite = appState.db.isTrackInPlaylist(playlistId: favId, trackId: trackId)
    }

    private func volumeIcon(_ volume: Float) -> String {
        if volume <= 0 { return "speaker.slash.fill" }
        if volume < 0.33 { return "speaker.wave.1.fill" }
        if volume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private func trackBitrate(_ track: Track) -> String {
        guard track.duration > 0 else { return "" }
        let kbps = Int(Double(track.fileSize) * 8.0 / track.duration / 1000.0)
        if kbps >= 1000 {
            return String(format: "%.1f Mbps", Double(kbps) / 1000.0)
        }
        return "\(kbps) kbps"
    }

    private func toggleFavorite(_ track: Track) {
        guard let trackId = track.id,
              let favId = appState.db.getOrCreateFavorites().id else { return }
        if isFavorite {
            appState.db.removeTrackFromPlaylist(playlistId: favId, trackId: trackId)
        } else {
            appState.db.addTrackToPlaylist(playlistId: favId, trackId: trackId)
        }
        isFavorite.toggle()
    }

    private func toggleEQ() {
        appState.settings.eqEnabled.toggle()
        appState.player.setEQEnabled(appState.settings.eqEnabled)
        appState.saveSettings()
    }

}

struct MiniPlayerPillView: View {
    @Environment(AppState.self) private var appState
    var onSwitchToNav: () -> Void
    var onExpandPlayer: () -> Void

    private var isNavTop: Bool {
        appState.settings.navPosition == "top"
    }

    @ViewBuilder
    var body: some View {
        let player = appState.player
        if let track = player.currentTrack {
            HStack(spacing: 10) {
                Button {
                    if let albumId = track.albumId,
                       let album = appState.db.getAlbum(id: albumId) {
                        appState.modalAlbum = album
                    }
                } label: {
                    CoverArtView(path: track.coverArtPath, size: 34)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 10))
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(action: { player.previous() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)

                    Button(action: { player.togglePlayPause() }) {
                        Image(systemName: player.state == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button(action: { player.next() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onExpandPlayer) {
                    Image(systemName: isNavTop ? "chevron.down" : "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.gray)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 460)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassPill()
        }
    }
}

struct PlaylistPickerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let track: Track

    @State private var playlists: [Playlist] = []

    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(Lang.addToPlaylist)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                }

                if playlists.isEmpty {
                    Text(Lang.noPlaylist)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    VStack(spacing: 0) {
                        ForEach(playlists) { playlist in
                            Button {
                                if let trackId = track.id, let playlistId = playlist.id {
                                    appState.db.addTrackToPlaylist(playlistId: playlistId, trackId: trackId)
                                }
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: playlist.isFavorites ? "heart.fill" : "music.note.list")
                                        .font(.caption)
                                        .foregroundStyle(playlist.isFavorites ? .pink : .gray)
                                    Text(playlist.name)
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .glassCard()
                }
            }
            .padding(20)
        }
        .onAppear {
            playlists = appState.db.getPlaylists()
        }
    }
}

struct VolumeSliderView: View {
    @Binding var volume: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.08))

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.35))
                    .frame(height: max(0, geo.size.height * CGFloat(volume)))
            }
            .frame(width: 4)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = 1 - (value.location.y / geo.size.height)
                        volume = Float(max(0, min(1, ratio)))
                    }
            )
        }
        .frame(width: 28, height: 100)
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
        )
    }
}

struct ProgressBarView: View {
    let progress: Double
    let onSeek: (Double) -> Void

    @State private var isHovering = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)

                Capsule()
                    .fill(Color.white.opacity(isHovering ? 0.6 : 0.4))
                    .frame(width: max(0, geo.size.width * progress), height: 4)

                if isHovering {
                    Circle()
                        .fill(.white)
                        .frame(width: 10, height: 10)
                        .offset(x: max(0, geo.size.width * progress - 5))
                }
            }
            .frame(height: 10)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = max(0, min(1, value.location.x / geo.size.width))
                        onSeek(ratio)
                    }
            )
        }
        .frame(height: 10)
    }
}
