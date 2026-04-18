import Foundation
import GRDB

extension DatabaseManager {
    func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "artists", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull().unique()
            }
            try db.create(table: "albums", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("album_artist", .text).notNull().defaults(to: "")
                t.column("year", .integer)
                t.column("cover_art_path", .text)
                t.uniqueKey(["name", "album_artist"])
            }
            try db.create(table: "tracks", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("path", .text).notNull().unique()
                t.column("title", .text).notNull()
                t.column("artist", .text).notNull().defaults(to: "")
                t.column("album_artist", .text).notNull().defaults(to: "")
                t.column("album", .text).notNull().defaults(to: "")
                t.column("genre", .text).notNull().defaults(to: "")
                t.column("year", .integer)
                t.column("track_number", .integer)
                t.column("disc_number", .integer)
                t.column("duration", .double).notNull().defaults(to: 0)
                t.column("sample_rate", .integer).notNull().defaults(to: 0)
                t.column("bit_depth", .integer).notNull().defaults(to: 0)
                t.column("format", .text).notNull().defaults(to: "")
                t.column("file_size", .integer).notNull().defaults(to: 0)
                t.column("date_added", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("date_modified", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("album_id", .integer).references("albums")
                t.column("artist_id", .integer).references("artists")
            }
            try db.create(table: "playlists", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("created_at", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updated_at", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }
            try db.create(table: "playlist_tracks", ifNotExists: true) { t in
                t.column("playlist_id", .integer).notNull().references("playlists", onDelete: .cascade)
                t.column("track_id", .integer).notNull().references("tracks", onDelete: .cascade)
                t.column("position", .integer).notNull()
                t.primaryKey(["playlist_id", "track_id"])
            }
            // FTS for search
            try db.create(virtualTable: "tracks_fts", ifNotExists: true, using: FTS5()) { t in
                t.synchronize(withTable: "tracks")
                t.column("title")
                t.column("artist")
                t.column("album")
                t.column("genre")
            }
        }
        migrator.registerMigration("v2") { db in
            try db.alter(table: "artists") { t in
                t.add(column: "cover_art_path", .text)
            }
            try db.alter(table: "tracks") { t in
                t.add(column: "cover_art_path", .text)
            }
        }
        migrator.registerMigration("v3") { db in
            // Recreate FTS with unicode61 remove_diacritics 2 for accent-insensitive search
            try db.execute(sql: "DROP TRIGGER IF EXISTS __tracks_fts_ai")
            try db.execute(sql: "DROP TRIGGER IF EXISTS __tracks_fts_ad")
            try db.execute(sql: "DROP TRIGGER IF EXISTS __tracks_fts_au")
            try db.execute(sql: "DROP TABLE IF EXISTS tracks_fts")
            try db.execute(sql: """
                CREATE VIRTUAL TABLE tracks_fts USING fts5(
                    title, artist, album, genre,
                    content=tracks, content_rowid=id,
                    tokenize='unicode61 remove_diacritics 2'
                )
            """)
            // Populate FTS index
            try db.execute(sql: """
                INSERT INTO tracks_fts(rowid, title, artist, album, genre)
                SELECT id, title, artist, album, genre FROM tracks
            """)
            // Recreate sync triggers
            try db.execute(sql: """
                CREATE TRIGGER tracks_fts_ai AFTER INSERT ON tracks BEGIN
                    INSERT INTO tracks_fts(rowid, title, artist, album, genre)
                    VALUES (new.id, new.title, new.artist, new.album, new.genre);
                END
            """)
            try db.execute(sql: """
                CREATE TRIGGER tracks_fts_ad AFTER DELETE ON tracks BEGIN
                    INSERT INTO tracks_fts(tracks_fts, rowid, title, artist, album, genre)
                    VALUES ('delete', old.id, old.title, old.artist, old.album, old.genre);
                END
            """)
            try db.execute(sql: """
                CREATE TRIGGER tracks_fts_au AFTER UPDATE ON tracks BEGIN
                    INSERT INTO tracks_fts(tracks_fts, rowid, title, artist, album, genre)
                    VALUES ('delete', old.id, old.title, old.artist, old.album, old.genre);
                    INSERT INTO tracks_fts(rowid, title, artist, album, genre)
                    VALUES (new.id, new.title, new.artist, new.album, new.genre);
                END
            """)
        }
        migrator.registerMigration("v4") { db in
            try db.alter(table: "playlists") { t in
                t.add(column: "is_favorites", .boolean).notNull().defaults(to: false)
            }
            // Mark existing "Favoris" playlist
            try db.execute(sql: "UPDATE playlists SET is_favorites = 1 WHERE name = 'Favoris'")
        }
        migrator.registerMigration("v5") { db in
            try db.create(index: "idx_tracks_album_id", on: "tracks", columns: ["album_id"], ifNotExists: true)
            try db.create(index: "idx_tracks_artist_id", on: "tracks", columns: ["artist_id"], ifNotExists: true)
            try db.create(index: "idx_albums_album_artist", on: "albums", columns: ["album_artist"], ifNotExists: true)
        }
        migrator.registerMigration("v6") { db in
            try db.alter(table: "tracks") { t in
                t.add(column: "replaygain_track_gain", .double)
                t.add(column: "replaygain_album_gain", .double)
            }
        }
        migrator.registerMigration("v7") { db in
            try db.create(table: "server_configs") { t in
                t.column("id", .text).primaryKey()
                t.column("type", .text).notNull()
                t.column("name", .text).notNull()
                t.column("host", .text).notNull()
                t.column("port", .integer)
                t.column("share_name", .text)
                t.column("username", .text)
                t.column("api_token", .text)
                t.column("created_at", .text)
            }

            try db.create(table: "cached_files") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("source_type", .text).notNull()
                t.column("source_id", .text)
                t.column("remote_path", .text)
                t.column("local_path", .text).notNull()
                t.column("track_id", .integer).references("tracks", onDelete: .cascade)
                t.column("file_size", .integer)
                t.column("is_cached", .integer).notNull().defaults(to: 1)
                t.column("is_pinned", .integer).notNull().defaults(to: 0)
                t.column("last_accessed", .text)
                t.column("download_date", .text)
            }
        }
        migrator.registerMigration("v8_musicbrainz") { db in
            try db.alter(table: "tracks") { t in
                t.add(column: "lyrics", .text)
                t.add(column: "musicbrainz_id", .text)
            }
            try db.alter(table: "albums") { t in
                t.add(column: "label", .text)
                t.add(column: "country", .text)
                t.add(column: "album_type", .text)
                t.add(column: "musicbrainz_id", .text)
            }
            try db.alter(table: "artists") { t in
                t.add(column: "musicbrainz_id", .text)
            }
            try db.create(table: "enrichment_queue") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("track_id", .integer).references("tracks", onDelete: .cascade)
                t.column("album_id", .integer).references("albums", onDelete: .cascade)
                t.column("artist_id", .integer).references("artists", onDelete: .cascade)
                t.column("status", .text).notNull().defaults(to: "pending")
                t.column("last_attempt", .text)
                t.column("error_message", .text)
                t.column("created_at", .text).notNull().defaults(sql: "(datetime('now'))")
            }
        }
        migrator.registerMigration("v9_favorite_albums") { db in
            try db.create(table: "playlist_albums", ifNotExists: true) { t in
                t.column("playlist_id", .integer).notNull().references("playlists", onDelete: .cascade)
                t.column("album_id", .integer).notNull().references("albums", onDelete: .cascade)
                t.column("position", .integer).notNull()
                t.primaryKey(["playlist_id", "album_id"])
            }
            try db.alter(table: "playlists") { t in
                t.add(column: "is_favorite_albums", .boolean).notNull().defaults(to: false)
            }
        }
        try migrator.migrate(dbQueue)
    }
}
