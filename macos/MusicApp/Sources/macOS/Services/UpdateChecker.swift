import AppKit
import Foundation
import os.log

private let updateLog = Logger(subsystem: "com.music.flayer", category: "Updater")

/// In-app updater for the macOS build.
///
/// - Queries the latest release on GitHub, compares semver tags.
/// - Downloads the DMG, mounts it via `hdiutil`, copies FlaYer.app to a
///   staging directory and strips the quarantine flag.
/// - On restart, a tiny shell script waits for this process to exit, swaps
///   the bundle in place, and relaunches the new build.
///
/// Homebrew-installed copies are detected via the bundle path and opt out
/// of the in-app flow — the user is pointed at `brew upgrade --cask flayer`
/// so the cask's sha256 / version stay in sync.
@Observable
@MainActor
final class UpdateChecker {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, notes: String, downloadURL: URL)
        case downloading
        case installing
        case readyToRestart(version: String)
        case error(String)
    }

    var status: Status = .idle
    var lastChecked: Date?

    private let releasesAPI = URL(string: "https://api.github.com/repos/SnitchTeam/flayer/releases/latest")!
    private let session: URLSession
    private var stagedAppURL: URL?

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }

    /// True when the running binary lives inside a Homebrew Caskroom —
    /// replacing it from within the app would leave the cask's manifest
    /// referencing a bundle that no longer matches its sha256.
    var installedViaHomebrew: Bool {
        let path = Bundle.main.bundlePath
        return path.contains("/Caskroom/") || path.contains("/homebrew/")
    }

    init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "FlaYer-macOS/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")",
            "Accept": "application/vnd.github+json"
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Check

    func check() async {
        status = .checking
        do {
            let (data, response) = try await session.data(from: releasesAPI)
            guard let http = response as? HTTPURLResponse else {
                status = .error("No HTTP response")
                return
            }
            guard http.statusCode == 200 else {
                status = .error("GitHub API \(http.statusCode)")
                return
            }
            let release = try JSONDecoder().decode(Release.self, from: data)
            lastChecked = .now
            let latest = release.tag_name.hasPrefix("v")
                ? String(release.tag_name.dropFirst())
                : release.tag_name

            guard isNewer(latest: latest, than: currentVersion) else {
                status = .upToDate
                return
            }
            guard let asset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) else {
                status = .error("No DMG attached to \(release.tag_name)")
                return
            }
            status = .available(
                version: latest,
                notes: release.body ?? "",
                downloadURL: asset.browser_download_url
            )
            updateLog.info("Update available: \(latest, privacy: .public)")
        } catch {
            updateLog.error("Check failed: \(error.localizedDescription, privacy: .public)")
            status = .error(error.localizedDescription)
        }
    }

    // MARK: - Download + stage

    func downloadAndStage(version: String, from url: URL) async {
        status = .downloading
        do {
            let (tempURL, _) = try await session.download(from: url)
            let dmgURL = FileManager.default.temporaryDirectory.appendingPathComponent("FlaYer-update.dmg")
            try? FileManager.default.removeItem(at: dmgURL)
            try FileManager.default.moveItem(at: tempURL, to: dmgURL)

            status = .installing
            let mountPoint = try mountDMG(at: dmgURL)
            defer { try? detachDMG(mountPoint: mountPoint) }

            let appInDMG = mountPoint.appendingPathComponent("FlaYer.app")
            guard FileManager.default.fileExists(atPath: appInDMG.path) else {
                status = .error("FlaYer.app not found in update DMG")
                return
            }

            let staging = FileManager.default.temporaryDirectory.appendingPathComponent("FlaYer-staged.app")
            try? FileManager.default.removeItem(at: staging)
            try FileManager.default.copyItem(at: appInDMG, to: staging)
            stripQuarantine(at: staging)

            stagedAppURL = staging
            status = .readyToRestart(version: version)
            updateLog.info("Update staged for restart: \(version, privacy: .public)")
        } catch {
            updateLog.error("Download/stage failed: \(error.localizedDescription, privacy: .public)")
            status = .error(error.localizedDescription)
        }
    }

    // MARK: - Restart + install

    func restartAndInstall() {
        guard let newAppURL = stagedAppURL else { return }
        let pid = ProcessInfo.processInfo.processIdentifier
        let currentPath = Bundle.main.bundlePath

        // Inline shell script: wait for the current process to exit, replace the
        // bundle in place, relaunch. Paths come from trusted sources (Bundle,
        // FileManager temporaryDirectory) so shell quoting is enough.
        let script = """
        while ps -p \(pid) > /dev/null 2>&1; do sleep 0.3; done
        rm -rf "\(currentPath)"
        mv "\(newAppURL.path)" "\(currentPath)"
        open "\(currentPath)"
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", script]
        do {
            try task.run()
        } catch {
            updateLog.error("Failed to spawn installer script: \(error.localizedDescription, privacy: .public)")
            status = .error("Could not launch installer: \(error.localizedDescription)")
            return
        }
        NSApp.terminate(nil)
    }

    // MARK: - Helpers

    private func isNewer(latest: String, than current: String) -> Bool {
        let l = latest.split(separator: ".").compactMap { Int($0) }
        let c = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(l.count, c.count) {
            let a = i < l.count ? l[i] : 0
            let b = i < c.count ? c[i] : 0
            if a != b { return a > b }
        }
        return false
    }

    private func mountDMG(at url: URL) throws -> URL {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        task.arguments = ["attach", "-nobrowse", "-quiet", "-plist", "-mountrandom", "/tmp", url.path]
        let pipe = Pipe()
        task.standardOutput = pipe
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            throw UpdateError.mountFailed
        }
        let data = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
        guard
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let entities = plist["system-entities"] as? [[String: Any]]
        else {
            throw UpdateError.mountFailed
        }
        for entity in entities {
            if let mountPoint = entity["mount-point"] as? String, !mountPoint.isEmpty {
                return URL(fileURLWithPath: mountPoint)
            }
        }
        throw UpdateError.mountFailed
    }

    private func detachDMG(mountPoint: URL) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        task.arguments = ["detach", "-quiet", mountPoint.path]
        try task.run()
        task.waitUntilExit()
    }

    private func stripQuarantine(at url: URL) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        task.arguments = ["-dr", "com.apple.quarantine", url.path]
        try? task.run()
        task.waitUntilExit()
    }

    // MARK: - DTOs

    private struct Release: Decodable {
        let tag_name: String
        let body: String?
        let assets: [Asset]
    }

    private struct Asset: Decodable {
        let name: String
        let browser_download_url: URL
    }

    enum UpdateError: LocalizedError {
        case mountFailed
        var errorDescription: String? {
            switch self {
            case .mountFailed: return "Could not mount the update DMG"
            }
        }
    }
}
