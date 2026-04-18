@preconcurrency import WatchConnectivity
import UIKit

// Sendable message representation parsed from [String: Any]
enum ParsedWatchMessage: Sendable {
    case command(String)
    case playAlbum(albumId: Int64, startIndex: Int)
    case playPlaylist(playlistId: Int64)
    case shuffleAlbum(albumId: Int64)
    case shufflePlaylist(playlistId: Int64)
    case playTrack(albumId: Int64?, playlistId: Int64?, trackIndex: Int)
    case requestLibrary
    case requestAlbumTracks(albumId: Int64)
    case requestArtistAlbums(artistName: String)
    case requestPlaylistTracks(playlistId: Int64)
    case unknown
}

enum WatchMessageParser {
    static func parse(_ message: [String: Any]) -> ParsedWatchMessage {
        guard let type = message["type"] as? String else { return .unknown }
        switch type {
        case "command":
            guard let cmd = message["command"] as? String else { return .unknown }
            return .command(cmd)
        case "playAlbum":
            guard let albumId = message["albumId"] as? Int64 else { return .unknown }
            let startIndex = message["startIndex"] as? Int ?? 0
            return .playAlbum(albumId: albumId, startIndex: startIndex)
        case "playPlaylist":
            guard let id = message["playlistId"] as? Int64 else { return .unknown }
            return .playPlaylist(playlistId: id)
        case "shuffleAlbum":
            guard let id = message["albumId"] as? Int64 else { return .unknown }
            return .shuffleAlbum(albumId: id)
        case "shufflePlaylist":
            guard let id = message["playlistId"] as? Int64 else { return .unknown }
            return .shufflePlaylist(playlistId: id)
        case "playTrack":
            let trackIndex = message["trackIndex"] as? Int ?? 0
            return .playTrack(
                albumId: message["albumId"] as? Int64,
                playlistId: message["playlistId"] as? Int64,
                trackIndex: trackIndex
            )
        case "requestLibrary":
            return .requestLibrary
        case "requestAlbumTracks":
            guard let id = message["albumId"] as? Int64 else { return .unknown }
            return .requestAlbumTracks(albumId: id)
        case "requestArtistAlbums":
            guard let name = message["artistName"] as? String else { return .unknown }
            return .requestArtistAlbums(artistName: name)
        case "requestPlaylistTracks":
            guard let id = message["playlistId"] as? Int64 else { return .unknown }
            return .requestPlaylistTracks(playlistId: id)
        default:
            return .unknown
        }
    }
}

@Observable
@MainActor
final class WatchConnectivityService: NSObject {
    var isWatchReachable = false
    private weak var appState: AppState?
    private var lastContextUpdate = Date.distantPast

