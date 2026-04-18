import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let entry: PlayerEntry

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            // Now playing: artwork + info + heart
            HStack(spacing: 10) {
                WidgetCoverArt(path: entry.nowPlaying?.coverArtPath, size: 64)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.nowPlaying?.title ?? "–")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(entry.nowPlaying?.artist ?? "")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(entry.nowPlaying?.album ?? "")
                        .font(.system(size: 9))
                        .foregroundStyle(.gray.opacity(0.6))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(intent: ToggleFavoriteIntent()) {
                    Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 13))
                        .foregroundStyle(entry.isFavorite ? Color(red: 0.93, green: 0.28, blue: 0.6) : .gray)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 8)

            WidgetProgressBar(progress: entry.progress)

            Spacer(minLength: 8)

            // Controls centered
            HStack(spacing: 36) {
                Button(intent: PreviousTrackIntent()) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Button(intent: PlayPauseIntent()) {
                    Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Button(intent: NextTrackIntent()) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 10)

            // Playlists (covers only)
            if !entry.playlists.isEmpty {
                LazyVGrid(columns: gridColumns, spacing: 8) {
                    ForEach(entry.playlists.prefix(4)) { playlist in
                        if let playlistId = playlist.id {
                            Link(destination: URL(string: "flayer://playlist/\(playlistId)")!) {
                                if playlist.isFavorites {
                                    ZStack {
                                        Color.white.opacity(0.06)
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 22))
                                            .foregroundStyle(Color(red: 0.93, green: 0.28, blue: 0.6))
                                    }
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    WidgetCoverArt(
                                        path: entry.playlistCovers[playlistId],
                                        size: 64
                                    )
                                }
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 6)

            // Recent albums (covers only)
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(entry.recentAlbums.prefix(4)) { album in
                    if let albumId = album.id {
                        Link(destination: URL(string: "flayer://album/\(albumId)")!) {
                            WidgetCoverArt(path: album.coverArtPath, size: 64)
                        }
                    }
                }
            }
        }
        .padding(12)
    }
}
