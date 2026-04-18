import Foundation

actor LyricsService {
    private let rateLimiter = RateLimiter(requestsPerSecond: 2)
    private let session: URLSession
    private let baseURL = "https://lrclib.net/api"

    struct LyricsResult: Decodable {
        let syncedLyrics: String?
        let plainLyrics: String?
    }

    init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": "FlaYer/1.1 (hi-fi-music-player)"]
        self.session = URLSession(configuration: config)
    }

    func fetchLyrics(artist: String, title: String, album: String, duration: Double) async -> LyricsResult? {
        await rateLimiter.wait()
        guard var components = URLComponents(string: "\(baseURL)/get") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "album_name", value: album),
            URLQueryItem(name: "duration", value: String(Int(duration)))
        ]
        guard let url = components.url else { return nil }
        guard let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(LyricsResult.self, from: data)
    }

    func searchLyrics(artist: String, title: String) async -> LyricsResult? {
        await rateLimiter.wait()
        guard var components = URLComponents(string: "\(baseURL)/search") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: title)
        ]
        guard let url = components.url else { return nil }
        guard let (data, _) = try? await session.data(from: url) else { return nil }
        let results = try? JSONDecoder().decode([LyricsResult].self, from: data)
        return results?.first
    }
}
