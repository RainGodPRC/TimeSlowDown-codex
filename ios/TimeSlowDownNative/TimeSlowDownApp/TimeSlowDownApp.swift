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
        case "timeline":
            let morning = MemorySlice(
                id: UUID(uuidString: "A3A42E2F-ADE4-41D4-BE3B-000000000089")!,
                title: "清晨窗边的光",
                body: "光落在杯子旁边，屋里很安静。",
                tags: ["日常", "影像"],
                capturedAt: date(2026, 7, 2, 8),
                media: MediaAnchor(kind: .image, label: "morning.jpg"),
                meaning: "普通的一天也有自己的光。",
                sources: ["ui-test-fixture"]
            )
            let evening = MemorySlice(
                id: UUID(uuidString: "B3A42E2F-ADE4-41D4-BE3B-000000000089")!,
                title: "同一天的晚风",
                body: "下楼走了一圈，风比早上凉。",
                tags: ["日常", "变化"],
                capturedAt: date(2026, 7, 2, 19),
                people: ["自己"],
                sources: ["ui-test-fixture"]
            )
            let june = MemorySlice(
                id: UUID(uuidString: "C3A42E2F-ADE4-41D4-BE3B-000000000089")!,
                title: "六月最后一次长谈",
                body: "回家以后，仍然记得他说话时停顿了一下。",
                tags: ["家人"],
                capturedAt: date(2026, 6, 28, 21),
                people: ["家人"],
                meaning: "后来还想再讲起。",
                sources: ["ui-test-fixture"]
            )
            return NativeShellStore(
                selectedRoute: .slices,
                slices: [morning, evening, june],
                revisits: [
                    MemoryRevisit(
                        sliceID: june.id,
                        revisitedAt: date(2026, 7, 10, 12),
                        reflection: "后来又想起那晚。"
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

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }
}
#endif
#endif
