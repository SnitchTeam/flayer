import SwiftUI
import CoreAudio

struct SettingsView: View {
    @Environment(AppState.self) var appState
    @State private var category: SettingsCategory = .library

    enum SettingsCategory: CaseIterable {
        case library, metadata, audio, equalizer, appearance, about

        var icon: String {
            switch self {
            case .library: return "folder"
            case .metadata: return "music.note.list"
            case .audio: return "speaker.wave.2"
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
        HStack(alignment: .top, spacing: 0) {
            // Sidebar
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
            .frame(width: 180)
            .padding(.trailing, 24)

            // Detail
            VStack(alignment: .leading, spacing: 0) {
                switch category {
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Library

    @ViewBuilder
    private var librarySettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Lang.library)
                .font(.title3)
                .fontWeight(.semibold)
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
                            .help(folder)
                        Spacer()
                        Button {
                            appState.db?.removeTracksInFolder(folder)
                            appState.settings.musicFolders.removeAll { $0 == folder }
                            appState.saveSettings()
                            appState.startWatchingFolders()
                            appState.libraryVersion += 1
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .glassCard()
                }

                Button {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        appState.settings.musicFolders.append(url.path)
                        appState.saveSettings()
                        appState.startWatchingFolders()
                        Task { await appState.scanLibrary() }
                    }
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
            }

            if appState.scanner?.isScanning == true {
                VStack(alignment: .leading, spacing: 8) {
                    let count = appState.scanner?.scanCount ?? 0
                    let total = appState.scanner?.scanTotal ?? 0

                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
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

                if appState.scanner?.scanProgress == Lang.scanComplete {
                    Text(Lang.scanComplete)
                        .font(.caption)
                        .foregroundStyle(.green.opacity(0.8))
                }
            }
        }
    }

    // MARK: - Audio

    @ViewBuilder
    private var audioSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Lang.audio)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(Lang.audioOutput)
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Spacer()
                    Button {
                        appState.player.refreshDevices()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 0) {
                    deviceRow(
                        name: Lang.defaultOutput,
                        detail: defaultDeviceName,
                        isSelected: appState.settings.outputDeviceUID.isEmpty
                    ) {
                        appState.settings.outputDeviceUID = ""
                        appState.player.setOutputDevice(uid: "")
                        appState.saveSettings()
                    }

                    ForEach(appState.player.availableDevices) { device in
                        Divider().background(Color.white.opacity(0.05))
                        deviceRow(
                            name: device.name,
                            detail: formatDeviceSampleRate(device),
                            isSelected: appState.settings.outputDeviceUID == device.uid
                        ) {
                            appState.settings.outputDeviceUID = device.uid
                            appState.player.setOutputDevice(uid: device.uid)
                            appState.saveSettings()
                        }
                    }
                }
                .glassCard()
            }

            // Playback settings
            VStack(alignment: .leading, spacing: 8) {
                Text(Lang.playbackSection)
                    .font(.caption)
                    .foregroundStyle(.gray)

                VStack(spacing: 0) {
                    settingToggle(label: Lang.gapless, isOn: Binding(
                        get: { appState.settings.gapless },
                        set: { newValue in
                            appState.settings.gapless = newValue
                            appState.player.gaplessEnabled = newValue
                            appState.saveSettings()
                        }
                    ))

                    Divider().background(Color.white.opacity(0.05))

                    settingToggle(label: Lang.exclusiveMode, isOn: Binding(
                        get: { appState.settings.exclusiveMode },
                        set: { newValue in
                            appState.settings.exclusiveMode = newValue
                            appState.player.exclusiveModeEnabled = newValue
                            appState.saveSettings()
                        }
                    ))

                    Divider().background(Color.white.opacity(0.05))

                    settingToggle(label: Lang.replayGain, isOn: Binding(
                        get: { appState.settings.replayGain },
                        set: { newValue in
                            appState.settings.replayGain = newValue
                            appState.player.replayGainEnabled = newValue
                            appState.saveSettings()
                        }
                    ))

                    if appState.settings.replayGain {
                        Divider().background(Color.white.opacity(0.05))
                        HStack {
                            Text(Lang.replayGainMode)
                                .font(.caption)
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
                        .padding(.vertical, 10)
                    }
                }
                .glassCard()
            }

        }
        .onAppear {
            appState.player.refreshDevices()
        }
    }

