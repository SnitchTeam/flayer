import Foundation
import AVFoundation

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

    func scan(folders: [String]) async {
        isScanning = true
        scanCount = 0
        scanTotal = 0
        scanProgress = ""

        for folder in folders {
            await scanDirectory(URL(fileURLWithPath: folder))
        }

        db.removeOrphanedTracks()
        isScanning = false
    }

    private func scanDirectory(_ url: URL) async {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return }

        // Collect URLs synchronously first (DirectoryEnumerator can't be used in async context)
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

    private func processFile(_ url: URL) async {
        let ext = url.pathExtension.lowercased()
        let asset = AVURLAsset(url: url)

        var tags: [String: String] = [:]

        // For FLAC files, use native parser first (AVFoundation has poor Vorbis comment support)
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
        do {
            let formats = try await asset.load(.availableMetadataFormats)
            for format in formats {
                let items = try await asset.loadMetadata(for: format)
                for item in items {
                    guard let value = try? await item.load(.stringValue), !value.isEmpty else { continue }
                    // Map by identifier
                    if let id = item.identifier {
                        let key = id.rawValue.lowercased()
                        if key.contains("title") { tags["title"] = tags["title"] ?? value }
                        else if key.contains("artist") && !key.contains("albumartist") {
                            tags["artist"] = tags["artist"] ?? value
                        }
                        else if key.contains("albumartist") || key.contains("album_artist") {
                            tags["albumArtist"] = tags["albumArtist"] ?? value
                        }
                        else if key.contains("albumname") || (key.contains("album") && !key.contains("artist")) {
                            tags["album"] = tags["album"] ?? value
                        }
                        else if key.contains("genre") || key.contains("type") {
                            tags["genre"] = tags["genre"] ?? value
                        }
                        else if key.contains("date") || key.contains("year") || key.contains("creation") {
                            tags["date"] = tags["date"] ?? value
                        }
                        else if key.contains("tracknumber") || key.contains("track") {
                            tags["trackNumber"] = tags["trackNumber"] ?? value
                        }
                        else if key.contains("discnumber") || key.contains("disc") {
                            tags["discNumber"] = tags["discNumber"] ?? value
                        }
                        else if key.contains("replaygain_track_gain") || key.contains("replaygain track gain") {
                            tags["replaygainTrackGain"] = tags["replaygainTrackGain"] ?? value
                        }
                        else if key.contains("replaygain_album_gain") || key.contains("replaygain album gain") {
                            tags["replaygainAlbumGain"] = tags["replaygainAlbumGain"] ?? value
                        }
                    }
                    // Also check commonKey
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
            // Fallback: try commonMetadata
            if tags.isEmpty {
                let common = try await asset.load(.commonMetadata)
                for item in common {
                    guard let ck = item.commonKey, let value = try? await item.load(.stringValue), !value.isEmpty else { continue }
                    switch ck {
                    case .commonKeyTitle: tags["title"] = value
                    case .commonKeyArtist: tags["artist"] = value
                    case .commonKeyAlbumName: tags["album"] = value
                    case .commonKeyType: tags["genre"] = value
                    case .commonKeyCreationDate: tags["date"] = value
                    default: break
                    }
                }
            }
        } catch { }
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
            // Handle "3/12" format
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

        // Try folder images first, then FLAC native extraction, then AVFoundation
        var coverArtPath = findCoverArt(in: parentDir)
        if coverArtPath == nil {
            let outputFile = parentDir.appendingPathComponent("cover.jpg")
            if !FileManager.default.fileExists(atPath: outputFile.path) {
                if ext == "flac" && FLACMetadataParser.extractCoverArt(url: url, outputFile: outputFile) {
                    coverArtPath = outputFile.path
                }
            } else {
                coverArtPath = outputFile.path
            }
        }
        if coverArtPath == nil {
            coverArtPath = await extractEmbeddedArt(from: asset, directory: parentDir)
        }
        var sampleRate = 44100
        var bitDepth = 16

        if let audioFile = try? AVAudioFile(forReading: url) {
            sampleRate = Int(audioFile.processingFormat.sampleRate)
            bitDepth = Int(audioFile.processingFormat.settings[AVLinearPCMBitDepthKey] as? Int ?? 16)
        }

        // Parse ReplayGain values
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
        } catch {
            // DB insert failed
        }
    }

    private func extractEmbeddedArt(from asset: AVURLAsset, directory: URL) async -> String? {
        let outputPath = directory.appendingPathComponent("cover.jpg").path
        // Don't re-extract if already done
        if FileManager.default.fileExists(atPath: outputPath) {
            return outputPath
        }
        do {
            let formats = try await asset.load(.availableMetadataFormats)
            for format in formats {
                let items = try await asset.loadMetadata(for: format)
                for item in items {
                    // Look for artwork data
                    if let ck = item.commonKey, ck == .commonKeyArtwork {
                        if let data = try? await item.load(.dataValue) {
                            try data.write(to: URL(fileURLWithPath: outputPath))
                            return outputPath
                        }
                    }
                    // Also check by identifier for formats that don't map to commonKey
                    if let id = item.identifier?.rawValue.lowercased(),
                       (id.contains("artwork") || id.contains("picture") || id.contains("cover")) {
                        if let data = try? await item.load(.dataValue) {
                            try data.write(to: URL(fileURLWithPath: outputPath))
                            return outputPath
                        }
                    }
                }
            }
            // Fallback: try commonMetadata directly
            let common = try await asset.load(.commonMetadata)
            for item in common {
                if item.commonKey == .commonKeyArtwork, let data = try? await item.load(.dataValue) {
                    try data.write(to: URL(fileURLWithPath: outputPath))
                    return outputPath
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

    private func stripFeaturing(_ artist: String) -> String {
        let patterns = [" feat. ", " feat ", " ft. ", " ft ", " featuring ", " Feat. ", " Feat ", " Ft. ", " Ft ", " Featuring "]
        for pattern in patterns {
            if let range = artist.range(of: pattern, options: .caseInsensitive) {
                return String(artist[artist.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        if let parenRange = artist.range(of: " (feat", options: .caseInsensitive) {
            return String(artist[artist.startIndex..<parenRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        if let parenRange = artist.range(of: " (ft", options: .caseInsensitive) {
            return String(artist[artist.startIndex..<parenRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return artist
    }

    private func parseReplayGain(_ value: String?) -> Double? {
        guard let value else { return nil }
        // Normalize Unicode minus (U+2212) and en/em dashes to ASCII '-'
        // so tags written by non-ASCII tagging tools still parse.
        let normalized = value
            .replacingOccurrences(of: "\u{2212}", with: "-")
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{2014}", with: "-")
        let cleaned = normalized.replacingOccurrences(of: " dB", with: "")
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
        // Fallback: first image file
        if let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            let imageExtensions = Set(["jpg", "jpeg", "png"])
            if let img = contents.first(where: { imageExtensions.contains($0.pathExtension.lowercased()) }) {
                return img.path
            }
        }
        return nil
    }
}
