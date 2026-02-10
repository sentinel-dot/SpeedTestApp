import Foundation

final class PingService {
    private let url = URL(string: "https://speed.cloudflare.com/__down?bytes=0")!
    private let session: URLSession
    private let numberOfRequests = 5
    private let timeout: TimeInterval = 15

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }

    func measurePing() async throws -> Double {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        var latencies: [Double] = []

        for _ in 0..<numberOfRequests {
            let start = Date()
            let (_, response) = try await session.data(for: request)
            let elapsed = Date().timeIntervalSince(start)

            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                latencies.append(elapsed * 1000)
            }
        }

        if latencies.isEmpty {
            throw NSError(domain: "PingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Keine Verbindung"])
        }

        return latencies.reduce(0, +) / Double(latencies.count)
    }
}
