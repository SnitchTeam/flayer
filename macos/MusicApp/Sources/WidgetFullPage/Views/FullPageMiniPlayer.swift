import SwiftUI
import WidgetKit

struct FullPageMiniPlayer: View {
    let entry: FullPageEntry

    var body: some View {
        HStack(spacing: 10) {
            // Artwork
            Link(destination: URL(string: "flayer://player")!) {
                WidgetCoverArt(path: entry.nowPlaying?.coverArtPath, size: 36)
            }

            // Track info
            Link(destination: URL(string: "flayer://player")!) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.nowPlaying?.title ?? "–")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(entry.nowPlaying?.artist ?? "")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Controls
            HStack(spacing: 14) {
                Button(intent: PreviousTrackIntent()) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)

                Button(intent: PlayPauseIntent()) {
                    Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(intent: NextTrackIntent()) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)

                Button(intent: ToggleFavoriteIntent()) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(red: 0.93, green: 0.28, blue: 0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ZStack {
                Color.black.opacity(0.4)
                Color.white.opacity(0.06)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }
}
