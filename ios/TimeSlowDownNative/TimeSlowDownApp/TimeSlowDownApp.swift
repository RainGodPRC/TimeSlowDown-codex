#if canImport(SwiftUI)
import SwiftUI
import TimeSlowDownKit
#if canImport(MetricKit)
import MetricKit
#endif

#if canImport(MetricKit)
@available(iOS 17.0, *)
private final class NativeMetricKitSubscriber: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = NativeMetricKitSubscriber()

    private let lock = NSLock()
    private var isStarted = false

    func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !isStarted else { return }
        MXMetricManager.shared.add(self)
        isStarted = true
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        let receipt = NativeRuntimeReceiptFactory.metricPayloads(payloads.count)
        Task { await NativeRuntimeDiagnostics.shared.record(receipt) }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let receipt = NativeRuntimeReceiptFactory.metricDiagnostics(
            payloadCount: payloads.count,
            crashCount: payloads.reduce(0) { $0 + ($1.crashDiagnostics?.count ?? 0) },
            hangCount: payloads.reduce(0) { $0 + ($1.hangDiagnostics?.count ?? 0) },
            diskWriteExceptionCount: payloads.reduce(0) { $0 + ($1.diskWriteExceptionDiagnostics?.count ?? 0) },
            cpuExceptionCount: payloads.reduce(0) { $0 + ($1.cpuExceptionDiagnostics?.count ?? 0) }
        )
        Task { await NativeRuntimeDiagnostics.shared.record(receipt) }
    }
}
#endif

@available(iOS 17.0, *)
@main
struct TimeSlowDownApp: App {
    init() {
#if canImport(MetricKit)
        NativeMetricKitSubscriber.shared.start()
#endif
    }

    var body: some Scene {
        WindowGroup {
            TSDNativeShellView()
        }
    }
}
#endif
