import SwiftUI

struct LibraryView: View {
    @Environment(WatchSessionManager.self) var session
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            List {
                Picker("", selection: $selectedTab) {
                    Text(Lang.albums).tag(0)
                    Text(Lang.artists).tag(1)
                    Text(Lang.playlists).tag(2)
                }
                .listRowBackground(Color.clear)

                switch selectedTab {
                case 0:
                    albumsList
                case 1:
                    artistsList
                case 2:
                    playlistsList
                default:
                    EmptyView()
                }
            }
            .navigationTitle(Lang.library)
            .navigationDestination(for: WatchAlbum.self) { album in
                AlbumDetailView(album: album)
            }
            .navigationDestination(for: WatchArtist.self) { artist in
                ArtistDetailView(artist: artist)
            }
            .navigationDestination(for: WatchPlaylist.self) { playlist in
                PlaylistDetailView(playlist: playlist)
            }
        }
        .onAppear {
            if session.albums.isEmpty {
                session.requestLibrarySync()
            }
        }
    }

    // MARK: - Albums

    @ViewBuilder
    private var albumsList: some View {
        if session.albums.isEmpty {
            Text(Lang.noResults)
                .foregroundStyle(.secondary)
                .font(.caption)
        } else {
            ForEach(session.albums) { album in
                NavigationLink(value: album) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(album.name)
                            .font(.caption)
                            .lineLimit(1)
                        Text(album.artist)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Artists

    @ViewBuilder
    private var artistsList: some View {
        if session.artists.isEmpty {
            Text(Lang.noResults)
                .foregroundStyle(.secondary)
                .font(.caption)
        } else {
            ForEach(session.artists) { artist in
                NavigationLink(value: artist) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(artist.name)
                            .font(.caption)
                            .lineLimit(1)
                        Text(Lang.albumCount(artist.albumCount))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Playlists

    @ViewBuilder
    private var playlistsList: some View {
        if session.playlists.isEmpty {
            Text(Lang.noPlaylist)
                .foregroundStyle(.secondary)
                .font(.caption)
        } else {
            ForEach(session.playlists) { playlist in
                NavigationLink(value: playlist) {
                    HStack {
                        if playlist.isFavorites {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(playlist.name)
                                .font(.caption)
                                .lineLimit(1)
                            Text(Lang.trackCount(playlist.trackCount))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
