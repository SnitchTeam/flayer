import SwiftUI

struct PlayerPillView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var sizeClass
    var onSwitchToNav: () -> Void
    var onExpandPlayer: (() -> Void)? = nil
    var namespace: Namespace.ID?

    @State private var showPlaylistPicker = false
    @State private var isFavorite = false
    @State private var showVolume = false

    private var isIPad: Bool { sizeClass == .regular }

    private var isNavTop: Bool {
        appState.settings.navPosition == "top"
    }

    @ViewBuilder
    var body: some View {
        let player = appState.player
        if let track = player.currentTrack {
            VStack(spacing: 6) {
                // Row 1: Artwork + title/artist/album + format info + chevron
                HStack(spacing: 10) {
                    CoverArtView(path: track.coverArtPath, size: 44)
                        .if(namespace != nil) { view in
                            view.matchedGeometryEffect(id: "playerCover", in: namespace!)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(track.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text("—")
                                .font(.system(size: 10))
                                .foregroundStyle(.gray.opacity(0.4))

                            Text(track.artist)
                                .font(.system(size: 11))
                                .foregroundStyle(.gray)
                                .lineLimit(1)
                        }

                        HStack(spacing: 6) {
                            Text(track.album)
                                .font(.system(size: 9))
                                .foregroundStyle(.gray.opacity(0.4))
                                .lineLimit(1)

                            FormatBadge(format: track.format)

                            Text(trackBitrate(track))
                                .font(.system(size: 7, weight: .medium, design: .monospaced))
                                .foregroundStyle(.gray.opacity(0.4))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: onSwitchToNav) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Lang.dismiss)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if let expandHandler = onExpandPlayer {
                        expandHandler()
                    }
                }

                // Row 2: Left actions | Center controls | Right volume
                HStack(spacing: 0) {
                    // Left actions
                    HStack(spacing: 8) {
                        Button(action: { toggleFavorite(track) }) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 12))
                                .foregroundStyle(isFavorite ? .pink : .gray.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isFavorite ? Lang.removeFavorite : Lang.addFavorite)

                        Button(action: { showPlaylistPicker = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 12))
                                .foregroundStyle(.gray.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.addToPlaylist)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Center controls
                    HStack(spacing: 10) {
                        Button(action: { player.toggleShuffle() }) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 11))
                                .foregroundStyle(player.shuffle ? .white : .gray.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.shuffle)

                        Button(action: { player.previous() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.gray)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.previous)

                        Button(action: { player.togglePlayPause() }) {
                            Image(systemName: player.state == .playing ? "pause.fill" : "play.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.playPause)

                        Button(action: { player.next() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.gray)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.next)

                        Button(action: { player.stop() }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.gray.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.stop)
                    }

                    // Right: volume
                    HStack(spacing: 8) {
                        Button(action: { showVolume.toggle() }) {
                            Image(systemName: volumeIcon(player.volume))
                                .font(.system(size: 12))
                                .foregroundStyle(.gray.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.volume)
                        .overlay(alignment: isNavTop ? .bottom : .top) {
                            if showVolume {
                                VolumeSliderView(volume: Binding(
                                    get: { player.volume },
                                    set: { player.setVolume($0) }
                                ))
                                .offset(y: isNavTop ? 20 : -20)
                                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: isNavTop ? .bottom : .top)))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // Row 3: Progress bar with time labels
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
            }
            .frame(maxWidth: isIPad ? 460 : .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .glassPill()
            .animation(.easeOut(duration: 0.15), value: showVolume)
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
                    .accessibilityLabel(Lang.dismiss)
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
