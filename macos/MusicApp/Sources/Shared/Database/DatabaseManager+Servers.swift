import Foundation
import GRDB

extension DatabaseManager {
    // MARK: - Server Configs

    func getServerConfigs() -> [ServerConfig] {
        (try? dbQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM server_configs ORDER BY name")
        }.map { row in
            ServerConfig(id: row["id"], type: row["type"], name: row["name"], host: row["host"],
                         port: row["port"], shareName: row["share_name"], username: row["username"],
                         apiToken: row["api_token"])
        }) ?? []
    }

    func insertServerConfig(_ config: ServerConfig) {
        do {
            try dbQueue.write { db in
                try db.execute(
                    sql: "INSERT OR REPLACE INTO server_configs (id, type, name, host, port, share_name, username, api_token, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, NULL, ?)",
                    arguments: [config.id, config.type, config.name, config.host, config.port,
                                config.shareName, config.username, config.createdAt]
                )
            }
        } catch { dbLog.error("insertServerConfig failed: \(error.localizedDescription, privacy: .public)") }
    }

    func deleteServerConfig(id: String) {
        do {
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM server_configs WHERE id = ?", arguments: [id])
                try db.execute(sql: "DELETE FROM cached_files WHERE source_id = ?", arguments: [id])
            }
        } catch { dbLog.error("deleteServerConfig failed: \(error.localizedDescription, privacy: .public)") }
    }

    // MARK: - Cached Files

    func insertCachedFile(sourceType: String, sourceId: String?, remotePath: String?, localPath: String, trackId: Int64?, fileSize: Int64?) {
        do {
            try dbQueue.write { db in
                try db.execute(
                    sql: "INSERT INTO cached_files (source_type, source_id, remote_path, local_path, track_id, file_size, is_cached, download_date) VALUES (?, ?, ?, ?, ?, ?, 1, ?)",
                    arguments: [sourceType, sourceId, remotePath, localPath, trackId, fileSize,
                                ISO8601DateFormatter().string(from: Date())]
                )
            }
        } catch { dbLog.error("insertCachedFile failed: \(error.localizedDescription, privacy: .public)") }
    }

    func markCachedFileUncached(localPath: String) {
        do {
            try dbQueue.write { db in
                try db.execute(sql: "UPDATE cached_files SET is_cached = 0 WHERE local_path = ?", arguments: [localPath])
            }
        } catch { dbLog.error("markCachedFileUncached failed: \(error.localizedDescription, privacy: .public)") }
    }

    func getCachedFiles(sourceId: String) -> [(localPath: String, fileSize: Int64, isCached: Bool, remotePath: String?)] {
        (try? dbQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT local_path, file_size, is_cached, remote_path FROM cached_files WHERE source_id = ?", arguments: [sourceId])
        }.map { ($0["local_path"] as String, $0["file_size"] as? Int64 ?? 0,
                 ($0["is_cached"] as? Int ?? 1) == 1, $0["remote_path"] as? String) }) ?? []
    }

    func getCacheStats() -> (totalSize: Int64, fileCount: Int, bySource: [(type: String, sourceId: String?, name: String?, size: Int64, count: Int)]) {
        let total: Int64 = (try? dbQueue.read { db in
            try Int64.fetchOne(db, sql: "SELECT COALESCE(SUM(file_size), 0) FROM cached_files WHERE is_cached = 1")
        }) ?? 0
        let count: Int = (try? dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM cached_files WHERE is_cached = 1")
        }) ?? 0
        let bySource = (try? dbQueue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT cf.source_type, cf.source_id, sc.name,
                       COALESCE(SUM(cf.file_size), 0) as total_size, COUNT(*) as file_count
                FROM cached_files cf LEFT JOIN server_configs sc ON cf.source_id = sc.id
                WHERE cf.is_cached = 1
                GROUP BY cf.source_type, cf.source_id
                """)
        }.map { ($0["source_type"] as String, $0["source_id"] as? String, $0["name"] as? String,
                 $0["total_size"] as Int64, $0["file_count"] as Int) }) ?? []
        return (totalSize: total, fileCount: count, bySource: bySource)
    }

    func deleteCachedFiles(sourceId: String) {
        do {
            try dbQueue.write { db in
                try db.execute(sql: "UPDATE cached_files SET is_cached = 0 WHERE source_id = ? AND is_pinned = 0", arguments: [sourceId])
            }
        } catch { dbLog.error("deleteCachedFiles failed: \(error.localizedDescription, privacy: .public)") }
    }

    func deleteAllCache() {
        do {
            try dbQueue.write { db in
                try db.execute(sql: "UPDATE cached_files SET is_cached = 0 WHERE is_pinned = 0")
            }
        } catch { dbLog.error("deleteAllCache failed: \(error.localizedDescription, privacy: .public)") }
    }

    func getTrackId(path: String) -> Int64? {
        try? dbQueue.read { db in
            try Int64.fetchOne(db, sql: "SELECT id FROM tracks WHERE path = ?", arguments: [path])
        }
    }

    func isTrackCached(trackId: Int64) -> Bool {
        (try? dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT is_cached FROM cached_files WHERE track_id = ?", arguments: [trackId])
        }) == 1
    }
}
