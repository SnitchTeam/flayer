import SwiftUI
#if os(iOS)
import Combine
#endif

// MARK: - Keyboard Height Observer

#if os(iOS)
@Observable
final class KeyboardObserver {
    var height: CGFloat = 0

    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height }
            .sink { [weak self] h in withAnimation(.easeOut(duration: 0.25)) { self?.height = h } }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in withAnimation(.easeOut(duration: 0.25)) { self?.height = 0 } }
            .store(in: &cancellables)
    }
}
#endif

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var currentPage: Page = .albums
    @State private var pillMode: PillMode = .nav
    @State private var searchOpen = false
    @State private var searchQuery = ""
    @State private var showFullPlayer = false
    @State private var dockState: DockState = .collapsed
    @State private var pendingImportURL: URL?
    @State private var showImportConfirmation = false
    @Namespace private var playerNamespace
    #if os(iOS)
    @State private var keyboardObserver = KeyboardObserver()
    #endif

    private var isIPad: Bool { sizeClass == .regular }

    enum PillMode {
        case nav, player
    }

    private var modalOpen: Bool {
        appState.modalAlbum != nil || appState.modalArtist != nil
    }

    private var isNavTop: Bool {
        appState.settings.navPosition == "top"
    }

    private var contentPadding: CGFloat { isIPad ? 32 : 16 }

    // Animations tuned for ProMotion ~90Hz feel
    private let modalSpring: Animation = .spring(duration: 0.42, bounce: 0.15)
    private let playerSpring: Animation = .spring(duration: 0.55, bounce: 0.18)
    private let pillSpring: Animation = .spring(duration: 0.45, bounce: 0.12)

    // MARK: - Body

    var body: some View {
        if isIPad {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    // MARK: - iPhone Layout

    @ViewBuilder
    private var iPhoneLayout: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                iPhonePageContent
                    .frame(maxHeight: .infinity)
            }
            .blur(radius: dockState.isExpanded ? 12 : 0)
            .allowsHitTesting(!dockState.isExpanded)

            // Dimming overlay
            if dockState.isExpanded {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            VStack {
                Spacer()
                if !modalOpen {
                    DockView(
                        currentPage: $currentPage,
                        searchQuery: $searchQuery,
                        dockState: $dockState
                    )
                    .padding(.bottom, keyboardObserver.height > 0 ? keyboardObserver.height : 0)
                }
            }
            .ignoresSafeArea(.keyboard)

            // Modal overlay (album/artist detail)
            if modalOpen {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(modalSpring) {
                            appState.modalAlbum = nil
                            appState.modalArtist = nil
                        }
                    }

                Group {
                    if let album = appState.modalAlbum {
                        AlbumModalView(album: album, onSelectAlbum: { newAlbum in
                            appState.modalAlbum = newAlbum
                        }, onDismiss: {
                            withAnimation(modalSpring) {
                                appState.modalAlbum = nil
                            }
                        })
                    } else if let artist = appState.modalArtist {
                        ArtistModalView(artist: artist, onSelectAlbum: { album in
                            withAnimation(modalSpring) {
                                appState.modalArtist = nil
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(modalSpring) {
                                    appState.modalAlbum = album
                                }
                            }
                        }, onDismiss: {
                            withAnimation(modalSpring) {
                                appState.modalArtist = nil
                            }
                        })
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.6), radius: 30, y: 8)
                .padding(.horizontal, 8)
                .padding(.top, 40)
                .padding(.bottom, 8)
                .transition(
                    .scale(scale: 0.15, anchor: isNavTop ? .top : .bottom)
                        .combined(with: .opacity)
                )
            }
        }
        .animation(.spring(duration: 0.5, bounce: 0.12), value: dockState)
        .animation(modalSpring, value: modalOpen)
        .onChange(of: currentPage) { _, newPage in
            if newPage != .albums && newPage != .artists {
                appState.sidebarLetters = []
            }
        }
        .onChange(of: appState.player.currentTrack) { _, newTrack in
            appState.mediaKeyController?.updateNowPlaying()
            if newTrack != nil && appState.settings.autoOpenPlayer {
                withAnimation(.spring(duration: 0.5, bounce: 0.12)) {
                    dockState = .player
                }
            }
        }
        .onChange(of: appState.player.state) { _, _ in
            appState.mediaKeyController?.updateNowPlaying()
        }
        .onOpenURL { url in
            if url.scheme == "flayer" {
                handleDeepLink(url)
            } else {
                pendingImportURL = url
                showImportConfirmation = true
            }
        }
        .alert(Lang.importFile, isPresented: $showImportConfirmation) {
            Button(Lang.cancel, role: .cancel) { pendingImportURL = nil }
            Button(Lang.importAction) {
                if let url = pendingImportURL {
                    importSharedFile(url)
                    pendingImportURL = nil
                }
            }
        } message: {
            Text(pendingImportURL?.lastPathComponent ?? "")
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard let host = url.host else { return }
        switch host {
        case "album":
            if let idStr = url.pathComponents.dropFirst().first, let id = Int64(idStr) {
                appState.modalAlbum = appState.db.getAlbum(id: id)
            }
        case "playlist":
            if let idStr = url.pathComponents.dropFirst().first, let id = Int64(idStr) {
                currentPage = .playlists
                appState.deepLinkPlaylistId = id
            }
        case "player":
            withAnimation(.spring(duration: 0.5, bounce: 0.12)) {
                dockState = .player
            }
        case "settings":
            currentPage = .settings
        default:
            break
        }
    }

    // MARK: - iPhone Page Content

    @ViewBuilder
    private var iPhonePageContent: some View {
        Group {
            switch currentPage {
            case .albums:
                AlbumGridView(onSelectAlbum: { album in
                    withAnimation(.spring(duration: 0.5, bounce: 0.12)) {
                        dockState = .album(album)
                    }
                })
            case .artists:
                ArtistGridView(
                    onSelectArtist: { artist in
                        withAnimation(.spring(duration: 0.5, bounce: 0.12)) {
                            dockState = .artist(artist, albumDetail: nil)
                        }
                    },
                    onSelectAlbum: { album in
                        withAnimation(.spring(duration: 0.5, bounce: 0.12)) {
                            dockState = .album(album)
                        }
                    }
                )
            case .playlists:
                ScrollView {
                    PlaylistGridView()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 120)
                }
            case .tracks:
                ScrollView {
                    TrackListView()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 120)
                }
            case .search:
                VStack(spacing: 0) {
                    // Search field
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundStyle(.gray)
                        TextField(Lang.typeToSearch, text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                            .tint(.white)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        if !searchQuery.isEmpty {
                            Button {
                                searchQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.gray)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    ScrollView {
                        SearchView(
                            query: $searchQuery,
                            onSelectAlbum: { album in
                                withAnimation(.spring(duration: 0.5, bounce: 0.12)) {
                                    dockState = .album(album)
                                }
                            },
                            onSelectArtist: { artist in
                                withAnimation(.spring(duration: 0.5, bounce: 0.12)) {
                                    dockState = .artist(artist, albumDetail: nil)
                                }
                            }
                        )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 120)
                    }
                }
            case .settings:
                SettingsView()
                    .padding(.bottom, 80)
            }
        }
        .id(currentPage)
        .transition(.opacity.combined(with: .offset(y: 6)))
        .animation(.easeOut(duration: 0.3), value: currentPage)
    }

    // MARK: - iPad Layout

    @ViewBuilder
    private var iPadLayout: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                if isNavTop {
                    pillView
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                }

                pageContent
            }
            .blur(radius: modalOpen ? 12 : 0)
            .allowsHitTesting(!modalOpen)

            // Bottom pill (only when position is bottom)
            if !isNavTop {
                VStack {
                    Spacer()
                    if !modalOpen {
                        pillView
                            .padding(.bottom, 12)
                    }
                }
                .allowsHitTesting(!modalOpen)
            }

            // Modal overlay
            if modalOpen {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(modalSpring) {
                            appState.modalAlbum = nil
                            appState.modalArtist = nil
                        }
                    }

                if isIPad {
                    Group {
                        if let album = appState.modalAlbum {
                            AlbumModalView(album: album, onSelectAlbum: { newAlbum in
                                appState.modalAlbum = newAlbum
                            }, onDismiss: {
                                withAnimation(modalSpring) {
                                    appState.modalAlbum = nil
                                }
                            })
                        } else if let artist = appState.modalArtist {
                            ArtistModalView(artist: artist, onSelectAlbum: { album in
                                withAnimation(modalSpring) {
                                    appState.modalArtist = nil
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation(modalSpring) {
                                        appState.modalAlbum = album
                                    }
                                }
                            }, onDismiss: {
                                withAnimation(modalSpring) {
                                    appState.modalArtist = nil
                                }
                            })
                        }
                    }
                    .frame(width: 700, height: 500)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.6), radius: 40, y: 10)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    // iPhone: modal expands from pill position (water drop)
                    Group {
                        if let album = appState.modalAlbum {
                            AlbumModalView(album: album, onSelectAlbum: { newAlbum in
                                appState.modalAlbum = newAlbum
                            }, onDismiss: {
                                withAnimation(modalSpring) {
                                    appState.modalAlbum = nil
                                }
                            })
                        } else if let artist = appState.modalArtist {
                            ArtistModalView(artist: artist, onSelectAlbum: { album in
                                withAnimation(modalSpring) {
                                    appState.modalArtist = nil
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation(modalSpring) {
                                        appState.modalAlbum = album
                                    }
                                }
                            }, onDismiss: {
                                withAnimation(modalSpring) {
                                    appState.modalArtist = nil
                                }
                            })
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.6), radius: 30, y: 8)
                    .padding(.horizontal, 8)
                    .padding(.top, 40)
                    .padding(.bottom, 8)
                    .transition(
                        .scale(scale: 0.15, anchor: isNavTop ? .top : .bottom)
                            .combined(with: .opacity)
                    )
                }
            }
            // Expanded player
            if showFullPlayer {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(playerSpring) { showFullPlayer = false }
                    }
                    .zIndex(19)
                    .transition(.opacity)

                FullScreenPlayerView(
                    namespace: playerNamespace,
                    onDismiss: {
                        withAnimation(playerSpring) { showFullPlayer = false }
                    }
                )
                .zIndex(20)
                .transition(
                    .scale(scale: 0.5, anchor: isNavTop ? .top : .bottom)
                        .combined(with: .opacity)
                        .combined(with: .offset(y: isNavTop ? -40 : 40))
                )
            }
        }
        .animation(modalSpring, value: modalOpen)
        .animation(playerSpring, value: showFullPlayer)
        .onChange(of: appState.player.currentTrack) { _, newTrack in
            if newTrack != nil && appState.player.state == .playing {
                withAnimation(pillSpring) { pillMode = .player }
            }
            appState.mediaKeyController?.updateNowPlaying()
        }
        .onChange(of: appState.player.state) { _, _ in
            appState.mediaKeyController?.updateNowPlaying()
        }
        .onChange(of: currentPage) { _, newPage in
            if newPage != .albums && newPage != .artists {
                appState.sidebarLetters = []
            }
        }
        .onOpenURL { url in
            if url.scheme == "flayer" {
                handleDeepLink(url)
            } else {
                pendingImportURL = url
                showImportConfirmation = true
            }
        }
        .alert(Lang.importFile, isPresented: $showImportConfirmation) {
            Button(Lang.cancel, role: .cancel) { pendingImportURL = nil }
            Button(Lang.importAction) {
                if let url = pendingImportURL {
                    importSharedFile(url)
                    pendingImportURL = nil
                }
            }
        } message: {
            Text(pendingImportURL?.lastPathComponent ?? "")
        }
    }

    // MARK: - iPad Page Content

    @ViewBuilder
    private var pageContent: some View {
        Group {
            switch currentPage {
            case .albums:
                AlbumGridView()
            case .artists:
                ArtistGridView()
            case .playlists:
                ScrollView {
                    PlaylistGridView()
                        .padding(.horizontal, contentPadding)
                        .padding(.bottom, isNavTop ? 40 : 120)
                }
            case .tracks:
                ScrollView {
                    TrackListView()
                        .padding(.horizontal, contentPadding)
                        .padding(.bottom, isNavTop ? 40 : 120)
                }
            case .search:
                ScrollView {
                    SearchView(query: $searchQuery)
                        .padding(.horizontal, contentPadding)
                        .padding(.bottom, isNavTop ? 40 : 120)
                }
            case .settings:
                SettingsView()
                    .padding(.bottom, isNavTop ? 0 : 80)
            }
        }
        .id(currentPage)
        .transition(.opacity.combined(with: .offset(y: 6)))
        .animation(.easeOut(duration: 0.3), value: currentPage)
    }

    // MARK: - iPad Pill View

    @ViewBuilder
    private var pillView: some View {
        if pillMode == .player, appState.player.currentTrack != nil, !showFullPlayer {
            PlayerPillView(
                onSwitchToNav: { withAnimation(pillSpring) { pillMode = .nav } },
                onExpandPlayer: !isIPad ? { withAnimation(playerSpring) { showFullPlayer = true } } : nil,
                namespace: playerNamespace
            )
                .transition(
                    .scale(scale: 0.92, anchor: isNavTop ? .top : .bottom)
                        .combined(with: .opacity)
                        .combined(with: .offset(y: isNavTop ? -8 : 8))
                )
        } else {
            NavigationPillView(
                currentPage: $currentPage,
                searchOpen: $searchOpen,
                searchQuery: $searchQuery,
                hasTrackPlaying: appState.player.currentTrack != nil && appState.player.state != .stopped,
                onSwitchToPlayer: { withAnimation(pillSpring) { pillMode = .player } }
            )
            .transition(
                .scale(scale: 0.92, anchor: isNavTop ? .top : .bottom)
                    .combined(with: .opacity)
                    .combined(with: .offset(y: isNavTop ? -8 : 8))
            )
        }
    }

    // MARK: - File Import

    private func importSharedFile(_ url: URL) {
        let dest = appState.cacheManager.cacheDirectory(sourceType: "share", sourceId: nil)
        let finalURL = dest.appendingPathComponent(url.lastPathComponent)
        Task.detached {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            try? FileManager.default.copyItem(at: url, to: finalURL)
            await MainActor.run {
                Task {
                    await appState.scanner?.processFile(finalURL)
                    appState.cacheManager.registerDownload(localPath: finalURL.path, sourceType: "share", sourceId: nil,
                                                           remotePath: nil, trackId: appState.db.getTrackId(path: finalURL.path), fileSize: nil)
                    appState.libraryVersion += 1
                }
            }
        }
    }
}
