import Foundation
import UIKit
#if canImport(WidgetKit)
import WidgetKit
#endif

@Observable
@MainActor
final class AppState {
    var db: DatabaseManager!
    var player = AudioEngine()
    var scanner: LibraryScanner!
    var cacheManager: CacheManager!
    var downloadManager: DownloadManager!
    var settings = AppSettings()
    var wifiServer: WiFiTransferServer?
    var mediaKeyController: MediaKeyController?
    var enricher: MetadataEnricher?
    var watchService: WatchConnectivityService?
    var modalAlbum: Album?
    var modalArtist: Artist?
    var deepLinkPlaylistId: Int64?
    var scrollToLetter: String?
    var sidebarLetters: [String] = []
    var libraryVersion: Int = 0
    var isInitialized = false
    /// Non-nil when `initialize()` failed; drives the recovery sheet in
    /// FlaYerApp so users can retry or reset the database instead of crashing.
    var initError: String?

    /// Security-scoped URLs currently being accessed (keyed by path)
    var securityScopedURLs: [String: URL] = [:]

    private let settingsKey = "com.flayer.settings"

    func initialize() {
        initError = nil
        do {
            db = try DatabaseManager()
        } catch {
            initError = error.localizedDescription
            return
        }
        scanner = LibraryScanner(db: db)
        cacheManager = CacheManager(db: db)
        downloadManager = DownloadManager(db: db, cacheManager: cacheManager)
        downloadManager.setScanner(scanner)
        mediaKeyController = MediaKeyController(player: player)
        enricher = MetadataEnricher(db: db, useAcoustID: settings.useAcoustID, settings: settings)
        enricher?.onTrackEnriched = { [weak self] in
            self?.libraryVersion += 1
        }
        player.isFavoriteCheck = { [weak self] track in
            guard let self, let trackId = track?.id else { return false }
            return self.db.isTrackInFavorites(trackId: trackId)
        }
        loadSettings()
        if let preset = HeadphonePresetDatabase.find(id: settings.eqPresetId) {
            player.applyEQPreset(preset)
        }
        player.setEQEnabled(settings.eqEnabled)
        player.replayGainEnabled = settings.replayGain
        player.replayGainMode = settings.replayGainMode
        player.gaplessEnabled = settings.gapless
        watchService = WatchConnectivityService()
        watchService?.configure(appState: self)
        isInitialized = true
    }

    /// Deletes the shared database file and retries `initialize()`. Called from
    /// the recovery sheet when the initial load failed (corrupt DB, schema
    /// mismatch from an iCloud restore, etc.). User-visible destructive action:
    /// the library will need to be rescanned, but the app can launch.
    func resetDatabaseAndRetry() {
        let dbURL = DatabaseManager.sharedDatabaseURL
        let fm = FileManager.default
        try? fm.removeItem(at: dbURL)
        // GRDB creates -wal and -shm siblings; remove them too so a fresh
        // DatabaseQueue does not pick up an orphaned WAL.
        try? fm.removeItem(at: dbURL.appendingPathExtension("wal"))
        try? fm.removeItem(at: dbURL.appendingPathExtension("shm"))
        initialize()
    }

