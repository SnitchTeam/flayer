import Foundation

actor RateLimiter {
    private let minInterval: TimeInterval
    private var lastRequestTime: Date = .distantPast

    init(requestsPerSecond: Double) {
        self.minInterval = 1.0 / requestsPerSecond
    }

    func wait() async {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRequestTime)
        if elapsed < minInterval {
            try? await Task.sleep(nanoseconds: UInt64((minInterval - elapsed) * 1_000_000_000))
        }
        lastRequestTime = Date()
    }
}
