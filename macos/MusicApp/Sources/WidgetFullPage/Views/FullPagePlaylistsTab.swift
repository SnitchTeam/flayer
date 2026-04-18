import SwiftUI

struct FullPagePlaylistsTab: View {
    let playlists: [Playlist]
    let playlistCovers: [Int64: String]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Favorites section
                if let fav = playlists.first(where: { $0.isFavorites }), let favId = fav.id {
                    Link(destination: URL(string: "flayer://playlist/\(favId)")!) {
                        HStack(spacing: 12) {
                            WidgetCoverArt(path: playlistCovers[favId], size: 56)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color(red: 0.93, green: 0.28, blue: 0.6))
                                    Text(Lang.favorites)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundStyle(.gray.opacity(0.4))
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                    }
                    .padding(.horizontal, 12)
                }

                // User playlists grid
                let userPlaylists = playlists.filter { !$0.isFavorites }
                if !userPlaylists.isEmpty {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(userPlaylists) { playlist in
                            if let playlistId = playlist.id {
                                Link(destination: URL(string: "flayer://playlist/\(playlistId)")!) {
                                    VStack(spacing: 4) {
                                        WidgetCoverArt(
                                            path: playlistCovers[playlistId],
                                            size: 90
                                        )

                                        Text(playlist.name)
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            .padding(.top, 8)
        }
    }
}
