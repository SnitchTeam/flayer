import Foundation
import AVFoundation
import CryptoKit

@Observable
@MainActor
final class LibraryScanner {
    var isScanning = false
    var scanProgress: String = ""
    var scanCount: Int = 0
    var scanTotal: Int = 0

    private let db: DatabaseManager
    private let supportedExtensions = Set(["flac", "wav", "aiff", "aif", "alac", "m4a", "mp3"])
    // Future DSD support: "dsf", "dff"

    private let coverFilenames = [
        "cover.jpg", "cover.png", "cover.jpeg",
        "folder.jpg", "folder.png",
        "front.jpg", "front.png",
        "artwork.jpg", "artwork.png",
        "album.jpg", "album.png",
        "Cover.jpg", "Cover.png",
        "Folder.jpg", "Front.jpg",
    ]

    init(db: DatabaseManager) {
        self.db = db
    }

    private var coverCacheDir: URL {
        let base: URL
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.flayer") {
            base = groupURL
        } else {
            base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        }
        let dir = base.appendingPathComponent("CoverArt", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func scan(folderURLs: [URL]) async {
        isScanning = true
        scanCount = 0
        scanTotal = 0
        scanProgress = ""

        // Start all security-scoped accesses first
        var accessedURLs: [URL] = []
        for url in folderURLs {
            if url.startAccessingSecurityScopedResource() {
                accessedURLs.append(url)
            }
        }

        for url in folderURLs {
            await scanDirectory(url)
        }

        // Clean up orphans while files are still accessible
        db.removeOrphanedTracks()

        // Release security-scoped access
        for url in accessedURLs {
            url.stopAccessingSecurityScopedResource()
        }

        isScanning = false
        scanProgress = Lang.scanComplete
    }

    func scan(folders: [String]) async {
        await scan(folderURLs: folders.map { URL(fileURLWithPath: $0) })
    }

    /// Check if a folder contains iCloud placeholder files (not yet downloaded)
    static func cloudFileCount(at url: URL) -> Int {
        let fm = FileManager.default
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var count = 0
        while let obj = enumerator.nextObject() {
            guard let fileURL = obj as? URL else { continue }
            let name = fileURL.lastPathComponent
            if name.hasPrefix(".") && name.hasSuffix(".icloud") { count += 1 }
        }
        return count
    }

    static func hasCloudFiles(at url: URL) -> Bool {
        return cloudFileCount(at: url) > 0
    }

    static func downloadCloudFiles(at url: URL, isPaused: @escaping () -> Bool,
                                    progress: @escaping (Int, Int) -> Void) async -> Bool {
        let fm = FileManager.default
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]) else { return false }

        var cloudFiles: [URL] = []
        while let fileURL = enumerator.nextObject() as? URL {
            let values = try? fileURL.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
            if values?.isUbiquitousItem == true,
               values?.ubiquitousItemDownloadingStatus != .current {
                cloudFiles.append(fileURL)
            }
        }

        guard !cloudFiles.isEmpty else { return true }

