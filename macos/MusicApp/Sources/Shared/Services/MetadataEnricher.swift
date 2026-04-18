import Foundation
import os.log

private let enrichLog = Logger(subsystem: "com.music.flayer", category: "Enricher")

@Observable
@MainActor
final class MetadataEnricher {
    var isEnriching = false
    var enrichProgress: String = ""
    var enrichCount = 0
    var enrichTotal = 0
    var coversFound = 0
    var lyricsFound = 0
    var metadataEnriched = 0
    private var cancelled = false

    private let db: DatabaseManager
    private let musicBrainz = MusicBrainzService()
    private let coverArt = CoverArtArchiveService()
    private let lyricsService = LyricsService()
    private let useAcoustID: Bool
    var settings: AppSettings

    init(db: DatabaseManager, useAcoustID: Bool, settings: AppSettings = AppSettings()) {
        self.db = db
        self.useAcoustID = useAcoustID
        self.settings = settings
    }

    func queueMissingData() {
        let tracks = db.getAllTracks()
        var queued = 0, skippedEnriched = 0, skippedComplete = 0, skippedHasData = 0
        for track in tracks {
            if track.musicbrainzId != nil { skippedEnriched += 1; continue }

            // Skip tracks that already have embedded artwork AND proper metadata
            let hasArtwork = track.coverArtPath != nil && !track.coverArtPath!.isEmpty
            let hasProperArtist = !track.artist.isEmpty && track.artist != Lang.unknownArtist
            let hasProperAlbum = !track.album.isEmpty && track.album != Lang.unknownAlbum
            let hasProperTitle = !track.title.contains(" - ") && !track.title.isEmpty
            if hasArtwork && hasProperArtist && hasProperAlbum && hasProperTitle && !track.genre.isEmpty && track.year != nil {
                skippedHasData += 1
                continue
            }

            let needsCover = settings.fetchCoverArt && !hasArtwork
            let needsGenre = settings.fetchGenre && track.genre.isEmpty
            let needsLyrics = settings.fetchLyrics && track.lyrics == nil
            let needsYear = settings.fetchYear && track.year == nil
            let needsArtist = settings.fetchArtist && !hasProperArtist
            let needsAlbum = settings.fetchAlbum && !hasProperAlbum
            let needsTitle = settings.fetchTitle && track.title.contains(" - ")
            if needsCover || needsGenre || needsLyrics || needsYear || needsArtist || needsAlbum || needsTitle {
                if let id = track.id {
                    db.enqueueEnrichment(trackId: id)
                    queued += 1
                }
            } else {
                skippedComplete += 1
            }
        }
        enrichLog.info("queueMissingData: \(tracks.count, privacy: .public) tracks total, \(queued, privacy: .public) queued, \(skippedEnriched, privacy: .public) already enriched, \(skippedHasData, privacy: .public) skipped (has data), \(skippedComplete, privacy: .public) already complete")
        enrichLog.info("Settings: coverArt=\(self.settings.fetchCoverArt, privacy: .public) genre=\(self.settings.fetchGenre, privacy: .public) lyrics=\(self.settings.fetchLyrics, privacy: .public) year=\(self.settings.fetchYear, privacy: .public) artist=\(self.settings.fetchArtist, privacy: .public) album=\(self.settings.fetchAlbum, privacy: .public) title=\(self.settings.fetchTitle, privacy: .public)")
    }

    /// Parse filename patterns like "Artist - Album - Title", "Artist - Title", "01 - Title"
    private func parseFilename(_ path: String) -> (artist: String?, album: String?, title: String?) {
        let filename = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let parts = filename.components(separatedBy: " - ")
        if parts.count >= 3 {
            let first = parts[0].trimmingCharacters(in: .whitespaces)
            let second = parts[1].trimmingCharacters(in: .whitespaces)
            let rest = parts[2...].joined(separator: " - ").trimmingCharacters(in: .whitespaces)
            // "01 - Artist - Title" (first is track number)
            if first.allSatisfy({ $0.isNumber }) {
                return (artist: second, album: nil, title: rest)
            }
            // "Artist - Album - Title"
            return (artist: first, album: second, title: rest)
        }
        if parts.count == 2 {
            let first = parts[0].trimmingCharacters(in: .whitespaces)
            let second = parts[1].trimmingCharacters(in: .whitespaces)
            if first.allSatisfy({ $0.isNumber }) {
                return (artist: nil, album: nil, title: second)
            }
            return (artist: first, album: nil, title: second)
        }
        return (artist: nil, album: nil, title: nil)
    }

