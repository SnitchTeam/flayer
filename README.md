# FlaYer

Native macOS music player for audiophiles. SwiftUI glass-morphism interface, 10-band parametric EQ with 100+ headphone presets, FLAC/DSD/ALAC/APE/ogg lossless support, optional MusicBrainz metadata enrichment, WidgetKit widgets, and an Apple Watch companion.

*[Version française plus bas](#version-française).*

> **Distribution status.** The released DMG is **ad-hoc signed** — there is no paid Apple Developer account behind this project. Gatekeeper will block the first launch unless you install via Homebrew (recommended) or bypass it manually.

## Features

### Audio
- FLAC, WAV, AIFF, ALAC, DSF, DFF, APE, MP3, M4A, OGG, WMA
- 10-band parametric EQ (AVAudioEngine)
- 100+ headphone presets (oratory1990 / Harman target) — AKG, Beyerdynamic, Focal, HiFiMan, Sennheiser, Sony, and more
- Exclusive-mode output on macOS (hog + sample-rate matching for bit-perfect playback)
- Gapless playback
- ReplayGain (track/album mode)

### Library
- Async file scanning with metadata extraction (title, artist, album, genre, year, cover art)
- Folder watching via FSEvents — auto-refresh when files change
- Full-text search through FTS5 (Unicode, accent-insensitive)
- Playlists — create, reorder, delete, favorites
- Temporal grouping (Today / This week / This month / by year)
- Optional MusicBrainz + Cover Art Archive enrichment (off by default)
- Optional LRCLib synced lyrics

### Interface
- Dark glass-morphism UI with translucent pills and semi-opaque borders
- Repositionable icon navigation (top / bottom)
- Three grid densities (compact 8-col, normal 6-col, large 4-col)
- Bilingual FR / EN
- Touch Bar controls
- WidgetKit widgets (small, medium, large, full-page) with deep links via `flayer://`

### Security fixes from the recent audit
- Hardened-runtime build flag enabled (prereq for future notarisation)
- FLAC metadata parser with 16 MiB block / 32 MiB picture caps and overflow-safe offset arithmetic
- Wi-Fi transfer server gated by a 6-digit PIN, bound to the Wi-Fi interface only, with a hard 200 MB body cap even when `Content-Length` is missing
- Privacy-aware `os.Logger` across database and MusicBrainz logging (user track/album/artist data marked `private`)
- Orphaned cover art auto-reclaimed on scan cleanup

## Install

### Homebrew (recommended)

> Replace `GH_OWNER` with the actual tap owner once the tap is published.

```sh
brew tap GH_OWNER/flayer
brew install --cask flayer
```

The cask's `postflight` strips `com.apple.quarantine` so Gatekeeper never blocks it.

### Manual — DMG

1. Download the latest `FlaYer-<version>.dmg` from the [Releases](#) page.
2. Open the DMG and drag `FlaYer.app` into `/Applications`.
3. **First launch only:** right-click (or control-click) the app in `/Applications`, then choose **Open**. Confirm the dialog that says "Apple cannot verify the developer." This builds a trust exception; subsequent launches go through normally.

   *Or, from Terminal:* `xattr -dr com.apple.quarantine /Applications/FlaYer.app`

Why the prompt: no paid Apple Developer account means no Developer ID certificate, no notarisation, and therefore no automatic Gatekeeper approval. The binary is still signed (ad-hoc), the hardened runtime is still applied, and the code is open for inspection — macOS just does not have a cryptographic attestation from Apple that it was built by an identified developer.

### From source

Prerequisites: macOS 14 (Sonoma) or later, Xcode 16, Homebrew, `xcodegen`.

```sh
brew install xcodegen
git clone https://github.com/GH_OWNER/flayer.git
cd flayer/macos/MusicApp
xcodegen generate
open FlaYer.xcodeproj
```

Then pick the `FlaYer` scheme and ⌘R.

## Building a release DMG

```sh
./scripts/build-release.sh 1.2
# → build/release/FlaYer-1.2.dmg
```

The script regenerates the Xcode project, archives the macOS target, ad-hoc signs it with the hardened runtime, and produces a DMG via `create-dmg`. Run once per tagged release. Environment overrides: `SCHEME`, `CONFIGURATION`, `OUTPUT_DIR`, `DEV_ID` (the `-` default means ad-hoc; set to a Developer ID when/if you get one).

## Project layout

```
.
├── macos/
│   └── MusicApp/
│       ├── project.yml              # xcodegen config (source of truth)
│       ├── Sources/
│       │   ├── Shared/              # GRDB, audio engine, services (MusicBrainz, CoverArtArchive, LRCLib)
│       │   ├── macOS/               # NSApp, settings UI, scanner, media keys, Touch Bar
│       │   ├── iOS/                 # iOS variant (currently de-prioritised)
│       │   ├── watchOS/             # Apple Watch companion
│       │   ├── Widgets/             # WidgetKit extension (small/medium/large)
│       │   └── WidgetFullPage/      # Full-page widget extension
│       └── README.md                # Detailed macOS-specific doc
├── scripts/
│   └── build-release.sh             # Archive + ad-hoc sign + DMG
├── Casks/
│   └── flayer.rb                    # Homebrew cask template — copy to your tap
└── .planning/codebase/              # Codebase audit documents (STACK, ARCHITECTURE, CONCERNS, …)
```

## Tech stack

| Layer | Tech |
|-------|------|
| Language | Swift 6.0 |
| UI | SwiftUI, `@Observable`, `@MainActor` |
| Audio | AVAudioEngine, CoreAudio, AudioToolbox |
| DB | SQLite via [GRDB](https://github.com/groue/GRDB.swift) 7 + FTS5 |
| iOS SMB | [AMSMB2](https://github.com/amosavian/AMSMB2) |
| Project gen | [XcodeGen](https://github.com/yonaskolb/XcodeGen) |
| Deployment | macOS 14 • iOS 17 • watchOS 10 |

## External services

All anonymous, rate-limited, opt-in:
- [MusicBrainz](https://musicbrainz.org/) (metadata)
- [Cover Art Archive](https://coverartarchive.org/) (album art)
- [LRCLib](https://lrclib.net/) (synced lyrics)
- [Wikidata / Wikimedia Commons](https://www.wikidata.org/) (artist photos)

On iOS: optional Jellyfin, Subsonic, or SMB server for remote libraries (credentials in Keychain).

## Contributing

1. Fork, branch from `main`.
2. `cd macos/MusicApp && xcodegen generate` before running from Xcode.
3. Before opening a PR, `./scripts/build-release.sh` must succeed — that is the closest this repo has to CI today.

The codebase audit lives in [`.planning/codebase/CONCERNS.md`](.planning/codebase/CONCERNS.md). Open a PR to knock items off it; most of the remaining medium/low items are mechanical.

## License

[PolyForm Noncommercial 1.0.0](LICENSE) — source-available, non-commercial.

- ✅ Use it, study it, modify it, share it, fork it for any non-commercial purpose (personal, research, hobby, non-profit, education…).
- ❌ You may not sell copies, offer it as a paid service, or bundle it into a commercial product. Commercial distribution is reserved to Snitch Team.
- Attribution (keep the copyright notice) is required.

If you want a commercial license, open an issue.

---

<a id="version-française"></a>

## Version française

FlaYer est un lecteur de musique natif macOS pour audiophiles. Interface SwiftUI en *glass morphism*, égaliseur paramétrique 10 bandes avec 100+ profils casques, support complet des formats lossless (FLAC / DSD / ALAC / APE), enrichissement MusicBrainz optionnel, widgets WidgetKit et compagnon Apple Watch.

> **Distribution.** Le DMG publié est **signé en ad-hoc** — il n'y a pas de compte Apple Developer payant derrière ce projet. Gatekeeper bloquera le premier lancement si tu n'installes pas via Homebrew.

### Installation

**Homebrew** (recommandé) : cf. la commande plus haut. Le cask retire automatiquement le flag de quarantaine.

**Manuel** : télécharge le DMG, déplace `FlaYer.app` dans `/Applications`, puis **clic droit → Ouvrir** la première fois pour créer l'exception Gatekeeper. Alternative Terminal :

```sh
xattr -dr com.apple.quarantine /Applications/FlaYer.app
```

### Compilation

```sh
brew install xcodegen
cd macos/MusicApp
xcodegen generate
open FlaYer.xcodeproj
```

### Release DMG

```sh
./scripts/build-release.sh 1.2
```

### Licence

[PolyForm Noncommercial 1.0.0](LICENSE) — source-available, non-commerciale.

- ✅ Utilisation, étude, modification, partage et fork libres pour tout usage non commercial (perso, recherche, hobby, asso, éducation…).
- ❌ Revente, service payant, intégration dans un produit commercial : interdits. La distribution commerciale reste l'exclusivité de Snitch Team.
- Mention du copyright à conserver.

Pour une licence commerciale, ouvre une issue.
