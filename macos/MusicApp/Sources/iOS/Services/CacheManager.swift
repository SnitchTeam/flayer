import Foundation

@Observable
@MainActor
final class CacheManager {
    var totalCacheSize: Int64 = 0

    private let db: DatabaseManager
    private let cacheRoot: URL
    private let fm = FileManager.default

    init(db: DatabaseManager) {
        self.db = db
        // Prefer Application Support; on the extremely rare case the OS does not
        // return one (e.g. a heavily sandboxed or corrupt container), fall back
        // to a subdirectory of the system temp dir rather than crashing.
        let root = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let support = root.appendingPathComponent("FlaYer/Cache")
        self.cacheRoot = support
        try? fm.createDirectory(at: support, withIntermediateDirectories: true)
        refreshCacheSize()
    }

    func cacheDirectory(sourceType: String, sourceId: String?) -> URL {
        let dir = cacheRoot
            .appendingPathComponent(sourceType)
            .appendingPathComponent(sourceId ?? "default")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func refreshCacheSize() {
        let stats = db.getCacheStats()
        totalCacheSize = stats.totalSize
    }

    func deleteCacheForSource(sourceId: String) {
        let files = db.getCachedFiles(sourceId: sourceId)
        for file in files where file.isCached {
            try? fm.removeItem(atPath: file.localPath)
        }
        db.deleteCachedFiles(sourceId: sourceId)
        refreshCacheSize()
    }

    func deleteAllCache() {
        // Remove entire cache directory to catch all files including those with nil sourceId
        try? fm.removeItem(at: cacheRoot)
        try? fm.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
        db.deleteAllCache()
        refreshCacheSize()
    }

    func registerDownload(localPath: String, sourceType: String, sourceId: String?, remotePath: String?, trackId: Int64?, fileSize: Int64?) {
        db.insertCachedFile(sourceType: sourceType, sourceId: sourceId, remotePath: remotePath,
                           localPath: localPath, trackId: trackId, fileSize: fileSize)
        refreshCacheSize()
    }
}
