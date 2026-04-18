import Foundation

enum Lang {
    nonisolated(unsafe) static var current: String = "fr"

    // MARK: - Navigation & Pages
    static var albums: String { current == "fr" ? "Albums" : "Albums" }
    static var artists: String { current == "fr" ? "Artistes" : "Artists" }
    static var playlists: String { current == "fr" ? "Playlists" : "Playlists" }
    static var tracks: String { current == "fr" ? "Titres" : "Tracks" }
    static var search: String { current == "fr" ? "Recherche" : "Search" }
    static var settings: String { current == "fr" ? "Réglages" : "Settings" }

    // MARK: - Playback
    static var playback: String { current == "fr" ? "Lecture" : "Playback" }
    static var playPause: String { current == "fr" ? "Lecture / Pause" : "Play / Pause" }
    static var next: String { current == "fr" ? "Suivant" : "Next" }
    static var previous: String { current == "fr" ? "Précédent" : "Previous" }
    static var volumeUp: String { current == "fr" ? "Volume +" : "Volume +" }
    static var volumeDown: String { current == "fr" ? "Volume -" : "Volume -" }
    static var play: String { current == "fr" ? "Lecture" : "Play" }
    static var stop: String { current == "fr" ? "Stop" : "Stop" }
    static var shuffle: String { current == "fr" ? "Aléatoire" : "Shuffle" }
    static var repeatMode: String { current == "fr" ? "Répéter" : "Repeat" }
    static var moreOptions: String { current == "fr" ? "Plus d'options" : "More Options" }
    static var volume: String { current == "fr" ? "Volume" : "Volume" }
    static var dismiss: String { current == "fr" ? "Fermer" : "Dismiss" }
    static var removeFolder: String { current == "fr" ? "Supprimer le dossier" : "Remove Folder" }
    static var playNext: String { current == "fr" ? "Lire ensuite" : "Play Next" }
    static var addToQueue: String { current == "fr" ? "Ajouter à la file d'attente" : "Add to Queue" }

    // MARK: - Settings Categories
    static var library: String { current == "fr" ? "Bibliothèque" : "Library" }
    static var audio: String { current == "fr" ? "Audio" : "Audio" }
    static var equalizer: String { current == "fr" ? "Égaliseur" : "Equalizer" }
    static var appearance: String { current == "fr" ? "Apparence" : "Appearance" }

    // MARK: - Library Settings
    static var database: String { current == "fr" ? "Base de données" : "Database" }
    static var musicFolders: String { current == "fr" ? "Dossiers musicaux" : "Music Folders" }
    static var addFolder: String { current == "fr" ? "Ajouter un dossier" : "Add Folder" }
    static var scanLibrary: String { current == "fr" ? "Analyser la bibliothèque" : "Scan Library" }
    static func scanningProgress(_ count: Int) -> String {
        current == "fr" ? "Analyse en cours... \(count) fichiers" : "Scanning... \(count) files"
    }
    static func scanningDetail(_ count: Int, _ total: Int) -> String {
        current == "fr" ? "Analyse \(count)/\(total)" : "Scanning \(count)/\(total)"
    }
    static func cloudFilesFound(_ count: Int) -> String {
        current == "fr" ? "\(count) fichier\(count > 1 ? "s" : "") sur iCloud (non téléchargé\(count > 1 ? "s" : ""))" : "\(count) file\(count > 1 ? "s" : "") on iCloud (not downloaded)"
    }
    static var downloadFromCloud: String { current == "fr" ? "Télécharger depuis iCloud" : "Download from iCloud" }
    static var downloading: String { current == "fr" ? "Téléchargement..." : "Downloading..." }
    static var scanComplete: String { current == "fr" ? "Analyse terminée" : "Scan complete" }
    static var openFiles: String { current == "fr" ? "Ouvrir Fichiers" : "Open Files" }
    static var cloudAlertMessage: String { current == "fr" ? "Ce dossier contient des fichiers iCloud non téléchargés. Veuillez d'abord les télécharger via l'app Fichiers." : "This folder contains iCloud files that haven't been downloaded. Please download them first using the Files app." }

