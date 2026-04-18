import SwiftUI
import WidgetKit

struct FullPagePlayerView: View {
    let entry: FullPageEntry

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Large artwork
            WidgetCoverArt(path: entry.nowPlaying?.coverArtPath, size: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)

            // Track info
            VStack(spacing: 4) {
                Text(entry.nowPlaying?.title ?? "–")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(entry.nowPlaying?.artist ?? "")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)

                Text(entry.nowPlaying?.album ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }

            // Progress bar
            WidgetProgressBar(progress: entry.progress)
                .padding(.horizontal, 40)

            // Controls
            HStack(spacing: 28) {
                Button(intent: PreviousTrackIntent()) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)

                Button(intent: PlayPauseIntent()) {
                    Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)

                Button(intent: NextTrackIntent()) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            // Format badge
            if let np = entry.nowPlaying {
                formatBadge(np)
            }

            // Queue preview
            if !entry.queue.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.queue.prefix(2), id: \.path) { track in
                        HStack(spacing: 8) {
                            WidgetCoverArt(path: track.coverArtPath, size: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(track.title)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.system(size: 8))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(10)
                .widgetGlass(cornerRadius: 10)
                .padding(.horizontal, 40)
            }

            Spacer()

            // Collapse chevron
            Link(destination: URL(string: "flayer://open")!) {
                Image(systemName: "chevron.compact.down")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(16)
    }

    private func formatBadge(_ np: NowPlayingInfo) -> some View {
        let label = "\(np.format.uppercased()) · \(formatSampleRate(np.sampleRate)) · \(np.bitDepth) bit"
        return Text(label)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
    }

    private func formatSampleRate(_ rate: Int) -> String {
        let khz = Double(rate) / 1000.0
        if khz == khz.rounded() {
            return "\(Int(khz)) kHz"
        }
        return String(format: "%.1f kHz", khz)
    }
}
