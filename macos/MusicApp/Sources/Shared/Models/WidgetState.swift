import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

struct NowPlayingInfo: Codable {
    let path: String
    let title: String
    let artist: String
    let album: String
    let coverArtPath: String?
    let format: String
    let sampleRate: Int
    let bitDepth: Int
    let duration: Double
}

struct WidgetState {
    static let suiteName = "group.com.flayer"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    static func writeNowPlaying(_ track: Track?, isPlaying: Bool, progress: Double, queue: [Track], isFavorite: Bool = false) {
        guard let defaults else { return }
        if let track {
            let info = NowPlayingInfo(
                path: track.path, title: track.title, artist: track.artist,
                album: track.album, coverArtPath: sharedCoverPath(for: track.coverArtPath),
                format: track.format, sampleRate: track.sampleRate,
                bitDepth: track.bitDepth, duration: track.duration
            )
            defaults.set(try? JSONEncoder().encode(info), forKey: "nowPlaying")
        } else {
            defaults.removeObject(forKey: "nowPlaying")
        }
        defaults.set(isPlaying, forKey: "isPlaying")
        defaults.set(progress, forKey: "playbackProgress")
        defaults.set(isFavorite, forKey: "isFavorite")

        let queueInfos = queue.prefix(5).map {
            NowPlayingInfo(path: $0.path, title: $0.title, artist: $0.artist,
                          album: $0.album, coverArtPath: sharedCoverPath(for: $0.coverArtPath),
                          format: $0.format, sampleRate: $0.sampleRate,
                          bitDepth: $0.bitDepth, duration: $0.duration)
        }
        defaults.set(try? JSONEncoder().encode(queueInfos), forKey: "queue")

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    /// Copy cover art to App Group container if needed, return the shared path
    private static func sharedCoverPath(for originalPath: String?) -> String? {
        guard let originalPath, !originalPath.isEmpty else { return nil }
        // Already in App Group container
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName),
           originalPath.hasPrefix(groupURL.path) {
            return originalPath
        }
        // Copy to shared container
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) else {
            return originalPath
        }
        let coverDir = groupURL.appendingPathComponent("CoverArt", isDirectory: true)
        try? FileManager.default.createDirectory(at: coverDir, withIntermediateDirectories: true)
        let filename = URL(fileURLWithPath: originalPath).lastPathComponent
        let destPath = coverDir.appendingPathComponent(filename).path
        if !FileManager.default.fileExists(atPath: destPath) {
            try? FileManager.default.copyItem(atPath: originalPath, toPath: destPath)
        }
        return destPath
    }

    static func readNowPlaying() -> NowPlayingInfo? {
        guard let data = defaults?.data(forKey: "nowPlaying") else { return nil }
        return try? JSONDecoder().decode(NowPlayingInfo.self, from: data)
    }

    static func readIsPlaying() -> Bool {
        defaults?.bool(forKey: "isPlaying") ?? false
    }

    static func readProgress() -> Double {
        defaults?.double(forKey: "playbackProgress") ?? 0
    }

    static func readQueue() -> [NowPlayingInfo] {
        guard let data = defaults?.data(forKey: "queue") else { return [] }
        return (try? JSONDecoder().decode([NowPlayingInfo].self, from: data)) ?? []
    }

    static func readIsFavorite() -> Bool {
        defaults?.bool(forKey: "isFavorite") ?? false
    }
}
