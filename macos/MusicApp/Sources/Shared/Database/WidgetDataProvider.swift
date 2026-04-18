import Foundation
import GRDB

struct WidgetDataProvider {
    private let dbQueue: DatabaseQueue?

    private static var databaseURL: URL {
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.flayer") {
            return groupURL.appendingPathComponent("musicapp.db")
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("FlaYer/musicapp.db")
    }

    init() {
        let url = Self.databaseURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            dbQueue = nil
            return
        }
        var config = Configuration()
        config.readonly = true
        dbQueue = try? DatabaseQueue(path: url.path, configuration: config)
    }

    func getRecentAlbums(limit: Int = 4) -> [Album] {
        guard let dbQueue else { return [] }
        return (try? dbQueue.read { db in
            try Album.order(sql: "id DESC").limit(limit).fetchAll(db)
        }) ?? []
    }

    func getRecentPlaylists(limit: Int = 3) -> [Playlist] {
        guard let dbQueue else { return [] }
        return (try? dbQueue.read { db in
            try Playlist
                .filter(Column("is_favorites") == false)
                .order(Column("updated_at").desc)
                .limit(limit)
                .fetchAll(db)
        }) ?? []
    }

    func getFavorites() -> Playlist? {
        guard let dbQueue else { return nil }
        return try? dbQueue.read { db in
            try Playlist.filter(Column("is_favorites") == true).fetchOne(db)
        }
    }

    func getAllAlbums() -> [Album] {
        guard let dbQueue else { return [] }
        return (try? dbQueue.read { db in
            try Album.order(sql: "id DESC").fetchAll(db)
        }) ?? []
    }

    func getAllArtists() -> [Artist] {
        guard let dbQueue else { return [] }
        return (try? dbQueue.read { db in
            try Artist.order(Column("name").asc).fetchAll(db)
        }) ?? []
    }

    func getAllPlaylists() -> [Playlist] {
        guard let dbQueue else { return [] }
        return (try? dbQueue.read { db in
            try Playlist.order(Column("updated_at").desc).fetchAll(db)
        }) ?? []
    }

    func getPlaylistCover(playlistId: Int64) -> String? {
        guard let dbQueue else { return nil }
        return try? dbQueue.read { db in
            try String.fetchOne(db, sql: """
                SELECT t.cover_art_path FROM tracks t
                JOIN playlist_tracks pt ON pt.track_id = t.id
                WHERE pt.playlist_id = ? AND t.cover_art_path IS NOT NULL
                ORDER BY pt.position LIMIT 1
            """, arguments: [playlistId])
        }
    }

    func getArtistAlbumCount(_ artistName: String) -> Int {
        guard let dbQueue else { return 0 }
        return (try? dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM albums WHERE album_artist = ?", arguments: [artistName])
        }) ?? 0
    }
}
