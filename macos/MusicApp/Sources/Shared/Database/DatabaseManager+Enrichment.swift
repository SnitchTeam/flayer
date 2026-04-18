import Foundation
import GRDB

extension DatabaseManager {
    // MARK: - Enrichment Queue

    func enqueueEnrichment(trackId: Int64? = nil, albumId: Int64? = nil, artistId: Int64? = nil) {
        do {
            try dbQueue.write { db in
                // Avoid duplicates
                if let tid = trackId {
                    let exists = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM enrichment_queue WHERE track_id = ? AND status = 'pending'", arguments: [tid]) ?? 0
                    if exists > 0 { return }
                }
                try db.execute(
                    sql: "INSERT INTO enrichment_queue (track_id, album_id, artist_id, status, created_at) VALUES (?, ?, ?, 'pending', datetime('now'))",
                    arguments: [trackId, albumId, artistId]
                )
            }
        } catch { dbLog.error("enqueueEnrichment failed: \(error.localizedDescription, privacy: .public)") }
    }

    func getPendingEnrichments(limit: Int = 50) -> [EnrichmentQueueItem] {
        (try? dbQueue.read { db in
            try EnrichmentQueueItem
                .filter(Column("status") == "pending")
                .order(Column("created_at").asc)
                .limit(limit)
                .fetchAll(db)
        }) ?? []
    }

    func markEnrichmentDone(id: Int64) {
        try? dbQueue.write { db in
            try db.execute(sql: "UPDATE enrichment_queue SET status = 'done', last_attempt = datetime('now') WHERE id = ?", arguments: [id])
        }
    }

    func markEnrichmentFailed(id: Int64, error: String) {
        try? dbQueue.write { db in
            try db.execute(sql: "UPDATE enrichment_queue SET status = 'failed', last_attempt = datetime('now'), error_message = ? WHERE id = ?", arguments: [error, id])
        }
    }

    func clearEnrichmentQueue() {
        try? dbQueue.write { db in
            try db.execute(sql: "DELETE FROM enrichment_queue")
        }
    }

    func resetEnrichmentData() {
        try? dbQueue.write { db in
            try db.execute(sql: "UPDATE tracks SET musicbrainz_id = NULL")
            try db.execute(sql: "UPDATE albums SET musicbrainz_id = NULL")
            try db.execute(sql: "UPDATE artists SET musicbrainz_id = NULL")
        }
    }

    func getEnrichmentStats() -> (pending: Int, done: Int, failed: Int) {
        (try? dbQueue.read { db in
            let pending = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM enrichment_queue WHERE status = 'pending'") ?? 0
            let done = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM enrichment_queue WHERE status = 'done'") ?? 0
            let failed = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM enrichment_queue WHERE status = 'failed'") ?? 0
            return (pending, done, failed)
        }) ?? (0, 0, 0)
    }

    // MARK: - MusicBrainz Updates

    func getTrackById(_ id: Int64) -> Track? {
        try? dbQueue.read { db in
            try Track.filter(Column("id") == id).fetchOne(db)
        }
    }

    func updateTrackLyrics(trackId: Int64, lyrics: String) {
        try? dbQueue.write { db in
            try db.execute(sql: "UPDATE tracks SET lyrics = ? WHERE id = ?", arguments: [lyrics, trackId])
        }
        dbLog.info("updateTrackLyrics: track \(trackId, privacy: .public) saved \(lyrics.count, privacy: .public) chars")
    }

    func updateTrackMusicBrainzId(trackId: Int64, mbid: String) {
        try? dbQueue.write { db in
            try db.execute(sql: "UPDATE tracks SET musicbrainz_id = ? WHERE id = ?", arguments: [mbid, trackId])
        }
    }

    func updateTrackArtist(trackId: Int64, artist: String) {
        try? dbQueue.write { db in
            try db.execute(sql: "UPDATE tracks SET artist = ? WHERE id = ?", arguments: [artist, trackId])
        }
        dbLog.info("updateTrackArtist: track \(trackId, privacy: .public) → '\(artist, privacy: .private)'")
    }

    func updateTrackTitle(trackId: Int64, title: String) {
        try? dbQueue.write { db in
            try db.execute(sql: "UPDATE tracks SET title = ? WHERE id = ?", arguments: [title, trackId])
        }
        dbLog.info("updateTrackTitle: track \(trackId, privacy: .public) → '\(title, privacy: .private)'")
    }

