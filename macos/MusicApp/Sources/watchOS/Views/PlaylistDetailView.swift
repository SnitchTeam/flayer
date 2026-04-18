import SwiftUI
import WatchKit

struct PlaylistDetailView: View {
    @Environment(WatchSessionManager.self) var session
    let playlist: WatchPlaylist
    @State private var tracks: [WatchTrack] = []
    @State private var isLoading = true

    var body: some View {
        List {
            // Header
            Section {
                HStack(spacing: 6) {
                    if playlist.isFavorites {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                    }
                    Text(playlist.name)
                        .font(.headline)
                        .lineLimit(2)
                }
                .listRowBackground(Color.clear)
            }

            // Actions
            Section {
                Button {
                    session.playPlaylist(id: playlist.id)
                    WKInterfaceDevice.current().play(.success)
                } label: {
                    Label(Lang.playAll, systemImage: "play.fill")
                }

                Button {
                    session.shufflePlaylist(id: playlist.id)
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
                    Text(Lang.emptyPlaylist)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        Button {
                            session.playTrackInPlaylist(playlistId: playlist.id, trackIndex: index)
                            WKInterfaceDevice.current().play(.success)
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(track.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
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
        session.requestPlaylistTracks(playlistId: playlist.id) { result in
            tracks = result
            isLoading = false
        }
    }
}
