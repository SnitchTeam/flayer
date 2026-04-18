import WidgetKit
import SwiftUI

struct FullPageEntry: TimelineEntry {
    let date: Date
    let nowPlaying: NowPlayingInfo?
    let isPlaying: Bool
    let progress: Double
    let queue: [NowPlayingInfo]
    let albums: [Album]
    let artists: [Artist]
    let playlists: [Playlist]
    let playlistCovers: [Int64: String]
    let activeTab: Int  // 0=albums, 1=artists, 2=playlists
    let showPlayer: Bool
}

struct FullPageTimelineProvider: TimelineProvider {
    let dataProvider = WidgetDataProvider()

    func placeholder(in context: Context) -> FullPageEntry {
        FullPageEntry(date: .now, nowPlaying: nil, isPlaying: false, progress: 0,
                     queue: [], albums: [], artists: [], playlists: [],
                     playlistCovers: [:], activeTab: 0, showPlayer: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (FullPageEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FullPageEntry>) -> Void) {
        let entry = makeEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry() -> FullPageEntry {
        let defaults = UserDefaults(suiteName: WidgetState.suiteName)
        // Sync language from App Group
        if let lang = defaults?.string(forKey: "appLanguage") {
            Lang.current = lang
        }
        let nowPlaying = WidgetState.readNowPlaying()
        let isPlaying = WidgetState.readIsPlaying()
        let progress = WidgetState.readProgress()
        let queue = WidgetState.readQueue()
        var albums = dataProvider.getAllAlbums()
        var artists = dataProvider.getAllArtists()
        let allPlaylists = dataProvider.getAllPlaylists()
        let activeTab = defaults?.integer(forKey: "fullPageActiveTab") ?? 0
        let showPlayer = defaults?.bool(forKey: "fullPageShowPlayer") ?? false

        // Ensure cover art is accessible
        for i in albums.indices {
            albums[i].coverArtPath = accessibleCoverPath(albums[i].coverArtPath)
        }
        for i in artists.indices {
            artists[i].coverArtPath = accessibleCoverPath(artists[i].coverArtPath)
        }

        var covers: [Int64: String] = [:]
        for p in allPlaylists {
            if let id = p.id, let cover = dataProvider.getPlaylistCover(playlistId: id) {
                covers[id] = accessibleCoverPath(cover) ?? cover
            }
        }

        return FullPageEntry(date: .now, nowPlaying: nowPlaying, isPlaying: isPlaying,
                            progress: progress, queue: queue, albums: albums,
                            artists: artists, playlists: allPlaylists,
                            playlistCovers: covers, activeTab: activeTab,
                            showPlayer: showPlayer)
    }

    private func accessibleCoverPath(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        if FileManager.default.fileExists(atPath: path) { return path }
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetState.suiteName) else { return nil }
        let filename = URL(fileURLWithPath: path).lastPathComponent
        let sharedPath = groupURL.appendingPathComponent("CoverArt").appendingPathComponent(filename).path
        if FileManager.default.fileExists(atPath: sharedPath) { return sharedPath }
        return nil
    }
}
