import SwiftUI

struct ArtistGridView: View {
    @Environment(AppState.self) private var appState
    @State private var artists: [Artist] = []
    @State private var temporalGroups: [TemporalGroup<Artist>] = []
    @State private var selectedArtist: Artist?
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

    private var sortMode: String {
        appState.settings.artistSort
    }

    private var grouped: [(letter: String, artists: [Artist])] {
        groupByLetter(artists)
    }

    private var showSidebar: Bool {
        appState.settings.showLetterNav && !appState.sidebarLetters.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            titleHeader
            if artists.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "person.2")
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
                        if sortMode == "az" || sortMode == "recent" {
                            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                                if sortMode == "az" {
                                    ForEach(grouped, id: \.letter) { group in
                                        Section {
                                            LazyVGrid(columns: columns, spacing: 28) {
                                                ForEach(group.artists) { artist in
                                                    ArtistCardView(artist: artist) {
                                                        selectedArtist = artist
                                                    }
                                                }
                                            }
                                            .padding(.horizontal, 32)
                                            .padding(.trailing, showSidebar ? 28 : 0)
                                            .padding(.bottom, 20)
                                        } header: {
                                            sectionHeader(group.letter)
                                        }
                                    }
                                } else {
                                    ForEach(temporalGroups) { group in
                                        Section {
                                            LazyVGrid(columns: columns, spacing: 28) {
                                                ForEach(group.items) { artist in
                                                    ArtistCardView(artist: artist) {
                                                        selectedArtist = artist
                                                    }
                                                }
                                            }
                                            .padding(.horizontal, 32)
                                            .padding(.trailing, showSidebar ? 28 : 0)
                                            .padding(.bottom, 20)
                                        } header: {
                                            sectionHeader(group.label, scrollId: group.shortLabel)
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, appState.settings.navPosition == "top" ? 40 : 120)
                        } else {
                            LazyVGrid(columns: columns, spacing: 28) {
                                ForEach(artists) { artist in
                                    ArtistCardView(artist: artist) {
                                        selectedArtist = artist
                                    }
                                }
                            }
                            .padding(.horizontal, 32)
                            .padding(.trailing, showSidebar ? 28 : 0)
                            .padding(.top, 4)
                            .padding(.bottom, appState.settings.navPosition == "top" ? 40 : 120)
                        }
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
            loadArtists()
            updateSidebarLetters()
        }
        .onChange(of: appState.libraryVersion) { _, _ in
            loadArtists()
            updateSidebarLetters()
        }
        .onChange(of: sortMode) { _, _ in
            updateSidebarLetters()
        }
        .onChange(of: selectedArtist) { _, newArtist in
            if let artist = newArtist {
                appState.modalArtist = artist
                selectedArtist = nil
            }
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
            Text(Lang.artists)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text("\(artists.count)")
                .font(.caption)
                .foregroundStyle(.gray.opacity(0.4))

            Spacer()

            SortMenuButton(
                options: [
                    (key: "az", label: Lang.alphabetical),
                    (key: "recent", label: Lang.recent),
                ],
                selected: sortMode
            ) { key in
                appState.settings.artistSort = key
                appState.saveSettings()
                loadArtists()
                updateSidebarLetters()
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 12)
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
        switch sortMode {
        case "az":
            appState.sidebarLetters = grouped.map(\.letter)
        case "recent":
            appState.sidebarLetters = temporalGroups.map(\.shortLabel)
        default:
            appState.sidebarLetters = []
        }
    }

    private func loadArtists() {
        if sortMode == "recent" {
            let dated = appState.db.getAllArtistsWithDate()
            temporalGroups = groupByTimePeriod(dated)
            artists = dated.map(\.0)
        } else {
            artists = appState.db.getAllArtists(sort: "az")
            temporalGroups = []
        }
    }

    private func groupByLetter(_ artists: [Artist]) -> [(letter: String, artists: [Artist])] {
        var groups: [String: [Artist]] = [:]
        for artist in artists {
            let first = String(artist.name.prefix(1)).uppercased()
            let letter = first.rangeOfCharacter(from: .letters) != nil ? first : "#"
            groups[letter, default: []].append(artist)
        }
        return groups.keys.sorted { a, b in
            if a == "#" { return false }
            if b == "#" { return true }
            return a < b
        }.map { (letter: $0, artists: groups[$0]!) }
    }
}

struct ArtistCardView: View {
    @Environment(AppState.self) private var appState
    let artist: Artist
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                CoverArtView(path: artist.coverArtPath, size: nil)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(artist.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                let albums = appState.db.getArtistAlbums(artistName: artist.name)
                var allTracks: [Track] = []
                for album in albums {
                    guard let albumId = album.id else { continue }
                    allTracks.append(contentsOf: appState.db.getAlbumTracks(albumId: albumId))
                }
                if !allTracks.isEmpty {
                    appState.player.playAlbum(allTracks)
                }
            } label: {
                Label(Lang.play, systemImage: "play.fill")
            }

