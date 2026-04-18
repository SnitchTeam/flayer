import Foundation

/// Parses FLAC metadata directly from file binary data,
/// bypassing AVFoundation which has poor Vorbis comment support on iOS.
struct FLACMetadataParser {

    /// FLAC spec caps metadata blocks at 2^24-1 bytes (~16 MiB). We use this as
    /// a hard upper bound when sizing reads so a crafted file can't ask us to
    /// allocate gigabytes. Cover art is additionally capped at 32 MiB.
    private static let maxBlockBytes = 16 * 1024 * 1024
    private static let maxPictureBytes = 32 * 1024 * 1024

    struct Tags {
        var title: String?
        var artist: String?
        var albumArtist: String?
        var album: String?
        var genre: String?
        var date: String?
        var trackNumber: String?
        var discNumber: String?
        var lyrics: String?
        var replaygainTrackGain: String?
        var replaygainAlbumGain: String?
    }

    /// Parse Vorbis comment tags from a FLAC file
    static func parse(url: URL) -> Tags? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        // Read magic: "fLaC"
        guard let magic = try? handle.read(upToCount: 4),
              magic.count == 4,
              String(data: magic, encoding: .ascii) == "fLaC" else { return nil }

        var tags = Tags()
        var isLast = false

        while !isLast {
            // METADATA_BLOCK_HEADER: 1 byte flags + 3 bytes length
            guard let headerData = try? handle.read(upToCount: 4),
                  headerData.count == 4 else { break }

            isLast = (headerData[0] & 0x80) != 0
            let blockType = headerData[0] & 0x7F
            let blockLength = Int(headerData[1]) << 16 | Int(headerData[2]) << 8 | Int(headerData[3])

            guard blockLength > 0, blockLength <= maxBlockBytes else { break }

            if blockType == 4 {
                // VORBIS_COMMENT block
                guard let blockData = try? handle.read(upToCount: blockLength),
                      blockData.count == blockLength else { break }
                tags = parseVorbisComment(data: blockData)
                if isLast { break }
            } else {
                // Skip this block
                guard let _ = try? handle.read(upToCount: blockLength) else { break }
            }
        }

