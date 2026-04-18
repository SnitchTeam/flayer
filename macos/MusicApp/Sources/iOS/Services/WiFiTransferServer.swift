import Foundation
import Network
import UIKit

@Observable
@MainActor
final class WiFiTransferServer {
    var isRunning = false
    var serverURL: String = ""
    var receivedCount: Int = 0
    /// 6-digit PIN regenerated on every `start()`. Clients must send it as
    /// `?pin=NNNNNN` on the request-line or as an `X-FlaYer-PIN` header —
    /// otherwise uploads and the landing page are rejected with 401.
    var pin: String = ""

    private var listener: NWListener?
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private var onFileReceived: ((URL, String) -> Void)?
    private let port: UInt16 = 8080
    private let maxUploadSize = 200 * 1024 * 1024 // 200 MB

    func start(onFileReceived: @escaping (URL, String) -> Void) {
        self.onFileReceived = onFileReceived
        self.pin = String(format: "%06d", Int.random(in: 0..<1_000_000))
        do {
            let params = NWParameters.tcp
            // Restrict to Wi-Fi so the server is not reachable over cellular
            // or USB/Ethernet tethering interfaces.
            params.requiredInterfaceType = .wifi
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                isRunning = false
                return
            }
            listener = try NWListener(using: params, on: nwPort)

            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        self?.serverURL = self?.getLocalIPAddress() ?? ""
                    case .failed, .cancelled:
                        self?.isRunning = false
                    default: break
                    }
                }
            }

            let expectedPin = self.pin
            let maxSize = self.maxUploadSize
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection, pin: expectedPin, maxBody: maxSize)
            }

            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            isRunning = false
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        endBackgroundTask()
    }

    func enterBackground() {
        guard isRunning else {
            stop()
            return
        }
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "WiFiTransfer") { [weak self] in
            Task { @MainActor in
                self?.stop()
            }
        }
    }

    func enterForeground() {
        endBackgroundTask()
    }

    private func endBackgroundTask() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }

    // MARK: - Connection Handling

    private nonisolated func handleConnection(_ connection: NWConnection, pin: String, maxBody: Int) {
        connection.start(queue: .global(qos: .userInitiated))

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let data else {
                connection.cancel()
                return
            }

            let request = String(data: data, encoding: .utf8) ?? ""

            if request.hasPrefix("OPTIONS") {
                let response = "HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Methods: POST\r\nAccess-Control-Allow-Headers: Content-Type, X-FlaYer-PIN\r\nConnection: close\r\n\r\n"
                self?.sendResponse(response, on: connection)
                return
            }

            if request.hasPrefix("POST") {
                // POST = upload. Require the PIN, accepted either as
                // `?pin=NNNNNN` on the request line or as `X-FlaYer-PIN`.
                guard Self.requestHasValidPin(request, expected: pin) else {
                    let body = "Unauthorized"
                    let response = "HTTP/1.1 401 Unauthorized\r\nContent-Type: text/plain\r\nContent-Length: \(body.utf8.count)\r\nWWW-Authenticate: FlaYer-PIN\r\nConnection: close\r\n\r\n\(body)"
                    self?.sendResponse(response, on: connection)
                    return
                }
                self?.accumulateUpload(data: data, connection: connection, maxBody: maxBody)
            } else {
                Task { @MainActor in
                    let html = self?.loadWebPage() ?? "<html><body>Error</body></html>"
                    let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
                    self?.sendResponse(response, on: connection)
                }
            }
        }
    }

    private nonisolated static func requestHasValidPin(_ request: String, expected: String) -> Bool {
        guard !expected.isEmpty else { return false }
        // Request-line query string: `GET /path?pin=NNNNNN HTTP/1.1`
        if let firstLineEnd = request.range(of: "\r\n") {
            let firstLine = request[request.startIndex..<firstLineEnd.lowerBound]
            if let q = firstLine.range(of: "?pin=") ?? firstLine.range(of: "&pin=") {
                let rest = firstLine[q.upperBound...]
                let terminator = rest.firstIndex(where: { $0 == " " || $0 == "&" || $0 == "#" }) ?? rest.endIndex
                if String(rest[..<terminator]) == expected { return true }
            }
        }
        // Header: `X-FlaYer-PIN: NNNNNN` (case-insensitive name)
        for line in request.components(separatedBy: "\r\n") {
            let lower = line.lowercased()
            if lower.hasPrefix("x-flayer-pin:") {
                let value = line.dropFirst("x-flayer-pin:".count).trimmingCharacters(in: .whitespaces)
                if value == expected { return true }
            }
        }
        return false
    }

    // MARK: - Upload Accumulation

    private nonisolated func accumulateUpload(data: Data, connection: NWConnection, maxBody: Int) {
        // Hard cap the accumulated buffer even before parsing headers. An attacker
        // omitting Content-Length could otherwise stream indefinitely via readMore.
        if data.count > maxBody {
            sendResponse("HTTP/1.1 413 Payload Too Large\r\nContent-Length: 0\r\nConnection: close\r\n\r\n", on: connection)
            return
        }

        let headerEndMarker = Data("\r\n\r\n".utf8)

        guard let headerEnd = data.range(of: headerEndMarker) else {
            readMore(accumulated: data, connection: connection, maxBody: maxBody)
            return
        }

        let headerStr = String(data: data[data.startIndex..<headerEnd.lowerBound], encoding: .utf8) ?? ""
        var contentLength: Int?
        for line in headerStr.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix("content-length:") {
                contentLength = Int(line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces))
            }
        }

        let bodyStart = headerEnd.upperBound
        let bodyReceived = data.count - bodyStart

        if let cl = contentLength, cl > maxBody {
            sendResponse("HTTP/1.1 413 Payload Too Large\r\nContent-Length: 0\r\nConnection: close\r\n\r\n", on: connection)
            return
        }

        if let cl = contentLength, bodyReceived < cl {
            readMore(accumulated: data, connection: connection, maxBody: maxBody)
        } else {
            parseMultipart(data: data, connection: connection)
        }
    }

    private nonisolated func readMore(accumulated: Data, connection: NWConnection, maxBody: Int) {
        let captured = accumulated
        connection.receive(minimumIncompleteLength: 1, maximumLength: 10_000_000) { [weak self] data, _, isComplete, _ in
            var all = captured
            if let data { all.append(data) }
            // Enforce the global cap here too: without it, a Content-Length-less
            // POST would keep growing until the device runs out of memory.
            if all.count > maxBody {
                self?.sendResponse("HTTP/1.1 413 Payload Too Large\r\nContent-Length: 0\r\nConnection: close\r\n\r\n", on: connection)
                return
            }
            if isComplete {
                self?.parseMultipart(data: all, connection: connection)
            } else {
                self?.accumulateUpload(data: all, connection: connection, maxBody: maxBody)
            }
        }
    }

    // MARK: - Multipart Parsing

    private nonisolated func parseMultipart(data: Data, connection: NWConnection) {
        let headerEndMarker = Data("\r\n\r\n".utf8)

        // Find HTTP header/body boundary
        guard let httpHeaderEnd = data.range(of: headerEndMarker) else {
            sendResponse("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n", on: connection)
            return
        }

        let httpHeaders = String(data: data[data.startIndex..<httpHeaderEnd.lowerBound], encoding: .utf8) ?? ""

        // Extract boundary from Content-Type header
        guard let boundaryRange = httpHeaders.range(of: "boundary=") else {
            sendResponse("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n", on: connection)
            return
        }
        var boundary = String(httpHeaders[boundaryRange.upperBound...])
        if let endIdx = boundary.firstIndex(where: { $0 == "\r" || $0 == "\n" || $0 == " " || $0 == ";" }) {
            boundary = String(boundary[..<endIdx])
        }
        if boundary.hasPrefix("\"") && boundary.hasSuffix("\"") {
            boundary = String(boundary.dropFirst().dropLast())
        }

        // Multipart body starts after HTTP headers
        let body = data[httpHeaderEnd.upperBound...]

        // Find the part's own header end (Content-Disposition, Content-Type, etc.)
        // Body: --boundary\r\nContent-Disposition: ...\r\n\r\n<FILE DATA>\r\n--boundary--
        guard let partHeaderEnd = body.range(of: headerEndMarker) else {
            sendResponse("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n", on: connection)
            return
        }

        // Extract filename from part headers
        let partHeaders = String(data: body[body.startIndex..<partHeaderEnd.lowerBound], encoding: .utf8) ?? ""
        var filename = "upload-\(UUID().uuidString).audio"
        if let fnRange = partHeaders.range(of: "filename=\""),
           let fnEnd = partHeaders[fnRange.upperBound...].firstIndex(of: "\"") {
            let rawFilename = String(partHeaders[fnRange.upperBound..<fnEnd])
            // Keep only the last path component and reject suspicious forms.
            let sanitized = (rawFilename as NSString).lastPathComponent
            let hasNulOrSlash = sanitized.contains("\0") || sanitized.contains("/") || sanitized.contains("\\")
            if !sanitized.isEmpty, !sanitized.hasPrefix("."), sanitized != "..", !hasNulOrSlash, sanitized.count <= 255 {
                filename = sanitized
            }
        }

        // File data starts after the part's headers
        let fileStart = partHeaderEnd.upperBound
        let closingBoundary = Data("\r\n--\(boundary)".utf8)

        let fileData: Data
        if let endRange = data[fileStart...].range(of: closingBoundary) {
            fileData = Data(data[fileStart..<endRange.lowerBound])
        } else {
            fileData = Data(data[fileStart...])
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try fileData.write(to: tempURL)
        } catch {
            sendResponse("HTTP/1.1 500 Internal Server Error\r\nContent-Length: 0\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n", on: connection)
            return
        }

        Task { @MainActor [weak self] in
            self?.onFileReceived?(tempURL, filename)
            self?.receivedCount += 1
        }

        let jsonResponse = "{\"ok\":true,\"filename\":\"\(filename)\"}"
        let response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(jsonResponse.utf8.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(jsonResponse)"
        sendResponse(response, on: connection)
    }

    // MARK: - Response

    private nonisolated func sendResponse(_ response: String, on connection: NWConnection) {
        let data = Data(response.utf8)
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Helpers

    private func loadWebPage() -> String {
        guard let url = Bundle.main.url(forResource: "wifi-transfer", withExtension: "html"),
              let html = try? String(contentsOf: url) else {
            return "<html><body style='background:#0a0a0a;color:#fff;font-family:system-ui;display:flex;justify-content:center;align-items:center;min-height:100vh'><h1>FlaYer Wi-Fi Transfer</h1></body></html>"
        }
        return html
    }

    private func getLocalIPAddress() -> String {
        var address = "http://localhost:\(port)"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return address }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            guard addrFamily == UInt8(AF_INET) else { continue }
            let name = String(cString: interface.ifa_name)
            guard name == "en0" else { continue }
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                       &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
            address = "http://\(String(cString: hostname)):\(port)"
            break
        }
        return address
    }
}