    func cancelEnrichment() {
        cancelled = true
    }

    var onTrackEnriched: (() -> Void)?

    func processQueue() async {
        isEnriching = true
        cancelled = false
        coversFound = 0; lyricsFound = 0; metadataEnriched = 0

        let pending = db.getPendingEnrichments(limit: 500)
        enrichTotal = pending.count
        enrichCount = 0
        enrichLog.info("processQueue: \(pending.count, privacy: .public) pending items")

        // Cache: albumId → (releaseMBID, releaseGroupMBID) already resolved this run
        var albumMBIDCache: [Int64: String?] = [:]
        var albumRGIDCache: [Int64: String?] = [:]
        var artistPhotoCache: [Int64: Bool] = [:] // artistId → already attempted

        for item in pending {
            guard !Task.isCancelled && !cancelled else { break }
            enrichCount += 1

            if let trackId = item.trackId, let queueId = item.id {
                let prevCovers = coversFound
                let prevMeta = metadataEnriched
                let prevLyrics = lyricsFound
                await enrichTrack(trackId: trackId, queueId: queueId, albumMBIDCache: &albumMBIDCache, albumRGIDCache: &albumRGIDCache, artistPhotoCache: &artistPhotoCache)
                if coversFound > prevCovers || metadataEnriched > prevMeta || lyricsFound > prevLyrics {
                    onTrackEnriched?()
                }
            }
        }

        isEnriching = false
        enrichProgress = cancelled ? Lang.enrichCancelled : Lang.enrichComplete
        enrichLog.info("processQueue DONE: \(self.enrichTotal, privacy: .public) processed, \(self.metadataEnriched, privacy: .public) enriched, \(self.coversFound, privacy: .public) covers, \(self.lyricsFound, privacy: .public) lyrics")
    }

