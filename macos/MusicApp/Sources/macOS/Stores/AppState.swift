import AppKit
import Foundation

@Observable
@MainActor
final class AppState {
    var db: DatabaseManager!
    var player = AudioEngine()
    var scanner: LibraryScanner!
    var settings = AppSettings()
    var mediaKeyController: MediaKeyController?
    var enricher: MetadataEnricher?
    var modalAlbum: Album?
    var modalArtist: Artist?
    var scrollToLetter: String?
    var sidebarLetters: [String] = []
    var libraryVersion: Int = 0
    var isInitialized = false

    private let settingsKey = "com.flayer.settings"
    private let folderWatcher = FolderWatcher()

    func initialize() {
        do {
            db = try DatabaseManager()
            scanner = LibraryScanner(db: db)
            enricher = MetadataEnricher(db: db, useAcoustID: settings.useAcoustID, settings: settings)
            enricher?.onTrackEnriched = { [weak self] in
                self?.libraryVersion += 1
            }
            mediaKeyController = MediaKeyController(player: player)
            loadSettings()
            if !settings.outputDeviceUID.isEmpty {
                player.currentDeviceUID = settings.outputDeviceUID
            }
            if let preset = HeadphonePresetDatabase.find(id: settings.eqPresetId) {
                player.applyEQPreset(preset)
            }
            player.setEQEnabled(settings.eqEnabled)
            player.replayGainEnabled = settings.replayGain
            player.replayGainMode = settings.replayGainMode
            player.gaplessEnabled = settings.gapless
            player.exclusiveModeEnabled = settings.exclusiveMode
            startWatchingFolders()
            isInitialized = true
        } catch {
            let alert = NSAlert()
            alert.messageText = "Database Error"
            alert.informativeText = "FlaYer could not open its database. Please check disk permissions and try again.\n\n\(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Quit")
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    func startWatchingFolders() {
        guard !settings.musicFolders.isEmpty else { return }
        folderWatcher.watch(folders: settings.musicFolders) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.scanLibrary()
            }
        }
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
    }

    func scanLibrary() async {
        await scanner.scan(folders: settings.musicFolders)
        libraryVersion += 1
        if settings.autoEnrich {
            await enrichLibrary()
        }
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

    func enrichLibrary() async {
        guard settings.enableMusicBrainz else { return }
        enricher?.queueMissingData()
        await enricher?.processQueue()
        libraryVersion += 1
    }
}
