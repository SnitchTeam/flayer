import SwiftUI

struct ServerBrowserView: View {
    @Environment(AppState.self) private var appState
    let config: ServerConfig

    @State private var items: [BrowseItem] = []
    @State private var currentPath: String = "/"
    @State private var isLoading = false
    @State private var selectedItems: Set<String> = Set()
    @State private var navigationStack: [(String, String)] = [] // (path, title) tuples

    struct BrowseItem: Identifiable {
        let id: String
        let name: String
        let subtitle: String?
        let isDirectory: Bool
        let remotePath: String
        let size: Int64
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding(40)
                } else if items.isEmpty {
                    Text(Lang.noResults)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .padding(40)
                } else {
                    ForEach(items) { item in
                        Button {
                            if item.isDirectory {
                                navigateInto(item)
                            } else {
                                toggleSelection(item.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.isDirectory ? "folder" : "music.note")
                                    .font(.system(size: 13))
                                    .foregroundStyle(item.isDirectory ? .yellow.opacity(0.7) : .gray)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    if let subtitle = item.subtitle {
                                        Text(subtitle)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.gray.opacity(0.5))
                                    }
                                }

                                Spacer()

                                if !item.isDirectory {
                                    if selectedItems.contains(item.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white)
                                    } else {
                                        Image(systemName: "circle")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.gray.opacity(0.3))
                                    }
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.gray.opacity(0.4))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider().background(Color.white.opacity(0.05))
                    }
                }
            }
            .glassCard()
            .padding(16)
        }
        .background(Color.black)
        .navigationTitle(config.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if !selectedItems.isEmpty {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        downloadSelected()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("\(Lang.downloadSelected) (\(selectedItems.count))")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task {
            await loadItems()
        }
    }

    private func navigateInto(_ item: BrowseItem) {
        navigationStack.append((currentPath, config.name))
        currentPath = item.remotePath
        Task { await loadItems() }
    }

    private func toggleSelection(_ id: String) {
        if selectedItems.contains(id) {
            selectedItems.remove(id)
        } else {
            selectedItems.insert(id)
        }
    }

    private func loadItems() async {
        isLoading = true
        items = []

        guard let password = KeychainHelper.load(key: "flayer-server-\(config.id)") else {
            isLoading = false
            return
        }

        do {
            switch config.type {
            case "smb":
                let client = SMBClient(config: config, password: password)
                let smbItems = try await client.listDirectory(path: currentPath)
                items = smbItems.map { item in
                    BrowseItem(id: item.path, name: item.name, subtitle: item.isDirectory ? nil : formatSize(item.size),
                              isDirectory: item.isDirectory, remotePath: item.path, size: item.size)
                }
            case "subsonic":
                let client = SubsonicClient(config: config, password: password)
                if currentPath == "/" {
                    // Show artists
                    let artists = try await client.getArtists()
                    items = artists.map { a in
                        BrowseItem(id: a.id, name: a.name, subtitle: Lang.albumCount(a.albumCount),
                                  isDirectory: true, remotePath: "artist:\(a.id)", size: 0)
                    }
                } else if currentPath.hasPrefix("artist:") {
                    let artistId = String(currentPath.dropFirst("artist:".count))
                    let albums = try await client.getArtist(id: artistId)
                    items = albums.map { a in
                        BrowseItem(id: a.id, name: a.name, subtitle: "\(a.artist) \u{00B7} \(Lang.trackCount(a.songCount))",
                                  isDirectory: true, remotePath: "album:\(a.id)", size: 0)
                    }
                } else if currentPath.hasPrefix("album:") {
                    let albumId = String(currentPath.dropFirst("album:".count))
                    let tracks = try await client.getAlbum(id: albumId)
                    items = tracks.map { t in
                        BrowseItem(id: t.id, name: t.title, subtitle: "\(t.artist) \u{00B7} \(t.suffix.uppercased())",
                                  isDirectory: false, remotePath: t.id, size: t.size)
                    }
                }
            case "jellyfin":
                let client = JellyfinClient(config: config, password: password)
                if currentPath == "/" {
                    let artists = try await client.getArtists()
                    items = artists.map { a in
                        BrowseItem(id: a.id, name: a.name, subtitle: nil,
                                  isDirectory: true, remotePath: "artist:\(a.id)", size: 0)
                    }
                } else if currentPath.hasPrefix("artist:") {
                    let artistId = String(currentPath.dropFirst("artist:".count))
                    let albums = try await client.getAlbums(artistId: artistId)
                    items = albums.map { a in
                        BrowseItem(id: a.id, name: a.name, subtitle: a.artist,
                                  isDirectory: true, remotePath: "album:\(a.id)", size: 0)
                    }
                } else if currentPath.hasPrefix("album:") {
                    let albumId = String(currentPath.dropFirst("album:".count))
                    let tracks = try await client.getTracks(albumId: albumId)
                    items = tracks.map { t in
                        let sub = t.container.isEmpty ? t.artist : "\(t.artist) \u{00B7} \(t.container.uppercased())"
                        return BrowseItem(id: t.id, name: t.title, subtitle: sub,
                                  isDirectory: false, remotePath: t.id, size: t.size)
                    }
                }
            default: break
            }
        } catch {
            // Items stay empty, loading indicator hidden
        }

        isLoading = false
    }

    private func downloadSelected() {
        guard let password = KeychainHelper.load(key: "flayer-server-\(config.id)") else { return }
        let destDir = appState.cacheManager.cacheDirectory(sourceType: config.type, sourceId: config.id)

        let selectedItemsList = items.filter { selectedItems.contains($0.id) }

        Task {
            for item in selectedItemsList {
                switch config.type {
                case "smb":
                    let client = SMBClient(config: config, password: password)
                    appState.downloadManager.downloadFromSMB(client: client, remotePath: item.remotePath,
                                                              filename: item.name, sourceId: config.id, destinationDir: destDir)
                case "subsonic":
                    let client = SubsonicClient(config: config, password: password)
                    if let url = await client.downloadURL(trackId: item.remotePath) {
                        let ext = item.subtitle?.split(separator: "\u{00B7}").last?.trimmingCharacters(in: .whitespaces).lowercased() ?? "flac"
                        appState.downloadManager.downloadFromURL(url, filename: "\(item.name).\(ext)",
                                                                  sourceType: "subsonic", sourceId: config.id, remotePath: item.remotePath, destinationDir: destDir)
                    }
                case "jellyfin":
                    let client = JellyfinClient(config: config, password: password)
                    if let request = await client.downloadRequest(trackId: item.remotePath) {
                        let ext = item.subtitle?.split(separator: "\u{00B7}").last?.trimmingCharacters(in: .whitespaces).lowercased() ?? "flac"
                        appState.downloadManager.downloadFromRequest(request, filename: "\(item.name).\(ext)",
                                                                      sourceType: "jellyfin", sourceId: config.id, remotePath: item.remotePath, destinationDir: destDir)
                    }
                default: break
                }
            }
        }

        selectedItems.removeAll()
    }

    private func formatSize(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }
}
