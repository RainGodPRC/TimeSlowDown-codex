import Foundation
#if canImport(OSLog)
import OSLog
#endif

public enum NativeRuntimeOperation: String, Codable, Equatable, Sendable {
    case vaultLoad = "vault_load"
    case vaultCommit = "vault_commit"
    case memoryExport = "memory_export"
    case systemExport = "system_export"
    case metricKitMetrics = "metrickit_metrics"
    case metricKitDiagnostics = "metrickit_diagnostics"
}

public enum NativeRuntimeOutcome: String, Codable, Equatable, Sendable {
    case success
    case migrated
    case recovered
    case cancelled
    case rejected
    case failed
    case received
}

public enum NativeRuntimeErrorCode: String, Codable, Equatable, Sendable {
    case unsupportedSchema = "unsupported_schema"
    case unsupportedImage = "unsupported_image"
    case unsupportedVideo = "unsupported_video"
    case mediaRenderFailed = "media_render_failed"
    case invalidMediaFileName = "invalid_media_file_name"
    case thumbnailTooLarge = "thumbnail_too_large"
    case unsafeExportPlan = "unsafe_export_plan"
    case exportEncodingFailed = "export_encoding_failed"
    case exportSizeOverflow = "export_size_overflow"
    case insufficientDiskSpace = "insufficient_disk_space"
    case exportFileIO = "export_file_io"
    case userCancelled = "user_cancelled"
    case ioUnknown = "io_unknown"

    public static func from(_ error: Error) -> NativeRuntimeErrorCode {
        if let error = error as? NativeVaultPersistenceError {
            switch error {
            case .unsupportedSchema:
                return .unsupportedSchema
            }
        }
        if let error = error as? MediaThumbnailError {
            switch error {
            case .unsupportedImage:
                return .unsupportedImage
            case .unsupportedVideo:
                return .unsupportedVideo
            case .renderFailed:
                return .mediaRenderFailed
            case .invalidFileName:
                return .invalidMediaFileName
            case .thumbnailTooLarge:
                return .thumbnailTooLarge
            }
        }
        if let error = error as? ExportZIPBuilderError {
            switch error {
            case .unsafePlan:
                return .unsafeExportPlan
            case .encodingFailed:
                return .exportEncodingFailed
            case .zipSizeOverflow:
                return .exportSizeOverflow
            case .insufficientDiskSpace:
                return .insufficientDiskSpace
            case .fileIO:
                return .exportFileIO
            }
        }
        if error is CancellationError {
            return .userCancelled
        }
        let cocoaError = error as NSError
        if cocoaError.domain == NSCocoaErrorDomain,
           cocoaError.code == NSUserCancelledError {
            return .userCancelled
        }
        return .ioUnknown
    }
}

public enum NativeRuntimeSizeBucket: String, Codable, Equatable, Sendable {
    case empty
    case underOneMB = "under_1_mb"
    case oneToTenMB = "1_to_10_mb"
    case tenToHundredMB = "10_to_100_mb"
    case overHundredMB = "over_100_mb"

    public static func from(byteCount: Int) -> NativeRuntimeSizeBucket {
        switch byteCount {
        case ...0:
            return .empty
        case ..<1_048_576:
            return .underOneMB
        case ..<10_485_760:
            return .oneToTenMB
        case ..<104_857_600:
            return .tenToHundredMB
        default:
            return .overHundredMB
        }
    }
}

public enum NativeRuntimeVaultLoadSource: String, Codable, Equatable, Sendable {
    case newVault = "new_vault"
    case restored
    case migratedLegacy = "migrated_legacy"
    case migratedVersioned = "migrated_versioned"
    case restoredLastKnownGood = "restored_last_known_good"
    case recoveredCorruptBackup = "recovered_corrupt_backup"
}

