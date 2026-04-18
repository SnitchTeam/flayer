import SwiftUI

struct AlbumGridView: View {
    @Environment(AppState.self) private var appState
    @State private var albums: [Album] = []
    @State private var temporalGroups: [TemporalGroup<Album>] = []
    @State private var yearGroups: [(year: String, albums: [Album])] = []
    @State private var selectedAlbum: Album?

    private var columns: [GridItem] {
        let count: Int
        switch appState.settings.gridSize {
        case "compact": count = 8
        case "large": count = 4
        default: count = 6
        }
        return Array(repeating: GridItem(.flexible(), spacing: 24), count: count)
    }
    private var sorts: [(String, String)] {
        [
            ("date_added", Lang.recent),
            ("alphabetical", Lang.alphabetical),
            ("year", Lang.year),
        ]
    }

    private var sortOrder: String {
        appState.settings.albumSort
    }

    private var grouped: [(letter: String, albums: [Album])] {
        guard sortOrder == "alphabetical" else { return [] }
        var groups: [String: [Album]] = [:]
        for album in albums {
            let first = String(album.name.prefix(1)).uppercased()
            let letter = first.rangeOfCharacter(from: .letters) != nil ? first : "#"
            groups[letter, default: []].append(album)
        }
        return groups.keys.sorted { a, b in
            if a == "#" { return false }
            if b == "#" { return true }
            return a < b
        }.map { (letter: $0, albums: groups[$0]!) }
    }

    private var showSidebar: Bool {
        appState.settings.showLetterNav && !appState.sidebarLetters.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            titleHeader
            if albums.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "square.stack")
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
            ZStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            if sortOrder == "alphabetical" {
                                ForEach(grouped, id: \.letter) { group in
                                    Section {
                                        albumGrid(group.albums)
                                    } header: {
                                        sectionHeader(group.letter)
                                    }
                                }
                            } else if sortOrder == "date_added" {
                                ForEach(temporalGroups) { group in
                                    Section {
                                        albumGrid(group.items)
                                    } header: {
                                        sectionHeader(group.label, scrollId: group.shortLabel)
                                    }
                                }
                            } else if sortOrder == "year" {
                                ForEach(yearGroups, id: \.year) { group in
                                    Section {
                                        albumGrid(group.albums)
                                    } header: {
                                        sectionHeader(group.year)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, appState.settings.navPosition == "top" ? 40 : 120)
                    }
                    .onChange(of: appState.scrollToLetter) { _, letter in
                        if let letter, !letter.isEmpty {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("letter-\(letter)", anchor: .top)
                            }
                            appState.scrollToLetter = nil
                        }
                    }
                }

                if showSidebar {
                    HStack {
                        Spacer()
                        LetterSidebar(letters: appState.sidebarLetters) { letter in
                            appState.scrollToLetter = letter
                        }
                    }
                }
            }
            } // else
        }
        .onAppear {
            loadAlbums()
            updateSidebarLetters()
        }
        .onChange(of: appState.libraryVersion) { _, _ in
            loadAlbums()
            updateSidebarLetters()
        }
        .onChange(of: sortOrder) { _, _ in
            updateSidebarLetters()
        }
        .onChange(of: selectedAlbum) { _, newAlbum in
            if let album = newAlbum {
                appState.modalAlbum = album
                selectedAlbum = nil
            }
        }
    }

    private var titleHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(Lang.albums)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text("\(albums.count)")
                .font(.caption)
                .foregroundStyle(.gray.opacity(0.4))

            Spacer()

            SortMenuButton(
                options: sorts.map { (key: $0.0, label: $0.1) },
                selected: sortOrder
            ) { key in
                appState.settings.albumSort = key
                appState.saveSettings()
                loadAlbums()
                updateSidebarLetters()
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 12)
    }

    private func albumGrid(_ albumList: [Album]) -> some View {
        LazyVGrid(columns: columns, spacing: 28) {
            ForEach(albumList) { album in
                AlbumCardView(album: album) {
                    selectedAlbum = album
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.trailing, showSidebar ? 28 : 0)
        .padding(.bottom, 20)
    }

    private func sectionHeader(_ label: String, scrollId: String? = nil) -> some View {
        Text(label)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.gray.opacity(0.4))
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .background(Color.black)
            .id("letter-\(scrollId ?? label)")
    }

    private func updateSidebarLetters() {
        switch sortOrder {
        case "alphabetical":
            appState.sidebarLetters = grouped.map(\.letter)
        case "date_added":
            appState.sidebarLetters = temporalGroups.map(\.shortLabel)
        case "year":
            appState.sidebarLetters = yearGroups.map(\.year)
        default:
            appState.sidebarLetters = []
        }
    }

    private func loadAlbums() {
        if sortOrder == "date_added" {
            let dated = appState.db.getAllAlbumsWithDate()
            temporalGroups = groupByTimePeriod(dated)
            albums = dated.map(\.0)
            yearGroups = []
        } else if sortOrder == "year" {
            albums = appState.db.getAllAlbums(sort: "year")
            temporalGroups = []
            var groups: [(year: String, albums: [Album])] = []
            var lastYear = ""
            for album in albums {
                let y = album.year.map(String.init) ?? "?"
                if y == lastYear, !groups.isEmpty {
                    groups[groups.count - 1].albums.append(album)
                } else {
                    groups.append((year: y, albums: [album]))
                    lastYear = y
                }
            }
            yearGroups = groups
        } else {
            albums = appState.db.getAllAlbums(sort: sortOrder)
            temporalGroups = []
            yearGroups = []
        }
    }
}

