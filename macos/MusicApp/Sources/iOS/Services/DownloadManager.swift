import Foundation
import UIKit

@Observable
@MainActor
final class DownloadManager: NSObject {
    var activeDownloads: [DownloadItem] = []
    var completedCount: Int = 0

    private let db: DatabaseManager
    private let cacheManager: CacheManager
    private var scanner: LibraryScanner?
    private var backgroundSession: URLSession!
    private var downloadCompletions: [String: @Sendable (URL) -> Void] = [:]

    struct DownloadItem: Identifiable {
        let id: String
        let filename: String
        let sourceType: String
        let sourceId: String?
        let remotePath: String?
        var progress: Double = 0
        var isComplete = false
        var localPath: String?
    }

    init(db: DatabaseManager, cacheManager: CacheManager) {
        self.db = db
        self.cacheManager = cacheManager
        super.init()

        let config = URLSessionConfiguration.background(withIdentifier: "com.flayer.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func setScanner(_ scanner: LibraryScanner) {
        self.scanner = scanner
    }

    func downloadFromURL(_ url: URL, filename: String, sourceType: String, sourceId: String?,
                         remotePath: String?, destinationDir: URL) {
        downloadFromRequest(URLRequest(url: url), filename: filename, sourceType: sourceType,
                           sourceId: sourceId, remotePath: remotePath, destinationDir: destinationDir)
    }

    func downloadFromRequest(_ request: URLRequest, filename: String, sourceType: String, sourceId: String?,
                             remotePath: String?, destinationDir: URL) {
        let localURL = destinationDir.appendingPathComponent(filename)
        let item = DownloadItem(id: UUID().uuidString, filename: filename, sourceType: sourceType,
                                sourceId: sourceId, remotePath: remotePath, localPath: localURL.path)
        activeDownloads.append(item)

        let task = backgroundSession.downloadTask(with: request)
        task.taskDescription = item.id
        let itemId = item.id
        let sType = sourceType
        let sId = sourceId
        let rPath = remotePath
        let lPath = localURL.path
        downloadCompletions[item.id] = { [weak self] tempURL in
            do {
                // Remove existing file if present to avoid moveItem failure
                if FileManager.default.fileExists(atPath: localURL.path) {
                    try FileManager.default.removeItem(at: localURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: localURL)
                Task { @MainActor in
                    await self?.onDownloadComplete(itemId: itemId, localPath: lPath,
                                                   sourceType: sType, sourceId: sId, remotePath: rPath)
                }
            } catch {
                print("⚠️ DownloadManager: failed to move file: \(error)")
                Task { @MainActor in
                    self?.activeDownloads.removeAll { $0.id == itemId }
                }
            }
        }
        task.resume()
    }

    func downloadFromSMB(client: SMBClient, remotePath: String, filename: String,
                         sourceId: String, destinationDir: URL) {
        let localURL = destinationDir.appendingPathComponent(filename)
        let itemId = UUID().uuidString
        let item = DownloadItem(id: itemId, filename: filename, sourceType: "smb",
                                sourceId: sourceId, remotePath: remotePath, localPath: localURL.path)
        activeDownloads.append(item)

        Task {
            do {
                try await client.downloadFile(remotePath: remotePath, to: localURL) { [weak self] progress in
                    Task { @MainActor in
                        if let idx = self?.activeDownloads.firstIndex(where: { $0.id == itemId }) {
                            self?.activeDownloads[idx].progress = progress
                        }
                    }
                }
                await onDownloadComplete(itemId: itemId, localPath: localURL.path,
                                         sourceType: "smb", sourceId: sourceId, remotePath: remotePath)
            } catch {
                activeDownloads.removeAll { $0.id == itemId }
            }
        }
    }

    private func onDownloadComplete(itemId: String, localPath: String, sourceType: String,
                                    sourceId: String?, remotePath: String?) async {
        let url = URL(fileURLWithPath: localPath)

        // Verify file exists before processing
        guard FileManager.default.fileExists(atPath: localPath) else {
            print("⚠️ DownloadManager: downloaded file not found at \(localPath)")
            activeDownloads.removeAll { $0.id == itemId }
            return
        }

        await scanner?.processFile(url)

        let trackId = db.getTrackId(path: localPath)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: localPath)[.size] as? Int64) ?? 0

        cacheManager.registerDownload(localPath: localPath, sourceType: sourceType, sourceId: sourceId,
                                      remotePath: remotePath, trackId: trackId, fileSize: fileSize)

        if let idx = activeDownloads.firstIndex(where: { $0.id == itemId }) {
            activeDownloads[idx].isComplete = true
            activeDownloads[idx].progress = 1.0
        }
        completedCount += 1

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                activeDownloads.removeAll { $0.id == itemId }
            }
        }
    }
}

extension DownloadManager: @preconcurrency URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = downloadTask.taskDescription else { return }
        // Copy to temp location before the system removes it
        let tempCopy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.copyItem(at: location, to: tempCopy)
        } catch {
            print("⚠️ DownloadManager: failed to copy temp file: \(error)")
            Task { @MainActor [weak self] in
                self?.downloadCompletions.removeValue(forKey: id)
                self?.activeDownloads.removeAll { $0.id == id }
            }
            return
        }
        Task { @MainActor [weak self] in
            let completion = self?.downloadCompletions.removeValue(forKey: id)
            completion?(tempCopy)
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let id = task.taskDescription else { return }
        print("⚠️ DownloadManager: download failed: \(error)")
        Task { @MainActor [weak self] in
            self?.downloadCompletions.removeValue(forKey: id)
            self?.activeDownloads.removeAll { $0.id == id }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                                didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTask.taskDescription else { return }
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        Task { @MainActor [weak self] in
            if let idx = self?.activeDownloads.firstIndex(where: { $0.id == id }) {
                self?.activeDownloads[idx].progress = progress
            }
        }
    }
}