public struct NativeRuntimeReceipt: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var recordedAt: Date
    public var operation: NativeRuntimeOperation
    public var outcome: NativeRuntimeOutcome
    public var errorCode: NativeRuntimeErrorCode?
    public var vaultLoadSource: NativeRuntimeVaultLoadSource?
    public var sourceSchemaVersion: Int?
    public var durationMilliseconds: Int?
    public var revision: UInt64?
    public var sliceCount: Int?
    public var revisitCount: Int?
    public var mediaCount: Int?
    public var garbageCollectedCount: Int?
    public var garbageCollectionFailureCount: Int?
    public var exportEntryCount: Int?
    public var exportSizeBucket: NativeRuntimeSizeBucket?
    public var metricPayloadCount: Int?
    public var diagnosticPayloadCount: Int?
    public var crashCount: Int?
    public var hangCount: Int?
    public var diskWriteExceptionCount: Int?
    public var cpuExceptionCount: Int?

    public init(
        recordedAt: Date = Date(),
        operation: NativeRuntimeOperation,
        outcome: NativeRuntimeOutcome,
        errorCode: NativeRuntimeErrorCode? = nil,
        vaultLoadSource: NativeRuntimeVaultLoadSource? = nil,
        sourceSchemaVersion: Int? = nil,
        durationMilliseconds: Int? = nil,
        revision: UInt64? = nil,
        sliceCount: Int? = nil,
        revisitCount: Int? = nil,
        mediaCount: Int? = nil,
        garbageCollectedCount: Int? = nil,
        garbageCollectionFailureCount: Int? = nil,
        exportEntryCount: Int? = nil,
        exportSizeBucket: NativeRuntimeSizeBucket? = nil,
        metricPayloadCount: Int? = nil,
        diagnosticPayloadCount: Int? = nil,
        crashCount: Int? = nil,
        hangCount: Int? = nil,
        diskWriteExceptionCount: Int? = nil,
        cpuExceptionCount: Int? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.recordedAt = recordedAt
        self.operation = operation
        self.outcome = outcome
        self.errorCode = errorCode
        self.vaultLoadSource = vaultLoadSource
        self.sourceSchemaVersion = sourceSchemaVersion
        self.durationMilliseconds = durationMilliseconds
        self.revision = revision
        self.sliceCount = sliceCount
        self.revisitCount = revisitCount
        self.mediaCount = mediaCount
        self.garbageCollectedCount = garbageCollectedCount
        self.garbageCollectionFailureCount = garbageCollectionFailureCount
        self.exportEntryCount = exportEntryCount
        self.exportSizeBucket = exportSizeBucket
        self.metricPayloadCount = metricPayloadCount
        self.diagnosticPayloadCount = diagnosticPayloadCount
        self.crashCount = crashCount
        self.hangCount = hangCount
        self.diskWriteExceptionCount = diskWriteExceptionCount
        self.cpuExceptionCount = cpuExceptionCount
    }

    public var isPrivacySafe: Bool {
        schemaVersion == Self.currentSchemaVersion &&
        durationMilliseconds.map { $0 >= 0 } != false &&
        sourceSchemaVersion.map { $0 >= 0 } != false &&
        [sliceCount, revisitCount, mediaCount, garbageCollectedCount,
         garbageCollectionFailureCount, exportEntryCount, metricPayloadCount,
         diagnosticPayloadCount, crashCount, hangCount,
         diskWriteExceptionCount, cpuExceptionCount]
            .compactMap { $0 }
            .allSatisfy { $0 >= 0 }
    }
}

public enum NativeRuntimeReceiptFactory {
    public static func vaultLoad(
        source: NativeShellPersistenceSource,
        store: NativeShellStore,
        duration: Duration
    ) -> NativeRuntimeReceipt {
        let outcome: NativeRuntimeOutcome
        let loadSource: NativeRuntimeVaultLoadSource
        let sourceSchemaVersion: Int?
        switch source {
        case .newVault:
            outcome = .success
            loadSource = .newVault
            sourceSchemaVersion = nil
        case .restored:
            outcome = .success
            loadSource = .restored
            sourceSchemaVersion = NativeVaultEnvelope.currentSchemaVersion
        case .migratedLegacy:
            outcome = .migrated
            loadSource = .migratedLegacy
            sourceSchemaVersion = nil
        case .migratedVersioned(let version):
            outcome = .migrated
            loadSource = .migratedVersioned
            sourceSchemaVersion = version
        case .restoredLastKnownGood:
            outcome = .recovered
            loadSource = .restoredLastKnownGood
            sourceSchemaVersion = NativeVaultEnvelope.currentSchemaVersion
        case .recoveredCorruptBackup:
            outcome = .recovered
            loadSource = .recoveredCorruptBackup
            sourceSchemaVersion = nil
        }
        return NativeRuntimeReceipt(
            operation: .vaultLoad,
            outcome: outcome,
            vaultLoadSource: loadSource,
            sourceSchemaVersion: sourceSchemaVersion,
            durationMilliseconds: milliseconds(duration),
            sliceCount: store.slices.count,
            revisitCount: store.revisits.count,
            mediaCount: store.snapshot.mediaAnchorCount
        )
    }

