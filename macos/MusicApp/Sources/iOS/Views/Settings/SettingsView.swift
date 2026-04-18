import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var category: SettingsCategory = .library
    @State private var showDocumentPicker = false
    @State private var cloudDownloadProgress: (Int, Int)?  // (current, total)
    @State private var cloudDownloadTask: Task<Void, Never>?
    @State private var cloudDownloadPaused = false
    @State private var showAddServer = false
    @State private var showClearCacheConfirm = false
    @State private var pendingCloudFolder: URL?
    @State private var pendingCloudFileCount: Int = 0

    private var isIPad: Bool { sizeClass == .regular }

    enum SettingsCategory: CaseIterable, Hashable {
        case library, metadata, audio, equalizer, appearance, about

        var icon: String {
            switch self {
            case .library: return "folder"
            case .metadata: return "music.note.list"
            case .audio: return "waveform"
            case .equalizer: return "slider.horizontal.3"
            case .appearance: return "paintpalette"
            case .about: return "info.circle"
            }
        }

        var label: String {
            switch self {
            case .library: return Lang.library
            case .metadata: return Lang.metadata
            case .audio: return Lang.audio
            case .equalizer: return Lang.equalizer
            case .appearance: return Lang.appearance
            case .about: return Lang.about
            }
        }
    }

    var body: some View {
        if isIPad {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    // MARK: - iPad Layout (sidebar, unchanged)

    private var iPadLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            sidebar
                .frame(width: 180)
                .padding(.trailing, 24)

            VStack(alignment: .leading, spacing: 0) {
                settingsDetail(for: category)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - iPhone Layout (NavigationStack with category list)

    private var iPhoneLayout: some View {
        NavigationStack {
            categoryList
                .navigationTitle(Lang.settings)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var categoryList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(SettingsCategory.allCases.enumerated()), id: \.element) { index, cat in
                    NavigationLink(value: cat) {
                        HStack(spacing: 14) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text(cat.label)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.gray.opacity(0.5))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < SettingsCategory.allCases.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.06))
                            .padding(.leading, 62)
                    }
                }
            }
            .glassCard()
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(Color.black)
        .navigationDestination(for: SettingsCategory.self) { cat in
            categoryDetailPage(for: cat)
        }
    }

    // MARK: - iPhone Detail Pages

    private func categoryDetailPage(for cat: SettingsCategory) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                settingsDetail(for: cat)
            }
            .padding(16)
        }
        .background(Color.black)
        .navigationTitle(cat.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Sidebar (iPad only)

    private var sidebar: some View {
        VStack(spacing: 4) {
            ForEach(SettingsCategory.allCases, id: \.self) { cat in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        category = cat
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(category == cat ? .white : .gray)
                            .frame(width: 28, height: 28)
                            .background(category == cat ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 7))

                        Text(cat.label)
                            .font(.system(size: 12, weight: category == cat ? .semibold : .regular))
                            .foregroundStyle(category == cat ? .white : .gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(category == cat ? Color.white.opacity(0.06) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Settings Detail Content

    @ViewBuilder
    private func settingsDetail(for cat: SettingsCategory) -> some View {
        switch cat {
        case .library:
            librarySettings
        case .metadata:
            metadataSettings
        case .audio:
            audioSettings
        case .equalizer:
            EqualizerSettingsView()
        case .appearance:
            appearanceSettings
        case .about:
            aboutSettings
        }
    }

    // MARK: - Library

    @ViewBuilder
    private var librarySettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Lang.library)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            // Database path
            VStack(alignment: .leading, spacing: 4) {
                Text(Lang.database)
                    .font(.caption)
                    .foregroundStyle(.gray)
                let dbPath = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                    .appendingPathComponent("FlaYer/musicapp.db").path) ?? "~/Library/Application Support/FlaYer/musicapp.db"
                Text(dbPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.gray.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()

            VStack(alignment: .leading, spacing: 8) {
                Text(Lang.musicFolders)
                    .font(.caption)
                    .foregroundStyle(.gray)

                ForEach(appState.settings.musicFolders, id: \.self) { folder in
                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(.gray)
                        Text(shortenedPath(folder))
                            .font(.caption)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            appState.db?.removeTracksInFolder(folder)
                            appState.settings.musicFolders.removeAll { $0 == folder }
                            appState.removeFolderBookmark(path: folder)
                            appState.saveSettings()
                            appState.libraryVersion += 1
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.removeFolder)
                    }
                    .padding(12)
                    .glassCard()
                }

                Button {
                    showDocumentPicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text(Lang.addFolder)
                    }
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .glassCard()
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showDocumentPicker) {
                    DocumentPickerView { url in
                        appState.saveFolderBookmark(url: url)
                        if !appState.settings.musicFolders.contains(url.path) {
                            appState.settings.musicFolders.append(url.path)
                        }
                        appState.saveSettings()

                        let cloudCount = LibraryScanner.cloudFileCount(at: url)
                        if cloudCount > 0 {
                            pendingCloudFolder = url
                            pendingCloudFileCount = cloudCount
                        } else {
                            Task { await appState.scanLibrary() }
                        }
                    }
                }
                .alert(Lang.downloadRequired, isPresented: Binding(
                    get: { pendingCloudFolder != nil },
                    set: { if !$0 { pendingCloudFolder = nil } }
                )) {
                    Button(Lang.downloadAction) {
                        guard let url = pendingCloudFolder else { return }
                        pendingCloudFolder = nil
                        startCloudDownload(at: url)
                    }
                    Button(Lang.skipDownload) {
                        pendingCloudFolder = nil
                        Task { await appState.scanLibrary() }
                    }
                    Button(Lang.cancel, role: .cancel) {
                        pendingCloudFolder = nil
                    }
                } message: {
                    Text(Lang.downloadWarningMessage(pendingCloudFileCount))
                }
            }

            // Cloud download progress
            if let progress = cloudDownloadProgress {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        if !cloudDownloadPaused {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "pause.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.orange)
                        }
                        Text(cloudDownloadPaused ? Lang.pause : Lang.downloading)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(Lang.downloadProgress(progress.0, progress.1))
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }

                    if progress.1 > 0 {
                        ProgressView(value: Double(progress.0), total: Double(progress.1))
                            .tint(cloudDownloadPaused ? .orange : .white)
                            .scaleEffect(y: 1.5)
                    }

                    HStack(spacing: 12) {
                        Button {
                            cloudDownloadPaused.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: cloudDownloadPaused ? "play.fill" : "pause.fill")
                                    .font(.system(size: 10))
                                Text(cloudDownloadPaused ? Lang.resume : Lang.pause)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            cloudDownloadTask?.cancel()
                            cloudDownloadTask = nil
                            cloudDownloadProgress = nil
                            cloudDownloadPaused = false
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10))
                                Text(Lang.cancel)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(.red.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                }
                .padding(12)
                .glassCard()
            }

            // Scan button + progress
            if appState.scanner?.isScanning == true {
                VStack(alignment: .leading, spacing: 8) {
                    let count = appState.scanner?.scanCount ?? 0
                    let total = appState.scanner?.scanTotal ?? 0

                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                        Text(Lang.scanningDetail(count, total))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                    }

                    if total > 0 {
                        ProgressView(value: Double(count), total: Double(total))
                            .tint(.white)
                            .scaleEffect(y: 1.5)
                    }

                    if let filename = appState.scanner?.scanProgress, !filename.isEmpty {
                        Text(filename)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.gray.opacity(0.6))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
            } else {
                Button {
                    Task { await appState.scanLibrary() }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text(Lang.scanLibrary)
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

                // Scan complete status
                if appState.scanner?.scanProgress == Lang.scanComplete {
                    Text(Lang.scanComplete)
                        .font(.caption)
                        .foregroundStyle(.green.opacity(0.8))
                }
            }

            // Network Sources
            VStack(alignment: .leading, spacing: 8) {
                Text(Lang.networkSources)
                    .font(.caption)
                    .foregroundStyle(.gray)

                VStack(spacing: 0) {
                    let servers = appState.db.getServerConfigs()
                    ForEach(servers, id: \.id) { server in
                        NavigationLink {
                            ServerBrowserView(config: server)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: serverIcon(server.type))
                                    .font(.system(size: 13))
                                    .foregroundStyle(.gray)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(server.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white)
                                    Text(server.host)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.gray.opacity(0.5))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.gray.opacity(0.4))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)

                        if server.id != servers.last?.id {
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }

                    Button { showAddServer = true } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text(Lang.addSource)
                        }
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
                .glassCard()
            }
            .sheet(isPresented: $showAddServer) {
                AddServerSheet()
            }

            // Wi-Fi Transfer
            VStack(alignment: .leading, spacing: 8) {
                Text(Lang.wifiTransfer)
                    .font(.caption)
                    .foregroundStyle(.gray)

                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "wifi")
                            .font(.system(size: 13))
                            .foregroundStyle(appState.wifiServer?.isRunning == true ? .green : .gray)
                        Text(appState.wifiServer?.isRunning == true ? Lang.wifiServerActive : Lang.wifiServerOff)
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { appState.wifiServer?.isRunning ?? false },
                            set: { $0 ? appState.startWiFiServer() : appState.stopWiFiServer() }
                        ))
                        .labelsHidden()
                        .tint(.accentColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if appState.wifiServer?.isRunning == true {
                        Divider().background(Color.white.opacity(0.05))
                        VStack(alignment: .leading, spacing: 8) {
                            Text(appState.wifiServer?.serverURL ?? "")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.white)
                                .textSelection(.enabled)
                            if let pin = appState.wifiServer?.pin, !pin.isEmpty {
                                HStack(spacing: 6) {
                                    Text("PIN")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.gray)
                                    Text(pin)
                                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.white)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                .glassCard()
            }

            // Cache Storage
            VStack(alignment: .leading, spacing: 8) {
                Text(Lang.storageCache)
                    .font(.caption)
                    .foregroundStyle(.gray)

                VStack(spacing: 0) {
                    let stats = appState.db.getCacheStats()

                    HStack {
                        Text(Lang.cacheUsage(formatCacheSize(stats.totalSize), cacheQuotaLabel))
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if stats.totalSize > 0 {
                        Divider().background(Color.white.opacity(0.05))
                        ForEach(Array(stats.bySource.enumerated()), id: \.offset) { _, source in
                            HStack {
                                Text(source.name ?? source.type.capitalized)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(formatCacheSize(source.size))
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.gray.opacity(0.5))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        Divider().background(Color.white.opacity(0.05))
                        Button {
                            showClearCacheConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red.opacity(0.7))
                                Text(Lang.clearAllCache)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red.opacity(0.7))
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .glassCard()
            }
            .alert(Lang.clearCacheConfirm, isPresented: $showClearCacheConfirm) {
                Button(Lang.cancel, role: .cancel) {}
                Button(Lang.delete, role: .destructive) {
                    appState.cacheManager.deleteAllCache()
                }
            }

        }
    }

    // MARK: - Metadata

    @ViewBuilder
    private var metadataSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Lang.metadata)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                HStack {
                    Text(Lang.enableMusicBrainzLabel)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.settings.enableMusicBrainz },
                        set: { newValue in
                            appState.settings.enableMusicBrainz = newValue
                            appState.saveSettings()
                        }
                    ))
                    .labelsHidden()
                    .tint(.accentColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().background(Color.white.opacity(0.05))

                HStack {
                    Text(Lang.autoEnrichLabel)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.settings.autoEnrich },
                        set: { newValue in
                            appState.settings.autoEnrich = newValue
                            appState.saveSettings()
                        }
                    ))
                    .labelsHidden()
                    .tint(.accentColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().background(Color.white.opacity(0.05))

                HStack {
                    Text(Lang.useAcoustIDLabel)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.settings.useAcoustID },
                        set: { newValue in
                            appState.settings.useAcoustID = newValue
                            appState.saveSettings()
                        }
                    ))
                    .labelsHidden()
                    .tint(.accentColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .glassCard()

            // Fetch filters
            if appState.settings.enableMusicBrainz {
            VStack(spacing: 0) {
                Text(Lang.fetchFilters)
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 4)

                metadataToggle(Lang.fetchArtist, icon: "person", binding: Binding(
                    get: { appState.settings.fetchArtist },
                    set: { appState.settings.fetchArtist = $0; appState.saveSettings() }
                ))
                Divider().background(Color.white.opacity(0.05))
                metadataToggle(Lang.fetchAlbum, icon: "square.stack", binding: Binding(
                    get: { appState.settings.fetchAlbum },
                    set: { appState.settings.fetchAlbum = $0; appState.saveSettings() }
                ))
                Divider().background(Color.white.opacity(0.05))
                metadataToggle(Lang.fetchTitleName, icon: "music.note", binding: Binding(
                    get: { appState.settings.fetchTitle },
                    set: { appState.settings.fetchTitle = $0; appState.saveSettings() }
                ))
                Divider().background(Color.white.opacity(0.05))
                metadataToggle(Lang.fetchCoverArt, icon: "photo", binding: Binding(
                    get: { appState.settings.fetchCoverArt },
                    set: { appState.settings.fetchCoverArt = $0; appState.saveSettings() }
                ))
                Divider().background(Color.white.opacity(0.05))
                metadataToggle(Lang.fetchGenre, icon: "guitars", binding: Binding(
                    get: { appState.settings.fetchGenre },
                    set: { appState.settings.fetchGenre = $0; appState.saveSettings() }
                ))
                Divider().background(Color.white.opacity(0.05))
                metadataToggle(Lang.fetchYear, icon: "calendar", binding: Binding(
                    get: { appState.settings.fetchYear },
                    set: { appState.settings.fetchYear = $0; appState.saveSettings() }
                ))
                Divider().background(Color.white.opacity(0.05))
                metadataToggle(Lang.fetchLyrics, icon: "text.quote", binding: Binding(
                    get: { appState.settings.fetchLyrics },
                    set: { appState.settings.fetchLyrics = $0; appState.saveSettings() }
                ))
            }
            .glassCard()
            }

            // Enrich button + progress
            if appState.enricher?.isEnriching == true {
                VStack(alignment: .leading, spacing: 8) {
                    let count = appState.enricher?.enrichCount ?? 0
                    let total = appState.enricher?.enrichTotal ?? 0

                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                        Text(Lang.enriching)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(count)/\(total)")
                            .font(.caption)
                            .foregroundStyle(.gray)

                        Button {
                            appState.enricher?.cancelEnrichment()
                        } label: {
                            Text(Lang.cancel)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if total > 0 {
                        ProgressView(value: Double(count), total: Double(total))
                            .tint(.white)
                            .scaleEffect(y: 1.5)
                    }

                    if let filename = appState.enricher?.enrichProgress, !filename.isEmpty {
                        Text(filename)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.gray.opacity(0.6))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
            } else {
                Button {
                    Task { await appState.enrichLibrary() }
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(Lang.enrichLibrary)
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

                if appState.enricher?.enrichProgress == Lang.enrichComplete {
                    let covers = appState.enricher?.coversFound ?? 0
                    let lyrics = appState.enricher?.lyricsFound ?? 0
                    let enriched = appState.enricher?.metadataEnriched ?? 0
                    Text(Lang.enrichResult(covers, lyrics, enriched))
                        .font(.caption)
                        .foregroundStyle(.green.opacity(0.8))
                }

                Button {
                    appState.db.clearEnrichmentQueue()
                    // Also clear musicbrainz_id on all tracks so they can be re-enriched
                    appState.db.resetEnrichmentData()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text(Lang.resetEnrichment)
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func metadataToggle(_ label: String, icon: String, binding: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.gray)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Appearance

    @ViewBuilder
    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Lang.appearance)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                settingsRow(
                    label: Lang.letterNav,
                    value: appState.settings.showLetterNav ? Lang.visible : Lang.hidden
                ) {
                    appState.settings.showLetterNav.toggle()
                    appState.saveSettings()
                }
                Divider().background(Color.white.opacity(0.05))
                settingsRow(
                    label: Lang.tracksTab,
                    value: appState.settings.showTracks ? Lang.active : Lang.inactive
                ) {
                    appState.settings.showTracks.toggle()
                    appState.saveSettings()
                }
                Divider().background(Color.white.opacity(0.05))
                settingsRow(
                    label: Lang.artistUnderAlbum,
                    value: appState.settings.showArtistLabel ? Lang.active : Lang.inactive
                ) {
                    appState.settings.showArtistLabel.toggle()
                    appState.saveSettings()
                }
                Divider().background(Color.white.opacity(0.05))
                settingsRow(
                    label: Lang.barPosition,
                    value: appState.settings.navPosition == "top" ? Lang.top : Lang.bottom
                ) {
                    appState.settings.navPosition = appState.settings.navPosition == "top" ? "bottom" : "top"
                    appState.saveSettings()
                }
                Divider().background(Color.white.opacity(0.05))
                settingsRow(
                    label: Lang.lang,
                    value: appState.settings.language == "fr" ? Lang.french : Lang.english
                ) {
                    appState.settings.language = appState.settings.language == "fr" ? "en" : "fr"
                    appState.saveSettings()
                }
                #if os(iOS)
                Divider().background(Color.white.opacity(0.05))
                settingsRow(
                    label: Lang.autoOpenPlayer,
                    value: appState.settings.autoOpenPlayer ? Lang.active : Lang.inactive
                ) {
                    appState.settings.autoOpenPlayer.toggle()
                    appState.saveSettings()
                }
                #endif
            }
            .glassCard()
        }
    }

    private func settingsRow(label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                Spacer()
                Text(value)
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Audio

    @ViewBuilder
    private var audioSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Lang.audio)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                HStack {
                    Text(Lang.gapless)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.settings.gapless },
                        set: { newValue in
                            appState.settings.gapless = newValue
                            appState.player.gaplessEnabled = newValue
                            appState.saveSettings()
                        }
                    ))
                    .labelsHidden()
                    .tint(.accentColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().background(Color.white.opacity(0.05))

                HStack {
                    Text(Lang.replayGain)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.settings.replayGain },
                        set: { newValue in
                            appState.settings.replayGain = newValue
                            appState.player.replayGainEnabled = newValue
                            appState.saveSettings()
                        }
                    ))
                    .labelsHidden()
                    .tint(.accentColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if appState.settings.replayGain {
                    Divider().background(Color.white.opacity(0.05))

                    HStack {
                        Text(Lang.replayGainMode)
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { appState.settings.replayGainMode },
                            set: { newValue in
                                appState.settings.replayGainMode = newValue
                                appState.player.replayGainMode = newValue
                                appState.saveSettings()
                            }
                        )) {
                            Text(Lang.trackMode).tag("track")
                            Text(Lang.albumMode).tag("album")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .glassCard()
        }
    }

    // MARK: - About

    @ViewBuilder
    private var aboutSettings: some View {
        let stats = appState.db?.getLibraryStats() ?? (tracks: 0, albums: 0, artists: 0, totalSize: Int64(0))

        VStack(alignment: .leading, spacing: 16) {
            Text(Lang.about)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            // App info
            VStack(spacing: 0) {
                HStack {
                    Text("FlaYer")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Lang.version) \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .glassCard()

            // Library stats
            VStack(alignment: .leading, spacing: 8) {
                Text(Lang.libraryStats)
                    .font(.caption)
                    .foregroundStyle(.gray)

                VStack(spacing: 0) {
                    statsRow(icon: "music.note", label: Lang.tracks, value: "\(stats.tracks)")
                    Divider().background(Color.white.opacity(0.05))
                    statsRow(icon: "square.stack", label: Lang.albums, value: "\(stats.albums)")
                    Divider().background(Color.white.opacity(0.05))
                    statsRow(icon: "person.2", label: Lang.artists, value: "\(stats.artists)")
                    Divider().background(Color.white.opacity(0.05))
                    statsRow(icon: "internaldrive", label: Lang.totalSize, value: formatSize(stats.totalSize))
                }
                .glassCard()
            }

            // Cache
            VStack(alignment: .leading, spacing: 8) {
                Text(Lang.coverArtCache)
                    .font(.caption)
                    .foregroundStyle(.gray)

                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                            .frame(width: 24)
                        Text(Lang.fileSize)
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(coverArtCacheSize())
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider().background(Color.white.opacity(0.05))

                    Button {
                        clearCoverArtCache()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundStyle(.red.opacity(0.7))
                                .frame(width: 24)
                            Text(Lang.clearCache)
                                .font(.system(size: 12))
                                .foregroundStyle(.red.opacity(0.7))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .glassCard()
            }
        }
    }

    private func statsRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.gray)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func formatSize(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.1f MB", mb)
    }

    private func coverArtCacheSize() -> String {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CoverArt") else { return "0 MB" }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) else { return "0 MB" }
        let total = files.reduce(Int64(0)) { sum, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return sum + Int64(size)
        }
        return formatSize(total)
    }

    private func clearCoverArtCache() {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CoverArt") else { return }
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    private func serverIcon(_ type: String) -> String {
        switch type {
        case "smb": return "externaldrive.connected.to.line.below"
        case "subsonic": return "music.note.house"
        case "jellyfin": return "play.rectangle"
        default: return "server.rack"
        }
    }

    private func formatCacheSize(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.1f MB", mb)
    }

    private var cacheQuotaLabel: String {
        let quota = appState.settings.cacheQuotaGB
        if quota == 0 { return Lang.unlimited }
        return "\(quota) GB"
    }

    private func startCloudDownload(at url: URL) {
        cloudDownloadPaused = false
        cloudDownloadTask = Task {
            let success = await LibraryScanner.downloadCloudFiles(
                at: url,
                isPaused: { cloudDownloadPaused }
            ) { current, total in
                Task { @MainActor in
                    cloudDownloadProgress = (current, total)
                }
            }
            await MainActor.run {
                cloudDownloadProgress = nil
                cloudDownloadTask = nil
                cloudDownloadPaused = false
            }
            if success {
                await appState.scanLibrary()
            }
        }
    }

    /// Show only the last 2 path components: "parent/folder"
    private func shortenedPath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let folder = url.lastPathComponent
        let parent = url.deletingLastPathComponent().lastPathComponent
        return "\(parent)/\(folder)"
    }
}
