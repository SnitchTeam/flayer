import Foundation
import GRDB
import os.log

// Module-wide so DatabaseManager extensions in sibling files can log through
// the same Logger/category without redeclaring it.
let dbLog = Logger(subsystem: "com.music.flayer", category: "Database")

final class DatabaseManager: Sendable {
    let dbQueue: DatabaseQueue

    static let unaccent = DatabaseFunction("unaccent", argumentCount: 1, pure: true) { values in
        guard let string = String.fromDatabaseValue(values[0]) else { return nil }
        return string.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }

    static var sharedDatabaseURL: URL {
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.flayer") {
            return groupURL.appendingPathComponent("musicapp.db")
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("FlaYer/musicapp.db")
    }

    init() throws {
        let fm = FileManager.default
        let sharedURL = DatabaseManager.sharedDatabaseURL
        let sharedDir = sharedURL.deletingLastPathComponent()
        try fm.createDirectory(at: sharedDir, withIntermediateDirectories: true)

        // Migrate from old location if needed
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let oldPath = appSupport.appendingPathComponent("FlaYer/musicapp.db")
            if fm.fileExists(atPath: oldPath.path) && !fm.fileExists(atPath: sharedURL.path) {
                try? fm.copyItem(at: oldPath, to: sharedURL)
            }
        }

