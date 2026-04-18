import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var currentPage: Page = .albums
    @State private var pillMode: PillMode = .nav
    @State private var searchOpen = false
    @State private var searchQuery = ""
    @State private var showTouchBarPlaylistPicker = false
    @State private var touchBarController = TouchBarController()

    enum PillMode {
        case nav, mini, player
    }

    private var modalOpen: Bool {
        appState.modalAlbum != nil || appState.modalArtist != nil
    }

    private var isNavTop: Bool {
        appState.settings.navPosition == "top"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                if isNavTop {
                    // Traffic light spacer
                    Color.clear.frame(height: 38)

                    // Top pill
                    pillView
                        .padding(.bottom, 12)
                } else {
                    // Traffic light spacer
                    Color.clear.frame(height: 52)
                }

                pageContent
            }
            .blur(radius: modalOpen ? 12 : 0)
            .allowsHitTesting(!modalOpen)

            // Bottom pill (only when position is bottom)
            if !isNavTop {
                VStack {
                    Spacer()
                    pillView
                        .padding(.bottom, 24)
                }
                .blur(radius: modalOpen ? 12 : 0)
                .allowsHitTesting(!modalOpen)
            }

            // Modal overlay (click outside to dismiss)
            if modalOpen {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(Anim.modalDismiss) {
                            appState.modalAlbum = nil
                            appState.modalArtist = nil
                        }
                    }

                Group {
                    if let album = appState.modalAlbum {
                        AlbumModalView(album: album, onSelectAlbum: { newAlbum in
                            appState.modalAlbum = newAlbum
                        }, onDismiss: {
                            withAnimation(Anim.modalDismiss) {
                                appState.modalAlbum = nil
                            }
                        })
                    } else if let artist = appState.modalArtist {
                        ArtistModalView(artist: artist, onSelectAlbum: { album in
                            withAnimation(Anim.modalDismiss) {
                                appState.modalArtist = nil
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                withAnimation(Anim.modalDismiss) {
                                    appState.modalAlbum = album
                                }
                            }
                        }, onDismiss: {
                            withAnimation(Anim.modalDismiss) {
                                appState.modalArtist = nil
                            }
                        })
                    }
                }
                .frame(width: 700, height: 500)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.6), radius: 40, y: 10)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(Anim.modal, value: modalOpen)
        .onChange(of: appState.player.currentTrack) { _, newTrack in
            if newTrack != nil && appState.player.state == .playing && pillMode == .nav {
                withAnimation(Anim.pillSwitch) {
                    pillMode = .mini
                }
            }
            appState.mediaKeyController?.updateNowPlaying()
        }
        .onChange(of: appState.player.state) { _, _ in
            appState.mediaKeyController?.updateNowPlaying()
        }
        .modifier(KeyboardShortcutsModifier(searchOpen: searchOpen))
        .onChange(of: currentPage) { _, newPage in
            if newPage != .albums && newPage != .artists {
                appState.sidebarLetters = []
            }
        }
        .onAppear {
            touchBarController.setup(appState: appState)
            touchBarController.onPageChange = { page in
                currentPage = page
                searchOpen = false
                searchQuery = ""
            }
            touchBarController.onSearchOpen = {
                currentPage = .search
                searchOpen = true
                searchQuery = ""
            }
            touchBarController.onShowPlaylistPicker = {
                showTouchBarPlaylistPicker = true
            }
        }
        .sheet(isPresented: $showTouchBarPlaylistPicker) {
            if let track = appState.player.currentTrack {
                PlaylistPickerView(track: track)
                    .frame(minWidth: 300, minHeight: 250)
            }
        }
    }

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
                        .padding(.horizontal, 32)
                        .padding(.bottom, isNavTop ? 40 : 120)
                }
            case .tracks:
                ScrollView {
                    TrackListView()
                        .padding(.horizontal, 32)
                        .padding(.bottom, isNavTop ? 40 : 120)
                }
            case .search:
                ScrollView {
                    SearchView(query: $searchQuery)
                        .padding(.horizontal, 32)
                        .padding(.bottom, isNavTop ? 40 : 120)
                }
            case .settings:
                ScrollView {
                    SettingsView()
                        .padding(.horizontal, 32)
                        .padding(.bottom, isNavTop ? 40 : 120)
                }
            }
        }
        .id(currentPage)
        .transition(.opacity.combined(with: .offset(y: 6)))
        .animation(Anim.pageChange, value: currentPage)
    }

    private var pillTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.92, anchor: isNavTop ? .top : .bottom)
                .combined(with: .opacity)
                .combined(with: .offset(y: isNavTop ? -8 : 8)),
            removal: .scale(scale: 0.92, anchor: isNavTop ? .top : .bottom)
                .combined(with: .opacity)
                .combined(with: .offset(y: isNavTop ? -8 : 8))
        )
    }

    @ViewBuilder
    private var pillView: some View {
        switch pillMode {
        case .player where appState.player.currentTrack != nil:
            PlayerPillView(onSwitchToNav: {
                withAnimation(Anim.pillSwitch) {
                    pillMode = .nav
                }
            })
            .transition(pillTransition)

        case .mini where appState.player.currentTrack != nil:
            MiniPlayerPillView(
                onSwitchToNav: {
                    withAnimation(Anim.pillSwitch) {
                        pillMode = .nav
                    }
                },
                onExpandPlayer: {
                    withAnimation(Anim.pillSwitch) {
                        pillMode = .player
                    }
                }
            )
            .transition(pillTransition)

        default:
            NavigationPillView(
                currentPage: $currentPage,
                searchOpen: $searchOpen,
                searchQuery: $searchQuery,
                hasTrackPlaying: appState.player.currentTrack != nil && appState.player.state != .stopped,
                onSwitchToPlayer: {
                    withAnimation(Anim.pillSwitch) {
                        pillMode = .mini
                    }
                }
            )
            .transition(pillTransition)
        }
    }
}

struct KeyboardShortcutsModifier: ViewModifier {
    @Environment(AppState.self) private var appState
    var searchOpen: Bool

    func body(content: Content) -> some View {
        content
            .onKeyPress(.space) {
                if searchOpen { return .ignored }
                let player = appState.player
                if player.state == .stopped && player.currentTrack == nil {
                    let allTracks = appState.db.getAllTracks()
                    if !allTracks.isEmpty {
                        player.playShuffled(allTracks)
                    }
                } else {
                    player.togglePlayPause()
                }
                return .handled
            }
    }
}
