import Foundation

@Observable
final class SpeedTestViewModel {
    var status: TestStatus = .idle
    var result: SpeedTestResult = SpeedTestResult()
    var currentSpeed: Double = 0
    var progress: Double = 0

    private let pingService = PingService()
    private let downloadService = DownloadService()
    private let uploadService = UploadService()

    private var downloadTask: URLSessionDataTask?
    private var uploadTask: URLSessionUploadTask?
    private var isCancelled = false

    func startTest() async {
        await MainActor.run {
            isCancelled = false
            status = .measuringDownload
            result = SpeedTestResult()
            currentSpeed = 0
            progress = 0
        }

        do {
            await MainActor.run { status = .measuringDownload }
            let downloadMbps = try await downloadService.measureDownload { [weak self] bytes, elapsed in
                Task { @MainActor in
                    guard let self else { return }
                    if elapsed > 0 {
                        self.currentSpeed = Double(bytes) / elapsed / 125_000.0
                    }
                }
            }
            await MainActor.run {
                result.download = downloadMbps
                progress = 1.0 / 3.0
            }
            if await MainActor.run(body: { isCancelled }) { return }

            await MainActor.run { status = .measuringUpload; currentSpeed = 0 }
            let uploadMbps = try await uploadService.measureUpload { [weak self] bytes, elapsed in
                Task { @MainActor in
                    guard let self else { return }
                    if elapsed > 0 {
                        self.currentSpeed = Double(bytes) / elapsed / 125_000.0
                    }
                }
            }
            await MainActor.run {
                result.upload = uploadMbps
                progress = 2.0 / 3.0
            }
            if await MainActor.run(body: { isCancelled }) { return }

            await MainActor.run { status = .measuringPing }
            let pingMs = try await pingService.measurePing()
            await MainActor.run {
                result.ping = pingMs
                progress = 1.0
                status = .done
            }
        } catch is CancellationError {
            await MainActor.run {
                status = .idle
            }
        } catch {
            await MainActor.run {
                status = .error(error.localizedDescription)
            }
        }
    }

    func stopTest() {
        isCancelled = true
        downloadService.cancel()
        uploadService.cancel()
    }

    func reset() {
        status = .idle
        result = SpeedTestResult()
        currentSpeed = 0
        progress = 0
    }
}
