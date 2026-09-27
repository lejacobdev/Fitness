import Foundation
import MetricKit

/// Crash and hang reports from Apple's MetricKit — no third-party SDK.
/// The newest reports are kept on the phone; the athlete can send them
/// from Me → Export my data if support asks for them.
final class MetricsReporter: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = MetricsReporter()

    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "diagnostics")
    }

    func start() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let directory = Self.directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for payload in payloads {
            let name = "diagnostic-\(Int(payload.timeStampEnd.timeIntervalSince1970)).json"
            try? payload.jsonRepresentation().write(to: directory.appending(path: name), options: .atomic)
        }
        // Keep the ten newest.
        let files = ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for old in files.dropFirst(10) { try? FileManager.default.removeItem(at: old) }
    }
}
