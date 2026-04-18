import SwiftUI

struct ArtistDetailView: View {
    @Environment(WatchSessionManager.self) var session
    let artist: WatchArtist
    @State private var albums: [WatchAlbum] = []
    @State private var isLoading = true

    var body: some View {
        List {
            Section {
                Text(artist.name)
                    .font(.headline)
                    .lineLimit(2)
                    .listRowBackground(Color.clear)
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if albums.isEmpty {
                Text(Lang.noResults)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(albums) { album in
                    NavigationLink(value: album) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(album.name)
                                .font(.caption)
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                if let year = album.year {
                                    Text(String(year))
                                }
                                Text(Lang.trackCount(album.trackCount))
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .onAppear { loadAlbums() }
    }

    private func loadAlbums() {
        session.requestArtistAlbums(artistName: artist.name) { result in
            albums = result
            isLoading = false
        }
    }
}