    // MARK: - Audio Settings
    static var audioOutput: String { current == "fr" ? "Sortie audio" : "Audio Output" }
    static var defaultOutput: String { current == "fr" ? "Sortie par défaut" : "Default Output" }
    static var systemDefault: String { current == "fr" ? "Système" : "System" }
    static var playbackSection: String { current == "fr" ? "Lecture" : "Playback" }
    static var gapless: String { current == "fr" ? "Lecture sans interruption" : "Gapless Playback" }
    static var exclusiveMode: String { current == "fr" ? "Mode exclusif" : "Exclusive Mode" }
    static var comingSoon: String { current == "fr" ? "Bientôt" : "Soon" }

    // MARK: - Appearance Settings
    static var gridDensity: String { current == "fr" ? "Densité de la grille" : "Grid Density" }
    static var compact: String { current == "fr" ? "Compact" : "Compact" }
    static var normal: String { current == "fr" ? "Normal" : "Normal" }
    static var large: String { current == "fr" ? "Large" : "Large" }
    static var letterNav: String { current == "fr" ? "Navigation par lettre" : "Letter Navigation" }
    static var visible: String { current == "fr" ? "Visible" : "Visible" }
    static var hidden: String { current == "fr" ? "Masquée" : "Hidden" }
    static var tracksTab: String { current == "fr" ? "Onglet Titres" : "Tracks Tab" }
    static var active: String { current == "fr" ? "Actif" : "On" }
    static var inactive: String { current == "fr" ? "Inactif" : "Off" }
    static var artistUnderAlbum: String { current == "fr" ? "Artiste sous l'album" : "Artist Below Album" }
    static var barPosition: String { current == "fr" ? "Position de la barre" : "Bar Position" }
    static var top: String { current == "fr" ? "Haut" : "Top" }
    static var bottom: String { current == "fr" ? "Bas" : "Bottom" }
    static var lang: String { current == "fr" ? "Langue" : "Language" }
    static var french: String { current == "fr" ? "Français" : "French" }
    static var english: String { current == "fr" ? "Anglais" : "English" }

    // MARK: - Equalizer
    static var headphone: String { current == "fr" ? "Casque" : "Headphone" }
    static var none: String { current == "fr" ? "Aucun" : "None" }
    static var parameters: String { current == "fr" ? "Paramètres" : "Parameters" }
    static func bandsCount(_ n: Int) -> String {
        current == "fr" ? "\(n) bandes" : "\(n) bands"
    }
    static var selectHeadphone: String { current == "fr" ? "Sélectionnez un casque pour\nafficher la correction EQ" : "Select a headphone to\ndisplay the EQ correction" }
    static var chooseHeadphone: String { current == "fr" ? "Choisir un casque" : "Choose Headphone" }
    static var searchHeadphone: String { current == "fr" ? "Rechercher un casque..." : "Search headphone..." }

    // MARK: - Headphone Types
    static var openBack: String { current == "fr" ? "Ouvert" : "Open-Back" }
    static var closedBack: String { current == "fr" ? "Fermé" : "Closed-Back" }
    static var wireless: String { current == "fr" ? "Sans fil" : "Wireless" }
    static var iem: String { current == "fr" ? "Intra" : "IEM" }

    // MARK: - Sort
    static var recent: String { current == "fr" ? "Récent" : "Recent" }
    static var alphabetical: String { current == "fr" ? "A-Z" : "A-Z" }
    static var year: String { current == "fr" ? "Année" : "Year" }

    // MARK: - Track List
    static var title: String { current == "fr" ? "Titre" : "Title" }
    static var album: String { current == "fr" ? "Album" : "Album" }
    static var duration: String { current == "fr" ? "Durée" : "Duration" }

    // MARK: - Search
    static var typeToSearch: String { current == "fr" ? "Tapez pour rechercher" : "Type to search" }
    static var noResults: String { current == "fr" ? "Aucun résultat" : "No results" }
    static var recentSearches: String { current == "fr" ? "Recherches récentes" : "Recent Searches" }
    static var clear: String { current == "fr" ? "Effacer" : "Clear" }

