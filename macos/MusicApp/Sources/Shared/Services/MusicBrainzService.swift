import Foundation
import os.log

private let mbLog = Logger(subsystem: "com.music.flayer", category: "MusicBrainz")

actor MusicBrainzService {
    private let rateLimiter = RateLimiter(requestsPerSecond: 1)
    private let session: URLSession
    private let baseURL = "https://musicbrainz.org/ws/2"

    struct MBRelease: Decodable, Identifiable {
        let id: String
        let score: Int?
        let title: String?
        let date: String?
        let country: String?
        let status: String?
        let labelInfo: [LabelInfo]?
        let releaseGroup: ReleaseGroup?
        let artistCredit: [ArtistCredit]?

        struct LabelInfo: Decodable {
            let label: Label?
            struct Label: Decodable { let name: String? }
        }
        struct ReleaseGroup: Decodable {
            let id: String?
            let primaryType: String?
            let genres: [Genre]?

            enum CodingKeys: String, CodingKey {
                case id
                case primaryType = "primary-type"
                case genres
            }
        }
        struct Genre: Decodable { let name: String?; let count: Int? }
        struct ArtistCredit: Decodable {
            let name: String?
        }

        enum CodingKeys: String, CodingKey {
            case id, score, title, date, country, status
            case labelInfo = "label-info"
            case releaseGroup = "release-group"
            case artistCredit = "artist-credit"
        }

        var labelName: String? { labelInfo?.first?.label?.name }
        var primaryGenre: String? { releaseGroup?.genres?.first?.name }
        var albumType: String? { releaseGroup?.primaryType }
        var releaseGroupId: String? { releaseGroup?.id }
        var artistName: String? { artistCredit?.compactMap(\.name).joined(separator: ", ") }
        var coverArtURL: URL? { URL(string: "https://coverartarchive.org/release/\(id)/front-250") }
        var coverArtFallbackURL: URL? {
            guard let rgid = releaseGroupId else { return nil }
            return URL(string: "https://coverartarchive.org/release-group/\(rgid)/front-250")
        }
        var yearFromDate: Int? {
            guard let date else { return nil }
            return Int(date.prefix(4))
        }
    }

    struct MBRecording: Decodable {
        let id: String
        let title: String?
        let releases: [MBRelease]?
    }

    struct MBArtist: Decodable {
        let id: String
        let name: String?
        let genres: [MBRelease.Genre]?
    }

    init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "FlaYer/1.1 (hi-fi-music-player)",
            "Accept": "application/json"
        ]
        self.session = URLSession(configuration: config)
    }

    func searchRelease(artist: String, album: String) async -> MBRelease? {
        mbLog.info("searchRelease: artist='\(artist, privacy: .private)' album='\(album, privacy: .private)'")
        let results = await searchReleases(artist: artist, album: album, minScore: 80)
        if let first = results.first {
            mbLog.info("searchRelease: FOUND '\(first.title ?? "?", privacy: .private)' (score=\((first.score ?? 0), privacy: .public), id=\(first.id, privacy: .public))")
        } else {
            mbLog.warning("searchRelease: NO MATCH for artist='\(artist, privacy: .private)' album='\(album, privacy: .private)'")
        }
        return results.first
    }

    func searchReleases(artist: String, album: String, limit: Int = 10, minScore: Int = 50) async -> [MBRelease] {
        // 1. Exact match
        let exact = await queryReleases(query: "release:\"\(album)\" AND artist:\"\(artist)\"", limit: limit, minScore: minScore)
        if !exact.isEmpty { return exact }

        // 2. Fuzzy artist (unquoted) — handles "IAMX" vs "I AM X", spacing variants
        let fuzzy = await queryReleases(query: "release:\"\(album)\" AND artist:\(artist)", limit: limit, minScore: minScore)
        if !fuzzy.isEmpty { return fuzzy }

        // 3. Alias search — MusicBrainz artistname: includes aliases
        let alias = await queryReleases(query: "release:\"\(album)\" AND artistname:\"\(artist)\"", limit: limit, minScore: minScore)
        if !alias.isEmpty { return alias }

        // 4. Album-only with lower limit as last resort
        return await queryReleases(query: "release:\"\(album)\"", limit: 5, minScore: max(minScore, 80))
    }

    private func queryReleases(query: String, limit: Int, minScore: Int) async -> [MBRelease] {
        await rateLimiter.wait()
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/release?query=\(encoded)&limit=\(limit)&fmt=json&inc=labels+release-groups+genres+artist-credits") else {
            mbLog.error("queryReleases: failed to build URL for query='\(query, privacy: .private)'")
            return []
        }
        mbLog.debug("queryReleases: GET \(url.absoluteString, privacy: .private)")
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                mbLog.error("queryReleases: non-HTTP response")
                return []
            }
            mbLog.debug("queryReleases: HTTP \(http.statusCode, privacy: .public), \(data.count, privacy: .public) bytes")
            guard http.statusCode == 200 else {
                mbLog.error("queryReleases: HTTP \(http.statusCode, privacy: .public) for query='\(query, privacy: .private)'")
                return []
            }
            struct Wrapper: Decodable { let releases: [MBRelease]? }
            guard let releases = (try? JSONDecoder().decode(Wrapper.self, from: data))?.releases else {
                mbLog.warning("queryReleases: decode failed or no releases array")
                return []
            }
            let filtered = releases.filter { ($0.score ?? 0) >= minScore }
            mbLog.info("queryReleases: \(releases.count, privacy: .public) results, \(filtered.count, privacy: .public) above minScore=\(minScore, privacy: .public)")
            return filtered
        } catch {
            mbLog.error("queryReleases: network error: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func searchRecording(artist: String, title: String) async -> MBRecording? {
        mbLog.info("searchRecording: artist='\(artist, privacy: .private)' title='\(title, privacy: .private)'")
        await rateLimiter.wait()
        let query = "recording:\"\(title)\" AND artist:\"\(artist)\""
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/recording?query=\(encoded)&limit=3&fmt=json&inc=releases") else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else { return nil }
            mbLog.debug("searchRecording: HTTP \(http.statusCode, privacy: .public), \(data.count, privacy: .public) bytes")
            guard http.statusCode == 200 else {
                mbLog.error("searchRecording: HTTP \(http.statusCode, privacy: .public)")
                return nil
            }
            struct Wrapper: Decodable { let recordings: [MBRecording]? }
            let result = (try? JSONDecoder().decode(Wrapper.self, from: data))?.recordings?.first
            if let r = result {
                mbLog.info("searchRecording: FOUND '\(r.title ?? "?", privacy: .private)' with \((r.releases?.count ?? 0), privacy: .public) releases")
            } else {
                mbLog.warning("searchRecording: NO MATCH")
            }
            return result
        } catch {
            mbLog.error("searchRecording: network error: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func getArtist(mbid: String) async -> MBArtist? {
        await rateLimiter.wait()
        guard let url = URL(string: "\(baseURL)/artist/\(mbid)?fmt=json&inc=genres") else { return nil }
        guard let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(MBArtist.self, from: data)
    }

    func searchArtist(name: String) async -> MBArtist? {
        await rateLimiter.wait()
        let query = "artist:\"\(name)\""
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/artist?query=\(encoded)&limit=1&fmt=json&inc=genres") else { return nil }
        guard let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        struct Wrapper: Decodable { let artists: [MBArtist]? }
        return (try? JSONDecoder().decode(Wrapper.self, from: data))?.artists?.first
    }

    /// Fetch artist photo URL via MusicBrainz → Wikidata → Wikipedia thumbnail
    func fetchArtistImageURL(artistMBID: String) async -> URL? {
        await rateLimiter.wait()
        mbLog.info("fetchArtistImage: looking up MBID=\(artistMBID, privacy: .public)")

        // 1. Get artist relations from MusicBrainz to find Wikidata URL
        guard let url = URL(string: "\(baseURL)/artist/\(artistMBID)?inc=url-rels&fmt=json"),
              let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            mbLog.warning("fetchArtistImage: failed to get relations for \(artistMBID, privacy: .public)")
            return nil
        }

        struct Relation: Decodable {
            let type: String?
            let url: RelURL?
            struct RelURL: Decodable { let resource: String? }
        }
        struct ArtistDetail: Decodable { let relations: [Relation]? }

        guard let detail = try? JSONDecoder().decode(ArtistDetail.self, from: data) else {
            mbLog.warning("fetchArtistImage: failed to decode relations for \(artistMBID, privacy: .public)")
            return nil
        }

        // Find Wikidata entity ID
        let wikidataURL = detail.relations?.first(where: { $0.type == "wikidata" })?.url?.resource
        guard let wikidataURL, let entityId = wikidataURL.components(separatedBy: "/").last else {
            mbLog.info("fetchArtistImage: no Wikidata link for \(artistMBID, privacy: .public)")
            return nil
        }
        mbLog.info("fetchArtistImage: Wikidata entity=\(entityId, privacy: .public)")

        // 2. Query Wikidata for the image filename — reuse our rate-limited
        // session so Wikimedia sees the same User-Agent and respects the
        // 1 req/s pacing shared with MusicBrainz (required by their bot policy).
        await rateLimiter.wait()
        guard let wdURL = URL(string: "https://www.wikidata.org/wiki/Special:EntityData/\(entityId).json"),
              let (wdData, wdResp) = try? await session.data(from: wdURL),
              let wdHttp = wdResp as? HTTPURLResponse, wdHttp.statusCode == 200 else {
            mbLog.warning("fetchArtistImage: Wikidata request failed for \(entityId, privacy: .public)")
            return nil
        }

        // Extract P18 (image) claim
        guard let json = try? JSONSerialization.jsonObject(with: wdData) as? [String: Any],
              let entities = json["entities"] as? [String: Any],
              let entity = entities[entityId] as? [String: Any],
              let claims = entity["claims"] as? [String: Any],
              let p18 = claims["P18"] as? [[String: Any]],
              let mainsnak = p18.first?["mainsnak"] as? [String: Any],
              let datavalue = mainsnak["datavalue"] as? [String: Any],
              let filename = datavalue["value"] as? String else {
            mbLog.info("fetchArtistImage: no P18 image claim for \(entityId, privacy: .public)")
            return nil
        }

        // 3. Build Wikipedia Commons thumbnail URL
        let sanitized = filename.replacingOccurrences(of: " ", with: "_")
        let encoded = sanitized.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sanitized
        let imageURL = URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/\(encoded)?width=500")
        mbLog.info("fetchArtistImage: found image → \(imageURL?.absoluteString ?? "nil", privacy: .private)")
        return imageURL
    }
}
