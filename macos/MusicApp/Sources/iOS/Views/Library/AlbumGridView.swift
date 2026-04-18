import SwiftUI

struct AlbumGridView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var albums: [Album] = []
    @State private var temporalGroups: [TemporalGroup<Album>] = []
    @State private var yearGroups: [(year: String, albums: [Album])] = []
    @State private var alphabeticalGroups: [(letter: String, albums: [Album])] = []
    @State private var selectedAlbum: Album?
    @State private var playlists: [Playlist] = []
    @State private var isContextMenuActive = false

    var onSelectAlbum: ((Album) -> Void)? = nil

    private var isIPad: Bool { sizeClass == .regular }

    private var columns: [GridItem] {
        let count = isIPad ? 6 : 3
        return Array(repeating: GridItem(.flexible(), spacing: isIPad ? 24 : 12), count: count)
    }

    private var horizontalPadding: CGFloat { isIPad ? 32 : 16 }

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

    private func buildAlphabeticalGroups(_ albums: [Album]) -> [(letter: String, albums: [Album])] {
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
            ZStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        if albums.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.gray.opacity(0.2))
                                Text(Lang.emptyLibrary)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.gray.opacity(0.5))
                                Text(Lang.emptyLibraryHint)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.gray.opacity(0.3))
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                            .padding(.top, 60)
                        }
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            if sortOrder == "alphabetical" {
                                ForEach(alphabeticalGroups, id: \.letter) { group in
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
        }
        .onAppear {
            loadAlbums()
            updateSidebarLetters()
            playlists = appState.db.getPlaylists()
        }
        .onChange(of: appState.libraryVersion) { _, _ in
            loadAlbums()
            updateSidebarLetters()
            playlists = appState.db.getPlaylists()
        }
        .onChange(of: sortOrder) { _, _ in
            updateSidebarLetters()
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
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, 12)
    }

    private func albumGrid(_ albumList: [Album]) -> some View {
        LazyVGrid(columns: columns, spacing: isIPad ? 28 : 16) {
            ForEach(albumList) { album in
                AlbumCardView(album: album, action: { selectedAlbum = album }, onContextMenu: { active in
                    isContextMenuActive = active
                }) {
                    albumContextMenu(album)
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.trailing, showSidebar ? 28 : 0)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func albumContextMenu(_ album: Album) -> some View {
        Button {
            guard let albumId = album.id else { return }
            let tracks = appState.db.getAlbumTracks(albumId: albumId)
            appState.player.playAlbum(tracks)
        } label: {
            Label(Lang.playAlbum, systemImage: "play.fill")
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

        Divider()

        Button {
            guard let albumId = album.id else { return }
            let tracks = appState.db.getAlbumTracks(albumId: albumId)
            if let playlist = appState.db.createPlaylist(name: album.name) {
                for track in tracks {
                    if let trackId = track.id, let playlistId = playlist.id {
                        appState.db.addTrackToPlaylist(playlistId: playlistId, trackId: trackId)
                    }
                }
                playlists = appState.db.getPlaylists()
            }
        } label: {
            Label(Lang.createPlaylistFromAlbum, systemImage: "music.note.list")
        }

        let userPlaylists = playlists.filter { !$0.isFavorites }
        if !userPlaylists.isEmpty {
            Menu(Lang.addToPlaylist) {
                ForEach(userPlaylists) { playlist in
                    Button(playlist.name) {
                        guard let albumId = album.id else { return }
                        let tracks = appState.db.getAlbumTracks(albumId: albumId)
                        for track in tracks {
                            if let trackId = track.id, let playlistId = playlist.id {
                                appState.db.addTrackToPlaylist(playlistId: playlistId, trackId: trackId)
                            }
                        }
                    }
                }
            }
        }

        Divider()

        Button {
            if let artist = appState.db.getArtistByName(album.albumArtist) {
                appState.modalArtist = artist
            }
        } label: {
            Label(Lang.viewOtherAlbums, systemImage: "person.crop.rectangle.stack")
        }
    }

    private func sectionHeader(_ label: String, scrollId: String? = nil) -> some View {
        Text(label)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.gray.opacity(0.4))
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .background(Color.black)
            .id("letter-\(scrollId ?? label)")
    }

    private func updateSidebarLetters() {
        switch sortOrder {
        case "alphabetical":
            appState.sidebarLetters = alphabeticalGroups.map(\.letter)
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
        } else if sortOrder == "alphabetical" {
            albums = appState.db.getAllAlbums(sort: sortOrder)
            alphabeticalGroups = buildAlphabeticalGroups(albums)
            temporalGroups = []
            yearGroups = []
        } else {
            albums = appState.db.getAllAlbums(sort: sortOrder)
            alphabeticalGroups = []
            temporalGroups = []
            yearGroups = []
        }
    }
}

struct AlbumCardView<M: View>: View {
    @Environment(AppState.self) private var appState
    let album: Album
    let action: () -> Void
    var onContextMenu: ((Bool) -> Void)? = nil
    @ViewBuilder let menu: () -> M

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
            menu()
        } preview: {
            CoverArtView(path: album.coverArtPath, size: nil)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: 200)
                .onAppear { onContextMenu?(true) }
                .onDisappear { onContextMenu?(false) }
        }
    }
}

