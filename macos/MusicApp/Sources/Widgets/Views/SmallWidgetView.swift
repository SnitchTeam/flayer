import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: PlayerEntry

    var body: some View {
        VStack(spacing: 6) {
            // Artwork + track info
            HStack(spacing: 8) {
                Link(destination: URL(string: "flayer://open")!) {
                    WidgetCoverArt(path: entry.nowPlaying?.coverArtPath, size: 56)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.nowPlaying?.title ?? "–")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(entry.nowPlaying?.artist ?? "")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Progress bar
            WidgetProgressBar(progress: entry.progress)
                .padding(.horizontal, 2)

            // Controls
            HStack(spacing: 0) {
                Button(intent: PreviousTrackIntent()) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                Button(intent: PlayPauseIntent()) {
                    Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                Button(intent: NextTrackIntent()) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                Button(intent: ToggleFavoriteIntent()) {
                    Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 10))
                        .foregroundStyle(entry.isFavorite ? Color(red: 0.93, green: 0.28, blue: 0.6) : .gray)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
    }
}