    // MARK: - Playlists
    static var librarySection: String { current == "fr" ? "Bibliothèque" : "Library" }
    static var myPlaylists: String { current == "fr" ? "Mes playlists" : "My Playlists" }
    static var noPlaylist: String { current == "fr" ? "Aucune playlist" : "No Playlists" }
    static var emptyPlaylist: String { current == "fr" ? "Playlist vide" : "Empty Playlist" }
    static var newPlaylist: String { current == "fr" ? "Nouvelle playlist" : "New Playlist" }
    static var name: String { current == "fr" ? "Nom" : "Name" }
    static var create: String { current == "fr" ? "Créer" : "Create" }
    static var cancel: String { current == "fr" ? "Annuler" : "Cancel" }
    static var delete: String { current == "fr" ? "Supprimer" : "Delete" }
    static var removeFromPlaylist: String { current == "fr" ? "Retirer de la playlist" : "Remove from Playlist" }
    static var addToPlaylist: String { current == "fr" ? "Ajouter à une playlist" : "Add to Playlist" }
    static var favorites: String { current == "fr" ? "Favoris" : "Favorites" }
    static var removeFavorite: String { current == "fr" ? "Retirer des favoris" : "Remove from Favorites" }
    static var addFavorite: String { current == "fr" ? "Ajouter aux favoris" : "Add to Favorites" }

    // MARK: - Album Context Menu
    static var playAlbum: String { current == "fr" ? "Lire l'album" : "Play Album" }
    static var createPlaylistFromAlbum: String { current == "fr" ? "Créer une playlist" : "Create Playlist" }
    static var viewOtherAlbums: String { current == "fr" ? "Voir les autres albums" : "View Other Albums" }

    // MARK: - Download Warning
    static var downloadRequired: String { current == "fr" ? "Téléchargement requis" : "Download Required" }
    static func downloadWarningMessage(_ count: Int) -> String {
        current == "fr"
            ? "Ce dossier contient \(count) fichier\(count > 1 ? "s" : "") iCloud non téléchargé\(count > 1 ? "s" : ""). Le téléchargement va occuper de l'espace de stockage sur cet appareil."
            : "This folder contains \(count) iCloud file\(count > 1 ? "s" : "") not yet downloaded. Downloading will use storage space on this device."
    }
    static var downloadAction: String { current == "fr" ? "Télécharger" : "Download" }
    static var skipDownload: String { current == "fr" ? "Analyser sans télécharger" : "Scan Without Downloading" }

    // MARK: - Album Detail
    static func trackCount(_ n: Int) -> String {
        if current == "fr" { return "\(n) titre\(n > 1 ? "s" : "")" }
        return "\(n) track\(n > 1 ? "s" : "")"
    }
    static func albumCount(_ n: Int) -> String {
        if current == "fr" { return "\(n) album\(n > 1 ? "s" : "")" }
        return "\(n) album\(n > 1 ? "s" : "")"
    }
    static func otherAlbumsBy(_ artist: String) -> String {
        current == "fr" ? "Autres albums de \(artist)" : "More by \(artist)"
    }
    static var discography: String { current == "fr" ? "Discographie" : "Discography" }

    // MARK: - Temporal Groups
    static var today: String { current == "fr" ? "Aujourd'hui" : "Today" }
    static var todayShort: String { current == "fr" ? "Auj." : "Today" }
    static var thisWeek: String { current == "fr" ? "Cette semaine" : "This Week" }
    static var thisWeekShort: String { current == "fr" ? "Sem." : "Week" }
    static var thisMonth: String { current == "fr" ? "Ce mois" : "This Month" }
    static var thisMonthShort: String { current == "fr" ? "Mois" : "Month" }

    // MARK: - Duration Formatting
    static func totalDuration(hours: Int, minutes: Int) -> String {
        if current == "fr" {
            return hours > 0 ? "\(hours) h \(String(format: "%02d", minutes)) min" : "\(minutes) min"
        }
        return hours > 0 ? "\(hours) h \(String(format: "%02d", minutes)) min" : "\(minutes) min"
    }