    private func enrichTrack(trackId: Int64, queueId: Int64, albumMBIDCache: inout [Int64: String?], albumRGIDCache: inout [Int64: String?], artistPhotoCache: inout [Int64: Bool]) async {
        guard let track = db.getTrackById(trackId) else {
            enrichLog.error("enrichTrack: track \(trackId, privacy: .public) not found in DB")
            db.markEnrichmentFailed(id: queueId, error: "Track not found")
            return
        }
        enrichLog.info("enrichTrack: [\(trackId, privacy: .public)] artist='\(track.artist, privacy: .public)' album='\(track.album, privacy: .public)' title='\(track.title, privacy: .public)'")

        // Show album name in progress (album-level enrichment)
        if let albumId = track.albumId, let album = db.getAlbum(id: albumId) {
            enrichProgress = "\(album.albumArtist) — \(album.name)"
        } else {
            enrichProgress = track.title
        }

        // Determine search artist/album/title — use filename parsing as fallback
        var searchArtist = track.artist
        var searchTitle = track.title
        var searchAlbum = track.album
        let parsed = parseFilename(track.path)
        if searchArtist.isEmpty || searchArtist == Lang.unknownArtist {
            if let a = parsed.artist, !a.isEmpty { searchArtist = a }
            if let t = parsed.title, !t.isEmpty { searchTitle = t }
            enrichLog.info("enrichTrack: filename fallback → artist='\(searchArtist, privacy: .public)' title='\(searchTitle, privacy: .public)'")
        }
        if searchAlbum.isEmpty || searchAlbum == Lang.unknownAlbum {
            if let al = parsed.album, !al.isEmpty { searchAlbum = al }
            enrichLog.info("enrichTrack: filename fallback → album='\(searchAlbum, privacy: .public)'")
        }

        // 1. Resolve album MBID (reuse if another track from same album already resolved it)
        var releaseMBID: String?
        var releaseGroupMBID: String?
        if let albumId = track.albumId, let cached = albumMBIDCache[albumId] {
            releaseMBID = cached
            releaseGroupMBID = albumRGIDCache[albumId] ?? nil
            enrichLog.debug("enrichTrack: album \(albumId, privacy: .public) cached MBID=\(cached ?? "nil", privacy: .public)")
            if let mbid = cached {
                db.updateTrackMusicBrainzId(trackId: trackId, mbid: mbid)
            }
        } else {
            // Check if album was already enriched in a previous run
            if let albumId = track.albumId, let album = db.getAlbum(id: albumId), album.musicbrainzId != nil {
                releaseMBID = album.musicbrainzId
                enrichLog.info("enrichTrack: album already has MBID=\(album.musicbrainzId!, privacy: .public)")
                db.updateTrackMusicBrainzId(trackId: trackId, mbid: album.musicbrainzId!)
                albumMBIDCache[albumId] = album.musicbrainzId
            } else {
                // Search MusicBrainz by artist+album
                var release: MusicBrainzService.MBRelease?
                if !searchAlbum.isEmpty && searchAlbum != Lang.unknownAlbum {
                    enrichLog.info("enrichTrack: searching release artist='\(searchArtist, privacy: .public)' album='\(searchAlbum, privacy: .public)'")
                    release = await musicBrainz.searchRelease(artist: searchArtist, album: searchAlbum)
                } else {
                    enrichLog.info("enrichTrack: album empty/unknown, skipping release search")
                }
                // Fallback: search by recording (artist+title) to find a release
                if release == nil && !searchArtist.isEmpty {
                    enrichLog.info("enrichTrack: fallback recording search artist='\(searchArtist, privacy: .public)' title='\(searchTitle, privacy: .public)'")
                    if let recording = await musicBrainz.searchRecording(artist: searchArtist, title: searchTitle) {
                        release = recording.releases?.first
                        if release != nil {
                            enrichLog.info("enrichTrack: recording fallback found release")
                        }
                    }
                }

                if let release {
                    let label = settings.fetchLabel ? release.labelName : nil
                    let year = settings.fetchYear ? release.yearFromDate : nil
                    var genre = settings.fetchGenre ? release.primaryGenre : nil
                    if genre == nil && settings.fetchGenre && !searchArtist.isEmpty {
                        genre = await fetchArtistGenre(artist: searchArtist)
                        if let g = genre { enrichLog.info("enrichTrack: artist genre fallback → '\(g, privacy: .public)'") }
                    }
                    enrichLog.info("enrichTrack: MATCHED release '\(release.title ?? "?", privacy: .public)' id=\(release.id, privacy: .public) rgid=\(release.releaseGroupId ?? "nil", privacy: .public) label=\(label ?? "nil", privacy: .public) year=\(String(describing: year), privacy: .public) genre=\(genre ?? "nil", privacy: .public) country=\(release.country ?? "nil", privacy: .public) type=\(release.albumType ?? "nil", privacy: .public)")
                    releaseMBID = release.id
                    releaseGroupMBID = release.releaseGroupId

                    // Update artist from MusicBrainz if unknown and fetchArtist enabled
                    if settings.fetchArtist,
                       let mbArtist = release.artistName, !mbArtist.isEmpty,
                       (track.artist.isEmpty || track.artist == Lang.unknownArtist) {
                        enrichLog.info("enrichTrack: updating artist '\(track.artist, privacy: .public)' → '\(mbArtist, privacy: .public)'")
                        db.updateTrackArtist(trackId: trackId, artist: mbArtist)
                    }

                    // Update title from filename parsing if it looks like raw filename and fetchTitle enabled
                    if settings.fetchTitle, let parsedTitle = parsed.title, !parsedTitle.isEmpty,
                       track.title.contains(" - ") {
                        enrichLog.info("enrichTrack: updating title '\(track.title, privacy: .public)' → '\(parsedTitle, privacy: .public)'")
                        db.updateTrackTitle(trackId: trackId, title: parsedTitle)
                    }

                    // If album was "Unknown", reassign track to the correct album from MusicBrainz
                    if settings.fetchAlbum, let releaseTitle = release.title, !releaseTitle.isEmpty,
                       (track.album.isEmpty || track.album == Lang.unknownAlbum) {
                        enrichLog.info("enrichTrack: reassigning from '\(track.album, privacy: .public)' → '\(releaseTitle, privacy: .public)'")
                        db.reassignTrackAlbum(
                            trackId: trackId,
                            newAlbumName: releaseTitle,
                            albumArtist: track.albumArtist.isEmpty ? (release.artistName ?? searchArtist) : track.albumArtist,
                            year: year,
                            coverArtPath: nil
                        )
                        // Refresh track to get new albumId
                        if let refreshed = db.getTrackById(trackId), let newAlbumId = refreshed.albumId {
                            db.updateAlbumMusicBrainz(
                                albumId: newAlbumId,
                                label: label,
                                country: release.country,
                                albumType: release.albumType,
                                mbid: release.id,
                                genre: genre,
                                year: year
                            )
                            albumMBIDCache[newAlbumId] = release.id
                            albumRGIDCache[newAlbumId] = release.releaseGroupId
                        }
                    } else if let albumId = track.albumId {
                        db.updateAlbumMusicBrainz(
                            albumId: albumId,
                            label: label,
                            country: release.country,
                            albumType: release.albumType,
                            mbid: release.id,
                            genre: genre,
                            year: year
                        )
                        albumMBIDCache[albumId] = release.id
                        albumRGIDCache[albumId] = release.releaseGroupId
                    }
                    db.updateTrackMusicBrainzId(trackId: trackId, mbid: release.id)
                    metadataEnriched += 1
                } else {
                    enrichLog.warning("enrichTrack: NO MATCH for [\(trackId, privacy: .public)] '\(searchArtist, privacy: .public) - \(searchAlbum, privacy: .public)'")
                    if let albumId = track.albumId {
                        albumMBIDCache[albumId] = nil
                    }
                }
            }
        }

        // 2. AcoustID fallback (placeholder — requires Chromaprint integration)
        if releaseMBID == nil && useAcoustID {
            // TODO: Chromaprint fingerprint → AcoustID lookup
        }

        // 3. Download cover if not already cached locally (use refreshed albumId in case of reassignment)
        let currentAlbumId = db.getTrackById(trackId)?.albumId ?? track.albumId
        if settings.fetchCoverArt, let mbid = releaseMBID, let albumId = currentAlbumId {
            // Skip if album already has cover art (e.g. manually changed)
            let existingAlbum = db.getAlbum(id: albumId)
            if let existingCover = existingAlbum?.coverArtPath, !existingCover.isEmpty,
               FileManager.default.fileExists(atPath: existingCover) {
                enrichLog.info("enrichTrack: album already has cover, skipping → \(existingCover, privacy: .public)")
            } else {
                let cacheDir = coverCacheDirectory()
                let cachedFile = cacheDir.appendingPathComponent("\(mbid).jpg")
                if FileManager.default.fileExists(atPath: cachedFile.path) {
                    db.updateAlbumCover(albumId: albumId, coverPath: cachedFile.path)
                    coversFound += 1
                    enrichLog.info("enrichTrack: cover from cache → \(cachedFile.path, privacy: .public)")
                } else {
                    enrichLog.info("enrichTrack: downloading cover for MBID=\(mbid, privacy: .public) rgid=\(releaseGroupMBID ?? "nil", privacy: .public)")
                    if let path = await coverArt.downloadCover(releaseMBID: mbid, releaseGroupMBID: releaseGroupMBID, saveTo: cacheDir) {
                        db.updateAlbumCover(albumId: albumId, coverPath: path)
                        coversFound += 1
                        enrichLog.info("enrichTrack: cover downloaded → \(path, privacy: .public)")
                    } else {
                        enrichLog.warning("enrichTrack: cover download FAILED for MBID=\(mbid, privacy: .public)")
                    }
                }
            }
        } else if releaseMBID == nil {
            enrichLog.info("enrichTrack: no MBID, skipping cover download")
        }

        // 4. Fetch lyrics if missing
        if settings.fetchLyrics, track.lyrics == nil {
            let lyricsArtist = searchArtist.isEmpty ? track.artist : searchArtist
            let lyricsTitle = searchTitle.isEmpty ? track.title : searchTitle
            enrichLog.info("enrichTrack: fetching lyrics for '\(lyricsArtist, privacy: .public) - \(lyricsTitle, privacy: .public)'")
            var result = await lyricsService.fetchLyrics(
                artist: lyricsArtist, title: lyricsTitle,
                album: track.album, duration: track.duration
            )
            if result == nil {
                result = await lyricsService.searchLyrics(artist: lyricsArtist, title: lyricsTitle)
            }

            if let lyricsText = result?.syncedLyrics ?? result?.plainLyrics {
                db.updateTrackLyrics(trackId: trackId, lyrics: lyricsText)
                lyricsFound += 1
                enrichLog.info("enrichTrack: lyrics saved (\(lyricsText.count, privacy: .public) chars, synced=\(result?.syncedLyrics != nil, privacy: .public))")
            } else {
                enrichLog.info("enrichTrack: no lyrics found for '\(lyricsArtist, privacy: .public) - \(lyricsTitle, privacy: .public)'")
            }
        }

        // 5. Fetch artist photo if not already attempted this run
        if settings.fetchArtist, let artistId = track.artistId, artistPhotoCache[artistId] == nil {
            artistPhotoCache[artistId] = true
            let hasOwnPhoto = db.artistHasOwnPhoto(artistId: artistId)
            if !hasOwnPhoto && !searchArtist.isEmpty {
                var mbid = db.getArtist(id: artistId)?.musicbrainzId
                if mbid == nil { mbid = (await musicBrainz.searchArtist(name: searchArtist))?.id }
                if let mbid {
                    if db.getArtist(id: artistId)?.musicbrainzId == nil {
                        db.updateArtistMusicBrainz(artistId: artistId, mbid: mbid, coverPath: nil)
                    }
                    if let imageURL = await musicBrainz.fetchArtistImageURL(artistMBID: mbid) {
                        let photoPath = coverCacheDirectory().appendingPathComponent("artist-\(mbid).jpg")
                        if let (data, resp) = try? await URLSession.shared.data(from: imageURL),
                           let http = resp as? HTTPURLResponse, http.statusCode == 200, !data.isEmpty {
                            try? data.write(to: photoPath)
                            db.updateArtistMusicBrainz(artistId: artistId, mbid: mbid, coverPath: photoPath.path)
                            enrichLog.info("enrichTrack: artist photo saved for '\(searchArtist, privacy: .public)'")
                        }
                    } else {
                        enrichLog.info("enrichTrack: no Wikidata photo for '\(searchArtist, privacy: .public)'")
                    }
                }
            }
        }

        db.markEnrichmentDone(id: queueId)
    }

