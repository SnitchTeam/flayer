import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Binding var query: String
    var onSelectAlbum: ((Album) -> Void)? = nil
    var onSelectArtist: ((Artist) -> Void)? = nil
    @State private var tracks: [Track] = []
    @State private var albums: [Album] = []
    @State private var artists: [Artist] = []
    @State private var selectedAlbum: Album?
    @State private var selectedArtist: Artist?
    @State private var recentCovers: [String: String] = [:]
    @State private var lastValidSearch: String = ""
    @State private var searchTask: Task<Void, Never>?

    private var isIPad: Bool { sizeClass == .regular }

    private var columns: [GridItem] {
        let count = isIPad ? 6 : 3
        return Array(repeating: GridItem(.flexible(), spacing: isIPad ? 24 : 12), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if query.isEmpty {
                let recents = appState.settings.recentSearches
                if recents.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(.gray.opacity(0.2))
                        Text(Lang.typeToSearch)
                            .font(.caption)
                            .foregroundStyle(.gray.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(Lang.recentSearches)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.gray.opacity(0.5))
                            Spacer()
                            Button {
                                appState.settings.recentSearches = []
                                appState.saveSettings()
                            } label: {
                                Text(Lang.clear)
                                    .font(.caption2)
                                    .foregroundStyle(.gray.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }

                        LazyVGrid(columns: columns, spacing: isIPad ? 28 : 16) {
                            ForEach(recents, id: \.self) { term in
                                recentSearchCard(term: term)
                            }
                        }
                    }
                }
            } else if query.count < 2 {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.gray.opacity(0.2))
                    Text(Lang.typeToSearch)
                        .font(.caption)
                        .foregroundStyle(.gray.opacity(0.4))
                }
                .frame(maxWidth: .infinity, minHeight: 300)
            } else if artists.isEmpty && albums.isEmpty && tracks.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.gray.opacity(0.2))
                    Text(Lang.noResults)
                        .font(.caption)
                        .foregroundStyle(.gray.opacity(0.4))
                }
                .frame(maxWidth: .infinity, minHeight: 300)
            } else {
                // Artists
                if !artists.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Lang.artists)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.gray.opacity(0.5))

                        LazyVGrid(columns: columns, spacing: isIPad ? 28 : 16) {
                            ForEach(artists) { artist in
                                ArtistCardView(artist: artist) {
                                    selectedArtist = artist
                                }
                            }
                        }
                    }
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
                }

                // Albums
                if !albums.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Lang.albums)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.gray.opacity(0.5))

                        LazyVGrid(columns: columns, spacing: isIPad ? 28 : 16) {
                            ForEach(albums) { album in
                                AlbumCardView(album: album, action: {
                                    selectedAlbum = album
                                }) {
                                    EmptyView()
                                }
                            }
                        }
                    }
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
                }

                // Tracks
                if !tracks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Lang.tracks)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.gray.opacity(0.5))

                        VStack(spacing: 0) {
                            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                                Button {
                                    appState.player.playTrack(track)
                                } label: {
                                    HStack(spacing: 12) {
                                        CoverArtView(path: track.coverArtPath, size: 32)

                                        VStack(alignment: .leading, spacing: 1) {
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

                                        if isIPad {
                                            Text(track.album)
                                                .font(.caption2)
                                                .foregroundStyle(.gray.opacity(0.4))
                                                .lineLimit(1)
                                                .frame(maxWidth: 200, alignment: .trailing)
                                        }

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

                                if index < tracks.count - 1 {
                                    Divider()
                                        .background(Color.white.opacity(0.04))
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .glassCard()
                    }
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
                }
            }
        }
        .onChange(of: query) { _, newQuery in
            performSearch(newQuery)
        }
        .onChange(of: selectedAlbum) { _, newAlbum in
            if let album = newAlbum {
                if let callback = onSelectAlbum {
                    callback(album)
                } else {
                    appState.modalAlbum = album
                }
                selectedAlbum = nil
            }
        }
        .onChange(of: selectedArtist) { _, newArtist in
            if let artist = newArtist {
                if let callback = onSelectArtist {
                    callback(artist)
                } else {
                    appState.modalArtist = artist
                }
                selectedArtist = nil
            }
        }
        .onAppear { loadRecentCovers() }
        .onChange(of: appState.libraryVersion) { _, _ in
            if !query.isEmpty { performSearch(query) }
            loadRecentCovers()
        }
        .onDisappear {
            searchTask?.cancel()
            searchTask = nil
            if !lastValidSearch.isEmpty {
                saveRecentSearch(lastValidSearch)
                lastValidSearch = ""
            }
        }
    }

    private func performSearch(_ q: String) {
        searchTask?.cancel()
        guard q.count >= 2 else {
            tracks = []
            albums = []
            artists = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            let results = appState.db.search(query: q)
            guard !Task.isCancelled else { return }
            tracks = results.tracks
            albums = results.albums
            artists = results.artists
            if !tracks.isEmpty || !albums.isEmpty || !artists.isEmpty {
                lastValidSearch = q
            }
        }
    }

    private func saveRecentSearch(_ query: String) {
        var recents = appState.settings.recentSearches
        recents.removeAll { $0.lowercased() == query.lowercased() }
        recents.insert(query, at: 0)
        if recents.count > 6 { recents = Array(recents.prefix(6)) }
        appState.settings.recentSearches = recents
        appState.saveSettings()
    }

    private func recentSearchCard(term: String) -> some View {
        Button {
            query = term
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    if let path = recentCovers[term],
                       let image = loadImage(contentsOfFile: path) {
                        Image(platformImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color(white: 0.1)
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 22))
                            .foregroundStyle(.gray.opacity(0.3))
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(term)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private func loadRecentCovers() {
        for term in appState.settings.recentSearches {
            let results = appState.db.search(query: term)
            if let album = results.albums.first, let cover = album.coverArtPath {
                recentCovers[term] = cover
            } else if let artist = results.artists.first, let cover = artist.coverArtPath {
                recentCovers[term] = cover
            } else if let track = results.tracks.first, let cover = track.coverArtPath {
                recentCovers[term] = cover
            }
        }
    }
}
