import AppKit
import SwiftUI

@MainActor
final class TouchBarController: NSObject, NSTouchBarDelegate {
    private weak var appState: AppState?
    private var currentTouchBar: NSTouchBar?
    private var observation: Any?
    private var refreshTimer: Timer?

    // Item identifiers - Navigation
    private static let navPlaylists = NSTouchBarItem.Identifier("com.flayer.nav.playlists")
    private static let navArtists = NSTouchBarItem.Identifier("com.flayer.nav.artists")
    private static let navAlbums = NSTouchBarItem.Identifier("com.flayer.nav.albums")
    private static let navTracks = NSTouchBarItem.Identifier("com.flayer.nav.tracks")
    private static let navSearch = NSTouchBarItem.Identifier("com.flayer.nav.search")
    private static let navSettings = NSTouchBarItem.Identifier("com.flayer.nav.settings")

    // Item identifiers - Player
    private static let trackInfo = NSTouchBarItem.Identifier("com.flayer.trackInfo")
    private static let prevBtn = NSTouchBarItem.Identifier("com.flayer.previous")
    private static let playPauseBtn = NSTouchBarItem.Identifier("com.flayer.playPause")
    private static let nextBtn = NSTouchBarItem.Identifier("com.flayer.next")
    private static let favBtn = NSTouchBarItem.Identifier("com.flayer.favorite")
    private static let playlistBtn = NSTouchBarItem.Identifier("com.flayer.playlist")
    private static let switchBtn = NSTouchBarItem.Identifier("com.flayer.switch")

    private var showingPlayer = true

    var onPageChange: ((Page) -> Void)?
    var onSearchOpen: (() -> Void)?
    var onShowPlaylistPicker: (() -> Void)?

