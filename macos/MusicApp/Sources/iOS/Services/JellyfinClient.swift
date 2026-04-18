import Foundation
import UIKit

struct JellyfinArtist: Identifiable {
    let id: String
    let name: String
}

struct JellyfinAlbum: Identifiable {
    let id: String
    let name: String
    let artist: String
    let year: Int?
    let songCount: Int
}

struct JellyfinTrack: Identifiable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let track: Int?
    let disc: Int?
    let duration: Int
    let size: Int64
    let container: String
}

actor JellyfinClient: MusicSourceClient {
    private let config: ServerConfig
    private let password: String
    private var accessToken: String?
    private var userId: String?

    init(config: ServerConfig, password: String) {
        self.config = config
        self.password = password
        self.accessToken = config.apiToken
    }

    private var baseURL: String {
        var host = config.host.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !host.hasPrefix("http://") && !host.hasPrefix("https://") {
            host = "https://\(host)"
        }
        return host
    }

    private func authHeaders() async -> [String: String] {
        let deviceId = await UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        var headers = [
            "X-Emby-Client": "FlaYer",
            "X-Emby-Client-Version": "1.0",
            "X-Emby-Device-Name": "iPhone",
            "X-Emby-Device-Id": deviceId,
        ]
        if let token = accessToken {
            headers["X-Emby-Token"] = token
        }
        return headers
    }

    func testConnection() async throws -> Bool {
        _ = try await authenticate()
        return true
    }

    func authenticate() async throws -> String {
        guard let url = URL(string: "\(baseURL)/Users/AuthenticateByName") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in await authHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let body: [String: String] = ["Username": config.username ?? "", "Pw": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let token = json?["AccessToken"] as? String else {
            throw NSError(domain: "Jellyfin", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
        }
        let user = json?["User"] as? [String: Any]
        self.userId = user?["Id"] as? String
        self.accessToken = token
        return token
    }

    private func ensureAuth() async throws -> String {
        if accessToken == nil || userId == nil {
            _ = try await authenticate()
        }
        guard let uid = userId else {
            throw URLError(.userAuthenticationRequired)
        }
        return uid
    }

    private func get(_ path: String, params: [String: String] = [:]) async throws -> Any {
        if accessToken == nil { _ = try await authenticate() }

        var components = URLComponents(string: "\(baseURL)\(path)")
        if !params.isEmpty {
            components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        for (key, value) in await authHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONSerialization.jsonObject(with: data)
    }

    func ping() async throws -> Bool {
        _ = try await authenticate()
        return true
    }

    func getArtists() async throws -> [JellyfinArtist] {
        let userId = try await ensureAuth()
        let json = try await get("/Users/\(userId)/Items", params: [
            "IncludeItemTypes": "MusicArtist",
            "Recursive": "true",
            "SortBy": "SortName",
            "SortOrder": "Ascending"
        ]) as? [String: Any]
        let items = json?["Items"] as? [[String: Any]] ?? []
        return items.map { JellyfinArtist(id: $0["Id"] as? String ?? "", name: $0["Name"] as? String ?? "") }
    }

    func getAlbums(artistId: String) async throws -> [JellyfinAlbum] {
        let userId = try await ensureAuth()
        let json = try await get("/Users/\(userId)/Items", params: [
            "IncludeItemTypes": "MusicAlbum",
            "Recursive": "true",
            "AlbumArtistIds": artistId,
            "SortBy": "ProductionYear,SortName",
            "SortOrder": "Descending",
            "Fields": "ChildCount"
        ]) as? [String: Any]
        let items = json?["Items"] as? [[String: Any]] ?? []
        return items.map {
            JellyfinAlbum(id: $0["Id"] as? String ?? "", name: $0["Name"] as? String ?? "",
                          artist: $0["AlbumArtist"] as? String ?? "", year: $0["ProductionYear"] as? Int,
                          songCount: $0["ChildCount"] as? Int ?? 0)
        }
    }

    func getTracks(albumId: String) async throws -> [JellyfinTrack] {
        let userId = try await ensureAuth()
        let json = try await get("/Users/\(userId)/Items", params: [
            "ParentId": albumId,
            "IncludeItemTypes": "Audio",
            "SortBy": "ParentIndexNumber,IndexNumber",
            "Fields": "MediaSources"
        ]) as? [String: Any]
        let items = json?["Items"] as? [[String: Any]] ?? []
        return items.map { item in
            let mediaSources = item["MediaSources"] as? [[String: Any]]
            let src = mediaSources?.first
            return JellyfinTrack(
                id: item["Id"] as? String ?? "", title: item["Name"] as? String ?? "",
                artist: (item["Artists"] as? [String])?.first ?? "", album: item["Album"] as? String ?? "",
                track: item["IndexNumber"] as? Int, disc: item["ParentIndexNumber"] as? Int,
                duration: (item["RunTimeTicks"] as? Int ?? 0) / 10_000_000,
                size: (src?["Size"] as? Int64) ?? 0, container: src?["Container"] as? String ?? "")
        }
    }

    func downloadRequest(trackId: String) -> URLRequest? {
        guard let token = accessToken else { return nil }
        guard let url = URL(string: "\(baseURL)/Items/\(trackId)/Download") else { return nil }
        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        return request
    }

    func imageURL(itemId: String, size: Int = 600) -> URL? {
        URL(string: "\(baseURL)/Items/\(itemId)/Images/Primary?maxWidth=\(size)&maxHeight=\(size)")
    }
}
