import SwiftUI
import WatchKit

struct AlbumDetailView: View {
    @Environment(WatchSessionManager.self) var session
    let album: WatchAlbum
    @State private var tracks: [WatchTrack] = []
    @State private var isLoading = true

    var body: some View {
        List {
            // Album header
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.name)
                        .font(.headline)
                        .lineLimit(2)
                    Text(album.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let year = album.year {
                        Text(String(year))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .listRowBackground(Color.clear)
            }

            // Actions
            Section {
                Button {
                    session.playAlbum(id: album.id)
                    WKInterfaceDevice.current().play(.success)
                } label: {
                    Label(Lang.playAll, systemImage: "play.fill")
                }

                Button {
                    session.shuffleAlbum(id: album.id)
                    WKInterfaceDevice.current().play(.success)
                } label: {
                    Label(Lang.shufflePlay, systemImage: "shuffle")
                }
            }

            // Track list
            Section {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if tracks.isEmpty {
                    Text(Lang.noResults)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        Button {
                            session.playTrack(albumId: album.id, trackIndex: index)
                            WKInterfaceDevice.current().play(.success)
                        } label: {
                            HStack(spacing: 6) {
                                if let num = track.trackNumber {
                                    Text("\(num)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 20, alignment: .trailing)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(track.title)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Text(formatDuration(track.duration))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear { loadTracks() }
    }

    private func loadTracks() {
        session.requestAlbumTracks(albumId: album.id) { result in
            tracks = result
            isLoading = false
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
