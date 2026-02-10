import Foundation

final class UploadService: NSObject {
    private let url = URL(string: "https://speed.cloudflare.com/__up")!
    private let chunkSize = 10_000_000
    private var session: URLSession!
    private var callback: ((UInt64, TimeInterval) -> Void)?
    private var lastCallbackTime: CFAbsoluteTime = 0
    private let callbackInterval: CFAbsoluteTime = 0.15
    private let minimumDuration: TimeInterval = 5.0
    private var task: URLSessionUploadTask?
    private var continuation: CheckedContinuation<Double, Error>?

    private var firstStartTime: CFAbsoluteTime = 0
    private var totalBytesFromCompletedChunks: UInt64 = 0

    override init() {
        super.init()
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func measureUpload(reportProgress: @escaping (UInt64, TimeInterval) -> Void) async throws -> Double {
        return try await withCheckedThrowingContinuation { [weak self] cont in
            guard let self else { return }
            self.continuation = cont
            self.callback = reportProgress
            self.lastCallbackTime = 0
            self.firstStartTime = CFAbsoluteTimeGetCurrent()
            self.totalBytesFromCompletedChunks = 0
            self.startNextChunk()
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

    private func startNextChunk() {
        var data = Data(count: chunkSize)
        _ = data.withUnsafeMutableBytes { ptr in
            arc4random_buf(ptr.baseAddress, ptr.count)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        task = session.uploadTask(with: request, from: data)
        task?.resume()
    }
}

extension UploadService: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let totalBytes = totalBytesFromCompletedChunks + UInt64(totalBytesSent)
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

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let bytesThisChunk = UInt64(task.countOfBytesSent)
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
            continuation?.resume(throwing: NSError(domain: "UploadService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Keine Verbindung"]))
            continuation = nil
        }
    }
}
