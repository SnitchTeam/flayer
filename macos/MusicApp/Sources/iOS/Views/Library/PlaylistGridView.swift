import SwiftUI

struct PlaylistGridView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var playlists: [Playlist] = []
    @State private var playlistCovers: [Int64: String] = [:]
    @State private var selectedPlaylist: Playlist?
    @State private var playlistTracks: [Track] = []
    @State private var showCreateSheet = false
    @State private var newPlaylistName = ""
    @State private var playlistToDelete: Playlist?
    @State private var contextMenuTrackIndex: Int?
    @State private var contextMenuPlaylistId: Int64?

    private var isIPad: Bool { sizeClass == .regular }

    private var columns: [GridItem] {
        let count = isIPad ? 6 : 3
        return Array(repeating: GridItem(.flexible(), spacing: isIPad ? 24 : 12), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let playlist = selectedPlaylist {
                playlistDetail(playlist)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else {
                // Header
                HStack(alignment: .firstTextBaseline) {
                    Text(Lang.playlists)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("\(playlists.count)")
                        .font(.caption)
                        .foregroundStyle(.gray.opacity(0.4))

                    Spacer()

                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.gray)
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                playlistGrid
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedPlaylist?.id)
        .onAppear { loadPlaylists(); checkDeepLink() }
        .onChange(of: appState.libraryVersion) { _, _ in loadPlaylists() }
        .onChange(of: appState.deepLinkPlaylistId) { _, _ in checkDeepLink() }
        .alert(Lang.newPlaylist, isPresented: $showCreateSheet) {
            TextField(Lang.name, text: $newPlaylistName)
            Button(Lang.create) {
                let trimmed = newPlaylistName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty,
                   !playlists.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
                    _ = appState.db.createPlaylist(name: trimmed)
                    loadPlaylists()
                }
                newPlaylistName = ""
            }
            Button(Lang.cancel, role: .cancel) {
                newPlaylistName = ""
            }
        }
        .alert(Lang.delete, isPresented: Binding(
            get: { playlistToDelete != nil },
            set: { if !$0 { playlistToDelete = nil } }
        )) {
            Button(Lang.cancel, role: .cancel) { playlistToDelete = nil }
            Button(Lang.delete, role: .destructive) {
                if let id = playlistToDelete?.id {
                    appState.db.deletePlaylist(id: id)
                    loadPlaylists()
                }
                playlistToDelete = nil
            }
        } message: {
            if let name = playlistToDelete?.name {
                Text(name)
            }
        }
    }

    private var systemPlaylists: [Playlist] {
        playlists.filter { $0.isFavorites }
    }

    private var userPlaylists: [Playlist] {
        playlists.filter { !$0.isFavorites }
    }

    private var playlistGrid: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !systemPlaylists.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(Lang.librarySection)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.gray.opacity(0.5))

                    LazyVGrid(columns: columns, spacing: isIPad ? 28 : 16) {
                        ForEach(systemPlaylists) { playlist in
                            PlaylistCardView(
                                playlist: playlist,
                                coverPath: playlist.id.flatMap { playlistCovers[$0] }
                            ) {
                                guard let id = playlist.id else { return }
                                let tracks = appState.db.getPlaylistTracks(playlistId: id)
                                playlistTracks = tracks
                                selectedPlaylist = playlist
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(Lang.myPlaylists)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.gray.opacity(0.5))

                if userPlaylists.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 32))
                            .foregroundStyle(.gray.opacity(0.2))
                        Text(Lang.noPlaylist)
                            .font(.caption)
                            .foregroundStyle(.gray.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    LazyVGrid(columns: columns, spacing: isIPad ? 28 : 16) {
                        ForEach(userPlaylists) { playlist in
                            PlaylistCardView(
                                playlist: playlist,
                                coverPath: playlist.id.flatMap { playlistCovers[$0] }
                            ) {
                                guard let id = playlist.id else { return }
                                let tracks = appState.db.getPlaylistTracks(playlistId: id)
                                playlistTracks = tracks
                                selectedPlaylist = playlist
                            }
                            .glassContextMenu(isPresented: Binding(
                                get: { contextMenuPlaylistId == playlist.id },
                                set: { if $0 { contextMenuPlaylistId = playlist.id } else { contextMenuPlaylistId = nil } }
                            ), items: !playlist.isFavorites ? [
                                GlassMenuItem(label: Lang.delete, icon: "trash", isDestructive: true) {
                                    playlistToDelete = playlist
                                }
                            ] : [])
                        }
                    }
                }
            }
        }
        .overlay {
            GlassContextMenuOverlay(isPresented: Binding(
                get: { contextMenuPlaylistId != nil },
                set: { if !$0 { contextMenuPlaylistId = nil } }
            ), items: contextMenuPlaylistId.flatMap { pid in
                guard let playlist = userPlaylists.first(where: { $0.id == pid }), !playlist.isFavorites else { return nil }
                return [GlassMenuItem(label: Lang.delete, icon: "trash", isDestructive: true) {
                    playlistToDelete = playlist
                }]
            } ?? [])
        }
    }

    @ViewBuilder
    private func playlistDetail(_ playlist: Playlist) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                selectedPlaylist = nil
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                    Text(Lang.playlists)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.gray)
            }
            .buttonStyle(.plain)

            HStack(alignment: .firstTextBaseline) {
                Text(playlist.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text(Lang.trackCount(playlistTracks.count))
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.4))
            }

            if playlistTracks.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .font(.system(size: 32))
                        .foregroundStyle(.gray.opacity(0.2))
                    Text(Lang.emptyPlaylist)
                        .font(.caption)
                        .foregroundStyle(.gray.opacity(0.4))
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(playlistTracks.enumerated()), id: \.element.id) { index, track in
                        Button {
                            appState.player.playAlbum(playlistTracks, startIndex: index)
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption2)
                                    .foregroundStyle(.gray.opacity(0.4))
                                    .frame(width: 20, alignment: .trailing)

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

                                Text(track.duration.formattedDuration)
                                    .font(.caption2)
                                    .foregroundStyle(.gray.opacity(0.4))
                                    .fontDesign(.monospaced)
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .glassContextMenu(isPresented: Binding(
                            get: { contextMenuTrackIndex == index },
                            set: { if $0 { contextMenuTrackIndex = index } else { contextMenuTrackIndex = nil } }
                        ), items: [
                            GlassMenuItem(label: Lang.removeFromPlaylist, icon: "minus.circle", isDestructive: true) {
                                if let trackId = track.id, let playlistId = playlist.id {
                                    appState.db.removeTrackFromPlaylist(playlistId: playlistId, trackId: trackId)
                                    playlistTracks = appState.db.getPlaylistTracks(playlistId: playlistId)
                                }
                            }
                        ])

                        if index < playlistTracks.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.04))
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .glassCard()
                .overlay {
                    GlassContextMenuOverlay(isPresented: Binding(
                        get: { contextMenuTrackIndex != nil },
                        set: { if !$0 { contextMenuTrackIndex = nil } }
                    ), items: contextMenuTrackIndex.flatMap { idx in
                        guard idx < playlistTracks.count else { return nil }
                        let track = playlistTracks[idx]
                        return [GlassMenuItem(label: Lang.removeFromPlaylist, icon: "minus.circle", isDestructive: true) {
                            if let trackId = track.id, let playlistId = playlist.id {
                                appState.db.removeTrackFromPlaylist(playlistId: playlistId, trackId: trackId)
                                playlistTracks = appState.db.getPlaylistTracks(playlistId: playlistId)
                            }
                        }]
                    } ?? [])
                }
            }
        }
    }

    private func loadPlaylists() {
        playlists = appState.db.getPlaylists()
        playlistCovers = [:]
        let ids = playlists.compactMap(\.id)
        for id in ids {
            if let cover = appState.db.getPlaylistCover(playlistId: id) {
                playlistCovers[id] = cover
            }
        }
    }

    private func checkDeepLink() {
        guard let playlistId = appState.deepLinkPlaylistId else { return }
        appState.deepLinkPlaylistId = nil
        if let playlist = playlists.first(where: { $0.id == playlistId }) {
            selectedPlaylist = playlist
            playlistTracks = appState.db.getPlaylistTracks(playlistId: playlistId)
        }
    }

}

struct PlaylistCardView: View {
    let playlist: Playlist
    let coverPath: String?
    let action: () -> Void

    private var isFavorites: Bool {
        playlist.isFavorites
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    if let path = coverPath, let image = loadImage(contentsOfFile: path) {
                        Image(platformImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color(white: 0.1)

                        if isFavorites {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(.pink.opacity(0.4))
                        } else {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 22))
                                .foregroundStyle(.gray.opacity(0.3))
                        }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(playlist.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}
