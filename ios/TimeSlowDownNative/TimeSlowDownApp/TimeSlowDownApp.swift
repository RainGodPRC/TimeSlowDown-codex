#if canImport(SwiftUI)
import SwiftUI
import TimeSlowDownKit
#if canImport(UIKit)
import UIKit
#endif
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
    private let uiTestStore: NativeShellStore?
    private let uiTestRequiresOnboarding: Bool
    private let diagnostics: NativeRuntimeDiagnostics

    init() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        self.uiTestStore = NativeUITestBootstrap.store(arguments: arguments)
        self.uiTestRequiresOnboarding = NativeUITestBootstrap.requiresOnboarding(arguments: arguments)
        if arguments.contains("--ui-testing") {
            let diagnosticsURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("TimeSlowDownUITests", isDirectory: true)
                .appendingPathComponent("runtime-receipts.json", isDirectory: false)
            self.diagnostics = NativeRuntimeDiagnostics(
                store: NativeRuntimeReceiptStore(url: diagnosticsURL)
            )
#if canImport(UIKit)
            if arguments.contains("--ui-test-disable-animations") {
                UIView.setAnimationsEnabled(false)
            }
#endif
        } else {
            self.diagnostics = .shared
        }
#else
        self.uiTestStore = nil
        self.uiTestRequiresOnboarding = false
        self.diagnostics = .shared
#endif
#if canImport(MetricKit)
        if uiTestStore == nil {
            NativeMetricKitSubscriber.shared.start()
        }
#endif
    }

    var body: some Scene {
        WindowGroup {
            if let uiTestStore {
                TSDNativeShellView(
                    store: uiTestStore,
                    persistenceURL: nil,
                    onboardingMode: uiTestRequiresOnboarding ? .required : .completed,
                    onboardingURL: nil,
                    diagnostics: diagnostics
                )
            } else {
                TSDNativeShellView(diagnostics: diagnostics)
            }
        }
    }
}

#if DEBUG
@available(iOS 17.0, *)
private enum NativeUITestBootstrap {
    static func store(arguments: [String]) -> NativeShellStore? {
        guard arguments.contains("--ui-testing") else { return nil }
        switch value(after: "--ui-test-fixture", in: arguments) ?? "empty" {
        case "empty", "onboarding":
            return NativeShellStore(selectedRoute: .now)
        case "seeded":
            return NativeShellStore(
                selectedRoute: .slices,
                slices: [
                    MemorySlice(
                        id: UUID(uuidString: "A3A42E2F-ADE4-41D4-BE3B-000000000085")!,
                        title: "测试切片：雨后散步",
                        body: "雨停以后绕着小区走了一圈。",
                        tags: ["日常", "变化"],
                        capturedAt: Date(timeIntervalSince1970: 1_783_684_800),
                        people: ["自己"],
                        meaning: "普通的一天也值得留下。",
                        sources: ["ui-test-fixture"]
                    )
                ]
            )
        default:
            return NativeShellStore(selectedRoute: .now)
        }
    }

    static func requiresOnboarding(arguments: [String]) -> Bool {
        value(after: "--ui-test-fixture", in: arguments) == "onboarding"
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
#endif
#endif