        for (index, file) in cloudFiles.enumerated() {
            // Check cancellation
            if Task.isCancelled { return false }

            // Wait while paused
            while isPaused() {
                try? await Task.sleep(nanoseconds: 200_000_000)
                if Task.isCancelled { return false }
            }

            progress(index + 1, cloudFiles.count)
            try? fm.startDownloadingUbiquitousItem(at: file)
            // Wait for download (poll with timeout)
            for _ in 0..<300 { // 30 second timeout per file
                try? await Task.sleep(nanoseconds: 100_000_000)
                if Task.isCancelled { return false }
                let status = try? file.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus
                if status == .current { break }
            }
        }
        return true
    }

    private func scanDirectory(_ url: URL) async {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var fileURLs: [URL] = []

        while let obj = enumerator.nextObject() {
            guard let fileURL = obj as? URL else { continue }
            let ext = fileURL.pathExtension.lowercased()
            if supportedExtensions.contains(ext) {
                fileURLs.append(fileURL)
            }
        }

        scanTotal += fileURLs.count

        for fileURL in fileURLs {
            scanProgress = fileURL.lastPathComponent
            scanCount += 1
            await processFile(fileURL)
        }
    }

    func processFile(_ url: URL) async {
        let ext = url.pathExtension.lowercased()
        let asset = AVURLAsset(url: url)

        var tags: [String: String] = [:]

        // For FLAC files, use native parser first (AVFoundation has poor Vorbis comment support on iOS)
        if ext == "flac", let flacTags = FLACMetadataParser.parse(url: url) {
            if let v = flacTags.title { tags["title"] = v }
            if let v = flacTags.artist { tags["artist"] = v }
            if let v = flacTags.albumArtist { tags["albumArtist"] = v }
            if let v = flacTags.album { tags["album"] = v }
            if let v = flacTags.genre { tags["genre"] = v }
            if let v = flacTags.date { tags["date"] = v }
            if let v = flacTags.trackNumber { tags["trackNumber"] = v }
            if let v = flacTags.discNumber { tags["discNumber"] = v }
            if let v = flacTags.replaygainTrackGain { tags["replaygainTrackGain"] = v }
            if let v = flacTags.replaygainAlbumGain { tags["replaygainAlbumGain"] = v }
        }

        // Fallback to AVFoundation for non-FLAC or if FLAC parser returned nothing
        if tags.isEmpty {
        // Try format-specific metadata
        do {
            let formats = try await asset.load(.availableMetadataFormats)
            for format in formats {
                let items = try await asset.loadMetadata(for: format)
                for item in items {
                    // Try stringValue first, then dataValue decoded as UTF-8
                    var value: String?
                    if let sv = try? await item.load(.stringValue), !sv.isEmpty {
                        value = sv
                    } else if let dv = try? await item.load(.dataValue), let sv = String(data: dv, encoding: .utf8), !sv.isEmpty {
                        value = sv
                    }
                    guard let value else { continue }

                    if let id = item.identifier {
                        let key = id.rawValue.lowercased()
                        if key.contains("title") && !key.contains("subtitle") { tags["title"] = tags["title"] ?? value }
                        else if key.contains("artist") && !key.contains("albumartist") && !key.contains("album_artist") {
                            tags["artist"] = tags["artist"] ?? value
                        }
                        else if key.contains("albumartist") || key.contains("album_artist") {
                            tags["albumArtist"] = tags["albumArtist"] ?? value
                        }
                        else if key.contains("albumname") || key.hasSuffix("album") || (key.contains("album") && !key.contains("artist")) {
                            tags["album"] = tags["album"] ?? value
                        }
                        else if key.contains("genre") {
                            tags["genre"] = tags["genre"] ?? value
                        }
                        else if key.contains("date") || key.contains("year") || key.contains("creation") {
                            tags["date"] = tags["date"] ?? value
                        }
                        else if key.contains("tracknumber") {
                            tags["trackNumber"] = tags["trackNumber"] ?? value
                        }
                        else if key.contains("discnumber") {
                            tags["discNumber"] = tags["discNumber"] ?? value
                        }
                        else if key.contains("replaygain_track_gain") || key.contains("replaygain track gain") {
                            tags["replaygainTrackGain"] = tags["replaygainTrackGain"] ?? value
                        }
                        else if key.contains("replaygain_album_gain") || key.contains("replaygain album gain") {
                            tags["replaygainAlbumGain"] = tags["replaygainAlbumGain"] ?? value
                        }
                    }
                    if let ck = item.commonKey {
                        switch ck {
                        case .commonKeyTitle: tags["title"] = tags["title"] ?? value
                        case .commonKeyArtist: tags["artist"] = tags["artist"] ?? value
                        case .commonKeyAlbumName: tags["album"] = tags["album"] ?? value
                        case .commonKeyType: tags["genre"] = tags["genre"] ?? value
                        case .commonKeyCreationDate: tags["date"] = tags["date"] ?? value
                        default: break
                        }
                    }
                }
            }
        } catch { }

        // Always try common metadata as fallback (separate try block)
        if tags["title"] == nil || tags["artist"] == nil {
            do {
                let common = try await asset.load(.commonMetadata)
                for item in common {
                    var value: String?
                    if let sv = try? await item.load(.stringValue), !sv.isEmpty {
                        value = sv
                    } else if let dv = try? await item.load(.dataValue), let sv = String(data: dv, encoding: .utf8), !sv.isEmpty {
                        value = sv
                    }
                    guard let ck = item.commonKey, let value else { continue }
                    switch ck {
                    case .commonKeyTitle: tags["title"] = tags["title"] ?? value
                    case .commonKeyArtist: tags["artist"] = tags["artist"] ?? value
                    case .commonKeyAlbumName: tags["album"] = tags["album"] ?? value
                    case .commonKeyType: tags["genre"] = tags["genre"] ?? value
                    case .commonKeyCreationDate: tags["date"] = tags["date"] ?? value
                    default: break
                    }
                }
            } catch { }
        }
        } // end if tags.isEmpty (AVFoundation fallback)

        let title = tags["title"] ?? url.deletingPathExtension().lastPathComponent
        let artist = tags["artist"] ?? ""
        let albumName = tags["album"] ?? ""
        let genre = tags["genre"] ?? ""

        var year: Int?
        if let dateStr = tags["date"] {
            year = Int(dateStr.prefix(4))
        }

        var trackNumber: Int?
        if let tn = tags["trackNumber"] {
            trackNumber = Int(tn.split(separator: "/").first.map(String.init) ?? tn)
        }

        var discNumber: Int?
        if let dn = tags["discNumber"] {
            discNumber = Int(dn.split(separator: "/").first.map(String.init) ?? dn)
        }

        // Fallback: parse filename pattern "Artist - Album - Title" or "Artist - Title"
        if artist.isEmpty || albumName.isEmpty {
            let parsed = parseFilenameForScan(url)
            if artist.isEmpty, let a = parsed.artist, !a.isEmpty { tags["artist"] = a }
            if albumName.isEmpty, let al = parsed.album, !al.isEmpty { tags["album"] = al }
            if tags["title"] == nil || title == url.deletingPathExtension().lastPathComponent {
                if let t = parsed.title, !t.isEmpty { tags["title"] = t }
            }
        }

        let parentDir = url.deletingLastPathComponent()

        let finalTitle = tags["title"] ?? title
        let finalArtist = tags["artist"] ?? artist
        let finalAlbum = tags["album"] ?? albumName
        let finalAlbumArtist = tags["albumArtist"] ?? stripFeaturing(finalArtist)

        let durationSeconds: Double
        do {
            let cmTime = try await asset.load(.duration)
            durationSeconds = cmTime.seconds.isFinite ? cmTime.seconds : 0
        } catch {
            durationSeconds = 0
        }

        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attrs?[.size] as? Int64) ?? 0

        let cacheKey = "\(finalAlbumArtist)-\(finalAlbum)".data(using: .utf8)!
        let digest = SHA256.hash(data: cacheKey)
        let hashName = digest.prefix(16).map { String(format: "%02x", $0) }.joined()
        let cacheFile = coverCacheDir.appendingPathComponent("\(hashName).jpg")

        var coverArtPath: String?
        if FileManager.default.fileExists(atPath: cacheFile.path) {
            coverArtPath = cacheFile.path
        } else {
            // 1. Try embedded art first (album-specific, most accurate)
            if ext == "flac" && FLACMetadataParser.extractCoverArt(url: url, outputFile: cacheFile) {
                coverArtPath = cacheFile.path
            } else if let embedded = await extractEmbeddedArt(from: asset, outputFile: cacheFile) {
                coverArtPath = embedded
            }
            // 2. Fall back to folder cover art (cover.jpg, folder.jpg, etc.)
            if coverArtPath == nil, let folderCover = findCoverArt(in: parentDir) {
                try? FileManager.default.copyItem(atPath: folderCover, toPath: cacheFile.path)
                coverArtPath = cacheFile.path
            }
        }
        var sampleRate = 44100
        var bitDepth = 16

        if let audioFile = try? AVAudioFile(forReading: url) {
            sampleRate = Int(audioFile.processingFormat.sampleRate)
            bitDepth = Int(audioFile.processingFormat.settings[AVLinearPCMBitDepthKey] as? Int ?? 16)
        }

        // Parse ReplayGain values (format: "-3.45 dB" or just "-3.45")
        let rgTrackGain = parseReplayGain(tags["replaygainTrackGain"])
        let rgAlbumGain = parseReplayGain(tags["replaygainAlbumGain"])

        do {
            let artistId = try db.insertOrGetArtist(name: finalAlbumArtist.isEmpty ? Lang.unknownArtist : finalAlbumArtist)
            let albumId = try db.insertOrGetAlbum(
                name: finalAlbum.isEmpty ? Lang.unknownAlbum : finalAlbum,
                albumArtist: finalAlbumArtist,
                year: year,
                coverArtPath: coverArtPath
            )

            let track = Track(
                path: url.path,
                title: finalTitle,
                artist: finalArtist,
                albumArtist: finalAlbumArtist,
                album: finalAlbum,
                genre: genre,
                year: year,
                trackNumber: trackNumber,
                discNumber: discNumber,
                duration: durationSeconds,
                sampleRate: sampleRate,
                bitDepth: bitDepth,
                format: ext.uppercased(),
                fileSize: fileSize,
                dateAdded: Date(),
                dateModified: Date(),
                albumId: albumId,
                artistId: artistId,
                coverArtPath: coverArtPath,
                replaygainTrackGain: rgTrackGain,
                replaygainAlbumGain: rgAlbumGain
            )
            try db.insertTrack(track)
        } catch { }
    }

    private func extractEmbeddedArt(from asset: AVURLAsset, outputFile: URL) async -> String? {
        do {
            let formats = try await asset.load(.availableMetadataFormats)
            for format in formats {
                let items = try await asset.loadMetadata(for: format)
                for item in items {
                    if let ck = item.commonKey, ck == .commonKeyArtwork {
                        if let data = try? await item.load(.dataValue) {
                            try data.write(to: outputFile)
                            return outputFile.path
                        }
                    }
                    if let id = item.identifier?.rawValue.lowercased(),
                       (id.contains("artwork") || id.contains("picture") || id.contains("cover")) {
                        if let data = try? await item.load(.dataValue) {
                            try data.write(to: outputFile)
                            return outputFile.path
                        }
                    }
                }
            }
            let common = try await asset.load(.commonMetadata)
            for item in common {
                if item.commonKey == .commonKeyArtwork, let data = try? await item.load(.dataValue) {
                    try data.write(to: outputFile)
                    return outputFile.path
                }
            }
        } catch { }
        return nil
    }

    /// Parse filename patterns: "Artist - Album - Title", "Artist - Title", "01 - Title", "01. Title"
    private func parseFilenameForScan(_ url: URL) -> (artist: String?, album: String?, title: String?) {
        let filename = url.deletingPathExtension().lastPathComponent
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

    /// Strip "feat.", "ft.", "featuring", etc. from artist name to get the primary artist.
    private func stripFeaturing(_ artist: String) -> String {
        let patterns = [" feat. ", " feat ", " ft. ", " ft ", " featuring ", " Feat. ", " Feat ", " Ft. ", " Ft ", " Featuring "]
        for pattern in patterns {
            if let range = artist.range(of: pattern, options: .caseInsensitive) {
                return String(artist[artist.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        // Also handle parenthesized featuring: "Artist (feat. Other)"
        if let parenRange = artist.range(of: " (feat", options: .caseInsensitive) {
            return String(artist[artist.startIndex..<parenRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        if let parenRange = artist.range(of: " (ft", options: .caseInsensitive) {
            return String(artist[artist.startIndex..<parenRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return artist
    }

    /// Parse ReplayGain string like "-3.45 dB" or "+1.23" to Double
    private func parseReplayGain(_ value: String?) -> Double? {
        guard let value else { return nil }
        let cleaned = value.replacingOccurrences(of: " dB", with: "")
            .replacingOccurrences(of: " db", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    private func findCoverArt(in directory: URL) -> String? {
        let fm = FileManager.default
        for filename in coverFilenames {
            let path = directory.appendingPathComponent(filename)
            if fm.fileExists(atPath: path.path) {
                return path.path
            }
        }
        if let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            let imageExtensions = Set(["jpg", "jpeg", "png"])
            if let img = contents.first(where: { imageExtensions.contains($0.pathExtension.lowercased()) }) {
                return img.path
            }
        }
        return nil
    }
}