    func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        }
        Lang.current = settings.language
    }

    func saveSettings() {
        Lang.current = settings.language
        enricher?.settings = settings
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
        // Sync language to App Group for widgets
        UserDefaults(suiteName: WidgetState.suiteName)?.set(settings.language, forKey: "appLanguage")
    }

    func scanLibrary() async {
        // Use security-scoped URLs when available, fallback to plain paths
        var urls: [URL] = []
        for folder in settings.musicFolders {
            if let scopedURL = securityScopedURLs[folder] {
                urls.append(scopedURL)
            } else {
                urls.append(URL(fileURLWithPath: folder))
            }
        }
        await scanner.scan(folderURLs: urls)
        libraryVersion += 1
        #if canImport(WidgetKit)
        WidgetKit.WidgetCenter.shared.reloadAllTimelines()
        #endif
        if settings.autoEnrich {
            await enrichLibrary()
        }
    }

    func enrichLibrary() async {
        guard settings.enableMusicBrainz else { return }
        enricher?.queueMissingData()
        await enricher?.processQueue()
        libraryVersion += 1
    }

    // MARK: - Wi-Fi Transfer

    func startWiFiServer() {
        if wifiServer == nil { wifiServer = WiFiTransferServer() }
        wifiServer?.start { [weak self] fileURL, filename in
            guard let self else { return }
            let dest = self.cacheManager.cacheDirectory(sourceType: "wifi", sourceId: nil)
            let finalURL = dest.appendingPathComponent(filename)
            try? FileManager.default.moveItem(at: fileURL, to: finalURL)
            Task {
                await self.scanner?.processFile(finalURL)
                self.cacheManager.registerDownload(localPath: finalURL.path, sourceType: "wifi", sourceId: nil,
                                                  remotePath: nil, trackId: self.db.getTrackId(path: finalURL.path), fileSize: nil)
                self.libraryVersion += 1
            }
        }
    }

    func stopWiFiServer() {
        wifiServer?.stop()
    }

    // MARK: - Widget Commands

    func checkWidgetCommands() {
        guard let defaults = UserDefaults(suiteName: WidgetState.suiteName) else { return }
        if defaults.bool(forKey: "widgetCommand_playPause") {
            defaults.removeObject(forKey: "widgetCommand_playPause")
            player.togglePlayPause()
        }
        if defaults.bool(forKey: "widgetCommand_next") {
            defaults.removeObject(forKey: "widgetCommand_next")
            player.next()
        }
        if defaults.bool(forKey: "widgetCommand_previous") {
            defaults.removeObject(forKey: "widgetCommand_previous")
            player.previous()
        }
        if defaults.bool(forKey: "widgetCommand_toggleFavorite") {
            defaults.removeObject(forKey: "widgetCommand_toggleFavorite")
            if let track = player.currentTrack, let trackId = track.id,
               let favId = db.getOrCreateFavorites().id {
                if db.isTrackInPlaylist(playlistId: favId, trackId: trackId) {
                    db.removeTrackFromPlaylist(playlistId: favId, trackId: trackId)
                } else {
                    db.addTrackToPlaylist(playlistId: favId, trackId: trackId)
                }
            }
        }
        if let albumId = defaults.object(forKey: "widgetCommand_openAlbum") as? Int {
            defaults.removeObject(forKey: "widgetCommand_openAlbum")
            if let album = db.getAlbum(id: Int64(albumId)) {
                modalAlbum = album
            }
        }
        if let playlistId = defaults.object(forKey: "widgetCommand_openPlaylist") as? Int {
            defaults.removeObject(forKey: "widgetCommand_openPlaylist")
            // Handle playlist opening via notification or state
        }
    }

    // MARK: - Security-Scoped Bookmark Management

    private let bookmarkKey = "com.flayer.folderBookmarks"

    func saveFolderBookmark(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        do {
            let bookmark = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var bookmarks = loadBookmarks()
            bookmarks[url.path] = bookmark
            if let data = try? JSONEncoder().encode(bookmarks) {
                UserDefaults.standard.set(data, forKey: bookmarkKey)
            }
            // Keep security-scoped access alive for scanning and playback
            securityScopedURLs[url.path] = url
            syncSecurityScopedURLsToPlayer()
        } catch {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
    }

    func restoreBookmarkedFolders() -> [URL] {
        // Snapshot the bookmarks dict once; collect mutations and apply them
        // after the loop. Mutating a Dictionary while iterating it is unsafe
        // in Swift and caused a prior library-wipe regression.
        let snapshot = loadBookmarks()
        var urls: [URL] = []
        var pathMigrations: [(old: String, new: String)] = []
        var refreshedBookmarks: [String: Data] = [:]
        var removedKeys: Set<String> = []

        for (path, data) in snapshot {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { continue }
            guard url.startAccessingSecurityScopedResource() else { continue }

            urls.append(url)
            let resolvedPath = url.path

            if resolvedPath != path {
                pathMigrations.append((old: path, new: resolvedPath))
                removedKeys.insert(path)
                refreshedBookmarks[resolvedPath] = data
            }

            securityScopedURLs[resolvedPath] = url

            if stale, let newData = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) {
                refreshedBookmarks[url.path] = newData
            }
        }

        // Apply DB migrations first (each is wrapped in its own write transaction
        // by GRDB; a crash between migrations leaves earlier ones durable and
        // later ones retryable on next launch via the same bookmark snapshot).
        for migration in pathMigrations {
            db?.migrateTrackPaths(from: migration.old, to: migration.new)
            if let idx = settings.musicFolders.firstIndex(of: migration.old) {
                settings.musicFolders[idx] = migration.new
            }
        }

        // Apply bookmark-dict mutations to a fresh copy, then persist atomically.
        if !removedKeys.isEmpty || !refreshedBookmarks.isEmpty {
            var updated = snapshot
            for key in removedKeys { updated.removeValue(forKey: key) }
            for (key, value) in refreshedBookmarks { updated[key] = value }
            if let encoded = try? JSONEncoder().encode(updated) {
                UserDefaults.standard.set(encoded, forKey: bookmarkKey)
            }
            saveSettings()
        }

        syncSecurityScopedURLsToPlayer()
        return urls
    }

    func removeFolderBookmark(path: String) {
        // Stop security-scoped access
        if let url = securityScopedURLs[path] {
            url.stopAccessingSecurityScopedResource()
            securityScopedURLs.removeValue(forKey: path)
            syncSecurityScopedURLsToPlayer()
        }
        var bookmarks = loadBookmarks()
        bookmarks.removeValue(forKey: path)
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        }
    }

    /// Syncs security-scoped folder URLs to the audio engine so it can
    /// access files inside user-selected folders during playback.
    private func syncSecurityScopedURLsToPlayer() {
        player.securityScopedFolderURLs = securityScopedURLs
    }

    private func loadBookmarks() -> [String: Data] {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey),
              let dict = try? JSONDecoder().decode([String: Data].self, from: data)
        else { return [:] }
        return dict
    }
}