struct AlbumCardView: View {
    @Environment(AppState.self) private var appState
    let album: Album
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                CoverArtView(path: album.coverArtPath, size: nil)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(album.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if appState.settings.showArtistLabel {
                        Text(album.albumArtist)
                            .font(.system(size: 10))
                            .foregroundStyle(.gray.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                guard let albumId = album.id else { return }
                let tracks = appState.db.getAlbumTracks(albumId: albumId)
                appState.player.playAlbum(tracks)
            } label: {
                Label(Lang.playAlbum, systemImage: "play.fill")
            }

            Button {
                guard let albumId = album.id else { return }
                let tracks = appState.db.getAlbumTracks(albumId: albumId)
                appState.player.playAlbum(tracks.shuffled())
            } label: {
                Label(Lang.shuffle, systemImage: "shuffle")
            }

            Divider()

            Button {
                guard let albumId = album.id else { return }
                let tracks = appState.db.getAlbumTracks(albumId: albumId)
                for track in tracks {
                    appState.player.playNext(track)
                }
            } label: {
                Label(Lang.playNext, systemImage: "text.line.first.and.arrowtriangle.forward")
            }

            Button {
                guard let albumId = album.id else { return }
                let tracks = appState.db.getAlbumTracks(albumId: albumId)
                for track in tracks {
                    appState.player.addToQueue(track)
                }
            } label: {
                Label(Lang.addToQueue, systemImage: "text.append")
            }

            Divider()

            Button {
                guard let albumId = album.id else { return }
                let tracks = appState.db.getAlbumTracks(albumId: albumId)
                guard let favId = appState.db.getOrCreateFavorites().id else { return }
                for track in tracks {
                    if let trackId = track.id {
                        appState.db.addTrackToPlaylist(playlistId: favId, trackId: trackId)
                    }
                }
            } label: {
                Label(Lang.addFavorite, systemImage: "heart")
            }

            Button {
                Task {
                    guard let albumId = album.id else { return }
                    let tracks = appState.db.getAlbumTracks(albumId: albumId)
                    for track in tracks {
                        if let id = track.id {
                            appState.db.enqueueEnrichment(trackId: id)
                        }
                    }
                    await appState.enricher?.processQueue()
                    appState.libraryVersion += 1
                }
            } label: {
                Label(Lang.refreshMetadata, systemImage: "arrow.clockwise")
            }
        }
    }
}

