import SwiftUI
import AVKit
import AVFoundation

// MARK: - DockState

enum DockState: Equatable {
    case collapsed
    case player
    case artist(Artist, albumDetail: Album?)
    case album(Album)

    var isExpanded: Bool {
        self != .collapsed
    }

    static func == (lhs: DockState, rhs: DockState) -> Bool {
        switch (lhs, rhs) {
        case (.collapsed, .collapsed), (.player, .player):
            return true
        case let (.artist(a1, d1), .artist(a2, d2)):
            return a1.id == a2.id && d1?.id == d2?.id
        case let (.album(a1), .album(a2)):
            return a1.id == a2.id
        default:
            return false
        }
    }
}

// MARK: - DockView

struct DockView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Binding var currentPage: Page
    @Binding var searchQuery: String
    @Namespace private var tabNamespace

    @Binding var dockState: DockState
    @State private var dragOffset: CGFloat = 0
    @State private var isFavorite = false
    @State private var showPlaylistPicker = false
    @State private var showTrackInfo = false
    @State private var showTrackActions = false
    @State private var showLyrics = false
    @State private var lyricsLines: [LRCLine] = []
    @State private var plainLyrics: String? = nil
    @State private var firstTabCenterX: CGFloat = 30
    @State private var outputIcon: String = "speaker.fill"
    @State private var outputName: String = "iPhone"

    private var isIPad: Bool { sizeClass == .regular }
    private let dockSpring: Animation = .spring(duration: 0.5, bounce: 0.12)

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let safeBottom = geo.safeAreaInsets.bottom
            let pillHeight: CGFloat = pillContentHeight + safeBottom
            let expandedHeight = geo.size.height + geo.safeAreaInsets.top + safeBottom

            ZStack(alignment: .bottom) {
                // Glass background
                UnevenRoundedRectangle(
                    topLeadingRadius: 28,
                    bottomLeadingRadius: dockState.isExpanded ? 0 : 28,
                    bottomTrailingRadius: dockState.isExpanded ? 0 : 28,
                    topTrailingRadius: 28
                )
                    .fill(.thinMaterial)
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 28,
                            bottomLeadingRadius: dockState.isExpanded ? 0 : 28,
                            bottomTrailingRadius: dockState.isExpanded ? 0 : 28,
                            topTrailingRadius: 28
                        )
                            .fill(.black.opacity(0.2))
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 28,
                            bottomLeadingRadius: dockState.isExpanded ? 0 : 28,
                            bottomTrailingRadius: dockState.isExpanded ? 0 : 28,
                            topTrailingRadius: 28
                        )
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.25), .white.opacity(0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: dockState.isExpanded ? 0 : 0.5
                            )
                    )
                    .shadow(color: .black.opacity(dockState.isExpanded ? 0 : 0.5), radius: 24, y: -10)
                    .frame(height: dockState.isExpanded ? expandedHeight : pillHeight)

                // Content
                ZStack(alignment: .bottom) {
                    // Collapsed content — always rendered, fades out
                    collapsedContent
                        .padding(.bottom, safeBottom)
                        .opacity(dockState.isExpanded ? 0 : 1)
                        .allowsHitTesting(!dockState.isExpanded)

                    // Expanded content — only rendered when needed, slides in/out
                    if dockState.isExpanded {
                        expandedContent
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(height: dockState.isExpanded ? expandedHeight : pillHeight, alignment: .bottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(.container, edges: .bottom)
            .offset(y: dragOffset)
            .gesture(
                dockState.isExpanded ?
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = 400 * (1 - exp(-value.translation.height / 400))
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 || value.predictedEndTranslation.height > 300 {
                            Haptic.medium()
                            withAnimation(dockSpring) { dockState = .collapsed }
                        }
                        withAnimation(.spring(duration: 0.4, bounce: 0.15)) { dragOffset = 0 }
                    }
                : nil
            )
        }
        .animation(dockSpring, value: dockState)
        .onChange(of: dockState) { _, newState in
            if !newState.isExpanded || newState != .player {
                withAnimation(.easeOut(duration: 0.2)) {
                    showLyrics = false
                }
            }
        }
    }

    // MARK: - Pill Content Height

    private var pillContentHeight: CGFloat {
        let hasTrack = appState.player.currentTrack != nil
        return hasTrack ? 94 : 54
    }

    // MARK: - Collapsed Content

    @ViewBuilder
    private var collapsedContent: some View {
        VStack(spacing: 8) {
            if appState.player.currentTrack != nil {
                miniPlayerRow
            }
            navTabsRow
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .coordinateSpace(name: "dockContent")
    }

    // MARK: - Mini Player Row

    @ViewBuilder
    private var miniPlayerRow: some View {
        if let track = appState.player.currentTrack {
            HStack(spacing: 10) {
                CoverArtView(path: track.coverArtPath, size: 40)
                    .padding(.leading, max(0, firstTabCenterX - 30))

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(track.artist)
                            .font(.system(size: 10))
                            .foregroundStyle(.gray)
                            .lineLimit(1)

                        Text("—")
                            .font(.system(size: 8))
                            .foregroundStyle(.gray.opacity(0.3))

                        Text(track.album)
                            .font(.system(size: 9))
                            .foregroundStyle(.gray.opacity(0.4))
                            .lineLimit(1)

                        FormatBadge(format: track.format)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: {
                    Haptic.light()
                    appState.player.togglePlayPause()
                }) {
                    Image(systemName: appState.player.state == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.7))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Lang.playPause)
                .padding(.trailing, 4)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Haptic.medium()
                withAnimation(dockSpring) {
                    dockState = .player
                }
            }
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.height < -30 {
                            withAnimation(dockSpring) {
                                dockState = .player
                            }
                        }
                    }
            )
        }
    }

    // MARK: - Nav Tabs Row

    private var navItems: [(page: Page, icon: String)] {
        var items: [(page: Page, icon: String)] = [
            (.playlists, "music.note.list"),
            (.artists, "person.2"),
            (.albums, "square.stack"),
        ]
        if appState.settings.showTracks {
            items.append((.tracks, "music.note"))
        }
        items.append((.settings, "gearshape"))
        items.append((.search, "magnifyingglass"))
        return items
    }

    @ViewBuilder
    private var navTabsRow: some View {
        HStack(spacing: 0) {
            ForEach(navItems, id: \.page) { item in
                Button {
                    Haptic.light()
                    withAnimation(.spring(duration: 0.45, bounce: 0.15)) {
                        currentPage = item.page
                        if item.page == .search {
                            searchQuery = ""
                        }
                    }
                } label: {
                    Image(systemName: item.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(currentPage == item.page ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background {
                            if currentPage == item.page {
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                            }
                        }
                        .background {
                            if item.page == .playlists {
                                GeometryReader { geo in
                                    Color.clear.onAppear {
                                        firstTabCenterX = geo.frame(in: .named("dockContent")).midX
                                    }
                                    .onChange(of: geo.size) { _, _ in
                                        firstTabCenterX = geo.frame(in: .named("dockContent")).midX
                                    }
                                }
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.page.accessibilityName)
            }
        }
    }

    // MARK: - Thin Progress Bar

    @ViewBuilder
    private var thinProgressBar: some View {
        let player = appState.player
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: geo.size.width * (player.duration > 0 ? player.position / player.duration : 0))
            }
        }
        .frame(height: 2)
        .clipShape(Capsule())
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private var expandedContent: some View {
        switch dockState {
        case .player:
            playerExpandedContent
        case let .artist(artist, albumDetail):
            Group {
                if let album = albumDetail {
                    albumExpandedContent(album: album, backToArtist: artist)
                } else {
                    artistExpandedContent(artist: artist)
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: albumDetail?.id)
        case let .album(album):
            albumExpandedContent(album: album, backToArtist: nil)
        case .collapsed:
            EmptyView()
        }
    }

    // MARK: - Drag Handle

    @ViewBuilder
    private var dragHandle: some View {
        Capsule()
            .fill(.white.opacity(0.25))
            .frame(width: 36, height: 4)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Player Expanded Content

    @ViewBuilder
    private var playerExpandedContent: some View {
        let player = appState.player
        if let track = player.currentTrack {
            GeometryReader { geo in
                let artworkSize = min(geo.size.width - 64, geo.size.height * 0.40)

                if showLyrics {
                    lyricsView(track: track)
                } else {
                VStack(spacing: 0) {
                    dragHandle

                    Spacer(minLength: 8)

                    // Artwork
                    CoverArtView(path: track.coverArtPath, size: artworkSize)
                        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)

                    // "..." menu below artwork, right-aligned
                    HStack {
                        Spacer()
                        Menu {
                            Button {
                                toggleFavorite()
                            } label: {
                                Label(isFavorite ? Lang.removeFavorite : Lang.addFavorite,
                                      systemImage: isFavorite ? "heart.slash" : "heart")
                            }

                            Button {
                                showPlaylistPicker = true
                            } label: {
                                Label(Lang.addToPlaylist, systemImage: "music.note.list")
                            }

                            Button {
                                showTrackActions = true
                            } label: {
                                Label(Lang.queue, systemImage: "list.bullet")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                                .frame(width: 36, height: 36)
                        }
                        .accessibilityLabel(Lang.moreOptions)
                    }
                    .padding(.horizontal, 32)

                    Spacer(minLength: 8)

                    // Track info
                    VStack(spacing: 6) {
                        MarqueeText(text: track.title, font: .system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 32)
                            .onTapGesture {
                                loadLyrics(for: track)
                                withAnimation(.easeInOut(duration: 0.3)) { showLyrics = true }
                            }

                        Button {
                            if let artistId = track.artistId,
                               let artist = appState.db.getArtist(id: artistId) {
                                withAnimation(dockSpring) {
                                    dockState = .artist(artist, albumDetail: nil)
                                }
                            }
                        } label: {
                            Text(track.artist)
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.65))
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 6) {
                            Button {
                                if let albumId = track.albumId,
                                   let album = appState.db.getAlbum(id: albumId) {
                                    withAnimation(dockSpring) {
                                        dockState = .album(album)
                                    }
                                }
                            } label: {
                                Text(track.album)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.35))
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)

                            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showTrackInfo.toggle() } }) {
                                FormatBadge(format: track.format)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Track info popup — overlay so it doesn't shift content
                    ZStack {
                        Color.clear.frame(height: 0)
                        if showTrackInfo {
                            VStack(spacing: 4) {
                                trackInfoRow(Lang.format, value: track.format.uppercased())
                                trackInfoRow(Lang.bitrate, value: trackBitrate(track))
                                trackInfoRow(Lang.sampleRate, value: "\(track.sampleRate) Hz")
                                trackInfoRow(Lang.bitDepth, value: "\(track.bitDepth) bit")
                                trackInfoRow(Lang.fileSize, value: formatFileSize(track.fileSize))
                            }
                            .padding(12)
                            .glassCard(cornerRadius: 10)
                            .padding(.horizontal, 40)
                            .offset(y: 6)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .zIndex(1)

                    Spacer(minLength: 16)

                    // Progress bar
                    VStack(spacing: 6) {
                        ProgressBarView(
                            progress: player.duration > 0 ? player.position / player.duration : 0,
                            onSeek: { ratio in
                                player.seek(to: ratio * player.duration)
                            }
                        )
                        .frame(height: 14)

                        HStack {
                            Text(player.position.formattedDuration)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.35))
                            Spacer()
                            Text(player.duration.formattedDuration)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer(minLength: 24)

                    // Line 1: Previous, Play/Pause, Next (large)
                    HStack(spacing: 36) {
                        Button(action: { Haptic.light(); player.previous() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.previous)

                        Button(action: { Haptic.medium(); player.togglePlayPause() }) {
                            Image(systemName: player.state == .playing ? "pause.fill" : "play.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.white)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.playPause)

                        Button(action: { Haptic.light(); player.next() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.next)
                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 16)

                    // Volume slider
                    HStack(spacing: 10) {
                        Image(systemName: "speaker.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.35))

                        VolumeSlider(
                            value: Binding(
                                get: { Double(player.volume) },
                                set: { player.setVolume(Float($0)) }
                            )
                        )

                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .padding(.horizontal, 32)

                    Spacer(minLength: 12)

                    // Audio info (EQ + output)
                    HStack(spacing: 8) {
                        Button(action: toggleEQ) {
                            Text("EQ")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(appState.settings.eqEnabled ? .white : .white.opacity(0.3))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(appState.settings.eqEnabled ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(appState.settings.eqEnabled ? Color.white.opacity(0.2) : .clear, lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)

                        if appState.settings.eqEnabled, let preset = HeadphonePresetDatabase.find(id: appState.settings.eqPresetId) {
                            Text(preset.name)
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.25))
                                .lineLimit(1)
                        }

                        Spacer()

                        HStack(spacing: 5) {
                            Image(systemName: outputIcon)
                                .font(.system(size: 10))
                            Text(outputName)
                                .font(.system(size: 10))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.horizontal, 32)

                    Spacer(minLength: 12)

                    // Pill: Repeat, AirPlay, Shuffle
                    HStack(spacing: 20) {
                        Button(action: { Haptic.light(); player.toggleRepeat() }) {
                            Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                                .font(.system(size: 13))
                                .foregroundStyle(player.repeatMode != .off ? .white : .white.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.repeatMode)

                        AirPlayButton()
                            .frame(width: 20, height: 20)
                            .accessibilityLabel("AirPlay")

                        Button(action: { Haptic.light(); player.toggleShuffle() }) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 13))
                                .foregroundStyle(player.shuffle ? .white : .white.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.shuffle)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .glassPill()

                    Spacer(minLength: 32)
                }
                .frame(maxWidth: .infinity)
            }
            }
            .onAppear {
                checkFavorite(track)
                loadLyrics(for: track)
                updateAudioOutput()
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { _ in
                updateAudioOutput()
            }
            .onChange(of: player.currentTrack) { _, newTrack in
                showTrackInfo = false
                if let t = newTrack {
                    checkFavorite(t)
                    showLyrics = false
                    loadLyrics(for: t)
                }
            }
            .sheet(isPresented: $showPlaylistPicker) {
                PlaylistPickerView(track: track)
            }
            .sheet(isPresented: $showTrackActions) {
                QueueSheetView()
                    .environment(appState)
            }
        }
    }

    private func trackInfoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func toggleEQ() {
        appState.settings.eqEnabled.toggle()
        appState.player.setEQEnabled(appState.settings.eqEnabled)
        appState.saveSettings()
    }

    private func updateAudioOutput() {
        let route = AVAudioSession.sharedInstance().currentRoute
        guard let output = route.outputs.first else {
            outputIcon = "speaker.fill"
            outputName = "iPhone"
            return
        }
        switch output.portType {
        case .builtInSpeaker:
            outputIcon = "speaker.fill"
            outputName = "iPhone"
        case .headphones:
            outputIcon = "headphones"
            outputName = output.portName
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            outputIcon = "headphones"
            outputName = output.portName
        case .usbAudio:
            outputIcon = "hifispeaker"
            outputName = output.portName
        case .airPlay:
            outputIcon = "airplayaudio"
            outputName = output.portName
        case .lineOut:
            outputIcon = "hifispeaker"
            outputName = output.portName
        case .carAudio:
            outputIcon = "car.fill"
            outputName = output.portName
        default:
            outputIcon = "speaker.wave.2"
            outputName = output.portName
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }

    // MARK: - Artist Expanded Content

    @ViewBuilder
    private func artistExpandedContent(artist: Artist) -> some View {
        let albums = appState.db.getArtistAlbums(artistName: artist.name)
        let albumIds = albums.compactMap(\.id)
        let albumFormats = appState.db.getAlbumsFormats(albumIds: albumIds)

        VStack(spacing: 0) {
            dragHandle

            ScrollView {
                VStack(spacing: 20) {
                    // Artist header
                    VStack(spacing: 12) {
                        CoverArtView(path: artist.coverArtPath, size: 120)

                        Text(artist.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)

                        Text(Lang.albumCount(albums.count))
                            .font(.caption)
                            .foregroundStyle(.gray.opacity(0.5))

                        // Play all button
                        Button {
                            let allTracks = albums.flatMap { album in
                                guard let id = album.id else { return [Track]() }
                                return appState.db.getAlbumTracks(albumId: id)
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
                    .padding(.top, 8)

                    // Discography
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Lang.discography)
                            .font(.caption)
                            .foregroundStyle(.gray.opacity(0.5))
                            .padding(.horizontal, 24)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 14) {
                            ForEach(albums) { album in
                                Button {
                                    withAnimation(dockSpring) {
                                        dockState = .artist(artist, albumDetail: album)
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        CoverArtView(path: album.coverArtPath, size: nil)
                                            .aspectRatio(1, contentMode: .fit)

                                        Text(album.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)

                                        HStack(spacing: 4) {
                                            if let year = album.year {
                                                Text(String(year))
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.gray.opacity(0.5))
                                            }
                                            if let albumId = album.id,
                                               let formats = albumFormats[albumId] {
                                                FormatBadgesView(formats: formats)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Album Expanded Content Wrapper

    @ViewBuilder
    private func albumExpandedContent(album: Album, backToArtist: Artist?) -> some View {
        AlbumExpandedInner(
            album: album,
            backToArtist: backToArtist,
            dockSpring: dockSpring,
            onBack: { artist in
                withAnimation(dockSpring) {
                    dockState = .artist(artist, albumDetail: nil)
                }
            },
            onSelectAlbum: { newAlbum in
                withAnimation(dockSpring) {
                    if let artist = backToArtist {
                        dockState = .artist(artist, albumDetail: newAlbum)
                    } else {
                        dockState = .album(newAlbum)
                    }
                }
            }
        )
    }

    // MARK: - Helper Methods

    private func checkFavorite(_ track: Track) {
        guard let trackId = track.id,
              let favId = appState.db.getOrCreateFavorites().id else { return }
        isFavorite = appState.db.isTrackInPlaylist(playlistId: favId, trackId: trackId)
    }

    private func toggleFavorite() {
        guard let track = appState.player.currentTrack,
              let trackId = track.id,
              let favId = appState.db.getOrCreateFavorites().id else { return }
        if isFavorite {
            appState.db.removeTrackFromPlaylist(playlistId: favId, trackId: trackId)
        } else {
            appState.db.addTrackToPlaylist(playlistId: favId, trackId: trackId)
        }
        isFavorite.toggle()
    }

    private func trackBitrate(_ track: Track) -> String {
        guard track.duration > 0 else { return "" }
        let kbps = Int(Double(track.fileSize) * 8.0 / track.duration / 1000.0)
        if kbps >= 1000 {
            return String(format: "%.1f Mbps", Double(kbps) / 1000.0)
        }
        return "\(kbps) kbps"
    }

    // MARK: - Lyrics View

    @ViewBuilder
    private func lyricsView(track: Track) -> some View {
        let player = appState.player

        VStack(spacing: 0) {
            dragHandle

            // Compact header: artwork + title/artist (tap to go back)
            HStack(spacing: 12) {
                CoverArtView(path: track.coverArtPath, size: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) { showLyrics = false }
            }

            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.horizontal, 24)

            // Lyrics content
            if !lyricsLines.isEmpty {
                // Synced LRC lyrics
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(lyricsLines) { line in
                                let isCurrent = isCurrentLine(line, in: lyricsLines, position: player.position)
                                Text(line.text.isEmpty ? " " : line.text)
                                    .font(.system(size: isCurrent ? 20 : 16, weight: isCurrent ? .bold : .regular))
                                    .foregroundStyle(isCurrent ? .white : .white.opacity(0.35))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(line.id)
                                    .animation(.easeInOut(duration: 0.3), value: isCurrent)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                    .onChange(of: currentLyricLineId(position: player.position)) { _, newId in
                        if let id = newId {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            } else if let plain = plainLyrics {
                // Plain text lyrics
                ScrollView {
                    Text(plain)
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                }
            } else {
                // No lyrics
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "music.note")
                        .font(.system(size: 36))
                        .foregroundStyle(.gray.opacity(0.3))
                    Text(Lang.noLyrics)
                        .font(.callout)
                        .foregroundStyle(.gray.opacity(0.5))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Lyrics Helpers

    private func currentLyricLineId(position: Double) -> UUID? {
        guard !lyricsLines.isEmpty else { return nil }
        var current: LRCLine?
        for line in lyricsLines {
            if line.time <= position {
                current = line
            } else {
                break
            }
        }
        return current?.id
    }

    private func isCurrentLine(_ line: LRCLine, in lines: [LRCLine], position: Double) -> Bool {
        guard let idx = lines.firstIndex(where: { $0.id == line.id }) else { return false }
        let isAfterStart = line.time <= position
        let isBeforeNext = idx + 1 < lines.count ? position < lines[idx + 1].time : true
        return isAfterStart && isBeforeNext
    }

    private func loadLyrics(for track: Track) {
        lyricsLines = []
        plainLyrics = nil

        let path = track.path
        let format = track.format
        let scopedURLs = appState.player.securityScopedFolderURLs

        Task {
            let result = await Self.fetchLyrics(path: path, format: format, scopedURLs: scopedURLs)
            guard appState.player.currentTrack?.path == path else { return }
            lyricsLines = result.lines
            plainLyrics = result.plain
        }
    }

    private static nonisolated func fetchLyrics(path: String, format: String, scopedURLs: [String: URL]) async -> (lines: [LRCLine], plain: String?) {
        var foundLines: [LRCLine] = []
        var foundPlain: String?

        let resolvedURL = resolveURL(for: path, scopedURLs: scopedURLs)

        // 1. Try embedded lyrics for FLAC
        if format.uppercased() == "FLAC" {
            if let tags = FLACMetadataParser.parse(url: resolvedURL),
               let embedded = tags.lyrics, !embedded.isEmpty {
                let parsed = LRCParser.parse(embedded)
                if !parsed.isEmpty {
                    foundLines = parsed
                } else {
                    foundPlain = embedded
                }
            }
        }

        // 2. Try .lrc file
        if foundLines.isEmpty && foundPlain == nil {
            let lrcURL = resolvedURL.deletingPathExtension().appendingPathExtension("lrc")
            if let content = try? String(contentsOf: lrcURL, encoding: .utf8), !content.isEmpty {
                let parsed = LRCParser.parse(content)
                if !parsed.isEmpty {
                    foundLines = parsed
                } else {
                    foundPlain = content
                }
            }
        }

        return (foundLines, foundPlain)
    }

    private static nonisolated func resolveURL(for path: String, scopedURLs: [String: URL]) -> URL {
        for (folderPath, folderURL) in scopedURLs {
            if path.hasPrefix(folderPath) {
                let relativePath = String(path.dropFirst(folderPath.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return folderURL.appendingPathComponent(relativePath)
            }
        }
        return URL(fileURLWithPath: path)
    }

    private func resolveSecurityScopedURL(for path: String) -> URL {
        Self.resolveURL(for: path, scopedURLs: appState.player.securityScopedFolderURLs)
    }
}

