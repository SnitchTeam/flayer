import SwiftUI
import WatchKit

struct NowPlayingView: View {
    @Environment(WatchSessionManager.self) var session

    var body: some View {
        if let np = session.nowPlaying, !np.title.isEmpty {
            ScrollView {
                VStack(spacing: 6) {
                    // Cover art
                    if let data = np.coverArtData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 90, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.gray.opacity(0.2))
                            .frame(width: 90, height: 90)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.title)
                                    .foregroundStyle(.gray)
                            }
                    }

                    // Track info
                    VStack(spacing: 2) {
                        Text(np.title)
                            .font(.system(.headline, design: .rounded))
                            .lineLimit(1)

                        Text(np.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text(np.album)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    // Progress
                    ProgressView(value: np.duration > 0 ? np.position / np.duration : 0)
                        .tint(.orange)
                        .padding(.horizontal, 4)

                    HStack {
                        Text(formatTime(np.position))
                        Spacer()
                        Text(formatTime(np.duration))
                    }
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                    // Playback controls
                    HStack(spacing: 16) {
                        Button { session.sendCommand(.previous) } label: {
                            Image(systemName: "backward.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)

                        Button { session.sendCommand(.playPause) } label: {
                            Image(systemName: np.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)

                        Button { session.sendCommand(.next) } label: {
                            Image(systemName: "forward.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)

                    // Favorite button
                    Button {
                        session.sendCommand(.toggleFavorite)
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: np.isFavorite ? "heart.fill" : "heart")
                                .foregroundStyle(np.isFavorite ? .red : .gray)
                            Text(np.isFavorite ? Lang.removeFavorite : Lang.addFavorite)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }
        } else {
            notPlayingView
        }
    }

    private var notPlayingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.system(size: 36))
                .foregroundStyle(.gray)
            Text(Lang.nowPlaying)
                .font(.headline)
                .foregroundStyle(.secondary)
            if !session.isConnected {
                Text(Lang.notConnected)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