    /// Search MusicBrainz for the artist's primary genre
    private func fetchArtistGenre(artist: String) async -> String? {
        // Search for the artist by name, then get their genres
        guard let mbArtist = await musicBrainz.searchArtist(name: artist) else { return nil }
        return mbArtist.genres?.max(by: { ($0.count ?? 0) < ($1.count ?? 0) })?.name
    }

    // MARK: - Single Album Enrichment (from album modal)

    func enrichSingleAlbum(albumId: Int64, release: MusicBrainzService.MBRelease) async {
        db.updateAlbumMusicBrainz(
            albumId: albumId,
            label: settings.fetchLabel ? release.labelName : nil,
            country: release.country,
            albumType: release.albumType,
            mbid: release.id,
            genre: settings.fetchGenre ? release.primaryGenre : nil,
            year: settings.fetchYear ? release.yearFromDate : nil
        )

        // Download cover
        if settings.fetchCoverArt {
            let cacheDir = coverCacheDirectory()
            let cachedFile = cacheDir.appendingPathComponent("\(release.id).jpg")
            if FileManager.default.fileExists(atPath: cachedFile.path) {
                db.updateAlbumCover(albumId: albumId, coverPath: cachedFile.path)
            } else if let path = await coverArt.downloadCover(releaseMBID: release.id, releaseGroupMBID: release.releaseGroupId, saveTo: cacheDir) {
                db.updateAlbumCover(albumId: albumId, coverPath: path)
            }
        }

        // Update all tracks in this album with the MBID
        let tracks = db.getAlbumTracks(albumId: albumId)
        for track in tracks {
            if let trackId = track.id {
                db.updateTrackMusicBrainzId(trackId: trackId, mbid: release.id)
            }
        }

        // Fetch lyrics for tracks missing them
        if settings.fetchLyrics {
            for track in tracks {
                if track.lyrics == nil, let trackId = track.id {
                    var result = await lyricsService.fetchLyrics(
                        artist: track.artist, title: track.title,
                        album: track.album, duration: track.duration
                    )
                    if result == nil {
                        result = await lyricsService.searchLyrics(artist: track.artist, title: track.title)
                    }
                    if let lyricsText = result?.syncedLyrics ?? result?.plainLyrics {
                        db.updateTrackLyrics(trackId: trackId, lyrics: lyricsText)
                    }
                }
            }
        }

        onTrackEnriched?()
    }

