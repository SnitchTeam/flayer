import WatchConnectivity
import Foundation

@Observable
@MainActor
final class WatchSessionManager: NSObject {
    var nowPlaying: WatchNowPlaying?
    var albums: [WatchAlbum] = []
    var artists: [WatchArtist] = []
    var playlists: [WatchPlaylist] = []
    var isConnected = false

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Send Commands

    func sendCommand(_ command: WatchCommand) {
        guard WCSession.default.isReachable else {
            isConnected = false
            return
        }
        WCSession.default.sendMessage(
            ["type": "command", "command": command.rawValue],
            replyHandler: { _ in },
            errorHandler: { [weak self] _ in
                Task { @MainActor in self?.isConnected = false }
            }
        )
    }

    func playAlbum(id: Int64, startIndex: Int = 0) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            ["type": "playAlbum", "albumId": id, "startIndex": startIndex],
            replyHandler: { _ in }, errorHandler: { _ in }
        )
    }

    func shuffleAlbum(id: Int64) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            ["type": "shuffleAlbum", "albumId": id],
            replyHandler: { _ in }, errorHandler: { _ in }
        )
    }

    func playPlaylist(id: Int64) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            ["type": "playPlaylist", "playlistId": id],
            replyHandler: { _ in }, errorHandler: { _ in }
        )
    }

    func shufflePlaylist(id: Int64) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            ["type": "shufflePlaylist", "playlistId": id],
            replyHandler: { _ in }, errorHandler: { _ in }
        )
    }

    func playTrack(albumId: Int64, trackIndex: Int) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            ["type": "playTrack", "albumId": albumId, "trackIndex": trackIndex],
            replyHandler: { _ in }, errorHandler: { _ in }
        )
    }

    func playTrackInPlaylist(playlistId: Int64, trackIndex: Int) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            ["type": "playTrack", "playlistId": playlistId, "trackIndex": trackIndex],
            replyHandler: { _ in }, errorHandler: { _ in }
        )
    }

    // MARK: - Request Data

    func requestLibrarySync() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            ["type": "requestLibrary"],
            replyHandler: { _ in }, errorHandler: { _ in }
        )
    }

    func requestAlbumTracks(albumId: Int64, completion: @escaping @MainActor ([WatchTrack]) -> Void) {
        guard WCSession.default.isReachable else {
            completion([])
            return
        }
        WCSession.default.sendMessage(
            ["type": "requestAlbumTracks", "albumId": albumId],
            replyHandler: { reply in
                if let data = reply["tracks"] as? Data,
                   let tracks = try? JSONDecoder().decode([WatchTrack].self, from: data) {
                    Task { @MainActor in completion(tracks) }
                } else {
                    Task { @MainActor in completion([]) }
                }
            },
            errorHandler: { _ in Task { @MainActor in completion([]) } }
        )
    }

    func requestArtistAlbums(artistName: String, completion: @escaping @MainActor ([WatchAlbum]) -> Void) {
        guard WCSession.default.isReachable else {
            completion([])
            return
        }
        WCSession.default.sendMessage(
            ["type": "requestArtistAlbums", "artistName": artistName],
            replyHandler: { reply in
                if let data = reply["albums"] as? Data,
                   let albums = try? JSONDecoder().decode([WatchAlbum].self, from: data) {
                    Task { @MainActor in completion(albums) }
                } else {
                    Task { @MainActor in completion([]) }
                }
            },
            errorHandler: { _ in Task { @MainActor in completion([]) } }
        )
    }

    func requestPlaylistTracks(playlistId: Int64, completion: @escaping @MainActor ([WatchTrack]) -> Void) {
        guard WCSession.default.isReachable else {
            completion([])
            return
        }
        WCSession.default.sendMessage(
            ["type": "requestPlaylistTracks", "playlistId": playlistId],
            replyHandler: { reply in
                if let data = reply["tracks"] as? Data,
                   let tracks = try? JSONDecoder().decode([WatchTrack].self, from: data) {
                    Task { @MainActor in completion(tracks) }
                } else {
                    Task { @MainActor in completion([]) }
                }
            },
            errorHandler: { _ in Task { @MainActor in completion([]) } }
        )
    }

    // MARK: - Decode Incoming Data

    private func decodeNowPlaying(_ data: Data) {
        guard let np = try? JSONDecoder().decode(WatchNowPlaying.self, from: data) else { return }
        nowPlaying = np
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        let reachable = session.isReachable
        let payload = session.receivedApplicationContext["payload"] as? Data
        Task { @MainActor in
            self.isConnected = reachable
            if let payload {
                self.decodeNowPlaying(payload)
            }
            if self.albums.isEmpty {
                self.requestLibrarySync()
            }
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext context: [String: Any]) {
        let payload = context["payload"] as? Data
        Task { @MainActor in
            self.isConnected = true
            if let payload {
                self.decodeNowPlaying(payload)
            }
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let type = userInfo["type"] as? String
        let albumsData = userInfo["albums"] as? Data
        let artistsData = userInfo["artists"] as? Data
        let playlistsData = userInfo["playlists"] as? Data
        Task { @MainActor in
            guard type == "librarySync" else { return }
            if let data = albumsData,
               let decoded = try? JSONDecoder().decode([WatchAlbum].self, from: data) {
                self.albums = decoded
            }
            if let data = artistsData,
               let decoded = try? JSONDecoder().decode([WatchArtist].self, from: data) {
                self.artists = decoded
            }
            if let data = playlistsData,
               let decoded = try? JSONDecoder().decode([WatchPlaylist].self, from: data) {
                self.playlists = decoded
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isConnected = reachable
        }
    }
}
