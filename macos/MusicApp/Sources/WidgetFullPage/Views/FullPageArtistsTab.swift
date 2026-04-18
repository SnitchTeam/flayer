import SwiftUI

struct FullPageArtistsTab: View {
    let artists: [Artist]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(artists) { artist in
                    Link(destination: URL(string: "flayer://artist/\(artist.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")") ?? URL(string: "flayer://open")!) {
                        HStack(spacing: 12) {
                            // Circular avatar
                            Group {
                                if let path = artist.coverArtPath {
                                    WidgetCoverArt(path: path, size: 40)
                                        .clipShape(Circle())
                                } else {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.06))
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.gray.opacity(0.5))
                                    }
                                    .frame(width: 40, height: 40)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(artist.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 9))
                                .foregroundStyle(.gray.opacity(0.4))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }

                    Divider()
                        .background(Color.white.opacity(0.06))
                        .padding(.leading, 66)
                }
            }
            .padding(.top, 8)
        }
    }
}
