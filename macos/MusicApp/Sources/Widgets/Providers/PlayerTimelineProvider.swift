import WidgetKit
import SwiftUI

struct PlayerEntry: TimelineEntry {
    let date: Date
    let nowPlaying: NowPlayingInfo?
    let isPlaying: Bool
    let progress: Double
    let isFavorite: Bool
    let queue: [NowPlayingInfo]
    let recentAlbums: [Album]
    let playlists: [Playlist]
    let playlistCovers: [Int64: String]
}

struct PlayerTimelineProvider: TimelineProvider {
    let dataProvider = WidgetDataProvider()

    func placeholder(in context: Context) -> PlayerEntry {
        PlayerEntry(date: .now, nowPlaying: nil, isPlaying: false, progress: 0,
                   isFavorite: false, queue: [], recentAlbums: [], playlists: [], playlistCovers: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (PlayerEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlayerEntry>) -> Void) {
        let entry = makeEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry() -> PlayerEntry {
        // Sync language from App Group
        if let lang = UserDefaults(suiteName: WidgetState.suiteName)?.string(forKey: "appLanguage") {
            Lang.current = lang
        }
        let nowPlaying = WidgetState.readNowPlaying()
        let isPlaying = WidgetState.readIsPlaying()
        let progress = WidgetState.readProgress()
        let isFavorite = WidgetState.readIsFavorite()
        let queue = WidgetState.readQueue()
        var albums = dataProvider.getRecentAlbums(limit: 4)

        // Ensure cover art is accessible in App Group
        for i in albums.indices {
            albums[i].coverArtPath = accessibleCoverPath(albums[i].coverArtPath)
        }

        var playlists: [Playlist] = []
        if let fav = dataProvider.getFavorites() { playlists.append(fav) }
        playlists.append(contentsOf: dataProvider.getRecentPlaylists(limit: 3))

        var covers: [Int64: String] = [:]
        for p in playlists {
            if let id = p.id, let cover = dataProvider.getPlaylistCover(playlistId: id) {
                covers[id] = accessibleCoverPath(cover) ?? cover
            }
        }

        return PlayerEntry(date: .now, nowPlaying: nowPlaying, isPlaying: isPlaying,
                          progress: progress, isFavorite: isFavorite, queue: queue,
                          recentAlbums: albums, playlists: playlists, playlistCovers: covers)
    }

    /// Returns a path accessible by the widget extension
    private func accessibleCoverPath(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        // If file exists at path, it's already accessible
        if FileManager.default.fileExists(atPath: path) { return path }
        // Try to find same filename in App Group CoverArt dir
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetState.suiteName) else { return nil }
        let filename = URL(fileURLWithPath: path).lastPathComponent
        let sharedPath = groupURL.appendingPathComponent("CoverArt").appendingPathComponent(filename).path
        if FileManager.default.fileExists(atPath: sharedPath) { return sharedPath }
        return nil
    }
}
