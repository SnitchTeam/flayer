import SwiftUI

struct FullPageAlbumsTab: View {
    let albums: [Album]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(albums) { album in
                    if let albumId = album.id {
                        Link(destination: URL(string: "flayer://album/\(albumId)")!) {
                            VStack(spacing: 4) {
                                WidgetCoverArt(path: album.coverArtPath, size: 100)

                                Text(album.name)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                Text(album.albumArtist)
                                    .font(.system(size: 8))
                                    .foregroundStyle(.gray)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }
}