        var config = Configuration()
        config.prepareDatabase { db in
            db.add(function: DatabaseManager.unaccent)
        }
        dbQueue = try DatabaseQueue(path: sharedURL.path, configuration: config)
        try migrate()
    }

    // Migrations live in DatabaseManager+Migrations.swift

    // MARK: - Albums

    func getAllAlbums(sort: String = "date_added") -> [Album] {
        do {
            return try dbQueue.read { db in
                switch sort {
                case "alphabetical":
                    return try Album.order(Column("name").asc).fetchAll(db)
                case "year":
                    return try Album.order(Column("year").desc).fetchAll(db)
                default:
                    let sql = """
                        SELECT a.*, MAX(t.date_added) as latest_date_added
                        FROM albums a
                        JOIN tracks t ON t.album_id = a.id
                        GROUP BY a.id
                        ORDER BY latest_date_added DESC
                    """
                    return try Album.fetchAll(db, sql: sql)
                }
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)"); return [] }
    }

    func getAllAlbumsWithDate() -> [(Album, Date)] {
        do {
            return try dbQueue.read { db in
                let sql = """
                    SELECT a.*, MAX(t.date_added) as latest_date_added
                    FROM albums a
                    JOIN tracks t ON t.album_id = a.id
                    GROUP BY a.id
                    ORDER BY latest_date_added DESC
                """
                let rows = try Row.fetchAll(db, sql: sql)
                return try rows.compactMap { row in
                    guard let date = row["latest_date_added"] as Date? else { return nil }
                    return (try Album(row: row), date)
                }
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)"); return [] }
    }

    func getAlbumTracks(albumId: Int64) -> [Track] {
        do {
            return try dbQueue.read { db in
                let sql = """
                    SELECT t.*, a.cover_art_path FROM tracks t
                    LEFT JOIN albums a ON t.album_id = a.id
                    WHERE t.album_id = ?
                    ORDER BY COALESCE(t.disc_number, 1), COALESCE(t.track_number, 9999), t.title
                """
                return try Track.fetchAll(db, sql: sql, arguments: [albumId])
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)"); return [] }
    }

    func getAlbumsFormats(albumIds: [Int64]) -> [Int64: Set<String>] {
        guard !albumIds.isEmpty else { return [:] }
        do {
            return try dbQueue.read { db in
                let placeholders = albumIds.map { _ in "?" }.joined(separator: ",")
                let sql = "SELECT album_id, format FROM tracks WHERE album_id IN (\(placeholders)) AND format != ''"
                let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(albumIds))
                var result: [Int64: Set<String>] = [:]
                for row in rows {
                    if let albumId = row["album_id"] as Int64?,
                       let format = row["format"] as String? {
                        result[albumId, default: []].insert(format.uppercased())
                    }
                }
                return result
            }
        } catch { return [:] }
    }

    func getAlbum(id: Int64) -> Album? {
        do {
            return try dbQueue.read { db in
                try Album.fetchOne(db, key: id)
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)"); return nil }
    }

    func getArtist(id: Int64) -> Artist? {
        do {
            return try dbQueue.read { db in
                let sql = """
                    SELECT ar.id, ar.name,
                    COALESCE(ar.cover_art_path, (SELECT al.cover_art_path FROM albums al JOIN tracks t ON t.album_id = al.id WHERE t.artist_id = ar.id AND al.cover_art_path IS NOT NULL LIMIT 1)) as cover_art_path
                    FROM artists ar WHERE ar.id = ?
                """
                return try Artist.fetchOne(db, sql: sql, arguments: [id])
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)"); return nil }
    }

    func getArtistByName(_ name: String) -> Artist? {
        do {
            let normalized = name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            return try dbQueue.read { db in
                let sql = """
                    SELECT ar.id, ar.name,
                    COALESCE(ar.cover_art_path, (SELECT al.cover_art_path FROM albums al JOIN tracks t ON t.album_id = al.id WHERE t.artist_id = ar.id AND al.cover_art_path IS NOT NULL LIMIT 1)) as cover_art_path
                    FROM artists ar WHERE unaccent(ar.name) = ?
                """
                return try Artist.fetchOne(db, sql: sql, arguments: [normalized])
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)"); return nil }
    }

    // MARK: - Artists

    func getAllArtists(sort: String = "az") -> [Artist] {
        do {
            return try dbQueue.read { db in
                let sql: String
                if sort == "date_added" {
                    sql = """
                        SELECT ar.id, ar.name,
                        COALESCE(ar.cover_art_path, (SELECT al.cover_art_path FROM albums al JOIN tracks t2 ON t2.album_id = al.id WHERE t2.artist_id = ar.id AND al.cover_art_path IS NOT NULL LIMIT 1)) as cover_art_path
                        FROM artists ar
                        WHERE EXISTS (SELECT 1 FROM tracks t WHERE t.artist_id = ar.id)
                        GROUP BY ar.id
                        ORDER BY (SELECT MAX(t.date_added) FROM tracks t WHERE t.artist_id = ar.id) DESC
                    """
                } else {
                    sql = """
                        SELECT ar.id, ar.name,
                        COALESCE(ar.cover_art_path, (SELECT al.cover_art_path FROM albums al JOIN tracks t2 ON t2.album_id = al.id WHERE t2.artist_id = ar.id AND al.cover_art_path IS NOT NULL LIMIT 1)) as cover_art_path
                        FROM artists ar
                        WHERE EXISTS (SELECT 1 FROM tracks t WHERE t.artist_id = ar.id)
                        GROUP BY ar.id
                        ORDER BY ar.name ASC
                    """
                }
                return try Artist.fetchAll(db, sql: sql)
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)"); return [] }
    }

    func getAllArtistsWithDate() -> [(Artist, Date)] {
        do {
            return try dbQueue.read { db in
                let sql = """
                    SELECT ar.id, ar.name,
                    COALESCE(ar.cover_art_path, (SELECT al.cover_art_path FROM albums al JOIN tracks t2 ON t2.album_id = al.id WHERE t2.artist_id = ar.id AND al.cover_art_path IS NOT NULL LIMIT 1)) as cover_art_path,
                    MAX(t.date_added) as latest_date_added
                    FROM artists ar
                    JOIN tracks t ON t.artist_id = ar.id
                    GROUP BY ar.id
                    ORDER BY latest_date_added DESC
                """
                let rows = try Row.fetchAll(db, sql: sql)
                return try rows.compactMap { row in
                    guard let date = row["latest_date_added"] as Date? else { return nil }
                    return (try Artist(row: row), date)
                }
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)"); return [] }
    }

    func getArtistAlbums(artistName: String) -> [Album] {
        do {
            let normalized = artistName.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            return try dbQueue.read { db in
                // Find albums via tracks.artist_id (reliable), fallback to album_artist match
                let sql = """
                    SELECT DISTINCT al.* FROM albums al
                    WHERE al.id IN (
                        SELECT DISTINCT t.album_id FROM tracks t
                        JOIN artists ar ON t.artist_id = ar.id
                        WHERE unaccent(ar.name) = ?
                    )
                    OR unaccent(al.album_artist) = ?
                    ORDER BY al.year DESC
                """
                return try Album.fetchAll(db, sql: sql, arguments: [normalized, normalized])
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)"); return [] }
    }

    // MARK: - Tracks

    func getAllTracks(sort: String = "date_added") -> [Track] {
        do {
            return try dbQueue.read { db in
                let orderClause: String
                switch sort {
                case "alphabetical": orderClause = "ORDER BY t.title ASC"
                default: orderClause = "ORDER BY t.date_added DESC"
                }
                let sql = """
                    SELECT t.*, a.cover_art_path FROM tracks t
                    LEFT JOIN albums a ON t.album_id = a.id
                    \(orderClause)
                """
                return try Track.fetchAll(db, sql: sql)
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)"); return [] }
    }

    // MARK: - Search

    func search(query: String) -> (tracks: [Track], albums: [Album], artists: [Artist]) {
        let normalized = query.folding(options: .diacriticInsensitive, locale: .current)
        do {
            return try dbQueue.read { db in
                // FTS5 with unicode61 remove_diacritics handles accent-insensitive matching
                let escaped = normalized.replacingOccurrences(of: "\"", with: "\"\"")
                let pattern = "\"\(escaped)\"*"
                let tracksSql = """
                    SELECT t.*, a.cover_art_path FROM tracks t
                    LEFT JOIN albums a ON t.album_id = a.id
                    JOIN tracks_fts fts ON fts.rowid = t.id
                    WHERE tracks_fts MATCH ?
                    ORDER BY rank LIMIT 50
                """
                let tracks = try Track.fetchAll(db, sql: tracksSql, arguments: [pattern])

                // Use unaccent() for accent-insensitive LIKE on albums/artists
                let likePattern = "%\(normalized)%"
                let albumsSql = """
                    SELECT * FROM albums
                    WHERE unaccent(name) LIKE ?
                    ORDER BY name LIMIT 20
                """
                let albums = try Album.fetchAll(db, sql: albumsSql, arguments: [likePattern])

                let artistsSql = """
                    SELECT ar.id, ar.name,
                    COALESCE(ar.cover_art_path, (SELECT al.cover_art_path FROM albums al JOIN tracks t2 ON t2.album_id = al.id WHERE t2.artist_id = ar.id AND al.cover_art_path IS NOT NULL LIMIT 1)) as cover_art_path
                    FROM artists ar
                    WHERE unaccent(ar.name) LIKE ?
                    AND EXISTS (SELECT 1 FROM tracks t WHERE t.artist_id = ar.id)
                    LIMIT 20
                """
                let artists = try Artist.fetchAll(db, sql: artistsSql, arguments: [likePattern])

                return (tracks, albums, artists)
            }
        } catch { return ([], [], []) }
    }

    // MARK: - Playlists

    func getPlaylists() -> [Playlist] {
        do {
            return try dbQueue.read { db in
                try Playlist.order(Column("updated_at").desc).fetchAll(db)
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)"); return [] }
    }

    func createPlaylist(name: String) -> Playlist? {
        do {
            return try dbQueue.write { db in
                let playlist = Playlist(name: name, createdAt: Date(), updatedAt: Date())
                try playlist.insert(db)
                return playlist
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)"); return nil }
    }

    func getOrCreateFavorites() -> Playlist {
        if let existing = getPlaylists().first(where: { $0.isFavorites }) {
            return existing
        }
        let name = Lang.current == "fr" ? "Favoris" : "Favorites"
        do {
            return try dbQueue.write { db in
                var playlist = Playlist(name: name, isFavorites: true, createdAt: Date(), updatedAt: Date())
                try playlist.insert(db)
                return playlist
            }
        } catch {
            return Playlist(name: name, isFavorites: true, createdAt: Date(), updatedAt: Date())
        }
    }

    // MARK: - Album Favorites

    func getOrCreateFavoriteAlbums() -> Playlist {
        if let existing = getPlaylists().first(where: { $0.isFavoriteAlbums }) {
            return existing
        }
        let name = Lang.current == "fr" ? "Albums Favoris" : "Favorite Albums"
        do {
            return try dbQueue.write { db in
                var playlist = Playlist(name: name, isFavoriteAlbums: true, createdAt: Date(), updatedAt: Date())
                try playlist.insert(db)
                return playlist
            }
        } catch {
            return Playlist(name: name, isFavoriteAlbums: true, createdAt: Date(), updatedAt: Date())
        }
    }

    func isAlbumFavorite(albumId: Int64) -> Bool {
        guard let favId = getPlaylists().first(where: { $0.isFavoriteAlbums })?.id else { return false }
        do {
            return try dbQueue.read { db in
                try PlaylistAlbum.filter(Column("playlist_id") == favId && Column("album_id") == albumId).fetchCount(db) > 0
            }
        } catch { return false }
    }

    func addAlbumToFavorites(albumId: Int64) {
        let favId = getOrCreateFavoriteAlbums().id!
        do {
            try dbQueue.write { db in
                let exists = try Bool.fetchOne(db, sql: "SELECT COUNT(*) > 0 FROM playlist_albums WHERE playlist_id = ? AND album_id = ?", arguments: [favId, albumId]) ?? false
                guard !exists else { return }
                let maxPos = try Int.fetchOne(db, sql: "SELECT MAX(position) FROM playlist_albums WHERE playlist_id = ?", arguments: [favId]) ?? 0
                let pa = PlaylistAlbum(playlistId: favId, albumId: albumId, position: maxPos + 1)
                try pa.insert(db)
                try db.execute(sql: "UPDATE playlists SET updated_at = ? WHERE id = ?", arguments: [Date(), favId])
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)") }
    }

    func removeAlbumFromFavorites(albumId: Int64) {
        guard let favId = getPlaylists().first(where: { $0.isFavoriteAlbums })?.id else { return }
        do {
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM playlist_albums WHERE playlist_id = ? AND album_id = ?", arguments: [favId, albumId])
                try db.execute(sql: "UPDATE playlists SET updated_at = ? WHERE id = ?", arguments: [Date(), favId])
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)") }
    }

    func isTrackInFavorites(trackId: Int64) -> Bool {
        guard let favId = getPlaylists().first(where: { $0.isFavorites })?.id else { return false }
        return isTrackInPlaylist(playlistId: favId, trackId: trackId)
    }

    func isTrackInPlaylist(playlistId: Int64, trackId: Int64) -> Bool {
        do {
            return try dbQueue.read { db in
                try PlaylistTrack.filter(Column("playlist_id") == playlistId && Column("track_id") == trackId).fetchCount(db) > 0
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)"); return false }
    }

    func removeTrackFromPlaylist(playlistId: Int64, trackId: Int64) {
        do {
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM playlist_tracks WHERE playlist_id = ? AND track_id = ?", arguments: [playlistId, trackId])
                try db.execute(sql: "UPDATE playlists SET updated_at = ? WHERE id = ?", arguments: [Date(), playlistId])
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)") }
    }

    func addTrackToPlaylist(playlistId: Int64, trackId: Int64) {
        do {
            try dbQueue.write { db in
                // Check if already in playlist
                let exists = try Bool.fetchOne(db, sql: "SELECT COUNT(*) > 0 FROM playlist_tracks WHERE playlist_id = ? AND track_id = ?", arguments: [playlistId, trackId]) ?? false
                guard !exists else { return }
                let maxPos = try Int.fetchOne(db, sql: "SELECT MAX(position) FROM playlist_tracks WHERE playlist_id = ?", arguments: [playlistId]) ?? 0
                let pt = PlaylistTrack(playlistId: playlistId, trackId: trackId, position: maxPos + 1)
                try pt.insert(db)
                try db.execute(sql: "UPDATE playlists SET updated_at = ? WHERE id = ?", arguments: [Date(), playlistId])
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)") }
    }

    func deletePlaylist(id: Int64) {
        do {
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM playlist_tracks WHERE playlist_id = ?", arguments: [id])
                try db.execute(sql: "DELETE FROM playlists WHERE id = ?", arguments: [id])
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)") }
    }

    func getPlaylistTracks(playlistId: Int64) -> [Track] {
        do {
            return try dbQueue.read { db in
                let sql = """
                    SELECT t.*, a.cover_art_path FROM tracks t
                    LEFT JOIN albums a ON t.album_id = a.id
                    JOIN playlist_tracks pt ON pt.track_id = t.id
                    WHERE pt.playlist_id = ?
                    ORDER BY pt.position
                """
                return try Track.fetchAll(db, sql: sql, arguments: [playlistId])
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)"); return [] }
    }

    func getPlaylistCover(playlistId: Int64) -> String? {
        do {
            return try dbQueue.read { db in
                let sql = """
                    SELECT COALESCE(t.cover_art_path, a.cover_art_path) as cover
                    FROM playlist_tracks pt
                    JOIN tracks t ON t.id = pt.track_id
                    LEFT JOIN albums a ON t.album_id = a.id
                    WHERE pt.playlist_id = ?
                    ORDER BY pt.position
                    LIMIT 1
                """
                return try String.fetchOne(db, sql: sql, arguments: [playlistId])
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)"); return nil }
    }

    // MARK: - Library Stats

    func getLibraryStats() -> (tracks: Int, albums: Int, artists: Int, totalSize: Int64) {
        do {
            return try dbQueue.read { db in
                let trackCount = try Track.fetchCount(db)
                let albumCount = try Album.fetchCount(db)
                let artistCount = try Artist.fetchCount(db)
                let totalSize = try Int64.fetchOne(db, sql: "SELECT COALESCE(SUM(file_size), 0) FROM tracks") ?? 0
                return (trackCount, albumCount, artistCount, totalSize)
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)"); return (0, 0, 0, 0) }
    }

    // MARK: - Cleanup

    func removeOrphanedTracks() {
        do {
            try dbQueue.write { db in
                let rows = try Row.fetchAll(db, sql: "SELECT id, path FROM tracks")
                let fm = FileManager.default
                let orphanedIds: [Int64] = rows.compactMap { row in
                    guard let id = row["id"] as Int64?,
                          let path = row["path"] as String?,
                          !fm.fileExists(atPath: path) else { return nil }
                    // Check if it's an iCloud placeholder — don't delete those
                    let url = URL(fileURLWithPath: path)
                    let dir = url.deletingLastPathComponent()
                    let icloudName = ".\(url.lastPathComponent).icloud"
                    if fm.fileExists(atPath: dir.appendingPathComponent(icloudName).path) { return nil }
                    return id
                }
                guard !orphanedIds.isEmpty else { return }
                let placeholders = orphanedIds.map { _ in "?" }.joined(separator: ",")
                let args = StatementArguments(orphanedIds)
                try db.execute(sql: "DELETE FROM playlist_tracks WHERE track_id IN (\(placeholders))", arguments: args)
                try db.execute(sql: "DELETE FROM tracks WHERE id IN (\(placeholders))", arguments: args)
                // Remove albums with no tracks
                try db.execute(sql: "DELETE FROM albums WHERE id NOT IN (SELECT DISTINCT album_id FROM tracks WHERE album_id IS NOT NULL)")
                // Remove artists with no tracks
                try db.execute(sql: "DELETE FROM artists WHERE id NOT IN (SELECT DISTINCT artist_id FROM tracks WHERE artist_id IS NOT NULL)")
            }
            // Reclaim disk used by now-unreferenced downloaded cover art.
            cleanupOrphanedCoverArt()
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)") }
    }

    /// Default CoverArt cache directory (app group when available, else
    /// `~/Library/Caches/CoverArt`). Matches MetadataEnricher.coverCacheDirectory
    /// so files downloaded by enrichment can be located for cleanup.
    static var defaultCoverArtCacheURL: URL {
        let base: URL
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.flayer") {
            base = groupURL
        } else {
            base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
        }
        return base.appendingPathComponent("CoverArt")
    }

    /// Delete cover-art files on disk that are no longer referenced by any
    /// album or artist row. `directory` is typically the per-process
    /// CoverArt cache (app group container or Caches/CoverArt). Safe to call
    /// after removeOrphanedTracks() to reclaim disk space left over when
    /// rescans delete albums.
    func cleanupOrphanedCoverArt(in directory: URL = DatabaseManager.defaultCoverArtCacheURL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { return }
        let referenced: Set<String> = (try? dbQueue.read { db in
            let albumPaths = try String.fetchAll(db, sql: "SELECT cover_art_path FROM albums WHERE cover_art_path IS NOT NULL")
            let artistPaths = try String.fetchAll(db, sql: "SELECT cover_art_path FROM artists WHERE cover_art_path IS NOT NULL")
            let trackPaths = try String.fetchAll(db, sql: "SELECT cover_art_path FROM tracks WHERE cover_art_path IS NOT NULL")
            return Set(albumPaths + artistPaths + trackPaths)
        }) ?? []

        guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        var removed = 0
        var reclaimed: Int64 = 0
        for file in files {
            if !referenced.contains(file.path) {
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                try? fm.removeItem(at: file)
                removed += 1
                reclaimed += Int64(size)
            }
        }
        dbLog.info("cleanupOrphanedCoverArt: removed \(removed, privacy: .public) files, reclaimed \(reclaimed, privacy: .public) bytes")
    }

    /// Remove all tracks whose path starts with the given folder prefix, plus orphaned albums/artists
    func removeTracksInFolder(_ folderPath: String) {
        do {
            try dbQueue.write { db in
                // Ensure trailing slash for prefix match
                let prefix = folderPath.hasSuffix("/") ? folderPath : folderPath + "/"
                let trackIds = try Int64.fetchAll(db, sql: "SELECT id FROM tracks WHERE path LIKE ? || '%'", arguments: [prefix])
                guard !trackIds.isEmpty else { return }
                let placeholders = trackIds.map { _ in "?" }.joined(separator: ",")
                let args = StatementArguments(trackIds)
                try db.execute(sql: "DELETE FROM playlist_tracks WHERE track_id IN (\(placeholders))", arguments: args)
                try db.execute(sql: "DELETE FROM tracks WHERE id IN (\(placeholders))", arguments: args)
                // Remove albums with no tracks
                try db.execute(sql: "DELETE FROM albums WHERE id NOT IN (SELECT DISTINCT album_id FROM tracks WHERE album_id IS NOT NULL)")
                // Remove artists with no tracks
                try db.execute(sql: "DELETE FROM artists WHERE id NOT IN (SELECT DISTINCT artist_id FROM tracks WHERE artist_id IS NOT NULL)")
            }
        } catch { dbLog.error("DB error: \(error.localizedDescription, privacy: .public)") }
    }

    /// Migrate all track paths from an old folder prefix to a new one (e.g. when iOS resolves a bookmark to a different container path)
    func migrateTrackPaths(from oldPrefix: String, to newPrefix: String) {
        let oldP = oldPrefix.hasSuffix("/") ? oldPrefix : oldPrefix + "/"
        let newP = newPrefix.hasSuffix("/") ? newPrefix : newPrefix + "/"
        guard oldP != newP else { return }
        // SQLite LIKE treats `%` and `_` as wildcards and `\` as the escape char
        // when ESCAPE is set. A folder name containing any of these (legal on iOS)
        // would otherwise match unrelated rows and silently rewrite their paths.
        let escaped = oldP
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        do {
            try dbQueue.write { db in
                let rows = try Row.fetchAll(
                    db,
                    sql: "SELECT id, path FROM tracks WHERE path LIKE ? || '%' ESCAPE '\\'",
                    arguments: [escaped]
                )
                for row in rows {
                    guard let id = row["id"] as Int64?,
                          let path = row["path"] as String?,
                          path.hasPrefix(oldP) else { continue }
                    let newPath = newP + path.dropFirst(oldP.count)
                    try db.execute(sql: "UPDATE tracks SET path = ? WHERE id = ?", arguments: [newPath, id])
                }
            }
        } catch { dbLog.error("migrateTrackPaths failed: \(error.localizedDescription, privacy: .public)") }
    }

    // MARK: - Insert (Scanner)

    /// Extract the primary artist from strings like "Artist feat. Other", "A, B & C", "A / B"
    static func primaryArtist(_ name: String) -> String {
        // Split on common multi-artist separators (case-insensitive)
        let separators = [" feat. ", " feat ", " ft. ", " ft ", " featuring ", " Feat. ", " Feat ", " Ft. ", " Ft ",
                          " vs. ", " vs ", " & ", " / ", ", ", " x ", " X "]
        var primary = name
        for sep in separators {
            if let range = primary.range(of: sep, options: .caseInsensitive) {
                primary = String(primary[primary.startIndex..<range.lowerBound])
                break
            }
        }
        return primary.trimmingCharacters(in: .whitespaces)
    }

    func insertOrGetArtist(name: String) throws -> Int64 {
        let primary = DatabaseManager.primaryArtist(name)
        return try dbQueue.write { db in
            // Exact match first
            if let existing = try Artist.filter(Column("name") == primary).fetchOne(db), let id = existing.id {
                return id
            }
            // Diacritics-insensitive match (e.g. "Royksopp" matches "Röyksopp")
            let normalized = primary.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            if let existing = try Artist.fetchOne(db, sql: "SELECT * FROM artists WHERE unaccent(name) = ?", arguments: [normalized]),
               let id = existing.id {
                return id
            }
            let artist = Artist(name: primary)
            try artist.insert(db)
            return db.lastInsertedRowID
        }
    }

    func insertOrGetAlbum(name: String, albumArtist: String, year: Int?, coverArtPath: String?) throws -> Int64 {
        let primary = DatabaseManager.primaryArtist(albumArtist)
        return try dbQueue.write { db in
            // Exact match first, then diacritics-insensitive fallback
            let existing: Album?
            if let exact = try Album.filter(Column("name") == name && Column("album_artist") == primary).fetchOne(db) {
                existing = exact
            } else {
                let normalizedArtist = primary.folding(options: .diacriticInsensitive, locale: .current).lowercased()
                existing = try Album.fetchOne(db, sql: "SELECT * FROM albums WHERE name = ? AND unaccent(album_artist) = ?", arguments: [name, normalizedArtist])
            }
            if let existing, let id = existing.id {
                var updates: [String] = []
                var args: [DatabaseValueConvertible?] = []
                // Only update cover art if album was NOT manually enriched (no musicbrainz_id)
                if existing.musicbrainzId == nil, let coverArtPath, existing.coverArtPath != coverArtPath {
                    updates.append("cover_art_path = ?")
                    args.append(coverArtPath)
                }
                if let year, existing.year == nil {
                    updates.append("year = ?")
                    args.append(year)
                }
                if !updates.isEmpty {
                    args.append(id)
                    try db.execute(sql: "UPDATE albums SET \(updates.joined(separator: ", ")) WHERE id = ?", arguments: StatementArguments(args))
                }
                return id
            }
            let album = Album(name: name, albumArtist: primary, year: year, coverArtPath: coverArtPath)
            try album.insert(db)
            return db.lastInsertedRowID
        }
    }

    func insertTrack(_ track: Track) throws {
        try dbQueue.write { db in
            if let existing = try Track.filter(Column("path") == track.path).fetchOne(db), let existingId = existing.id {
                // Preserve enriched metadata (cover, genre) if track was manually enriched
                let coverPath = existing.musicbrainzId != nil ? existing.coverArtPath : track.coverArtPath
                let genre = (existing.musicbrainzId != nil && !existing.genre.isEmpty) ? existing.genre : track.genre
                try db.execute(
                    sql: """
                        UPDATE tracks SET title = ?, artist = ?, album_artist = ?, album = ?,
                        genre = ?, year = ?, track_number = ?, disc_number = ?, duration = ?,
                        sample_rate = ?, bit_depth = ?, format = ?, file_size = ?,
                        date_modified = ?, album_id = ?, artist_id = ?, cover_art_path = ?,
                        replaygain_track_gain = ?, replaygain_album_gain = ?
                        WHERE id = ?
                        """,
                    arguments: [
                        track.title, track.artist, track.albumArtist, track.album,
                        genre, track.year, track.trackNumber, track.discNumber, track.duration,
                        track.sampleRate, track.bitDepth, track.format, track.fileSize,
                        track.dateModified, track.albumId, track.artistId, coverPath,
                        track.replaygainTrackGain, track.replaygainAlbumGain,
                        existingId
                    ]
                )
            } else {
                let t = track
                try t.insert(db)
            }
        }
    }

}
