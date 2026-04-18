import Foundation

/// Common interface for remote music source clients (Jellyfin, Subsonic, SMB).
protocol MusicSourceClient {
    func testConnection() async throws -> Bool
}