            Button {
                let albums = appState.db.getArtistAlbums(artistName: artist.name)
                var allTracks: [Track] = []
                for album in albums {
                    guard let albumId = album.id else { continue }
                    allTracks.append(contentsOf: appState.db.getAlbumTracks(albumId: albumId))
                }
                if !allTracks.isEmpty {
                    appState.player.playAlbum(allTracks.shuffled())
                }
            } label: {
                Label(Lang.shuffle, systemImage: "shuffle")
            }
        }
    }
}

// MARK: - Letter Sidebar

struct LetterSidebar: View {
    let letters: [String]
    let onSelect: (String) -> Void

    @State private var hoveredLetter: String?

    private var isCompact: Bool {
        letters.allSatisfy { $0.count <= 2 }
    }

    var body: some View {
        VStack(spacing: isCompact ? 2 : 4) {
            ForEach(letters, id: \.self) { letter in
                Text(letter)
                    .font(.system(size: isCompact ? 10 : 9, weight: hoveredLetter == letter ? .bold : .medium))
                    .foregroundStyle(hoveredLetter == letter ? .white : .gray.opacity(0.5))
                    .frame(height: 14)
                    .fixedSize()
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(letter) }
                    .onHover { isHovered in
                        if isHovered {
                            hoveredLetter = letter
                        } else if hoveredLetter == letter {
                            hoveredLetter = nil
                        }
                    }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
    }
}

// MARK: - Artist Modal

struct ArtistModalView: View {
    @Environment(AppState.self) private var appState
    let artist: Artist
    var onSelectAlbum: (Album) -> Void
    var onDismiss: () -> Void

    @State private var albums: [Album] = []
    @State private var albumFormats: [Int64: Set<String>] = [:]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 4)

    var body: some View {
        ZStack {
            ZStack {
                Color.black.opacity(0.85)
                Color.white.opacity(0.04)
            }
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    HStack(alignment: .center, spacing: 20) {
                        CoverArtView(path: artist.coverArtPath, size: 120)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(artist.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)

                            Text(Lang.albumCount(albums.count))
                                .font(.caption)
                                .foregroundStyle(.gray.opacity(0.5))

                            Spacer()

                            Button {
                                var allTracks: [Track] = []
                                for album in albums {
                                    guard let albumId = album.id else { continue }
                                    let tracks = appState.db.getAlbumTracks(albumId: albumId)
                                    allTracks.append(contentsOf: tracks)
                                }
                                if !allTracks.isEmpty {
                                    appState.player.playAlbum(allTracks)
                                }
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
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(Lang.discography)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.gray.opacity(0.5))
                            .padding(.horizontal, 24)

                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(albums) { album in
                                Button {
                                    onSelectAlbum(album)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        CoverArtView(path: album.coverArtPath, size: nil)
                                            .aspectRatio(1, contentMode: .fit)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Text(album.name)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)

                                        HStack(spacing: 4) {
                                            if let year = album.year {
                                                Text(String(year))
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.gray.opacity(0.5))
                                            }
                                            if let id = album.id, let formats = albumFormats[id], !formats.isEmpty {
                                                FormatBadgesView(formats: formats)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.vertical, 24)
            }

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
            albums = appState.db.getArtistAlbums(artistName: artist.name)
            let ids = albums.compactMap(\.id)
            albumFormats = appState.db.getAlbumsFormats(albumIds: ids)
        }
    }
}
