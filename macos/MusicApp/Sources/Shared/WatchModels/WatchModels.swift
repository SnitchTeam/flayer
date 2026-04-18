import Foundation

// MARK: - DTOs for WatchConnectivity (no GRDB dependency)

struct WatchTrack: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let trackNumber: Int?
}

struct WatchAlbum: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let name: String
    let artist: String
    let year: Int?
    let trackCount: Int
}

struct WatchArtist: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let name: String
    let albumCount: Int
}

struct WatchPlaylist: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let name: String
    let trackCount: Int
    let isFavorites: Bool
}

struct WatchNowPlaying: Codable, Sendable {
    let title: String
    let artist: String
    let album: String
    let isPlaying: Bool
    let isFavorite: Bool
    let position: Double
    let duration: Double
    let coverArtData: Data?
    let queueCount: Int
    let queueIndex: Int
    let shuffle: Bool
    let repeatMode: String
}

enum WatchCommand: String, Codable, Sendable {
    case playPause
    case next
    case previous
    case toggleFavorite
}