    // MARK: - Queue
    static var queue: String { current == "fr" ? "File d'attente" : "Queue" }
    static var emptyQueue: String { current == "fr" ? "Aucun morceau en attente" : "No tracks in queue" }

    // MARK: - Playback Behavior
    static var autoOpenPlayer: String { current == "fr" ? "Ouvrir le lecteur" : "Open Player" }
    static var autoOpenPlayerDesc: String { current == "fr" ? "À la lecture d'un morceau" : "When a track starts playing" }

    // MARK: - Track Info
    static var format: String { current == "fr" ? "Format" : "Format" }
    static var bitrate: String { current == "fr" ? "Débit" : "Bitrate" }
    static var sampleRate: String { current == "fr" ? "Échantillonnage" : "Sample Rate" }
    static var bitDepth: String { current == "fr" ? "Profondeur" : "Bit Depth" }
    static var fileSize: String { current == "fr" ? "Taille" : "File Size" }

    // MARK: - Audio Technical
    static var preamp: String { current == "fr" ? "Préampli" : "Preamp" }
    static var replayGain: String { "ReplayGain" }
    static var noLyrics: String { current == "fr" ? "Aucune parole" : "No lyrics" }
    static var lyrics: String { current == "fr" ? "Paroles" : "Lyrics" }

    static var unknownArtist: String { current == "fr" ? "Artiste inconnu" : "Unknown Artist" }
    static var unknownAlbum: String { current == "fr" ? "Album inconnu" : "Unknown Album" }

    // MARK: - Settings: Audio
    static var replayGainMode: String { current == "fr" ? "Mode ReplayGain" : "ReplayGain Mode" }
    static var trackMode: String { current == "fr" ? "Titre" : "Track" }
    static var albumMode: String { current == "fr" ? "Album" : "Album" }

    // MARK: - Settings: About
    static var about: String { current == "fr" ? "À propos" : "About" }
    static var version: String { "Version" }
    static var libraryStats: String { current == "fr" ? "Statistiques" : "Statistics" }
    static func artistCount(_ n: Int) -> String {
        if current == "fr" { return "\(n) artiste\(n > 1 ? "s" : "")" }
        return "\(n) artist\(n > 1 ? "s" : "")"
    }
    static var totalSize: String { current == "fr" ? "Taille totale" : "Total Size" }
    static var coverArtCache: String { current == "fr" ? "Cache pochettes" : "Cover Art Cache" }
    static var clearCache: String { current == "fr" ? "Vider le cache" : "Clear Cache" }
    static var cacheCleared: String { current == "fr" ? "Cache vidé" : "Cache Cleared" }

    // MARK: - Onboarding
    static var emptyLibrary: String { current == "fr" ? "Aucune musique" : "No music yet" }
    static var emptyLibraryHint: String { current == "fr" ? "Ajoutez un dossier dans les réglages" : "Add a folder in settings" }
    static var onboardingSubtitle: String { current == "fr" ? "Votre musique, sans compromis" : "Your music, uncompromised" }
    static var onboardingLocalFiles: String { current == "fr" ? "Fichiers locaux" : "Local Files" }
    static var onboardingLocalFilesDesc: String { current == "fr" ? "Importez votre musique depuis l'appareil ou via Wi-Fi" : "Import music from your device or via Wi-Fi" }
    static var onboardingNetwork: String { current == "fr" ? "Sources réseau" : "Network Sources" }
    static var onboardingNetworkDesc: String { current == "fr" ? "Connectez vos serveurs NAS, Jellyfin ou Subsonic" : "Connect your NAS, Jellyfin or Subsonic servers" }
    static var onboardingMetadata: String { current == "fr" ? "Métadonnées enrichies" : "Rich Metadata" }
    static var onboardingMetadataDesc: String { current == "fr" ? "Pochettes, paroles et infos récupérées automatiquement" : "Cover art, lyrics and info fetched automatically" }
    static var onboardingContinue: String { current == "fr" ? "Continuer" : "Continue" }
    static var onboardingEQDesc: String { current == "fr" ? "Égalisation par casque avec base de données intégrée" : "Per-headphone EQ with built-in preset database" }