    public static func failure(
        operation: NativeRuntimeOperation,
        error: Error,
        duration: Duration? = nil
    ) -> NativeRuntimeReceipt {
        let code = NativeRuntimeErrorCode.from(error)
        return NativeRuntimeReceipt(
            operation: operation,
            outcome: code == .userCancelled ? .cancelled : (code == .insufficientDiskSpace ? .rejected : .failed),
            errorCode: code,
            durationMilliseconds: duration.map(milliseconds)
        )
    }

    public static func vaultCommit(
        _ receipt: NativeShellPersistenceCommitReceipt,
        store: NativeShellStore,
        duration: Duration
    ) -> NativeRuntimeReceipt {
        NativeRuntimeReceipt(
            operation: .vaultCommit,
            outcome: receipt.mediaGarbageCollection.failedFileNames.isEmpty ? .success : .failed,
            errorCode: receipt.mediaGarbageCollection.failedFileNames.isEmpty ? nil : .ioUnknown,
            durationMilliseconds: milliseconds(duration),
            revision: receipt.revision,
            sliceCount: store.slices.count,
            revisitCount: store.revisits.count,
            mediaCount: store.snapshot.mediaAnchorCount,
            garbageCollectedCount: receipt.mediaGarbageCollection.removedFileNames.count,
            garbageCollectionFailureCount: receipt.mediaGarbageCollection.failedFileNames.count
        )
    }

    public static func memoryExport(
        _ artifact: NativeExportFileArtifact,
        duration: Duration
    ) -> NativeRuntimeReceipt {
        NativeRuntimeReceipt(
            operation: .memoryExport,
            outcome: .success,
            durationMilliseconds: milliseconds(duration),
            exportEntryCount: artifact.entries.count,
            exportSizeBucket: .from(byteCount: artifact.fileSizeBytes)
        )
    }

    public static func systemExport(error: Error? = nil) -> NativeRuntimeReceipt {
        guard let error else {
            return NativeRuntimeReceipt(operation: .systemExport, outcome: .success)
        }
        return failure(operation: .systemExport, error: error)
    }

    public static func metricPayloads(_ count: Int) -> NativeRuntimeReceipt {
        NativeRuntimeReceipt(
            operation: .metricKitMetrics,
            outcome: .received,
            metricPayloadCount: max(0, count)
        )
    }

    public static func metricDiagnostics(
        payloadCount: Int,
        crashCount: Int,
        hangCount: Int,
        diskWriteExceptionCount: Int,
        cpuExceptionCount: Int
    ) -> NativeRuntimeReceipt {
        NativeRuntimeReceipt(
            operation: .metricKitDiagnostics,
            outcome: .received,
            diagnosticPayloadCount: max(0, payloadCount),
            crashCount: max(0, crashCount),
            hangCount: max(0, hangCount),
            diskWriteExceptionCount: max(0, diskWriteExceptionCount),
            cpuExceptionCount: max(0, cpuExceptionCount)
        )
    }

    public static func milliseconds(_ duration: Duration) -> Int {
        let components = duration.components
        let seconds = components.seconds.multipliedReportingOverflow(by: 1_000)
        guard !seconds.overflow else { return Int.max }
        let fractional = components.attoseconds / 1_000_000_000_000_000
        let total = seconds.partialValue.addingReportingOverflow(Int64(fractional))
        if total.overflow || total.partialValue > Int64(Int.max) { return Int.max }
        return max(0, Int(total.partialValue))
    }
}

public struct NativeDiagnosticsExportArtifact: Equatable, Sendable {
    public var fileURL: URL
    public var receiptCount: Int

    public init(fileURL: URL, receiptCount: Int) {
        self.fileURL = fileURL
        self.receiptCount = receiptCount
    }
}

