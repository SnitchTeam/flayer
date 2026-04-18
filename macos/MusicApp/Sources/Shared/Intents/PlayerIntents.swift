import AppIntents
#if canImport(WidgetKit)
import WidgetKit
#endif

struct PlayPauseIntent: AppIntent {
    static let title: LocalizedStringResource = "Play/Pause"
    static let description: IntentDescription = "Toggle playback"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: WidgetState.suiteName)
        let isPlaying = defaults?.bool(forKey: "isPlaying") ?? false
        defaults?.set(!isPlaying, forKey: "isPlaying")
        defaults?.set(true, forKey: "widgetCommand_playPause")
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        return .result()
    }
}

struct NextTrackIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Track"
    static let description: IntentDescription = "Skip to next track"

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: WidgetState.suiteName)?.set(true, forKey: "widgetCommand_next")
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        return .result()
    }
}

struct PreviousTrackIntent: AppIntent {
    static let title: LocalizedStringResource = "Previous Track"
    static let description: IntentDescription = "Go to previous track"

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: WidgetState.suiteName)?.set(true, forKey: "widgetCommand_previous")
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        return .result()
    }
}

struct ToggleFavoriteIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Favorite"
    static let description: IntentDescription = "Add or remove from favorites"

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: WidgetState.suiteName)?.set(true, forKey: "widgetCommand_toggleFavorite")
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        return .result()
    }
}

struct OpenAlbumIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Album"
    static let description: IntentDescription = "Open an album in FlaYer"

    @Parameter(title: "Album ID")
    var albumId: Int

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: WidgetState.suiteName)?.set(albumId, forKey: "widgetCommand_openAlbum")
        return .result()
    }
}

struct OpenPlaylistIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Playlist"
    static let description: IntentDescription = "Open a playlist in FlaYer"

    @Parameter(title: "Playlist ID")
    var playlistId: Int

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: WidgetState.suiteName)?.set(playlistId, forKey: "widgetCommand_openPlaylist")
        return .result()
    }
}

struct SwitchTabIntent: AppIntent {
    static let title: LocalizedStringResource = "Switch Tab"
    static let description: IntentDescription = "Switch full page widget tab"

    @Parameter(title: "Tab Index")
    var tabIndex: Int

    init() {}

    init(tabIndex: Int) {
        self.tabIndex = tabIndex
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: WidgetState.suiteName)
        defaults?.set(tabIndex, forKey: "fullPageActiveTab")
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "FlaYerFullPage")
        #endif
        return .result()
    }
}