    func configure(appState: AppState) {
        self.appState = appState
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Sync Now Playing State

    func syncNowPlaying() {
        guard WCSession.default.activationState == .activated else { return }
        guard let appState else { return }
        let player = appState.player

        let now = Date()
        guard now.timeIntervalSince(lastContextUpdate) >= 1.0 else { return }
        lastContextUpdate = now

        let nowPlaying = WatchNowPlaying(
            title: player.currentTrack?.title ?? "",
            artist: player.currentTrack?.artist ?? "",
            album: player.currentTrack?.album ?? "",
            isPlaying: player.state == .playing,
            isFavorite: player.isFavoriteCheck?(player.currentTrack) ?? false,
            position: player.position,
            duration: player.duration,
            coverArtData: generateThumbnail(for: player.currentTrack?.coverArtPath, size: 160),
            queueCount: player.queue.count,
            queueIndex: player.queueIndex,
            shuffle: player.shuffle,
            repeatMode: player.repeatMode.rawValue
        )

        guard let data = try? JSONEncoder().encode(nowPlaying) else { return }
        try? WCSession.default.updateApplicationContext(["type": "nowPlaying", "payload": data])
    }

    // MARK: - Sync Library

    func syncLibrary() {
        guard WCSession.default.activationState == .activated else { return }
        guard let appState else { return }

        let albums = appState.db.getAllAlbums().map { album in
            let trackCount = appState.db.getAlbumTracks(albumId: album.id!).count
            return WatchAlbum(
                id: album.id!, name: album.name, artist: album.albumArtist,
                year: album.year, trackCount: trackCount
            )
        }
        let artists = appState.db.getAllArtists().map { artist in
            WatchArtist(
                id: artist.id!, name: artist.name,
                albumCount: appState.db.getArtistAlbums(artistName: artist.name).count
            )
        }
        let playlists = appState.db.getPlaylists().map { playlist in
            let trackCount = appState.db.getPlaylistTracks(playlistId: playlist.id!).count
            return WatchPlaylist(
                id: playlist.id!, name: playlist.name,
                trackCount: trackCount, isFavorites: playlist.isFavorites
            )
        }

        var userInfo: [String: Any] = ["type": "librarySync"]
        if let data = try? JSONEncoder().encode(albums) { userInfo["albums"] = data }
        if let data = try? JSONEncoder().encode(artists) { userInfo["artists"] = data }
        if let data = try? JSONEncoder().encode(playlists) { userInfo["playlists"] = data }

        WCSession.default.transferUserInfo(userInfo)
    }

    // MARK: - Thumbnail Generation

    private func generateThumbnail(for coverPath: String?, size: CGFloat) -> Data? {
        guard let path = coverPath, !path.isEmpty,
              let image = UIImage(contentsOfFile: path) else { return nil }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.jpegData(withCompressionQuality: 0.6) { ctx in
            image.draw(in: CGRect(origin: .zero, size: CGSize(width: size, height: size)))
        }
    }

    // MARK: - Handle Messages from Watch

    private func handleParsedMessage(_ parsed: ParsedWatchMessage,
                                     replyHandler: @escaping ([String: Any]) -> Void) {
        guard let appState else {
            replyHandler(["error": "not ready"])
            return
        }

        switch parsed {
        case .command(let cmd):
            switch cmd {
            case "playPause": appState.player.togglePlayPause()
            case "next": appState.player.next()
            case "previous": appState.player.previous()
            case "toggleFavorite":
                if let track = appState.player.currentTrack, let trackId = track.id,
                   let favId = appState.db.getOrCreateFavorites().id {
                    if appState.db.isTrackInPlaylist(playlistId: favId, trackId: trackId) {
                        appState.db.removeTrackFromPlaylist(playlistId: favId, trackId: trackId)
                    } else {
                        appState.db.addTrackToPlaylist(playlistId: favId, trackId: trackId)
                    }
                }
            default: break
            }
            lastContextUpdate = .distantPast
            syncNowPlaying()
            replyHandler(["status": "ok"])

        case .playAlbum(let albumId, let startIndex):
            let tracks = appState.db.getAlbumTracks(albumId: albumId)
            if !tracks.isEmpty {
                appState.player.playAlbum(tracks, startIndex: startIndex)
            }
            replyHandler(["status": "ok"])

        case .playPlaylist(let playlistId):
            let tracks = appState.db.getPlaylistTracks(playlistId: playlistId)
            if !tracks.isEmpty {
                appState.player.setQueue(tracks, startIndex: 0)
            }
            replyHandler(["status": "ok"])

        case .shuffleAlbum(let albumId):
            let tracks = appState.db.getAlbumTracks(albumId: albumId)
            if !tracks.isEmpty {
                appState.player.playShuffled(tracks)
            }
            replyHandler(["status": "ok"])

        case .shufflePlaylist(let playlistId):
            let tracks = appState.db.getPlaylistTracks(playlistId: playlistId)
            if !tracks.isEmpty {
                appState.player.playShuffled(tracks)
            }
            replyHandler(["status": "ok"])

        case .playTrack(let albumId, let playlistId, let trackIndex):
            if let albumId {
                let tracks = appState.db.getAlbumTracks(albumId: albumId)
                if trackIndex < tracks.count {
                    appState.player.playAlbum(tracks, startIndex: trackIndex)
                }
            } else if let playlistId {
                let tracks = appState.db.getPlaylistTracks(playlistId: playlistId)
                if trackIndex < tracks.count {
                    appState.player.setQueue(tracks, startIndex: trackIndex)
                }
            }
            replyHandler(["status": "ok"])

        case .requestLibrary:
            syncLibrary()
            replyHandler(["status": "ok"])

        case .requestAlbumTracks(let albumId):
            let tracks = appState.db.getAlbumTracks(albumId: albumId).map {
                WatchTrack(id: $0.id!, title: $0.title, artist: $0.artist,
                           album: $0.album, duration: $0.duration, trackNumber: $0.trackNumber)
            }
            if let data = try? JSONEncoder().encode(tracks) {
                replyHandler(["tracks": data])
            } else {
                replyHandler(["tracks": Data()])
            }

        case .requestArtistAlbums(let artistName):
            let albums = appState.db.getArtistAlbums(artistName: artistName).map { album in
                let trackCount = appState.db.getAlbumTracks(albumId: album.id!).count
                return WatchAlbum(
                    id: album.id!, name: album.name, artist: album.albumArtist,
                    year: album.year, trackCount: trackCount
                )
            }
            if let data = try? JSONEncoder().encode(albums) {
                replyHandler(["albums": data])
            } else {
                replyHandler(["albums": Data()])
            }

        case .requestPlaylistTracks(let playlistId):
            let tracks = appState.db.getPlaylistTracks(playlistId: playlistId).map {
                WatchTrack(id: $0.id!, title: $0.title, artist: $0.artist,
                           album: $0.album, duration: $0.duration, trackNumber: $0.trackNumber)
            }
            if let data = try? JSONEncoder().encode(tracks) {
                replyHandler(["tracks": data])
            } else {
                replyHandler(["tracks": Data()])
            }

        case .unknown:
            replyHandler(["error": "unknown message"])
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isWatchReachable = reachable
            if reachable {
                self.syncNowPlaying()
                self.syncLibrary()
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isWatchReachable = reachable
            if reachable {
                self.lastContextUpdate = .distantPast
                self.syncNowPlaying()
                self.syncLibrary()
            }
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        let parsed = WatchMessageParser.parse(message)
        nonisolated(unsafe) let reply = replyHandler
        Task { @MainActor in
            self.handleParsedMessage(parsed, replyHandler: reply)
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        let parsed = WatchMessageParser.parse(message)
        Task { @MainActor in
            self.handleParsedMessage(parsed) { _ in }
        }
    }
}