    func updateAlbumArtwork(albumId: Int64, releaseMBID: String, releaseGroupMBID: String? = nil) async -> Bool {
        let cacheDir = coverCacheDirectory()
        let cachedFile = cacheDir.appendingPathComponent("\(releaseMBID).jpg")
        if FileManager.default.fileExists(atPath: cachedFile.path) {
            db.updateAlbumCover(albumId: albumId, coverPath: cachedFile.path)
            onTrackEnriched?()
            return true
        } else if let path = await coverArt.downloadCover(releaseMBID: releaseMBID, releaseGroupMBID: releaseGroupMBID, saveTo: cacheDir) {
            db.updateAlbumCover(albumId: albumId, coverPath: path)
            onTrackEnriched?()
            return true
        }
        return false
    }

    func searchReleasesForAlbum(artist: String, album: String) async -> [MusicBrainzService.MBRelease] {
        let cleaned = Self.cleanAlbumName(album)
        var results = await musicBrainz.searchReleases(artist: artist, album: cleaned, limit: 10, minScore: 50)
        // If cleaning changed the name and we got no results, retry with original
        if results.isEmpty && cleaned != album {
            results = await musicBrainz.searchReleases(artist: artist, album: album, limit: 10, minScore: 50)
        }
        return results
    }

    /// Strip noise words from album names that prevent MusicBrainz matches
    static func cleanAlbumName(_ name: String) -> String {
        var cleaned = name
        // Remove common noise patterns (case-insensitive)
        let patterns = [
            "\\s*[\\(\\[].*?(?:Blu[- ]?Ray|DVD|SACD|HDCD|Hi[- ]?Res|Remaster(?:ed)?|Deluxe(?:\\s+Edition)?|Expanded(?:\\s+Edition)?|Special(?:\\s+Edition)?|Limited(?:\\s+Edition)?|Anniversary(?:\\s+Edition)?|Collector'?s?(?:\\s+Edition)?|Bonus\\s+Track|Disc\\s+\\d+).*?[\\)\\]]",
            "\\s*-\\s*(?:Blu[- ]?Ray|DVD|SACD|HDCD).*$",
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
            }
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    private func coverCacheDirectory() -> URL {
        let base: URL
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.flayer") {
            base = groupURL
        } else {
            base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        }
        let dir = base.appendingPathComponent("CoverArt")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
