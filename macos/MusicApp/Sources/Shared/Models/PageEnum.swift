enum Page: String, CaseIterable {
    case playlists, artists, albums, tracks, search, settings

    var accessibilityName: String {
        switch self {
        case .playlists: Lang.playlists
        case .artists: Lang.artists
        case .albums: Lang.albums
        case .tracks: Lang.tracks
        case .search: Lang.search
        case .settings: Lang.settings
        }
    }
}