public actor NativeRuntimeReceiptStore {
    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("TimeSlowDown", isDirectory: true)
            .appendingPathComponent("Diagnostics", isDirectory: true)
            .appendingPathComponent("runtime-receipts.json", isDirectory: false)
    }

    public let url: URL
    public let maximumReceiptCount: Int
    public let maximumEncodedBytes: Int

    public init(
        url: URL = NativeRuntimeReceiptStore.defaultURL,
        maximumReceiptCount: Int = 200,
        maximumEncodedBytes: Int = 256 * 1_024
    ) {
        self.url = url
        self.maximumReceiptCount = max(1, maximumReceiptCount)
        self.maximumEncodedBytes = max(4_096, maximumEncodedBytes)
    }

    public func append(_ receipt: NativeRuntimeReceipt) throws {
        guard receipt.isPrivacySafe else { return }
        var receipts = readAllRecovering()
        receipts.append(receipt)
        if receipts.count > maximumReceiptCount {
            receipts.removeFirst(receipts.count - maximumReceiptCount)
        }
        var data = try encode(receipts)
        while data.count > maximumEncodedBytes, receipts.count > 1 {
            receipts.removeFirst()
            data = try encode(receipts)
        }
        try write(data)
    }

    public func readAll() throws -> [NativeRuntimeReceipt] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([NativeRuntimeReceipt].self, from: Data(contentsOf: url))
    }

    public func exportSnapshot(
        to directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeSlowDownDiagnostics", isDirectory: true)
    ) throws -> NativeDiagnosticsExportArtifact {
        let receipts = readAllRecovering()
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try removeOwnedExports(in: directory)
        let finalURL = directory.appendingPathComponent("tsd-diagnostics-\(UUID().uuidString.lowercased()).json")
        let partialURL = finalURL.appendingPathExtension("partial")
        do {
            try encode(receipts).write(to: partialURL, options: protectedWriteOptions)
            try fileManager.moveItem(at: partialURL, to: finalURL)
            return NativeDiagnosticsExportArtifact(fileURL: finalURL, receiptCount: receipts.count)
        } catch {
            try? fileManager.removeItem(at: partialURL)
            try? fileManager.removeItem(at: finalURL)
            throw error
        }
    }

    private func removeOwnedExports(in directory: URL) throws {
        let fileManager = FileManager.default
        for candidate in try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) {
            let name = candidate.lastPathComponent
            guard name.hasPrefix("tsd-diagnostics-"),
                  name.hasSuffix(".json") || name.hasSuffix(".json.partial") else { continue }
            try fileManager.removeItem(at: candidate)
        }
    }

    private func readAllRecovering() -> [NativeRuntimeReceipt] {
        do {
            return try readAll()
        } catch {
            try? FileManager.default.removeItem(at: url)
            return []
        }
    }

    private func encode(_ receipts: [NativeRuntimeReceipt]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(receipts)
    }

    private func write(_ data: Data) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: protectedWriteOptions)
    }

    private var protectedWriteOptions: Data.WritingOptions {
#if os(iOS)
        [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
#else
        .atomic
#endif
    }
}

public actor NativeRuntimeDiagnostics {
    public static let shared = NativeRuntimeDiagnostics()

    private let store: NativeRuntimeReceiptStore
#if canImport(OSLog)
    private let vaultLogger = Logger(subsystem: "com.raingodprc.timeslowdown", category: "vault")
    private let exportLogger = Logger(subsystem: "com.raingodprc.timeslowdown", category: "export")
    private let metricKitLogger = Logger(subsystem: "com.raingodprc.timeslowdown", category: "metrickit")
#endif

    public init(store: NativeRuntimeReceiptStore = NativeRuntimeReceiptStore()) {
        self.store = store
    }

    public func record(_ receipt: NativeRuntimeReceipt) async {
        guard receipt.isPrivacySafe else { return }
#if canImport(OSLog)
        let logger: Logger
        switch receipt.operation {
        case .vaultLoad, .vaultCommit:
            logger = vaultLogger
        case .memoryExport, .systemExport:
            logger = exportLogger
        case .metricKitMetrics, .metricKitDiagnostics:
            logger = metricKitLogger
        }
        logger.log(
            level: receipt.outcome == .failed ? .error : .info,
            "operation=\(receipt.operation.rawValue, privacy: .public) outcome=\(receipt.outcome.rawValue, privacy: .public) error=\(receipt.errorCode?.rawValue ?? "none", privacy: .public) duration_ms=\(receipt.durationMilliseconds ?? -1, privacy: .public)"
        )
#endif
        try? await store.append(receipt)
    }

    public func receipts() async -> [NativeRuntimeReceipt] {
        (try? await store.readAll()) ?? []
    }

    public func exportSnapshot() async throws -> NativeDiagnosticsExportArtifact {
        try await store.exportSnapshot()
    }
}
