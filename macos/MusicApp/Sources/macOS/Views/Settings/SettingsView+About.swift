import SwiftUI

/// Software-update panel for the About tab. Drives UpdateChecker through
/// its Status state machine: check → available? → download & stage →
/// restart to install. Homebrew-installed copies short-circuit with a
/// `brew upgrade --cask flayer` hint since replacing the bundle in place
/// would leave the cask manifest stale.
private struct SoftwareUpdateCard: View {
    @Bindable var checker: UpdateChecker
    @State private var confirmingRestart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Lang.softwareUpdate)
                .font(.caption)
                .foregroundStyle(.gray)

            VStack(alignment: .leading, spacing: 10) {
                statusLine
                actionRow
                releaseNotesBlock
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassCard()
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        HStack(spacing: 8) {
            icon
            Text(statusText)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .textSelection(.enabled)
            Spacer()
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch checker.status {
        case .checking, .downloading, .installing:
            ProgressView()
                .controlSize(.small)
                .tint(.white)
        case .upToDate:
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.green)
        case .available, .readyToRestart:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
        case .error:
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        case .idle:
            Image(systemName: "arrow.clockwise")
                .foregroundStyle(.gray)
        }
    }

    private var statusText: String {
        switch checker.status {
        case .idle:
            return Lang.updateIdle(checker.currentVersion)
        case .checking:
            return Lang.updateChecking
        case .upToDate:
            return Lang.updateUpToDate(checker.currentVersion)
        case let .available(version, _, _):
            return Lang.updateAvailable(version)
        case .downloading:
            return Lang.updateDownloading
        case .installing:
            return Lang.updateInstalling
        case let .readyToRestart(version):
            return Lang.updateReadyToRestart(version)
        case let .error(message):
            return Lang.updateError(message)
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        if checker.installedViaHomebrew {
            Text(Lang.updateViaHomebrew)
                .font(.system(size: 11))
                .foregroundStyle(.gray)
                .textSelection(.enabled)
        } else {
            HStack {
                actionButton
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch checker.status {
        case .idle, .upToDate, .error:
            Button(Lang.checkForUpdates) {
                Task { await checker.check() }
            }
            .buttonStyle(.borderedProminent)
        case let .available(version, _, downloadURL):
            Button(Lang.downloadAndInstall(version)) {
                Task { await checker.downloadAndStage(version: version, from: downloadURL) }
            }
            .buttonStyle(.borderedProminent)
        case .checking, .downloading, .installing:
            Button(Lang.inProgress) {}
                .buttonStyle(.bordered)
                .disabled(true)
        case .readyToRestart:
            Button(Lang.restartToInstall) {
                confirmingRestart = true
            }
            .buttonStyle(.borderedProminent)
            .confirmationDialog(
                Lang.restartConfirmTitle,
                isPresented: $confirmingRestart,
                titleVisibility: .visible
            ) {
                Button(Lang.restartNow, role: .destructive) {
                    checker.restartAndInstall()
                }
                Button(Lang.cancel, role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private var releaseNotesBlock: some View {
        if case let .available(_, notes, _) = checker.status, !notes.isEmpty {
            Divider().background(Color.white.opacity(0.05))
            ScrollView {
                Text(notes)
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 140)
        }
    }
}

/// Reads the cover-art cache directory off the main thread on appearance
/// and displays the formatted size. Avoids blocking `body` on a synchronous
/// FileManager.contentsOfDirectory + per-file stat pass when the cache has
/// thousands of entries.
private struct CoverArtCacheSizeText: View {
    @State private var size: String = "…"

    var body: some View {
        Text(size)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.gray)
            .task { size = await Self.computeSize() }
    }

    private static func computeSize() async -> String {
        await Task.detached(priority: .utility) {
            guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
                .appendingPathComponent("CoverArt") else { return "0 MB" }
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) else { return "0 MB" }
            let total = files.reduce(Int64(0)) { sum, url in
                let s = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return sum + Int64(s)
            }
            let gb = Double(total) / 1_073_741_824
            if gb >= 1 { return String(format: "%.1f GB", gb) }
            let mb = Double(total) / 1_048_576
            return String(format: "%.1f MB", mb)
        }.value
    }
}

extension SettingsView {
    @ViewBuilder
    var aboutSettings: some View {
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

            // Software update
            SoftwareUpdateCard(checker: appState.updateChecker)

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
                        CoverArtCacheSizeText()
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

    func statsRow(icon: String, label: String, value: String) -> some View {
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

    func formatSize(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.1f MB", mb)
    }

    func clearCoverArtCache() {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CoverArt") else { return }
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
}
