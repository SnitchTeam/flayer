import Foundation
import GRDB

struct Track: Identifiable, Codable, Equatable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var path: String
    var title: String
    var artist: String
    var albumArtist: String
    var album: String
    var genre: String
    var year: Int?
    var trackNumber: Int?
    var discNumber: Int?
    var duration: Double
    var sampleRate: Int
    var bitDepth: Int
    var format: String
    var fileSize: Int64
    var dateAdded: Date
    var dateModified: Date
    var albumId: Int64?
    var artistId: Int64?
    var coverArtPath: String?
    var replaygainTrackGain: Double?
    var replaygainAlbumGain: Double?
    var lyrics: String?
    var musicbrainzId: String?

    static let databaseTableName = "tracks"

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id, path, title, artist
        case albumArtist = "album_artist"
        case album, genre, year
        case trackNumber = "track_number"
        case discNumber = "disc_number"
        case duration
        case sampleRate = "sample_rate"
        case bitDepth = "bit_depth"
        case format
        case fileSize = "file_size"
        case dateAdded = "date_added"
        case dateModified = "date_modified"
        case albumId = "album_id"
        case artistId = "artist_id"
        case coverArtPath = "cover_art_path"
        case replaygainTrackGain = "replaygain_track_gain"
        case replaygainAlbumGain = "replaygain_album_gain"
        case lyrics
        case musicbrainzId = "musicbrainz_id"
    }
}

struct Album: Identifiable, Codable, Equatable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var name: String
    var albumArtist: String
    var year: Int?
    var coverArtPath: String?
    var label: String?
    var country: String?
    var albumType: String?
    var musicbrainzId: String?

    static let databaseTableName = "albums"

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id, name
        case albumArtist = "album_artist"
        case year
        case coverArtPath = "cover_art_path"
        case label, country
        case albumType = "album_type"
        case musicbrainzId = "musicbrainz_id"
    }
}

struct Artist: Identifiable, Codable, Equatable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var name: String
    var coverArtPath: String?
    var musicbrainzId: String?

    static let databaseTableName = "artists"

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id, name
        case coverArtPath = "cover_art_path"
        case musicbrainzId = "musicbrainz_id"
    }
}

struct Playlist: Identifiable, Codable, Equatable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var name: String
    var isFavorites: Bool = false
    var isFavoriteAlbums: Bool = false
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "playlists"

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id, name
        case isFavorites = "is_favorites"
        case isFavoriteAlbums = "is_favorite_albums"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct PlaylistAlbum: Codable, FetchableRecord, PersistableRecord {
    var playlistId: Int64
    var albumId: Int64
    var position: Int

    static let databaseTableName = "playlist_albums"

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case playlistId = "playlist_id"
        case albumId = "album_id"
        case position
    }
}

struct PlaylistTrack: Codable, FetchableRecord, PersistableRecord {
    var playlistId: Int64
    var trackId: Int64
    var position: Int

    static let databaseTableName = "playlist_tracks"

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case playlistId = "playlist_id"
        case trackId = "track_id"
        case position
    }
}

struct AppSettings: Codable {
    var musicFolders: [String] = []
    var gridSize: String = "medium"
    var showTracks: Bool = false
    var showArtistLabel: Bool = true
    var gapless: Bool = true
    var replayGain: Bool = false
    var replayGainMode: String = "track"
    var exclusiveMode: Bool = false
    var showLetterNav: Bool = true
    var albumSort: String = "date_added"
    var artistSort: String = "az"
    var trackSort: String = "date_added"
    var outputDeviceUID: String = ""
    var eqEnabled: Bool = false
    var eqPresetId: String = ""
    var navPosition: String = "top"    // "bottom" or "top"
    var recentSearches: [String] = []
    var language: String = Locale.current.language.languageCode?.identifier == "fr" ? "fr" : "en"
    var autoOpenPlayer: Bool = true  // auto full-screen player on playback start
    var cacheQuotaGB: Int = 10  // 0 = unlimited
    var enableMusicBrainz: Bool = false
    var useAcoustID: Bool = true
    var autoEnrich: Bool = true
    var fetchCoverArt: Bool = true
    var fetchGenre: Bool = true
    var fetchYear: Bool = true
    var fetchLabel: Bool = true
    var fetchLyrics: Bool = true
    var fetchArtist: Bool = true
    var fetchAlbum: Bool = true
    var fetchTitle: Bool = true
    var hasCompletedOnboarding: Bool = false
}

struct ServerConfig: Identifiable, Codable {
    var id: String
    var type: String            // "smb", "subsonic", "jellyfin"
    var name: String
    var host: String
    var port: Int?
    var shareName: String?      // SMB only
    var username: String?
    var apiToken: String?       // Jellyfin only
    var createdAt: String?

    init(id: String = UUID().uuidString, type: String, name: String, host: String, port: Int? = nil,
         shareName: String? = nil, username: String? = nil, apiToken: String? = nil) {
        self.id = id
        self.type = type
        self.name = name
        self.host = host
        self.port = port
        self.shareName = shareName
        self.username = username
        self.apiToken = apiToken
        self.createdAt = ISO8601DateFormatter().string(from: Date())
    }
}

struct EnrichmentQueueItem: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var trackId: Int64?
    var albumId: Int64?
    var artistId: Int64?
    var status: String = "pending"
    var lastAttempt: String?
    var errorMessage: String?
    var createdAt: String = ""

    static let databaseTableName = "enrichment_queue"

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id
        case trackId = "track_id"
        case albumId = "album_id"
        case artistId = "artist_id"
        case status
        case lastAttempt = "last_attempt"
        case errorMessage = "error_message"
        case createdAt = "created_at"
    }
}