    func updateAlbumMusicBrainz(albumId: Int64, label: String?, country: String?, albumType: String?, mbid: String?, genre: String? = nil, year: Int? = nil) {
        do {
            try dbQueue.write { db in
                var sets: [String] = []
                var args: [DatabaseValueConvertible?] = []
                if let label { sets.append("label = ?"); args.append(label) }
                if let country { sets.append("country = ?"); args.append(country) }
                if let albumType { sets.append("album_type = ?"); args.append(albumType) }
                if let mbid { sets.append("musicbrainz_id = ?"); args.append(mbid) }
                if let year { sets.append("year = COALESCE(year, ?)"); args.append(year) }
                guard !sets.isEmpty else { return }
                args.append(albumId)
                let sql = "UPDATE albums SET \(sets.joined(separator: ", ")) WHERE id = ?"
                try db.execute(sql: sql, arguments: StatementArguments(args))
                let changes = db.changesCount
                dbLog.info("updateAlbumMusicBrainz: albumId=\(albumId, privacy: .public) sets=[\(sets.joined(separator: ", "), privacy: .public)] changes=\(changes, privacy: .public)")

                // Update genre on tracks if provided and tracks have empty genre
                if let genre, !genre.isEmpty {
                    try db.execute(sql: "UPDATE tracks SET genre = ? WHERE album_id = ? AND (genre IS NULL OR genre = '')", arguments: [genre, albumId])
                    let genreChanges = db.changesCount
                    dbLog.info("updateAlbumMusicBrainz: genre='\(genre, privacy: .public)' updated \(genreChanges, privacy: .public) tracks")
                }
            }
        } catch {
            dbLog.error("updateAlbumMusicBrainz FAILED: \(error.localizedDescription, privacy: .public)")
        }
    }

    func updateAlbumCover(albumId: Int64, coverPath: String) {
        dbLog.info("updateAlbumCover: albumId=\(albumId, privacy: .public) path=\(coverPath, privacy: .private)")
        try? dbQueue.write { db in
            try db.execute(sql: "UPDATE albums SET cover_art_path = ? WHERE id = ?", arguments: [coverPath, albumId])
            try db.execute(sql: "UPDATE tracks SET cover_art_path = ? WHERE album_id = ?", arguments: [coverPath, albumId])
        }
    }

    /// Reassign a track to the correct album (creates album if needed), used when enrichment discovers the real album name
    func reassignTrackAlbum(trackId: Int64, newAlbumName: String, albumArtist: String, year: Int?, coverArtPath: String?) {
        do {
            let newAlbumId = try insertOrGetAlbum(name: newAlbumName, albumArtist: albumArtist, year: year, coverArtPath: coverArtPath)
            try dbQueue.write { db in
                try db.execute(sql: "UPDATE tracks SET album = ?, album_id = ? WHERE id = ?", arguments: [newAlbumName, newAlbumId, trackId])
            }
            // Clean up orphaned albums (old "Unknown Album" with no tracks left)
            try? dbQueue.write { db in
                try db.execute(sql: "DELETE FROM albums WHERE id NOT IN (SELECT DISTINCT album_id FROM tracks WHERE album_id IS NOT NULL)")
            }
            dbLog.info("reassignTrackAlbum: track \(trackId, privacy: .public) → album '\(newAlbumName, privacy: .private)' (id=\(newAlbumId, privacy: .public))")
        } catch {
            dbLog.error("reassignTrackAlbum FAILED: \(error.localizedDescription, privacy: .public)")
        }
    }

    func artistHasOwnPhoto(artistId: Int64) -> Bool {
        do {
            return try dbQueue.read { db in
                let row = try Row.fetchOne(db, sql: "SELECT cover_art_path FROM artists WHERE id = ?", arguments: [artistId])
                guard let path = row?["cover_art_path"] as String? else { return false }
                return !path.isEmpty
            }
        } catch { return false }
    }

    func updateArtistMusicBrainz(artistId: Int64, mbid: String?, coverPath: String?) {
        try? dbQueue.write { db in
            var sets: [String] = []
            var args: [DatabaseValueConvertible?] = []
            if let mbid { sets.append("musicbrainz_id = ?"); args.append(mbid) }
            if let coverPath { sets.append("cover_art_path = ?"); args.append(coverPath) }
            guard !sets.isEmpty else { return }
            args.append(artistId)
            try db.execute(sql: "UPDATE artists SET \(sets.joined(separator: ", ")) WHERE id = ?", arguments: StatementArguments(args))
        }
        dbLog.info("updateArtistMusicBrainz: artistId=\(artistId, privacy: .public) mbid=\(mbid ?? "nil", privacy: .public) coverPath=\(coverPath ?? "nil", privacy: .private)")
    }
}