struct AlbumModalView: View {
    @Environment(AppState.self) private var appState
    let album: Album
    var onSelectAlbum: (Album) -> Void
    var onDismiss: () -> Void

    @State private var tracks: [Track] = []
    @State private var otherAlbums: [Album] = []
    @State private var playlists: [Playlist] = []
    @State private var favoriteTrackIds: Set<Int64> = []
    @State private var musicBrainzMode: MusicBrainzSheetMode?

    private var isTrackPlaying: (Track) -> Bool {
        { track in
            guard let current = appState.player.currentTrack else { return false }
            return current.id == track.id && appState.player.state == .playing
        }
    }

    private var isTrackCurrent: (Track) -> Bool {
        { track in
            guard let current = appState.player.currentTrack else { return false }
            return current.id == track.id
        }
    }

    var body: some View {
        ZStack {
            ZStack {
                Color.black.opacity(0.85)
                Color.white.opacity(0.04)
            }
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack(alignment: .top, spacing: 20) {
                        CoverArtView(path: album.coverArtPath, size: 140)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(album.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)

                            Text(album.albumArtist)
                                .font(.callout)
                                .foregroundStyle(.gray)

                            HStack(spacing: 6) {
                                if let year = album.year {
                                    Text(String(year))
                                        .font(.caption)
                                        .foregroundStyle(.gray.opacity(0.5))
                                }
                                FormatBadgesView(formats: Set(tracks.map(\.format).filter { !$0.isEmpty }))
                            }

                            if !tracks.isEmpty {
                                HStack(spacing: 6) {
                                    Text(Lang.trackCount(tracks.count))
                                    Text("·")
                                    Text(formatTotalDuration(tracks.reduce(0) { $0 + $1.duration }))
                                    if let bitrate = albumBitrate {
                                        Text("·")
                                        Text(bitrate)
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(.gray.opacity(0.4))
                            }

                            Spacer()

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
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                Button {
                                    appState.player.playAlbum(tracks.shuffled())
                                } label: {
                                    Image(systemName: "shuffle")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                        .frame(width: 30, height: 30)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Button {
                                    musicBrainzMode = .artwork
                                } label: {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.gray)
                                        .frame(width: 26, height: 26)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help(Lang.changeArtwork)

                                Button {
                                    musicBrainzMode = .metadata
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.gray)
                                        .frame(width: 26, height: 26)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help(Lang.refreshMetadata)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)

                    // Track list
                    VStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
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
                                .padding(.vertical, 7)
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
                .padding(.vertical, 24)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.gray)
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(14)
                }
                Spacer()
            }
        }
        .onAppear {
            guard let albumId = album.id else { return }
            tracks = appState.db.getAlbumTracks(albumId: albumId)
            otherAlbums = appState.db.getArtistAlbums(artistName: album.albumArtist).filter { $0.id != album.id }
            playlists = appState.db.getPlaylists()
            loadFavorites()
        }
        .sheet(item: $musicBrainzMode) { mode in
            MusicBrainzSheet(album: album, mode: mode) {
                musicBrainzMode = nil
                if let albumId = album.id {
                    tracks = appState.db.getAlbumTracks(albumId: albumId)
                }
                appState.libraryVersion += 1
            }
            .environment(appState)
            .frame(width: 500, height: 450)
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

    private var albumBitrate: String? {
        guard !tracks.isEmpty else { return nil }
        let totalSize = tracks.reduce(Int64(0)) { $0 + $1.fileSize }
        let totalDuration = tracks.reduce(0.0) { $0 + $1.duration }
        guard totalDuration > 0 else { return nil }
        let kbps = Int(Double(totalSize) * 8.0 / totalDuration / 1000.0)
        if kbps >= 1000 {
            return String(format: "%.1f Mbps", Double(kbps) / 1000.0)
        }
        return "\(kbps) kbps"
    }

    private func formatTotalDuration(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return Lang.totalDuration(hours: h, minutes: m)
    }
}