    static var monthLocale: Locale {
        current == "fr" ? Locale(identifier: "fr_FR") : Locale(identifier: "en_US")
    }

    // MARK: - Music Sources

    static var networkSources: String { current == "fr" ? "Sources réseau" : "Network Sources" }
    static var addSource: String { current == "fr" ? "Ajouter une source" : "Add Source" }
    static var serverName: String { current == "fr" ? "Nom" : "Name" }
    static var address: String { current == "fr" ? "Adresse" : "Address" }
    static var port: String { current == "fr" ? "Port" : "Port" }
    static var shareName: String { current == "fr" ? "Partage" : "Share" }
    static var username: String { current == "fr" ? "Utilisateur" : "Username" }
    static var password: String { current == "fr" ? "Mot de passe" : "Password" }
    static var testConnection: String { current == "fr" ? "Tester" : "Test" }
    static var connectionOK: String { current == "fr" ? "Connexion réussie" : "Connection successful" }
    static var connectionFailed: String { current == "fr" ? "Échec de connexion" : "Connection failed" }
    static var connected: String { current == "fr" ? "Connecté" : "Connected" }
    static var offline: String { current == "fr" ? "Hors ligne" : "Offline" }
    static var smb: String { "SMB" }
    static var subsonic: String { "Subsonic" }
    static var jellyfin: String { "Jellyfin" }
    static var browse: String { current == "fr" ? "Parcourir" : "Browse" }
    static var pause: String { current == "fr" ? "Pause" : "Pause" }
    static var resume: String { current == "fr" ? "Reprendre" : "Resume" }
    static var downloadCancelled: String { current == "fr" ? "Téléchargement annulé" : "Download cancelled" }
    static var downloadSelected: String { current == "fr" ? "Télécharger" : "Download" }
    static func downloadProgress(_ done: Int, _ total: Int) -> String {
        current == "fr" ? "\(done)/\(total) fichiers" : "\(done)/\(total) files"
    }

    // Wi-Fi Transfer
    static var wifiTransfer: String { current == "fr" ? "Transfert Wi-Fi" : "Wi-Fi Transfer" }
    static var wifiServerActive: String { current == "fr" ? "Serveur actif" : "Server active" }
    static var wifiServerOff: String { current == "fr" ? "Serveur éteint" : "Server off" }
    static func filesReceived(_ count: Int) -> String {
        current == "fr" ? "\(count) fichier\(count > 1 ? "s" : "") reçu\(count > 1 ? "s" : "")" : "\(count) file\(count > 1 ? "s" : "") received"
    }

    // Cache
    static var storageCache: String { current == "fr" ? "Stockage cache" : "Cache Storage" }
    static var cacheQuota: String { current == "fr" ? "Quota" : "Quota" }
    static var unlimited: String { current == "fr" ? "Illimité" : "Unlimited" }
    static func cacheUsage(_ used: String, _ total: String) -> String {
        current == "fr" ? "\(used) / \(total) utilisés" : "\(used) / \(total) used"
    }
    static var clearAllCache: String { current == "fr" ? "Tout supprimer" : "Clear All" }
    static var clearCacheConfirm: String { current == "fr" ? "Supprimer tous les fichiers téléchargés ? Ils resteront disponibles au re-téléchargement." : "Delete all downloaded files? They will remain available for re-download." }
    static var deleteSource: String { current == "fr" ? "Supprimer la source" : "Delete Source" }
    static var pinned: String { current == "fr" ? "Épinglé" : "Pinned" }
    static var availableForDownload: String { current == "fr" ? "Téléchargeable" : "Available for download" }

    // Share Sheet
    static var importFile: String { current == "fr" ? "Importer ce fichier ?" : "Import this file?" }
    static var importAction: String { current == "fr" ? "Importer" : "Import" }
    static func tracksImported(_ count: Int) -> String {
        current == "fr" ? "\(count) morceau\(count > 1 ? "x" : "") importé\(count > 1 ? "s" : "")" : "\(count) track\(count > 1 ? "s" : "") imported"
    }