        return tags
    }

    /// Extract embedded cover art (PICTURE block, type 3 = front cover) from a FLAC file
    static func extractCoverArt(url: URL, outputFile: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }

        guard let magic = try? handle.read(upToCount: 4),
              magic.count == 4,
              String(data: magic, encoding: .ascii) == "fLaC" else { return false }

        var isLast = false

        while !isLast {
            guard let headerData = try? handle.read(upToCount: 4),
                  headerData.count == 4 else { break }

            isLast = (headerData[0] & 0x80) != 0
            let blockType = headerData[0] & 0x7F
            let blockLength = Int(headerData[1]) << 16 | Int(headerData[2]) << 8 | Int(headerData[3])

            guard blockLength > 0, blockLength <= maxBlockBytes else { break }

            if blockType == 6 {
                // PICTURE block
                guard let blockData = try? handle.read(upToCount: blockLength),
                      blockData.count == blockLength else { break }
                if let imageData = parsePictureBlock(data: blockData) {
                    do {
                        try imageData.write(to: outputFile)
                        return true
                    } catch { }
                }
                if isLast { break }
            } else {
                guard let _ = try? handle.read(upToCount: blockLength) else { break }
            }
        }

        return false
    }

    // MARK: - Private

    private static func parseVorbisComment(data: Data) -> Tags {
        var tags = Tags()
        var offset = 0

        // Vendor string length (LE 32-bit)
        guard offset + 4 <= data.count else { return tags }
        let vendorLength = Int(readLE32(data, at: offset))
        offset += 4

        // Skip vendor string
        offset += vendorLength
        guard offset + 4 <= data.count else { return tags }

        // Number of comments (LE 32-bit)
        let commentCount = Int(readLE32(data, at: offset))
        offset += 4

        // Vorbis comment count is 32-bit; cap iterations so a crafted file
        // can't make us spin on billions of comment entries.
        let safeCommentCount = min(commentCount, data.count / 4)
        for _ in 0..<safeCommentCount {
            guard offset + 4 <= data.count else { break }
            let commentLength = Int(readLE32(data, at: offset))
            offset += 4

            let (endOffset, overflow) = offset.addingReportingOverflow(commentLength)
            guard !overflow, commentLength >= 0, commentLength <= maxBlockBytes,
                  endOffset <= data.count else { break }
            let commentData = data[offset..<endOffset]
            offset = endOffset

            guard let comment = String(data: commentData, encoding: .utf8),
                  let eqIndex = comment.firstIndex(of: "=") else { continue }

            let key = comment[comment.startIndex..<eqIndex].uppercased()
            let value = String(comment[comment.index(after: eqIndex)...])

            guard !value.isEmpty else { continue }

            switch key {
            case "TITLE":
                tags.title = tags.title ?? value
            case "ARTIST":
                tags.artist = tags.artist ?? value
            case "ALBUMARTIST", "ALBUM ARTIST", "ALBUM_ARTIST":
                tags.albumArtist = tags.albumArtist ?? value
            case "ALBUM":
                tags.album = tags.album ?? value
            case "GENRE":
                tags.genre = tags.genre ?? value
            case "DATE", "YEAR":
                tags.date = tags.date ?? value
            case "TRACKNUMBER":
                tags.trackNumber = tags.trackNumber ?? value
            case "DISCNUMBER":
                tags.discNumber = tags.discNumber ?? value
            case "LYRICS", "UNSYNCEDLYRICS", "UNSYNCED LYRICS":
                tags.lyrics = tags.lyrics ?? value
            case "REPLAYGAIN_TRACK_GAIN":
                tags.replaygainTrackGain = tags.replaygainTrackGain ?? value
            case "REPLAYGAIN_ALBUM_GAIN":
                tags.replaygainAlbumGain = tags.replaygainAlbumGain ?? value
            case "R128_TRACK_GAIN":
                // R128 is in 1/256 dB units relative to -23 LUFS; convert to dB gain
                if tags.replaygainTrackGain == nil, let raw = Int(value) {
                    tags.replaygainTrackGain = String(format: "%.2f dB", Double(raw) / 256.0)
                }
            case "R128_ALBUM_GAIN":
                if tags.replaygainAlbumGain == nil, let raw = Int(value) {
                    tags.replaygainAlbumGain = String(format: "%.2f dB", Double(raw) / 256.0)
                }
            default:
                break
            }
        }

        return tags
    }

    private static func parsePictureBlock(data: Data) -> Data? {
        var offset = 0

        // Picture type (BE 32-bit)
        guard offset + 4 <= data.count else { return nil }
        let pictureType = readBE32(data, at: offset)
        offset += 4

        // MIME type
        guard offset + 4 <= data.count else { return nil }
        let mimeLength = Int(readBE32(data, at: offset))
        offset += 4
        let (mimeEnd, mimeOverflow) = offset.addingReportingOverflow(mimeLength)
        guard !mimeOverflow, mimeLength >= 0, mimeLength <= maxBlockBytes,
              mimeEnd <= data.count else { return nil }
        offset = mimeEnd

        // Description
        guard offset + 4 <= data.count else { return nil }
        let descLength = Int(readBE32(data, at: offset))
        offset += 4
        let (descEnd, descOverflow) = offset.addingReportingOverflow(descLength)
        guard !descOverflow, descLength >= 0, descLength <= maxBlockBytes,
              descEnd <= data.count else { return nil }
        offset = descEnd

        // Width, height, depth, colors (4 x 4 bytes)
        guard offset + 16 <= data.count else { return nil }
        offset += 16

        // Picture data
        guard offset + 4 <= data.count else { return nil }
        let dataLength = Int(readBE32(data, at: offset))
        offset += 4

        let (pictureEnd, pictureOverflow) = offset.addingReportingOverflow(dataLength)
        guard !pictureOverflow, dataLength >= 0, dataLength <= maxPictureBytes,
              pictureEnd <= data.count else { return nil }

        // Prefer front cover (type 3), but accept any
        if pictureType == 3 || pictureType == 0 {
            return Data(data[offset..<pictureEnd])
        }

        return nil
    }

    private static func readLE32(_ data: Data, at offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else { return 0 }
        return UInt32(data[offset]) |
               UInt32(data[offset + 1]) << 8 |
               UInt32(data[offset + 2]) << 16 |
               UInt32(data[offset + 3]) << 24
    }

    private static func readBE32(_ data: Data, at offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else { return 0 }
        return UInt32(data[offset]) << 24 |
               UInt32(data[offset + 1]) << 16 |
               UInt32(data[offset + 2]) << 8 |
               UInt32(data[offset + 3])
    }
}