    private func settingToggle(label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var defaultDeviceName: String {
        let defaultID = AudioDeviceManager.getDefaultDeviceID()
        return appState.player.availableDevices.first(where: { $0.id == defaultID })?.name ?? Lang.systemDefault
    }

    private func deviceRow(name: String, detail: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.white)
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.gray.opacity(0.6))
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formatDeviceSampleRate(_ device: AudioOutputDevice) -> String {
        let current = formatSampleRate(device.sampleRate)
        if device.maxSampleRate > device.sampleRate {
            return "\(current) · max \(formatSampleRate(device.maxSampleRate))"
        }
        return current
    }

    private func formatSampleRate(_ rate: Double) -> String {
        if rate >= 1000 {
            let khz = rate / 1000
            if khz == khz.rounded() {
                return "\(Int(khz)) kHz"
            }
            return String(format: "%.1f kHz", khz)
        }
        return "\(Int(rate)) Hz"
    }

    // MARK: - Metadata

    @ViewBuilder
    private var metadataSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Lang.metadata)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                settingToggle(label: Lang.enableMusicBrainzLabel, isOn: Binding(
                    get: { appState.settings.enableMusicBrainz },
                    set: { newValue in
                        appState.settings.enableMusicBrainz = newValue
                        appState.saveSettings()
                    }
                ))

                Divider().background(Color.white.opacity(0.05))

                settingToggle(label: Lang.autoEnrichLabel, isOn: Binding(
                    get: { appState.settings.autoEnrich },
                    set: { newValue in
                        appState.settings.autoEnrich = newValue
                        appState.saveSettings()
                    }
                ))

                Divider().background(Color.white.opacity(0.05))

                settingToggle(label: Lang.useAcoustIDLabel, isOn: Binding(
                    get: { appState.settings.useAcoustID },
                    set: { newValue in
                        appState.settings.useAcoustID = newValue
                        appState.saveSettings()
                    }
                ))
            }
            .glassCard()

            if appState.settings.enableMusicBrainz {
                VStack(spacing: 0) {
                    Text(Lang.fetchFilters)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 4)

                    settingToggle(label: Lang.fetchArtist, isOn: Binding(
                        get: { appState.settings.fetchArtist },
                        set: { appState.settings.fetchArtist = $0; appState.saveSettings() }
                    ))
                    Divider().background(Color.white.opacity(0.05))
                    settingToggle(label: Lang.fetchAlbum, isOn: Binding(
                        get: { appState.settings.fetchAlbum },
                        set: { appState.settings.fetchAlbum = $0; appState.saveSettings() }
                    ))
                    Divider().background(Color.white.opacity(0.05))
                    settingToggle(label: Lang.fetchTitleName, isOn: Binding(
                        get: { appState.settings.fetchTitle },
                        set: { appState.settings.fetchTitle = $0; appState.saveSettings() }
                    ))
                    Divider().background(Color.white.opacity(0.05))
                    settingToggle(label: Lang.fetchCoverArt, isOn: Binding(
                        get: { appState.settings.fetchCoverArt },
                        set: { appState.settings.fetchCoverArt = $0; appState.saveSettings() }
                    ))
                    Divider().background(Color.white.opacity(0.05))
                    settingToggle(label: Lang.fetchGenre, isOn: Binding(
                        get: { appState.settings.fetchGenre },
                        set: { appState.settings.fetchGenre = $0; appState.saveSettings() }
                    ))
                    Divider().background(Color.white.opacity(0.05))
                    settingToggle(label: Lang.fetchYear, isOn: Binding(
                        get: { appState.settings.fetchYear },
                        set: { appState.settings.fetchYear = $0; appState.saveSettings() }
                    ))
                    Divider().background(Color.white.opacity(0.05))
                    settingToggle(label: Lang.fetchLyrics, isOn: Binding(
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
            }
        }
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
                    label: Lang.gridDensity,
                    value: gridSizeLabel
                ) {
                    cycleGridSize()
                }
                Divider().background(Color.white.opacity(0.05))
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
            }
            .glassCard()
        }
    }

    private var gridSizeLabel: String {
        switch appState.settings.gridSize {
        case "compact": return Lang.compact
        case "large": return Lang.large
        default: return Lang.normal
        }
    }

    private func cycleGridSize() {
        switch appState.settings.gridSize {
        case "medium": appState.settings.gridSize = "compact"
        case "compact": appState.settings.gridSize = "large"
        default: appState.settings.gridSize = "medium"
        }
        appState.saveSettings()
    }

    private func settingsRow(label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                Spacer()
                Text(value)
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Show only the last 2 path components: "parent/folder"
    private func shortenedPath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let folder = url.lastPathComponent
        let parent = url.deletingLastPathComponent().lastPathComponent
        return "\(parent)/\(folder)"
    }

}
