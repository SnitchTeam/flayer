import Foundation
import os.log

private let coverLog = Logger(subsystem: "com.music.flayer", category: "CoverArt")

actor CoverArtArchiveService {
    private let rateLimiter = RateLimiter(requestsPerSecond: 1)
    private let session = URLSession.shared

    /// Download cover art, trying release first, then release-group as fallback
    func downloadCover(releaseMBID: String, releaseGroupMBID: String? = nil, saveTo directory: URL) async -> String? {
        // 1. Try release-specific cover
        if let path = await fetchImage(endpoint: "release/\(releaseMBID)", filename: releaseMBID, saveTo: directory) {
            return path
        }
        // 2. Fallback: try release-group cover
        if let rgid = releaseGroupMBID {
            coverLog.info("downloadCover: trying release-group fallback rgid=\(rgid, privacy: .public)")
            if let path = await fetchImage(endpoint: "release-group/\(rgid)", filename: releaseMBID, saveTo: directory) {
                return path
            }
        }
        return nil
    }

    private func fetchImage(endpoint: String, filename: String, saveTo directory: URL) async -> String? {
        await rateLimiter.wait()
        guard let url = URL(string: "https://coverartarchive.org/\(endpoint)/front-500") else {
            coverLog.error("fetchImage: invalid URL for endpoint=\(endpoint, privacy: .public)")
            return nil
        }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                coverLog.error("fetchImage: non-HTTP response for \(endpoint, privacy: .public)")
                return nil
            }
            guard http.statusCode == 200 else {
                coverLog.warning("fetchImage: HTTP \(http.statusCode, privacy: .public) for \(endpoint, privacy: .public)")
                return nil
            }
            guard !data.isEmpty else {
                coverLog.warning("fetchImage: empty data for \(endpoint, privacy: .public)")
                return nil
            }
            let outputPath = directory.appendingPathComponent("\(filename).jpg")
            try data.write(to: outputPath)
            coverLog.info("fetchImage: saved \(data.count, privacy: .public) bytes from \(endpoint, privacy: .public)")
            return outputPath.path
        } catch {
            coverLog.error("fetchImage: error for \(endpoint, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