    func setup(appState: AppState) {
        self.appState = appState
        startRefreshTimer()
        installTouchBar()
    }

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTouchBar()
            }
        }
    }

    private var lastShowPlayer = false

    private func updateTouchBar() {
        guard let appState else { return }
        let active = appState.player.currentTrack != nil && appState.player.state != .stopped

        // When track stops, reset to nav mode
        if !active && lastShowPlayer {
            lastShowPlayer = false
            showingPlayer = true
            installTouchBar()
            return
        }
        // When track starts, show player
        if active && !lastShowPlayer {
            lastShowPlayer = true
            showingPlayer = true
            installTouchBar()
            return
        }

        // Skip updates when in nav mode (nothing dynamic to update)
        if !active { return }

        // Update existing items
        guard let touchBar = currentTouchBar else { return }

        if active && showingPlayer {
            // Update track info
            if let item = touchBar.item(forIdentifier: Self.trackInfo) as? NSCustomTouchBarItem,
               let stack = item.view as? NSStackView,
               let track = appState.player.currentTrack {
                // Update artwork
                if let imageView = stack.arrangedSubviews.first as? NSImageView {
                    if let path = track.coverArtPath {
                        imageView.image = NSImage(contentsOfFile: path)
                    } else {
                        imageView.image = symbol("music.note")
                    }
                }
                // Update text
                if let textStack = stack.arrangedSubviews.last as? NSStackView {
                    if let titleLabel = textStack.arrangedSubviews.first(where: { $0.tag == 1 }) as? NSTextField {
                        titleLabel.stringValue = track.title
                    }
                    if let artistLabel = textStack.arrangedSubviews.first(where: { $0.tag == 2 }) as? NSTextField {
                        artistLabel.stringValue = track.artist
                    }
                }
            }

            // Update play/pause icon
            if let item = touchBar.item(forIdentifier: Self.playPauseBtn) as? NSCustomTouchBarItem,
               let button = item.view as? NSButton {
                let icon = appState.player.state == .playing ? "pause.fill" : "play.fill"
                button.image = symbol(icon)
            }

            // Update favorite icon
            if let item = touchBar.item(forIdentifier: Self.favBtn) as? NSCustomTouchBarItem,
               let button = item.view as? NSButton {
                let isFav = checkFavorite()
                let icon = isFav ? "heart.fill" : "heart"
                button.image = symbol(icon)
            }

        }
    }

    private var hasActiveTrack: Bool {
        appState?.player.currentTrack != nil && appState?.player.state != .stopped
    }

    private func installTouchBar() {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.customizationIdentifier = NSTouchBar.CustomizationIdentifier("com.flayer.touchbar")

        if hasActiveTrack && showingPlayer {
            touchBar.defaultItemIdentifiers = [
                Self.trackInfo,
                .fixedSpaceSmall,
                Self.prevBtn,
                Self.playPauseBtn,
                Self.nextBtn,
                .fixedSpaceSmall,
                Self.favBtn,
                Self.playlistBtn,
                .fixedSpaceSmall,
                Self.switchBtn,
            ]
        } else {
            var ids: [NSTouchBarItem.Identifier] = [
                Self.navPlaylists,
                Self.navArtists,
                Self.navAlbums,
            ]
            if appState?.settings.showTracks == true {
                ids.append(Self.navTracks)
            }
            ids.append(contentsOf: [Self.navSearch, Self.navSettings])
            if hasActiveTrack {
                ids.append(contentsOf: [.fixedSpaceSmall, Self.switchBtn])
            }
            touchBar.defaultItemIdentifiers = ids
        }

        currentTouchBar = touchBar

        // Apply to main window
        DispatchQueue.main.async {
            NSApplication.shared.mainWindow?.touchBar = touchBar
        }
    }

    // MARK: - NSTouchBarDelegate

    nonisolated func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        MainActor.assumeIsolated {
            makeItem(identifier: identifier)
        }
    }

    private func makeItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {

        // MARK: Navigation items
        case Self.navPlaylists:
            return makeNavItem(id: identifier, icon: "music.note.list", page: .playlists)
        case Self.navArtists:
            return makeNavItem(id: identifier, icon: "person.2", page: .artists)
        case Self.navAlbums:
            return makeNavItem(id: identifier, icon: "square.stack", page: .albums)
        case Self.navTracks:
            return makeNavItem(id: identifier, icon: "music.note", page: .tracks)
        case Self.navSearch:
            return makeNavItem(id: identifier, icon: "magnifyingglass", page: .search)
        case Self.navSettings:
            return makeNavItem(id: identifier, icon: "gearshape", page: .settings)

        // MARK: Player items
        case Self.trackInfo:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let stack = NSStackView()
            stack.orientation = .horizontal
            stack.spacing = 8
            stack.alignment = .centerY

            // Artwork
            let imageView = NSImageView()
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.wantsLayer = true
            imageView.layer?.cornerRadius = 4
            imageView.layer?.masksToBounds = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 28),
                imageView.heightAnchor.constraint(equalToConstant: 28),
            ])
            if let path = appState?.player.currentTrack?.coverArtPath {
                imageView.image = NSImage(contentsOfFile: path)
            } else {
                imageView.image = symbol("music.note")
            }
            stack.addArrangedSubview(imageView)

            // Two-line text
            let textStack = NSStackView()
            textStack.orientation = .vertical
            textStack.spacing = 1
            textStack.alignment = .leading

            let titleLabel = NSTextField(labelWithString: appState?.player.currentTrack?.title ?? "")
            titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
            titleLabel.textColor = .white
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.tag = 1

            let artistLabel = NSTextField(labelWithString: appState?.player.currentTrack?.artist ?? "")
            artistLabel.font = .systemFont(ofSize: 9)
            artistLabel.textColor = .secondaryLabelColor
            artistLabel.lineBreakMode = .byTruncatingTail
            artistLabel.tag = 2

            textStack.addArrangedSubview(titleLabel)
            textStack.addArrangedSubview(artistLabel)
            textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            stack.addArrangedSubview(textStack)
            item.view = stack
            return item

        case Self.prevBtn:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(
                image: symbol("backward.fill"),
                target: self,
                action: #selector(previousTapped)
            )
            item.view = button
            return item

        case Self.playPauseBtn:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let icon = appState?.player.state == .playing ? "pause.fill" : "play.fill"
            let button = NSButton(
                image: symbol(icon),
                target: self,
                action: #selector(playPauseTapped)
            )
            item.view = button
            return item

        case Self.nextBtn:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(
                image: symbol("forward.fill"),
                target: self,
                action: #selector(nextTapped)
            )
            item.view = button
            return item

        case Self.favBtn:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let isFav = checkFavorite()
            let button = NSButton(
                image: symbol(isFav ? "heart.fill" : "heart"),
                target: self,
                action: #selector(favoriteTapped)
            )
            item.view = button
            return item

        case Self.playlistBtn:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(
                image: symbol("text.badge.plus"),
                target: self,
                action: #selector(playlistTapped)
            )
            item.view = button
            return item

        case Self.switchBtn:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let icon = showingPlayer ? "chevron.down" : "chevron.up"
            let button = NSButton(
                image: symbol(icon),
                target: self,
                action: #selector(switchTapped)
            )
            item.view = button
            return item

        default:
            return nil
        }
    }

    private func makeNavItem(id: NSTouchBarItem.Identifier, icon: String, page: Page) -> NSCustomTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: id)
        let button = NSButton(
            image: symbol(icon),
            target: self,
            action: page == .search ? #selector(searchTapped) : #selector(navTapped(_:))
        )
        button.tag = Page.allCases.firstIndex(of: page) ?? 0
        item.view = button
        return item
    }

    // MARK: - Actions

    @objc private func navTapped(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < Page.allCases.count else { return }
        let page = Page.allCases[sender.tag]
        onPageChange?(page)
    }

    @objc private func searchTapped() {
        onSearchOpen?()
    }

    @objc private func previousTapped() {
        appState?.player.previous()
    }

    @objc private func playPauseTapped() {
        appState?.player.togglePlayPause()
    }

    @objc private func nextTapped() {
        appState?.player.next()
    }

    @objc private func favoriteTapped() {
        guard let appState,
              let track = appState.player.currentTrack,
              let trackId = track.id,
              let favId = appState.db.getOrCreateFavorites().id else { return }
        let isFav = appState.db.isTrackInPlaylist(playlistId: favId, trackId: trackId)
        if isFav {
            appState.db.removeTrackFromPlaylist(playlistId: favId, trackId: trackId)
        } else {
            appState.db.addTrackToPlaylist(playlistId: favId, trackId: trackId)
        }
    }

    @objc private func playlistTapped() {
        onShowPlaylistPicker?()
    }

    @objc private func switchTapped() {
        showingPlayer.toggle()
        installTouchBar()
    }

    // MARK: - Helpers

    private func symbol(_ name: String) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
    }

    private func checkFavorite() -> Bool {
        guard let appState,
              let track = appState.player.currentTrack,
              let trackId = track.id,
              let favId = appState.db.getOrCreateFavorites().id else { return false }
        return appState.db.isTrackInPlaylist(playlistId: favId, trackId: trackId)
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            refreshTimer?.invalidate()
        }
    }
}
