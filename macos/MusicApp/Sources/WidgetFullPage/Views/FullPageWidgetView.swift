import SwiftUI
import WidgetKit

struct FullPageWidgetView: View {
    let entry: FullPageEntry

    private var activeTab: Int { entry.activeTab }

    var body: some View {
        if entry.showPlayer {
            FullPagePlayerView(entry: entry)
        } else {
            mainView
        }
    }

    private var mainView: some View {
        VStack(spacing: 0) {
            // Tab bar (glass)
            tabBar
                .padding(.horizontal, 12)
                .padding(.top, 8)

            // Content
            Group {
                switch activeTab {
                case 0:
                    FullPageAlbumsTab(albums: entry.albums)
                case 1:
                    FullPageArtistsTab(artists: entry.artists)
                case 2:
                    FullPagePlaylistsTab(
                        playlists: entry.playlists,
                        playlistCovers: entry.playlistCovers
                    )
                default:
                    FullPageAlbumsTab(albums: entry.albums)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Mini-player
            FullPageMiniPlayer(entry: entry)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(label: Lang.albums, icon: "square.stack", index: 0)
            tabButton(label: Lang.artists, icon: "person.2", index: 1)
            tabButton(label: Lang.playlists, icon: "music.note.list", index: 2)

            Link(destination: URL(string: "flayer://settings")!) {
                VStack(spacing: 2) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                    Text(Lang.settings)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding(4)
        .background(
            ZStack {
                Color.black.opacity(0.3)
                Color.white.opacity(0.05)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }

    private func tabButton(label: String, icon: String, index: Int) -> some View {
        Button(intent: SwitchTabIntent(tabIndex: index)) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(activeTab == index ? .white : .gray)
                Text(label)
                    .font(.system(size: 8, weight: activeTab == index ? .semibold : .medium))
                    .foregroundStyle(activeTab == index ? .white : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(activeTab == index ? Color.white.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