    // MARK: - Metadata / MusicBrainz
    static var metadata: String { current == "fr" ? "Métadonnées" : "Metadata" }
    static var enrichLibrary: String { current == "fr" ? "Enrichir la bibliothèque" : "Enrich Library" }
    static var enriching: String { current == "fr" ? "Enrichissement en cours..." : "Enriching..." }
    static var enrichComplete: String { current == "fr" ? "Enrichissement terminé" : "Enrichment Complete" }
    static var enrichCancelled: String { current == "fr" ? "Enrichissement annulé" : "Enrichment Cancelled" }
    static var resetEnrichment: String { current == "fr" ? "Réinitialiser l'enrichissement" : "Reset Enrichment" }
    static var changeArtwork: String { current == "fr" ? "Modifier la pochette" : "Change Artwork" }
    static var updateMetadata: String { current == "fr" ? "Mettre à jour les métadonnées" : "Update Metadata" }
    static var refreshMetadata: String { current == "fr" ? "Rafraîchir les métadonnées" : "Refresh Metadata" }
    static var addAlbumFavorite: String { current == "fr" ? "Ajouter aux albums favoris" : "Add to Favorite Albums" }
    static var removeAlbumFavorite: String { current == "fr" ? "Retirer des albums favoris" : "Remove from Favorite Albums" }
    static var fetchFilters: String { current == "fr" ? "Données à récupérer" : "Data to Fetch" }
    static var fetchArtist: String { current == "fr" ? "Artiste" : "Artist" }
    static var fetchAlbum: String { current == "fr" ? "Album" : "Album" }
    static var fetchTitleName: String { current == "fr" ? "Titre" : "Title" }
    static var fetchCoverArt: String { current == "fr" ? "Pochettes" : "Cover Art" }
    static var fetchGenre: String { current == "fr" ? "Genre" : "Genre" }
    static var fetchYear: String { current == "fr" ? "Année" : "Year" }
    static var fetchLyrics: String { current == "fr" ? "Paroles" : "Lyrics" }
    static var enableMusicBrainzLabel: String { current == "fr" ? "MusicBrainz" : "MusicBrainz" }
    static var autoEnrichLabel: String { current == "fr" ? "Enrichissement automatique" : "Auto Enrichment" }
    static var useAcoustIDLabel: String { current == "fr" ? "Fingerprint audio (AcoustID)" : "Audio Fingerprint (AcoustID)" }
    static func enrichResult(_ covers: Int, _ lyrics: Int, _ enriched: Int) -> String {
        current == "fr" ? "\(covers) pochettes, \(lyrics) paroles, \(enriched) enrichis" : "\(covers) covers, \(lyrics) lyrics, \(enriched) enriched"
    }

    // MARK: - Watch
    static var notConnected: String { current == "fr" ? "iPhone non connecte" : "iPhone not connected" }
    static var openIPhone: String { current == "fr" ? "Ouvrez FlaYer sur votre iPhone" : "Open FlaYer on your iPhone" }
    static var playAll: String { current == "fr" ? "Tout lire" : "Play All" }
    static var shufflePlay: String { current == "fr" ? "Lecture aleatoire" : "Shuffle" }

    // MARK: - Widgets
    static var recentlyAdded: String { current == "fr" ? "Derniers ajouts" : "Recently Added" }
    static var nowPlaying: String { current == "fr" ? "En cours" : "Now Playing" }

    // Source types
    static var sourceType: String { current == "fr" ? "Type de source" : "Source Type" }
    static var smbDescription: String { current == "fr" ? "Partage réseau (NAS, PC)" : "Network share (NAS, PC)" }
    static var subsonicDescription: String { current == "fr" ? "Navidrome, Airsonic, Gonic" : "Navidrome, Airsonic, Gonic" }
    static var jellyfinDescription: String { current == "fr" ? "Serveur Jellyfin" : "Jellyfin Server" }
}
