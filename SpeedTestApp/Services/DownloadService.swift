import Foundation

final class DownloadService: NSObject {
    private let url = URL(string: "https://speed.cloudflare.com/__down?bytes=10000000")!
    private var session: URLSession!
    private var callback: ((UInt64, TimeInterval) -> Void)?
    private var lastCallbackTime: CFAbsoluteTime = 0
    private let callbackInterval: CFAbsoluteTime = 0.15
    private let minimumDuration: TimeInterval = 5.0
    private var task: URLSessionDataTask?
    private var continuation: CheckedContinuation<Double, Error>?

    /// Start der allerersten Messung (bleibt für Gesamt-Elapsed)
    private var firstStartTime: CFAbsoluteTime = 0
    /// Summe aller Bytes aus bereits abgeschlossenen Chunks
    private var totalBytesFromCompletedChunks: UInt64 = 0

    override init() {
        super.init()
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func measureDownload(reportProgress: @escaping (UInt64, TimeInterval) -> Void) async throws -> Double {
        return try await withCheckedThrowingContinuation { [weak self] cont in
            guard let self else { return }
            self.continuation = cont
            self.callback = reportProgress
            self.lastCallbackTime = 0
            self.firstStartTime = CFAbsoluteTimeGetCurrent()
            self.totalBytesFromCompletedChunks = 0
            let request = URLRequest(url: url)
            self.task = session.dataTask(with: request)
            self.task?.resume()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        if continuation != nil {
            continuation?.resume(throwing: CancellationError())
            continuation = nil
        }
    }

    /// Startet den nächsten 10-MB-Download (wird aufgerufen, wenn ein Chunk fertig ist und noch keine 5 s vergangen)
    private func startNextChunk() {
        let request = URLRequest(url: url)
        task = session.dataTask(with: request)
        task?.resume()
    }
}

extension DownloadService: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let bytesThisChunk = UInt64(dataTask.countOfBytesReceived)
        let totalBytes = totalBytesFromCompletedChunks + bytesThisChunk
        let elapsed = CFAbsoluteTimeGetCurrent() - firstStartTime
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastCallbackTime >= callbackInterval {
            lastCallbackTime = now
            let cb = callback
            DispatchQueue.main.async {
                cb?(totalBytes, elapsed)
            }
        }
    }
}

extension DownloadService: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let bytesThisChunk = UInt64(task.countOfBytesReceived)
        totalBytesFromCompletedChunks += bytesThisChunk
        let totalElapsed = CFAbsoluteTimeGetCurrent() - firstStartTime

        if let error = error as NSError?, error.code == NSURLErrorCancelled {
            continuation?.resume(throwing: CancellationError())
            continuation = nil
            return
        }
        if let error = error {
            continuation?.resume(throwing: error)
            continuation = nil
            return
        }
        if totalElapsed > 0 && totalBytesFromCompletedChunks > 0 {
            let mbps = Double(totalBytesFromCompletedChunks) / totalElapsed / 125_000.0
            if totalElapsed >= minimumDuration {
                continuation?.resume(returning: mbps)
                continuation = nil
                self.task = nil
                return
            }
            startNextChunk()
        } else {
            continuation?.resume(throwing: NSError(domain: "DownloadService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Keine Verbindung"]))
            continuation = nil
        }
    }
}
