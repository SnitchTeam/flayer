import Foundation
import CryptoKit

struct SubsonicArtist: Identifiable {
    let id: String
    let name: String
    let albumCount: Int
    let coverArtId: String?
}

struct SubsonicAlbum: Identifiable {
    let id: String
    let name: String
    let artist: String
    let year: Int?
    let songCount: Int
    let coverArtId: String?
}

struct SubsonicTrack: Identifiable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let track: Int?
    let disc: Int?
    let duration: Int
    let size: Int64
    let suffix: String
    let bitRate: Int?
    let coverArtId: String?
}

actor SubsonicClient: MusicSourceClient {
    private let config: ServerConfig
    private let password: String

    init(config: ServerConfig, password: String) {
        self.config = config
        self.password = password
    }

    private var baseURL: String {
        var host = config.host.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !host.hasPrefix("http://") && !host.hasPrefix("https://") {
            host = "https://\(host)"
        }
        return host
    }

    private func buildURL(method: String, params: [String: String] = [:]) -> URL? {
        let salt = UUID().uuidString.prefix(8)
        let token = Insecure.MD5.hash(data: Data((password + salt).utf8))
            .map { String(format: "%02x", $0) }.joined()

        var components = URLComponents(string: "\(baseURL)/rest/\(method)")
        var queryItems = [
            URLQueryItem(name: "u", value: config.username ?? ""),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: String(salt)),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "FlaYer"),
            URLQueryItem(name: "f", value: "json"),
        ]
        for (key, value) in params {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        components?.queryItems = queryItems
        return components?.url
    }

    func testConnection() async throws -> Bool {
        try await ping()
    }

    func ping() async throws -> Bool {
        guard let url = buildURL(method: "ping") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let response = json?["subsonic-response"] as? [String: Any]
        return response?["status"] as? String == "ok"
    }

    func getArtists() async throws -> [SubsonicArtist] {
        guard let url = buildURL(method: "getArtists") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let response = json?["subsonic-response"] as? [String: Any]
        let artists = response?["artists"] as? [String: Any]
        let indexes = artists?["index"] as? [[String: Any]] ?? []

        var result: [SubsonicArtist] = []
        for index in indexes {
            let artistList = index["artist"] as? [[String: Any]] ?? []
            for a in artistList {
                result.append(SubsonicArtist(
                    id: a["id"] as? String ?? "",
                    name: a["name"] as? String ?? "",
                    albumCount: a["albumCount"] as? Int ?? 0,
                    coverArtId: a["coverArt"] as? String
                ))
            }
        }
        return result
    }

    func getArtist(id: String) async throws -> [SubsonicAlbum] {
        guard let url = buildURL(method: "getArtist", params: ["id": id]) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let response = json?["subsonic-response"] as? [String: Any]
        let artist = response?["artist"] as? [String: Any]
        let albums = artist?["album"] as? [[String: Any]] ?? []

        return albums.map { a in
            SubsonicAlbum(
                id: a["id"] as? String ?? "",
                name: a["name"] as? String ?? "",
                artist: a["artist"] as? String ?? "",
                year: a["year"] as? Int,
                songCount: a["songCount"] as? Int ?? 0,
                coverArtId: a["coverArt"] as? String
            )
        }
    }

    func getAlbum(id: String) async throws -> [SubsonicTrack] {
        guard let url = buildURL(method: "getAlbum", params: ["id": id]) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let response = json?["subsonic-response"] as? [String: Any]
        let album = response?["album"] as? [String: Any]
        let songs = album?["song"] as? [[String: Any]] ?? []

        return songs.map { s in
            SubsonicTrack(
                id: s["id"] as? String ?? "",
                title: s["title"] as? String ?? "",
                artist: s["artist"] as? String ?? "",
                album: s["album"] as? String ?? "",
                track: s["track"] as? Int,
                disc: s["discNumber"] as? Int,
                duration: s["duration"] as? Int ?? 0,
                size: (s["size"] as? Int64) ?? Int64(s["size"] as? Int ?? 0),
                suffix: s["suffix"] as? String ?? "",
                bitRate: s["bitRate"] as? Int,
                coverArtId: s["coverArt"] as? String
            )
        }
    }

    func downloadURL(trackId: String) -> URL? {
        buildURL(method: "download", params: ["id": trackId])
    }

    func coverArtURL(id: String, size: Int = 600) -> URL? {
        buildURL(method: "getCoverArt", params: ["id": id, "size": String(size)])
    }
}
