import Foundation
import AMSMB2

struct SMBFileItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
}

actor SMBClient: MusicSourceClient {
    private let config: ServerConfig
    private let password: String
    private let supportedExtensions = Set(["flac", "wav", "aiff", "aif", "alac", "m4a", "mp3"])

    init(config: ServerConfig, password: String) {
        self.config = config
        self.password = password
    }

    private func createClient() throws -> SMB2Manager {
        let credential = URLCredential(user: config.username ?? "",
                                        password: password,
                                        persistence: .forSession)
        let port = config.port ?? 445
        guard let serverURL = URL(string: "smb://\(config.host):\(port)") else {
            throw NSError(domain: "SMBClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid server URL"])
        }
        guard let client = SMB2Manager(url: serverURL, credential: credential) else {
            throw NSError(domain: "SMBClient", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create SMB client"])
        }
        return client
    }

    func testConnection() async throws -> Bool {
        let client = try createClient()
        try await client.connectShare(name: config.shareName ?? "")
        try await client.disconnectShare()
        return true
    }

    func listDirectory(path: String) async throws -> [SMBFileItem] {
        let client = try createClient()
        try await client.connectShare(name: config.shareName ?? "")
        let items = try await client.contentsOfDirectory(atPath: path)
        try await client.disconnectShare()

        return items.compactMap { item in
            let name = item[.nameKey] as? String ?? ""
            let isDir = (item[.isDirectoryKey] as? Bool) ?? false
            let size = (item[.fileSizeKey] as? Int64) ?? 0
            guard !name.hasPrefix(".") else { return nil }

            if isDir {
                return SMBFileItem(name: name, path: "\(path)/\(name)", isDirectory: true, size: 0)
            }
            let ext = (name as NSString).pathExtension.lowercased()
            guard supportedExtensions.contains(ext) else { return nil }
            return SMBFileItem(name: name, path: "\(path)/\(name)", isDirectory: false, size: size)
        }.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    func downloadFile(remotePath: String, to localURL: URL, progress: @Sendable @escaping (Double) -> Void) async throws {
        let client = try createClient()
        try await client.connectShare(name: config.shareName ?? "")

        do {
            // Get file size for accurate progress
            let attrs = try await client.attributesOfItem(atPath: remotePath)
            let totalSize = (attrs[.fileSizeKey] as? Int64) ?? 0

            // Stream chunks directly to file to avoid OOM on large files
            FileManager.default.createFile(atPath: localURL.path, contents: nil)
            let handle = try FileHandle(forWritingTo: localURL)
            var bytesWritten: Int64 = 0
            for try await chunk in client.contents(atPath: remotePath) {
                handle.write(chunk)
                bytesWritten += Int64(chunk.count)
                let pct = totalSize > 0 ? Double(bytesWritten) / Double(totalSize) : 0
                progress(min(pct, 1.0))
            }
            try handle.close()
            try await client.disconnectShare()
        } catch {
            try? await client.disconnectShare()
            throw error
        }
    }
}
