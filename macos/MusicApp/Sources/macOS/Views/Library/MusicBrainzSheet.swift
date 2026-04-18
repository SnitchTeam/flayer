import SwiftUI

// MARK: - Cover Art with release-group fallback

private struct CoverArtImage: View {
    let primaryURL: URL?
    let fallbackURL: URL?
    let size: CGFloat
    let cornerRadius: CGFloat

    @State private var useFallback = false

    var body: some View {
        AsyncImage(url: useFallback ? fallbackURL : primaryURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .failure:
                if !useFallback && fallbackURL != nil {
                    Color.clear.onAppear { useFallback = true }
                } else {
                    placeholder
                }
            default:
                ProgressView().controlSize(.small)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var placeholder: some View {
        ZStack {
            Color.white.opacity(0.06)
            Image(systemName: "music.note")
                .foregroundStyle(.gray.opacity(0.4))
        }
    }
}

enum MusicBrainzSheetMode: Identifiable {
    case artwork
    case metadata

    var id: String {
        switch self {
        case .artwork: return "artwork"
        case .metadata: return "metadata"
        }
    }
}

struct MusicBrainzSheet: View {
    @Environment(AppState.self) private var appState
    let album: Album
    let mode: MusicBrainzSheetMode
    var onDone: () -> Void

    @State private var releases: [MusicBrainzService.MBRelease] = []
    @State private var isLoading = true
    @State private var isApplying = false

    private let artworkColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(mode == .artwork ? Lang.changeArtwork : Lang.updateMetadata)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Spacer()

                    Button(action: onDone) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.gray)
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if isLoading {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                } else if releases.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28))
                            .foregroundStyle(.gray)
                        Text(Lang.noResults)
                            .font(.callout)
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                } else if mode == .artwork {
                    artworkGrid
                } else {
                    releaseList
                }
            }

            if isApplying {
                Color.black.opacity(0.6).ignoresSafeArea()
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .task { await search() }
    }

    @ViewBuilder
    private var artworkGrid: some View {
        ScrollView {
            LazyVGrid(columns: artworkColumns, spacing: 12) {
                ForEach(releases) { release in
                    Button {
                        Task { await selectArtwork(release) }
                    } label: {
                        VStack(spacing: 6) {
                            CoverArtImage(
                                primaryURL: release.coverArtURL,
                                fallbackURL: release.coverArtFallbackURL,
                                size: 130, cornerRadius: 6
                            )

                            releaseCaption(release)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var releaseList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(releases) { release in
                    Button {
                        Task { await selectRelease(release) }
                    } label: {
                        HStack(spacing: 12) {
                            CoverArtImage(
                                primaryURL: release.coverArtURL,
                                fallbackURL: release.coverArtFallbackURL,
                                size: 48, cornerRadius: 5
                            )

                            VStack(alignment: .leading, spacing: 3) {
                                Text(release.title ?? album.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(release.artistName ?? album.albumArtist)
                                    .font(.caption2)
                                    .foregroundStyle(.gray)
                                    .lineLimit(1)
                                HStack(spacing: 8) {
                                    if let year = release.yearFromDate {
                                        Text(String(year))
                                    }
                                    if let label = release.labelName {
                                        Text(label)
                                    }
                                    if let country = release.country {
                                        Text(country)
                                    }
                                    if let type = release.albumType {
                                        Text(type)
                                    }
                                }
                                .font(.system(size: 10))
                                .foregroundStyle(.gray.opacity(0.5))
                                .lineLimit(1)
                            }

                            Spacer()

                            if let score = release.score {
                                Text("\(score)%")
                                    .font(.caption2)
                                    .foregroundStyle(.gray.opacity(0.4))
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.gray.opacity(0.3))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .background(Color.white.opacity(0.05))
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private func releaseCaption(_ release: MusicBrainzService.MBRelease) -> some View {
        VStack(spacing: 2) {
            if let artist = release.artistName {
                Text(artist)
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }
            HStack(spacing: 4) {
                if let year = release.yearFromDate {
                    Text(String(year))
                }
                if let country = release.country {
                    Text("· \(country)")
                }
            }
            .font(.system(size: 9))
            .foregroundStyle(.gray.opacity(0.5))
        }
        .frame(width: 130)
    }

    private func search() async {
        guard let enricher = appState.enricher else {
            isLoading = false
            return
        }
        var artist = album.albumArtist
        if artist.isEmpty || artist == Lang.unknownArtist {
            if let albumId = album.id,
               let firstTrack = appState.db.getAlbumTracks(albumId: albumId).first,
               !firstTrack.artist.isEmpty && firstTrack.artist != Lang.unknownArtist {
                artist = firstTrack.artist
            }
        }
        releases = await enricher.searchReleasesForAlbum(
            artist: artist,
            album: album.name
        )
        isLoading = false
    }

    private func selectArtwork(_ release: MusicBrainzService.MBRelease) async {
        guard let albumId = album.id, let enricher = appState.enricher else { return }
        isApplying = true
        _ = await enricher.updateAlbumArtwork(albumId: albumId, releaseMBID: release.id, releaseGroupMBID: release.releaseGroupId)
        isApplying = false
        onDone()
    }

    private func selectRelease(_ release: MusicBrainzService.MBRelease) async {
        guard let albumId = album.id, let enricher = appState.enricher else { return }
        isApplying = true
        await enricher.enrichSingleAlbum(albumId: albumId, release: release)
        isApplying = false
        onDone()
    }
}
