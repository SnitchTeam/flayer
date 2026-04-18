import SwiftUI

struct TrackListView: View {
    @Environment(AppState.self) private var appState
    @State private var tracks: [Track] = []
    @State private var playlists: [Playlist] = []
    @State private var favoriteTrackIds: Set<Int64> = []

    private var sortMode: String {
        appState.settings.trackSort
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text(Lang.tracks)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("\(tracks.count)")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.4))

                Spacer()

                SortMenuButton(
                    options: [
                        (key: "date_added", label: Lang.recent),
                        (key: "alphabetical", label: Lang.alphabetical),
                    ],
                    selected: sortMode
                ) { key in
                    appState.settings.trackSort = key
                    appState.saveSettings()
                    loadTracks()
                }
            }

            if tracks.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .font(.system(size: 36))
                        .foregroundStyle(.gray.opacity(0.2))
                    Text(Lang.emptyLibrary)
                        .font(.callout)
                        .foregroundStyle(.gray.opacity(0.5))
                    Text(Lang.emptyLibraryHint)
                        .font(.caption)
                        .foregroundStyle(.gray.opacity(0.3))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {

            // Column header
            HStack(spacing: 12) {
                Text("")
                    .frame(width: 36)
                Text(Lang.title)
                Spacer()
                Text(Lang.album)
                    .frame(maxWidth: 200, alignment: .trailing)
                Text(Lang.duration)
                    .frame(width: 44, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.gray.opacity(0.35))
            .padding(.horizontal, 16)

            // Track list
            LazyVStack(spacing: 0) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    Button {
                        appState.player.playAlbum(tracks, startIndex: index)
                    } label: {
                        HStack(spacing: 12) {
                            CoverArtView(path: track.coverArtPath, size: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.caption2)
                                    .foregroundStyle(.gray.opacity(0.6))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(track.album)
                                .font(.caption2)
                                .foregroundStyle(.gray.opacity(0.4))
                                .lineLimit(1)
                                .frame(maxWidth: 200, alignment: .trailing)

                            Text(track.duration.formattedDuration)
                                .font(.caption2)
                                .foregroundStyle(.gray.opacity(0.4))
                                .fontDesign(.monospaced)
                                .frame(width: 44, alignment: .trailing)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu { trackContextMenu(track) }

                    if index < tracks.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.04))
                            .padding(.horizontal, 16)
                    }
                }
            }
            .glassCard()

            } // else
        }
        .onAppear {
            loadTracks()
            playlists = appState.db.getPlaylists()
            loadFavorites()
        }
        .onChange(of: appState.libraryVersion) { _, _ in
            loadTracks()
            playlists = appState.db.getPlaylists()
            loadFavorites()
        }
    }

    @ViewBuilder
    private func trackContextMenu(_ track: Track) -> some View {
        let isFav = track.id.map { favoriteTrackIds.contains($0) } ?? false

        Button {
            toggleFavorite(track)
        } label: {
            Label(isFav ? Lang.removeFavorite : Lang.addFavorite,
                  systemImage: isFav ? "heart.slash" : "heart")
        }

        Divider()

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

        let userPlaylists = playlists.filter { !$0.isFavorites }
        if !userPlaylists.isEmpty {
            Divider()
            Menu(Lang.addToPlaylist) {
                ForEach(userPlaylists) { playlist in
                    Button(playlist.name) {
                        if let trackId = track.id, let playlistId = playlist.id {
                            appState.db.addTrackToPlaylist(playlistId: playlistId, trackId: trackId)
                        }
                    }
                }
            }
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

    private func loadFavorites() {
        guard let favId = appState.db.getOrCreateFavorites().id else { return }
        let favTracks = appState.db.getPlaylistTracks(playlistId: favId)
        favoriteTrackIds = Set(favTracks.compactMap(\.id))
    }

    private func loadTracks() {
        tracks = appState.db.getAllTracks(sort: sortMode)
    }

}
