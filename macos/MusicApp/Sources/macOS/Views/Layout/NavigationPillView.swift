import SwiftUI

struct NavigationPillView: View {
    @Binding var currentPage: Page
    @Binding var searchOpen: Bool
    @Binding var searchQuery: String
    var hasTrackPlaying: Bool
    var onSwitchToPlayer: () -> Void

    @Environment(AppState.self) private var appState
    @FocusState private var searchFocused: Bool
    @Namespace private var tabNamespace

    private var navItems: [(page: Page, icon: String)] {
        var items: [(page: Page, icon: String)] = [
            (.playlists, "music.note.list"),
            (.artists, "person.2"),
            (.albums, "square.stack"),
        ]
        if appState.settings.showTracks {
            items.append((.tracks, "music.note"))
        }
        items.append((.settings, "gearshape"))
        return items
    }

    var body: some View {
        HStack(spacing: 4) {
            if searchOpen {
                Spacer()
                searchField
                Spacer()
            } else {
                navButtons
            }

            searchToggleButton

            if hasTrackPlaying {
                playerToggleButton
            }
        }
        .frame(width: 460, height: 34)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .glassPill()
        .animation(Anim.navTab, value: searchOpen)
    }

    private var isNavTop: Bool {
        appState.settings.navPosition == "top"
    }

    private var playerToggleButton: some View {
        Button(action: onSwitchToPlayer) {
            Image(systemName: isNavTop ? "chevron.down" : "chevron.up")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.gray)
                .padding(8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var navButtons: some View {
        ForEach(navItems, id: \.page) { item in
            Button {
                withAnimation(Anim.navTab) {
                    currentPage = item.page
                    searchOpen = false
                    searchQuery = ""
                }
            } label: {
                Image(systemName: item.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(currentPage == item.page ? .white : .gray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background {
                        if currentPage == item.page {
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                        }
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var searchToggleButton: some View {
        Button {
            withAnimation(Anim.navTab) {
                if searchOpen {
                    searchOpen = false
                    searchQuery = ""
                    if currentPage == .search { currentPage = .albums }
                } else {
                    searchOpen = true
                    currentPage = .search
                    searchQuery = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        searchFocused = true
                    }
                }
            }
        } label: {
            Image(systemName: searchOpen ? "xmark" : "magnifyingglass")
                .font(.system(size: searchOpen ? 14 : 18))
                .foregroundStyle(searchOpen ? .gray : (currentPage == .search ? .white : .gray))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    if !searchOpen && currentPage == .search {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        TextField(Lang.search, text: $searchQuery)
            .textFieldStyle(.plain)
            .font(.system(size: 18))
            .foregroundStyle(.white)
            .tint(.white)
            .focused($searchFocused)
            .onSubmit {}
            .multilineTextAlignment(.center)
    }
}
