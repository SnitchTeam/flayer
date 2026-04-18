# FlaYer — The Flac Player

Native macOS music player built for audiophiles. SwiftUI glass morphism interface, 10-band parametric equalizer with 100+ headphone presets, and full lossless format support.

*[Version française ci-dessous](#flayer--the-flac-player-1)*

## Features

### Audio
- **12 supported formats** — FLAC, WAV, AIFF, ALAC, DSF, DFF, APE, MP3, M4A, OGG, WMA
- **10-band equalizer** — Parametric peak/shelf filters via AVAudioEngine
- **100+ headphone presets** — oratory1990 profiles (Harman target) for AKG, Beyerdynamic, Focal, HiFiMan, Sennheiser, Sony…
- **Audio output selection** — Device picker with sample rate display
- **Queue & shuffle** — Full playback management

### Library
- **Auto scanning** — Metadata extraction (title, artist, album, genre, year, cover art)
- **Folder watching** — Auto-refresh via FSEvents
- **Full-text search** — FTS5 with Unicode support, accent-insensitive
- **Playlists** — Create, delete, reorder, favorites
- **Temporal sorting** — Group by period (Today, This week, This month, by year)

### Interface
- **Glass morphism** — Black background, translucent pills, semi-opaque borders
- **Icon navigation** — Repositionable bar (top/bottom)
- **3 grid densities** — Compact (8 col), Normal (6), Large (4)
- **Bilingual** — French and English
- **Touch Bar** — Integrated playback controls

## Tech Stack

| Component | Technology |
|-----------|------------|
| Language | Swift 6.0 |
| UI | SwiftUI |
| Audio | AVAudioEngine + CoreAudio |
| Database | SQLite via [GRDB](https://github.com/groue/GRDB.swift) 7.0+ |
| Build | XcodeGen |
| Target | macOS 14.0+ (Sonoma) |

## Installation

### DMG (recommended)

Open `FlaYer.dmg` and drag the app to the Applications folder.

### From source

```bash
# Prerequisites: Xcode 16+, XcodeGen
brew install xcodegen

# Generate Xcode project
cd macos/MusicApp
xcodegen generate

# Build
xcodebuild -scheme FlaYer -configuration Release build
```

The compiled app is located in `DerivedData/.../Build/Products/Release/FlaYer.app`.

## Usage

1. **Add folders** — Settings → Library → Add folder
2. **Scan** — Scanning starts automatically after adding a folder
3. **Browse** — Albums, Artists, Playlists via the navigation bar
4. **Equalizer** — Settings → Equalizer → Choose a headphone preset
5. **Audio output** — Settings → Audio → Select device

## Project Structure

```
Sources/
├── App/            # Entry point, Info.plist, entitlements
├── Audio/          # AudioEngine, device management, media keys
├── Database/       # GRDB migrations, queries, FTS5 search
├── Models/         # Track, Album, Artist, Playlist, EQ presets, i18n
├── Scanner/        # Async scanning, metadata extraction, folder watching
├── Stores/         # AppState (@Observable)
└── Views/
    ├── Layout/     # Navigation, player, glass modifiers, Touch Bar
    ├── Library/    # Album/artist/playlist grids, search
    └── Settings/   # Library, audio, equalizer, appearance
```

## License

Personal use.

---

# FlaYer — The Flac Player

Lecteur de musique natif macOS conçu pour les audiophiles. Interface SwiftUI avec effet glass morphism, égaliseur paramétrique 10 bandes avec 100+ presets casques, et support complet des formats lossless.

## Fonctionnalités

### Audio
- **12 formats supportés** — FLAC, WAV, AIFF, ALAC, DSF, DFF, APE, MP3, M4A, OGG, WMA
- **Égaliseur 10 bandes** — Filtres peak/shelf paramétriques via AVAudioEngine
- **100+ presets casques** — Profils oratory1990 (Harman target) pour AKG, Beyerdynamic, Focal, HiFiMan, Sennheiser, Sony…
- **Sélection de sortie audio** — Choix du périphérique avec affichage du sample rate
- **File d'attente & shuffle** — Gestion complète de la lecture

### Bibliothèque
- **Scan automatique** — Extraction des métadonnées (titre, artiste, album, genre, année, pochette)
- **Surveillance des dossiers** — Mise à jour automatique via FSEvents
- **Recherche full-text** — FTS5 avec support Unicode, insensible aux accents
- **Playlists** — Création, suppression, réorganisation, favoris
- **Tri temporel** — Groupement par période (Aujourd'hui, Cette semaine, Ce mois, par année)

### Interface
- **Glass morphism** — Fond noir, pilules transparentes, bordures semi-opaques
- **Navigation par icônes** — Barre repositionnable (haut/bas)
- **3 densités de grille** — Compact (8 col), Normal (6), Large (4)
- **Bilingue** — Français et anglais
- **Touch Bar** — Contrôles de lecture intégrés

## Stack technique

| Composant | Technologie |
|-----------|-------------|
| Langage | Swift 6.0 |
| UI | SwiftUI |
| Audio | AVAudioEngine + CoreAudio |
| Base de données | SQLite via [GRDB](https://github.com/groue/GRDB.swift) 7.0+ |
| Build | XcodeGen |
| Cible | macOS 14.0+ (Sonoma) |

## Installation

### DMG (recommandé)

Ouvrir `FlaYer.dmg` et glisser l'application dans le dossier Applications.

### Depuis les sources

```bash
# Prérequis : Xcode 16+, XcodeGen
brew install xcodegen

# Générer le projet Xcode
cd macos/MusicApp
xcodegen generate

# Build
xcodebuild -scheme FlaYer -configuration Release build
```

L'application compilée se trouve dans `DerivedData/.../Build/Products/Release/FlaYer.app`.

## Utilisation

1. **Ajouter des dossiers** — Réglages → Bibliothèque → Ajouter un dossier
2. **Scanner** — Le scan démarre automatiquement après l'ajout
3. **Naviguer** — Albums, Artistes, Playlists via la barre de navigation
4. **Égaliseur** — Réglages → Égaliseur → Choisir un preset casque
5. **Sortie audio** — Réglages → Audio → Sélectionner le périphérique

## Structure du projet

```
Sources/
├── App/            # Point d'entrée, Info.plist, entitlements
├── Audio/          # AudioEngine, gestion des périphériques, touches média
├── Database/       # GRDB migrations, requêtes, recherche FTS5
├── Models/         # Track, Album, Artist, Playlist, presets EQ, i18n
├── Scanner/        # Scan async, extraction métadonnées, surveillance dossiers
├── Stores/         # AppState (@Observable)
└── Views/
    ├── Layout/     # Navigation, player, glass modifiers, Touch Bar
    ├── Library/    # Grilles albums/artistes/playlists, recherche
    └── Settings/   # Bibliothèque, audio, égaliseur, apparence
```

## Licence

Usage personnel.
