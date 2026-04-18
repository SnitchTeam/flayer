import SwiftUI

// MARK: - Album Expanded Inner

struct AlbumExpandedInner: View {
    @Environment(AppState.self) private var appState
    let album: Album
    let backToArtist: Artist?
    let dockSpring: Animation
    let onBack: (Artist) -> Void
    let onSelectAlbum: (Album) -> Void

    @State private var currentAlbum: Album?
    @State private var tracks: [Track] = []
    @State private var otherAlbums: [Album] = []
    @State private var favoriteTrackIds: Set<Int64> = []
    @State private var isAlbumFavorite: Bool = false
    @State private var musicBrainzMode: MusicBrainzSheetMode?
    @State private var showCoverMenu = false

    private var displayAlbum: Album { currentAlbum ?? album }

    var body: some View {
        ZStack {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(.white.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity)

            // Back button
            HStack {
                if let artist = backToArtist {
                    Button {
                        onBack(artist)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text(artist.name)
                                .font(.system(size: 13))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 4)

            ScrollView {
                VStack(spacing: 24) {
                    // Album header
                    VStack(spacing: 12) {
                        CoverArtView(path: displayAlbum.coverArtPath, size: 200)
                            .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
                            .glassContextMenu(isPresented: $showCoverMenu, items: [
                                GlassMenuItem(label: Lang.changeArtwork, icon: "photo.on.rectangle") {
                                    musicBrainzMode = .artwork
                                },
                                GlassMenuItem(label: Lang.refreshMetadata, icon: "arrow.clockwise") {
                                    musicBrainzMode = .metadata
                                },
                            ])

                        Text(displayAlbum.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)

                        Text(displayAlbum.albumArtist)
                            .font(.callout)
                            .foregroundStyle(.gray)

                        HStack(spacing: 6) {
                            if let year = displayAlbum.year {
                                Text(String(year))
                                    .font(.caption)
                                    .foregroundStyle(.gray.opacity(0.5))
                            }
                            FormatBadgesView(formats: Set(tracks.map(\.format).filter { !$0.isEmpty }))
                        }

                        if !tracks.isEmpty {
                            HStack(spacing: 6) {
                                Text(Lang.trackCount(tracks.count))
                                Text("\u{b7}")
                                Text(formatTotalDuration(tracks.reduce(0) { $0 + $1.duration }))
                            }
                            .font(.caption2)
                            .foregroundStyle(.gray.opacity(0.4))
                        }

                        // Play / Shuffle / Favorite
                        HStack(spacing: 8) {
                            Button {
                                appState.player.playAlbum(tracks)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 10))
                                    Text(Lang.play)
                                }
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)

                            Button {
                                appState.player.playShuffled(tracks)
                            } label: {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.gray)
                                    .frame(width: 30, height: 30)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button {
                                toggleAlbumFavorite()
                            } label: {
                                Image(systemName: isAlbumFavorite ? "heart.fill" : "heart")
                                    .font(.system(size: 14))
                                    .foregroundStyle(isAlbumFavorite ? .pink : .gray)
                                    .frame(width: 34, height: 34)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                    }

                    // Track list
                    VStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            HStack(spacing: 0) {
                                Button {
                                    appState.player.playAlbum(tracks, startIndex: index)
                                } label: {
                                    HStack(spacing: 8) {
                                        ZStack {
                                            if isTrackPlaying(track) {
                                                NowPlayingBars()
                                                    .frame(width: 14, height: 12)
                                            } else {
                                                Text("\(track.trackNumber ?? (index + 1))")
                                                    .font(.caption2)
                                                    .foregroundStyle(isTrackCurrent(track) ? .white : .gray.opacity(0.5))
                                            }
                                        }
                                        .frame(width: 24, alignment: .trailing)

                                        Text(track.title)
                                            .font(.caption)
                                            .foregroundStyle(isTrackCurrent(track) ? .white : .primary.opacity(0.85))
                                            .fontWeight(isTrackCurrent(track) ? .semibold : .regular)
                                            .lineLimit(1)

                                        Spacer()

                                        if let trackId = track.id, favoriteTrackIds.contains(trackId) {
                                            Image(systemName: "heart.fill")
                                                .font(.system(size: 8))
                                                .foregroundStyle(.pink.opacity(0.5))
                                        }

                                        Text(track.duration.formattedDuration)
                                            .font(.caption2)
                                            .foregroundStyle(.gray.opacity(0.4))
                                            .fontDesign(.monospaced)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Menu {
                                    let isFav = track.id.map { favoriteTrackIds.contains($0) } ?? false
                                    Button {
                                        toggleFavorite(track)
                                    } label: {
                                        Label(isFav ? Lang.removeFavorite : Lang.addFavorite,
                                              systemImage: isFav ? "heart.slash" : "heart")
                                    }
                                    Button {
                                        appState.player.playNext(track)
                                    } label: {
                                        Label(Lang.playNext, systemImage: "text.line.first.and.arrowtriangle.forward")
                                    }
                                    Button {
                                        appState.player.addToQueue(track)
                                    } label: {
                                        Label(Lang.addToQueue, systemImage: "text.append")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray.opacity(0.4))
                                        .frame(width: 28, height: 28)
                                        .contentShape(Rectangle())
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.leading, 16)
                            .padding(.trailing, 8)

                            if index < tracks.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.04))
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .glassCard()
                    .padding(.horizontal, 20)

                    // Other albums
                    if !otherAlbums.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(Lang.otherAlbumsBy(album.albumArtist))
                                .font(.caption)
                                .foregroundStyle(.gray.opacity(0.5))
                                .padding(.horizontal, 24)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(otherAlbums) { other in
                                        Button {
                                            onSelectAlbum(other)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 4) {
                                                CoverArtView(path: other.coverArtPath, size: 80)
                                                Text(other.name)
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.gray)
                                                    .lineLimit(1)
                                                    .frame(width: 80, alignment: .leading)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.bottom, 24)
            }
        }
        .blur(radius: musicBrainzMode == .artwork ? 20 : 0)
        .allowsHitTesting(musicBrainzMode != .artwork)

        if musicBrainzMode == .artwork {
            Color.black.opacity(0.4)
            ArtworkPickerOverlay(album: displayAlbum) {
                musicBrainzMode = nil
                loadData()
            }
            .environment(appState)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        }
        .overlay {
            GlassContextMenuOverlay(isPresented: $showCoverMenu, items: [
                GlassMenuItem(label: Lang.changeArtwork, icon: "photo.on.rectangle") {
                    musicBrainzMode = .artwork
                },
                GlassMenuItem(label: Lang.refreshMetadata, icon: "arrow.clockwise") {
                    musicBrainzMode = .metadata
                },
            ])
        }
        .animation(.spring(duration: 0.35), value: musicBrainzMode == .artwork)
        .onAppear { loadData() }
        .onChange(of: album.id) { _, _ in loadData() }
        .sheet(isPresented: Binding(
            get: { musicBrainzMode == .metadata },
            set: { if !$0 { musicBrainzMode = nil } }
        )) {
            MusicBrainzSheet(album: displayAlbum, mode: .metadata) {
                musicBrainzMode = nil
                loadData()
            }
            .environment(appState)
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        guard let albumId = album.id else { return }
        currentAlbum = appState.db.getAlbum(id: albumId)
        tracks = appState.db.getAlbumTracks(albumId: albumId)
        otherAlbums = appState.db.getArtistAlbums(artistName: album.albumArtist)
            .filter { $0.id != album.id }
        loadFavorites()
        isAlbumFavorite = appState.db.isAlbumFavorite(albumId: albumId)
    }

    private func loadFavorites() {
        guard let favId = appState.db.getOrCreateFavorites().id else { return }
        let favTracks = appState.db.getPlaylistTracks(playlistId: favId)
        favoriteTrackIds = Set(favTracks.compactMap(\.id))
    }

    // MARK: - Track Helpers

    private func isTrackPlaying(_ track: Track) -> Bool {
        guard let current = appState.player.currentTrack else { return false }
        return current.id == track.id && appState.player.state == .playing
    }

    private func isTrackCurrent(_ track: Track) -> Bool {
        guard let current = appState.player.currentTrack else { return false }
        return current.id == track.id
    }

    private func formatTotalDuration(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return Lang.totalDuration(hours: h, minutes: m)
    }

    private func toggleAlbumFavorite() {
        guard let albumId = album.id else { return }
        if isAlbumFavorite {
            appState.db.removeAlbumFromFavorites(albumId: albumId)
        } else {
            appState.db.addAlbumToFavorites(albumId: albumId)
        }
        withAnimation(.spring(duration: 0.3)) {
            isAlbumFavorite.toggle()
        }
    }

    private func toggleFavorite(_ track: Track) {
        guard let trackId = track.id,
              let favId = appState.db.getOrCreateFavorites().id else { return }
        if favoriteTrackIds.contains(trackId) {
            appState.db.removeTrackFromPlaylist(playlistId: favId, trackId: trackId)
            favoriteTrackIds.remove(trackId)
        } else {
            appState.db.addTrackToPlaylist(playlistId: favId, trackId: trackId)
            favoriteTrackIds.insert(trackId)
        }
    }
}
