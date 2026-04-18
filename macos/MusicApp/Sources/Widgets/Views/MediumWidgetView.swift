import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: PlayerEntry

    var body: some View {
        VStack(spacing: 8) {
            // Top: 4 recent albums
            HStack(spacing: 6) {
                ForEach(entry.recentAlbums.prefix(4)) { album in
                    if let albumId = album.id {
                        Link(destination: URL(string: "flayer://album/\(albumId)")!) {
                            VStack(spacing: 3) {
                                WidgetCoverArt(path: album.coverArtPath, size: 56)
                                Text(album.name)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                if entry.recentAlbums.count < 4 {
                    ForEach(0..<(4 - entry.recentAlbums.count), id: \.self) { _ in
                        VStack(spacing: 3) {
                            WidgetCoverArt(path: nil, size: 56)
                            Text(" ")
                                .font(.system(size: 9))
                        }
                    }
                }
            }

            // Bottom: mini-player
            HStack(spacing: 8) {
                WidgetCoverArt(path: entry.nowPlaying?.coverArtPath, size: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.nowPlaying?.title ?? "–")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(entry.nowPlaying?.artist ?? "")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(entry.nowPlaying?.album ?? "")
                        .font(.system(size: 8))
                        .foregroundStyle(.gray.opacity(0.6))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    Button(intent: PreviousTrackIntent()) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)

                    Button(intent: PlayPauseIntent()) {
                        Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)

                    Button(intent: NextTrackIntent()) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)

                    Button(intent: ToggleFavoriteIntent()) {
                        Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 9))
                            .foregroundStyle(entry.isFavorite ? Color(red: 0.93, green: 0.28, blue: 0.6) : .gray)
                    }
                    .buttonStyle(.plain)
                }
            }

            WidgetProgressBar(progress: entry.progress)
                .padding(.horizontal, 2)
        }
        .padding(10)
    }
}