struct AlbumModalView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var sizeClass
    let album: Album
    var onSelectAlbum: (Album) -> Void
    var onDismiss: () -> Void

    @State private var tracks: [Track] = []
    @State private var otherAlbums: [Album] = []
    @State private var playlists: [Playlist] = []
    @State private var favoriteTrackIds: Set<Int64> = []
    @State private var isAlbumFavorite: Bool = false
    @State private var dragOffset: CGFloat = 0
    @State private var musicBrainzSheetMode: MusicBrainzSheetMode?
    @State private var showCoverOptions = false

    private var isIPad: Bool { sizeClass == .regular }

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
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(.white.opacity(0.25))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height > 0 {
                                    dragOffset = value.translation.height
                                }
                            }
                            .onEnded { value in
                                if value.translation.height > 100 || value.predictedEndTranslation.height > 300 {
                                    onDismiss()
                                }
                                withAnimation(.spring(duration: 0.6, bounce: 0.18)) { dragOffset = 0 }
                            }
                    )

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        if isIPad {
                            HStack(alignment: .top, spacing: 20) {
                                CoverArtView(path: album.coverArtPath, size: 140)
                                    .contentShape(Rectangle())
                                    .onLongPressGesture { showCoverOptions = true }
                                albumHeaderInfo
                            }
                            .padding(.horizontal, 24)
                        } else {
                            VStack(spacing: 16) {
                                CoverArtView(path: album.coverArtPath, size: 200)
                                    .contentShape(Rectangle())
                                    .onLongPressGesture { showCoverOptions = true }
                                albumHeaderInfo
                            }
                            .padding(.horizontal, 24)
                        }

                        // Action bar: play + shuffle left, heart right
                        albumActionBar
                            .padding(.horizontal, 24)

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
                                        let userPlaylists = playlists.filter { !$0.isFavorites }
                                        if !userPlaylists.isEmpty {
                                            Divider()
                                            ForEach(userPlaylists) { playlist in
                                                Button {
                                                    if let trackId = track.id, let playlistId = playlist.id {
                                                        appState.db.addTrackToPlaylist(playlistId: playlistId, trackId: trackId)
                                                    }
                                                } label: {
                                                    Label(playlist.name, systemImage: "music.note.list")
                                                }
                                            }
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
                }
            }
            .blur(radius: musicBrainzSheetMode == .artwork ? 20 : 0)
            .allowsHitTesting(musicBrainzSheetMode != .artwork)

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
            .opacity(musicBrainzSheetMode == .artwork ? 0 : 1)

            if musicBrainzSheetMode == .artwork {
                Color.black.opacity(0.4)
                ArtworkPickerOverlay(album: album) {
                    musicBrainzSheetMode = nil
                    appState.libraryVersion += 1
                }
                .environment(appState)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: musicBrainzSheetMode == .artwork)
        .offset(y: dragOffset)
        .onAppear {
            guard let albumId = album.id else { return }
            tracks = appState.db.getAlbumTracks(albumId: albumId)
            otherAlbums = appState.db.getArtistAlbums(artistName: album.albumArtist).filter { $0.id != album.id }
            playlists = appState.db.getPlaylists()
            loadFavorites()
        }
        .sheet(isPresented: Binding(
            get: { musicBrainzSheetMode == .metadata },
            set: { if !$0 { musicBrainzSheetMode = nil } }
        )) {
            MusicBrainzSheet(album: album, mode: .metadata) {
                musicBrainzSheetMode = nil
                appState.libraryVersion += 1
            }
            .environment(appState)
        }
        .confirmationDialog("", isPresented: $showCoverOptions) {
            Button(Lang.changeArtwork) { musicBrainzSheetMode = .artwork }
            Button(Lang.updateMetadata) { musicBrainzSheetMode = .metadata }
            Button(Lang.cancel, role: .cancel) {}
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
        let trackIds = Set(tracks.compactMap(\.id))
        isAlbumFavorite = !trackIds.isEmpty && trackIds.isSubset(of: favoriteTrackIds)
    }

    private func toggleAlbumFavorite() {
        guard let favId = appState.db.getOrCreateFavorites().id else { return }
        if isAlbumFavorite {
            for track in tracks {
                if let trackId = track.id {
                    appState.db.removeTrackFromPlaylist(playlistId: favId, trackId: trackId)
                    favoriteTrackIds.remove(trackId)
                }
            }
        } else {
            for track in tracks {
                if let trackId = track.id, !favoriteTrackIds.contains(trackId) {
                    appState.db.addTrackToPlaylist(playlistId: favId, trackId: trackId)
                    favoriteTrackIds.insert(trackId)
                }
            }
        }
        isAlbumFavorite.toggle()
    }

    @ViewBuilder
    private var albumHeaderInfo: some View {
        VStack(alignment: isIPad ? .leading : .center, spacing: 6) {
            Text(album.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(isIPad ? .leading : .center)

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
                    Text("\u{b7}")
                    Text(formatTotalDuration(tracks.reduce(0) { $0 + $1.duration }))
                    if let bitrate = albumBitrate {
                        Text("\u{b7}")
                        Text(bitrate)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.gray.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, alignment: isIPad ? .leading : .center)
    }

    @ViewBuilder
    private var albumActionBar: some View {
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
