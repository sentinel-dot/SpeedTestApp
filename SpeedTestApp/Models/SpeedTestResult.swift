import Foundation

struct SpeedTestResult {
    var ping: Double?
    var download: Double?
    var upload: Double?
}

enum TestStatus: Equatable {
    case idle
    case measuringPing
    case measuringDownload
    case measuringUpload
    case done
    case error(String)
}
