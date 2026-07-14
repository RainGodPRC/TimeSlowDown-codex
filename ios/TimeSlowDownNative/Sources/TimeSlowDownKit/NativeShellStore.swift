import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

public enum NativeShellRoute: String, CaseIterable, Codable, Equatable, Sendable {
    case now
    case slices
    case meadow
    case launch
    case account

    public var title: String {
        switch self {
        case .now: "此刻"
        case .slices: "切片"
        case .meadow: "旷野"
        case .launch: "印记"
        case .account: "我的"
        }
    }
}

public struct NativeShellSnapshot: Codable, Equatable, Sendable {
    public var routeCount: Int
    public var sliceCount: Int
    public var mediaAnchorCount: Int
    public var nativeTodoCount: Int
    public var submissionTodoCount: Int
    public var privacySafe: Bool
    public var hasExportPackage: Bool
    public var lastExportEntryCount: Int
    public var dailyDifferenceCandidateCount: Int
    public var ninetyDayTellableCount: Int
    public var ninetyDayMinimumTarget: Int
    public var yesterdayEchoAvailable: Bool
    public var weeklyStoryClaimedCount: Int
    public var weeklyStoryReadyCount: Int
    public var revisitCount: Int

    public init(
        routeCount: Int,
        sliceCount: Int,
        mediaAnchorCount: Int,
        nativeTodoCount: Int,
        submissionTodoCount: Int,
        privacySafe: Bool,
        hasExportPackage: Bool = false,
        lastExportEntryCount: Int = 0,
        dailyDifferenceCandidateCount: Int = 0,
        ninetyDayTellableCount: Int = 0,
        ninetyDayMinimumTarget: Int = 5,
        yesterdayEchoAvailable: Bool = false,
        weeklyStoryClaimedCount: Int = 0,
        weeklyStoryReadyCount: Int = 0,
        revisitCount: Int = 0
    ) {
        self.routeCount = routeCount
        self.sliceCount = sliceCount
        self.mediaAnchorCount = mediaAnchorCount
        self.nativeTodoCount = nativeTodoCount
        self.submissionTodoCount = submissionTodoCount
        self.privacySafe = privacySafe
        self.hasExportPackage = hasExportPackage
        self.lastExportEntryCount = lastExportEntryCount
        self.dailyDifferenceCandidateCount = dailyDifferenceCandidateCount
        self.ninetyDayTellableCount = ninetyDayTellableCount
        self.ninetyDayMinimumTarget = ninetyDayMinimumTarget
        self.yesterdayEchoAvailable = yesterdayEchoAvailable
        self.weeklyStoryClaimedCount = weeklyStoryClaimedCount
        self.weeklyStoryReadyCount = weeklyStoryReadyCount
        self.revisitCount = revisitCount
    }
}

public struct NativeExportSummary: Codable, Equatable, Sendable {
    public var fileName: String
    public var entryCount: Int
    public var fileSizeBytes: Int
    public var generatedOnDevice: Bool
    public var canBeGeneratedAfterSubscriptionEnds: Bool
    public var excludesRawMediaAndAITranscripts: Bool

    public init(
        fileName: String,
        entryCount: Int,
        fileSizeBytes: Int,
        generatedOnDevice: Bool,
        canBeGeneratedAfterSubscriptionEnds: Bool,
        excludesRawMediaAndAITranscripts: Bool
    ) {
        self.fileName = fileName
        self.entryCount = entryCount
        self.fileSizeBytes = fileSizeBytes
        self.generatedOnDevice = generatedOnDevice
        self.canBeGeneratedAfterSubscriptionEnds = canBeGeneratedAfterSubscriptionEnds
        self.excludesRawMediaAndAITranscripts = excludesRawMediaAndAITranscripts
    }

    public static func from(_ package: ExportZIPPackage) -> NativeExportSummary {
        NativeExportSummary(
            fileName: package.fileName,
            entryCount: package.entries.count,
            fileSizeBytes: package.data.count,
            generatedOnDevice: package.generatedOnDevice,
            canBeGeneratedAfterSubscriptionEnds: package.canBeGeneratedAfterSubscriptionEnds,
            excludesRawMediaAndAITranscripts: package.entries.allSatisfy {
                !$0.containsRawMedia && !$0.containsAITranscript
            }
        )
    }

    public static func from(_ artifact: NativeExportFileArtifact) -> NativeExportSummary {
        NativeExportSummary(
            fileName: artifact.fileName,
            entryCount: artifact.entries.count,
            fileSizeBytes: artifact.fileSizeBytes,
            generatedOnDevice: artifact.generatedOnDevice,
            canBeGeneratedAfterSubscriptionEnds: artifact.canBeGeneratedAfterSubscriptionEnds,
            excludesRawMediaAndAITranscripts: artifact.entries.allSatisfy {
                !$0.containsRawMedia && !$0.containsAITranscript
            }
        )
    }

    public var isTSDMemoryRightsSafe: Bool {
        generatedOnDevice &&
        canBeGeneratedAfterSubscriptionEnds &&
        excludesRawMediaAndAITranscripts &&
        entryCount >= 5 &&
        fileName.hasSuffix(".zip")
    }
}

public enum NativeShellPersistenceSource: Equatable, Sendable {
    case newVault
    case restored
    case migratedLegacy
    case migratedVersioned(Int)
    case restoredLastKnownGood(String)
    case recoveredCorruptBackup(String)
}

public struct NativeShellPersistenceLoadResult: Equatable, Sendable {
    public var store: NativeShellStore
    public var source: NativeShellPersistenceSource

    public init(store: NativeShellStore, source: NativeShellPersistenceSource) {
        self.store = store
        self.source = source
    }
}

public enum NativeVaultPersistenceError: Error, Equatable, Sendable {
    case unsupportedSchema(Int)
}

public struct NativeVaultPayload: Codable, Equatable, Sendable {
    public var slices: [MemorySlice]
    public var revisits: [MemoryRevisit]
    public var privacyBoundary: PrivacyBoundary

    public init(
        slices: [MemorySlice],
        revisits: [MemoryRevisit],
        privacyBoundary: PrivacyBoundary
    ) {
        self.slices = slices
        self.revisits = revisits
        self.privacyBoundary = privacyBoundary
    }

    public init(store: NativeShellStore) {
        self.init(
            slices: store.slices,
            revisits: store.revisits,
            privacyBoundary: store.privacyBoundary
        )
    }

    public var store: NativeShellStore {
        NativeShellStore(
            slices: slices,
            revisits: revisits,
            privacyBoundary: privacyBoundary
        )
    }
}

public struct NativeVaultEnvelope: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 3

    public var schemaVersion: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var payloadChecksum: String
    public var payload: NativeVaultPayload

    public var store: NativeShellStore { payload.store }

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        createdAt: Date,
        updatedAt: Date,
        payloadChecksum: String,
        store: NativeShellStore
    ) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.payloadChecksum = payloadChecksum
        self.payload = NativeVaultPayload(store: store)
    }
}

private struct NativeVaultEnvelopeV2: Codable {
    var schemaVersion: Int
    var createdAt: Date
    var updatedAt: Date
    var payloadChecksum: String
    var store: NativeShellStore
}

private struct DecodedNativeVault {
    var schemaVersion: Int
    var createdAt: Date
    var store: NativeShellStore
}

public struct NativeDeletedMemorySlice: Equatable, Sendable {
    public var slice: MemorySlice
    public var index: Int
    public var revisits: [MemoryRevisit]

    public init(slice: MemorySlice, index: Int, revisits: [MemoryRevisit]) {
        self.slice = slice
        self.index = index
        self.revisits = revisits
    }
}

public enum NativeShellPersistence {
    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("TimeSlowDown", isDirectory: true)
            .appendingPathComponent("native-shell-v1.json", isDirectory: false)
    }

    public static func loadRecovering(from url: URL = defaultURL) throws -> NativeShellPersistenceLoadResult {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            return NativeShellPersistenceLoadResult(store: NativeShellStore(), source: .newVault)
        }

        let data = try Data(contentsOf: url)
        if let schemaVersion = envelopeSchemaVersion(in: data),
           schemaVersion > NativeVaultEnvelope.currentSchemaVersion {
            throw NativeVaultPersistenceError.unsupportedSchema(schemaVersion)
        }
        if let decodedVault = decodeSupportedEnvelope(data) {
            if decodedVault.schemaVersion < NativeVaultEnvelope.currentSchemaVersion {
                try save(decodedVault.store, to: url)
                return NativeShellPersistenceLoadResult(
                    store: decodedVault.store,
                    source: .migratedVersioned(decodedVault.schemaVersion)
                )
            }
            return NativeShellPersistenceLoadResult(store: decodedVault.store, source: .restored)
        }
        if looksLikeLegacyStore(data), let store = decodeLegacyStore(data) {
            try save(store, to: url)
            return NativeShellPersistenceLoadResult(store: store, source: .migratedLegacy)
        }

        let backupURL = corruptBackupURL(for: url)
        try fileManager.moveItem(at: url, to: backupURL)
        let lastKnownGoodURL = lastKnownGoodURL(for: url)
        if fileManager.fileExists(atPath: lastKnownGoodURL.path),
           let lastKnownGoodVault = decodeSupportedEnvelope(try Data(contentsOf: lastKnownGoodURL)) {
            try save(lastKnownGoodVault.store, to: url)
            return NativeShellPersistenceLoadResult(
                store: lastKnownGoodVault.store,
                source: .restoredLastKnownGood(backupURL.lastPathComponent)
            )
        }
        return NativeShellPersistenceLoadResult(
            store: NativeShellStore(),
            source: .recoveredCorruptBackup(backupURL.lastPathComponent)
        )
    }

    public static func lastKnownGoodURL(for url: URL) -> URL {
        url.deletingPathExtension().appendingPathExtension("last-known-good.json")
    }

    public static func save(_ store: NativeShellStore, to url: URL = defaultURL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var currentVault: DecodedNativeVault?
        if fileManager.fileExists(atPath: url.path) {
            let currentData = try Data(contentsOf: url)
            if let schemaVersion = envelopeSchemaVersion(in: currentData),
               schemaVersion > NativeVaultEnvelope.currentSchemaVersion {
                throw NativeVaultPersistenceError.unsupportedSchema(schemaVersion)
            }
            currentVault = decodeSupportedEnvelope(currentData)
            if currentVault != nil {
                try write(currentData, to: lastKnownGoodURL(for: url))
            }
        }
        let now = Date()
        let payload = NativeVaultPayload(store: store)
        let envelope = NativeVaultEnvelope(
            createdAt: currentVault?.createdAt ?? now,
            updatedAt: now,
            payloadChecksum: try checksum(for: payload),
            store: store
        )
        let data = try encoder().encode(envelope)
        try write(data, to: url)
    }

    private static func corruptBackupURL(for url: URL) -> URL {
        url.deletingPathExtension()
            .appendingPathExtension("corrupt-\(UUID().uuidString).json")
    }

    private static func write(_ data: Data, to url: URL) throws {
#if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
#else
        try data.write(to: url, options: .atomic)
#endif
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static func checksum<T: Encodable>(for value: T) throws -> String {
        let payload = try encoder().encode(value)
#if canImport(CryptoKit)
        return SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
#else
        return payload.base64EncodedString()
#endif
    }

    private static func decodeSupportedEnvelope(_ data: Data) -> DecodedNativeVault? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        switch envelopeSchemaVersion(in: data) {
        case NativeVaultEnvelope.currentSchemaVersion:
            guard let envelope = try? decoder.decode(NativeVaultEnvelope.self, from: data),
                  let expectedChecksum = try? checksum(for: envelope.payload),
                  envelope.payloadChecksum == expectedChecksum else {
                return nil
            }
            return DecodedNativeVault(
                schemaVersion: envelope.schemaVersion,
                createdAt: envelope.createdAt,
                store: envelope.store
            )
        case 2:
            guard let envelope = try? decoder.decode(NativeVaultEnvelopeV2.self, from: data),
                  let expectedChecksum = try? checksum(for: envelope.store),
                  envelope.payloadChecksum == expectedChecksum else {
                return nil
            }
            return DecodedNativeVault(
                schemaVersion: envelope.schemaVersion,
                createdAt: envelope.createdAt,
                store: NativeVaultPayload(store: envelope.store).store
            )
        default:
            return nil
        }
    }

    private static func looksLikeLegacyStore(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return object["schemaVersion"] == nil &&
            (object["slices"] != nil || object["privacyBoundary"] != nil || object["selectedRoute"] != nil)
    }

    private static func envelopeSchemaVersion(in data: Data) -> Int? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object["schemaVersion"] as? Int
    }

    private static func decodeLegacyStore(_ data: Data) -> NativeShellStore? {
        let isoDecoder = JSONDecoder()
        isoDecoder.dateDecodingStrategy = .iso8601
        if let store = try? isoDecoder.decode(NativeShellStore.self, from: data) {
            return store
        }
        return try? JSONDecoder().decode(NativeShellStore.self, from: data)
    }
}

public enum NativeOnboardingOutcome: String, Codable, Equatable, Sendable {
    case capturedPhoto
    case capturedVideo
    case capturedText
    case skipped
}

public struct NativeOnboardingState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var completedAt: Date
    public var outcome: NativeOnboardingOutcome

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        completedAt: Date = Date(),
        outcome: NativeOnboardingOutcome
    ) {
        self.schemaVersion = schemaVersion
        self.completedAt = completedAt
        self.outcome = outcome
    }
}

public enum NativeOnboardingPersistenceError: Error, Equatable, Sendable {
    case unsupportedSchema(Int)
}

public enum NativeOnboardingPersistence {
    public static var defaultURL: URL {
        NativeShellPersistence.defaultURL
            .deletingLastPathComponent()
            .appendingPathComponent("native-onboarding-v1.json", isDirectory: false)
    }

    public static func load(from url: URL = defaultURL) throws -> NativeOnboardingState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let state = try decoder.decode(NativeOnboardingState.self, from: Data(contentsOf: url))
        guard state.schemaVersion <= NativeOnboardingState.currentSchemaVersion else {
            throw NativeOnboardingPersistenceError.unsupportedSchema(state.schemaVersion)
        }
        return state
    }

    public static func save(
        _ state: NativeOnboardingState,
        to url: URL = defaultURL
    ) throws {
        guard state.schemaVersion <= NativeOnboardingState.currentSchemaVersion else {
            throw NativeOnboardingPersistenceError.unsupportedSchema(state.schemaVersion)
        }
        if FileManager.default.fileExists(atPath: url.path),
           let object = try? JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
           let existingSchema = object["schemaVersion"] as? Int,
           existingSchema > NativeOnboardingState.currentSchemaVersion {
            throw NativeOnboardingPersistenceError.unsupportedSchema(existingSchema)
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
#if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
#else
        try data.write(to: url, options: .atomic)
#endif
    }
}

public enum NativeOnboardingMode: Equatable, Sendable {
    case automatic
    case required
    case completed
}

public enum NativeOnboardingDecision {
    public static func shouldPresent(
        mode: NativeOnboardingMode,
        hasInjectedStore: Bool,
        vaultSource: NativeShellPersistenceSource?,
        savedState: NativeOnboardingState?
    ) -> Bool {
        switch mode {
        case .required:
            return true
        case .completed:
            return false
        case .automatic:
            guard !hasInjectedStore, savedState == nil else { return false }
            if case .newVault? = vaultSource { return true }
            return false
        }
    }
}

public struct NativeShellStore: Codable, Equatable, Sendable {
    public var selectedRoute: NativeShellRoute
    public private(set) var slices: [MemorySlice]
    public private(set) var revisits: [MemoryRevisit]
    public private(set) var privacyBoundary: PrivacyBoundary
    public private(set) var latestExportSummary: NativeExportSummary?
    public private(set) var latestExportError: String?
    public private(set) var vaultRevision: UInt64

    public var referencedThumbnailFileNames: Set<String> {
        Set(slices.compactMap { $0.media?.thumbnailFileName })
    }

    public static func == (lhs: NativeShellStore, rhs: NativeShellStore) -> Bool {
        lhs.selectedRoute == rhs.selectedRoute &&
        lhs.slices == rhs.slices &&
        lhs.revisits == rhs.revisits &&
        lhs.privacyBoundary == rhs.privacyBoundary &&
        lhs.latestExportSummary == rhs.latestExportSummary &&
        lhs.latestExportError == rhs.latestExportError
    }

    public init(
        selectedRoute: NativeShellRoute = .now,
        slices: [MemorySlice] = [],
        revisits: [MemoryRevisit] = [],
        privacyBoundary: PrivacyBoundary = PrivacyBoundary(),
        latestExportSummary: NativeExportSummary? = nil,
        latestExportError: String? = nil
    ) {
        self.selectedRoute = selectedRoute
        self.slices = slices
        self.revisits = revisits
        self.privacyBoundary = privacyBoundary
        self.latestExportSummary = latestExportSummary
        self.latestExportError = latestExportError
        self.vaultRevision = 0
    }

    private enum CodingKeys: String, CodingKey {
        case selectedRoute
        case slices
        case revisits
        case privacyBoundary
        case latestExportSummary
        case latestExportError
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedRoute = try container.decodeIfPresent(NativeShellRoute.self, forKey: .selectedRoute) ?? .now
        slices = try container.decodeIfPresent([MemorySlice].self, forKey: .slices) ?? []
        revisits = try container.decodeIfPresent([MemoryRevisit].self, forKey: .revisits) ?? []
        privacyBoundary = try container.decodeIfPresent(PrivacyBoundary.self, forKey: .privacyBoundary) ?? PrivacyBoundary()
        latestExportSummary = try container.decodeIfPresent(NativeExportSummary.self, forKey: .latestExportSummary)
        latestExportError = try container.decodeIfPresent(String.self, forKey: .latestExportError)
        vaultRevision = 0
    }

    public static func seeded(now: Date = Date()) -> NativeShellStore {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let earlier = Calendar.current.date(byAdding: .day, value: -3, to: now) ?? now
        return NativeShellStore(
            slices: [
                SliceFactory.quickMark(
                    title: "他第一次自己爬上滑梯",
                    body: "我站在下面有点紧张，但他回头笑了。",
                    tags: ["第一次", "家人"],
                    media: MediaAnchor(kind: .image, label: "park.jpg", note: "孩子第一次自己爬上滑梯"),
                    now: now
                ),
                SliceFactory.quickMark(
                    title: "和爸爸吃面",
                    body: "没有聊什么大事，但那碗面让我想起小时候。",
                    tags: ["家人", "饭桌"],
                    now: yesterday
                ),
                SliceFactory.quickMark(
                    title: "会议后的回家路",
                    body: "有点低落，也算这一周的一部分。",
                    tags: ["工作", "低落"],
                    now: earlier
                )
            ]
        )
    }

    public var snapshot: NativeShellSnapshot {
        let radar = SliceFactory.dailyDifferenceRadar(from: slices)
        let progress = SliceFactory.ninetyDayTellableProgress(
            from: slices,
            claimedSliceIDs: Array(slices.prefix(3)).map(\.id)
        )
        let weekly = SliceFactory.weeklyStoryProgress(
            from: slices,
            claimedSliceIDs: Array(slices.prefix(3)).map(\.id)
        )
        let echo = SliceFactory.yesterdayEcho(from: slices, revisits: revisits)
        return NativeShellSnapshot(
            routeCount: NativeShellRoute.allCases.count,
            sliceCount: slices.count,
            mediaAnchorCount: slices.filter(\.hasMediaAnchor).count,
            nativeTodoCount: NativeHandoffLedger.rows.filter { $0.status == .todo }.count,
            submissionTodoCount: SubmissionPacket.rows.filter { $0.status == .todo }.count,
            privacySafe: privacyBoundary.isAppStoreSafeDefault,
            hasExportPackage: latestExportSummary != nil,
            lastExportEntryCount: latestExportSummary?.entryCount ?? 0,
            dailyDifferenceCandidateCount: radar.candidates.count,
            ninetyDayTellableCount: progress.tellableCount,
            ninetyDayMinimumTarget: progress.minimumTarget,
            yesterdayEchoAvailable: echo != nil,
            weeklyStoryClaimedCount: weekly.claimedCount,
            weeklyStoryReadyCount: weekly.readyCount,
            revisitCount: revisits.count
        )
    }

    @discardableResult
    public mutating func revisitYesterdayEcho(reflection: String = "", now: Date = Date()) -> MemoryRevisit? {
        guard let echo = SliceFactory.yesterdayEcho(from: slices, revisits: revisits, now: now) else { return nil }
        let revisit = SliceFactory.revisit(echo, reflection: reflection, now: now)
        revisits.append(revisit)
        markVaultChanged()
        selectedRoute = .now
        return revisit
    }

    public mutating func captureFromMemoryCamera(_ media: MediaAnchor, title: String? = nil) -> MemorySlice {
        let slice = SliceFactory.quickMark(
            title: title ?? "照片/视频先占位",
            tags: ["影像"],
            media: media
        )
        slices.insert(slice, at: 0)
        markVaultChanged()
        selectedRoute = .slices
        return slice
    }

    @discardableResult
    public mutating func captureQuickMark(title: String, body: String = "", now: Date = Date()) -> MemorySlice? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return nil }
        let slice = SliceFactory.quickMark(
            title: cleanTitle,
            body: cleanBody,
            tags: ["快速记录"],
            now: now
        )
        slices.insert(slice, at: 0)
        markVaultChanged()
        selectedRoute = .now
        return slice
    }

    @discardableResult
    public mutating func captureFirstMemory(
        title: String,
        body: String = "",
        tags: [String] = [],
        media: MediaAnchor? = nil,
        sources: [String] = [],
        now: Date = Date()
    ) -> MemorySlice? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return nil }
        let provenance = Array(Set(["首次体验"] + sources)).sorted()
        let slice = SliceFactory.quickMark(
            title: cleanTitle,
            body: cleanBody,
            tags: tags,
            media: media,
            now: now,
            sources: provenance
        )
        slices.insert(slice, at: 0)
        markVaultChanged()
        selectedRoute = .slices
        return slice
    }

    @discardableResult
    public mutating func completeWeekendGap(
        sliceID: UUID,
        kind: WeeklyStoryGapKind,
        value: String = "",
        media: MediaAnchor? = nil
    ) -> Bool {
        guard let index = slices.firstIndex(where: { $0.id == sliceID }) else { return false }
        switch kind {
        case .media:
            guard let media else { return false }
            slices[index] = SliceFactory.attach(media, to: slices[index])
            if !slices[index].sources.contains("周末补全：影像") {
                slices[index].sources.append("周末补全：影像")
            }
        case .people, .meaning:
            let next = SliceFactory.completeWeekendGap(kind, value: value, in: slices[index])
            guard next != slices[index] else { return false }
            slices[index] = next
        }
        markVaultChanged()
        selectedRoute = .now
        return true
    }

    @discardableResult
    public mutating func updateSlice(
        id: UUID,
        title: String,
        body: String,
        peopleText: String,
        meaning: String
    ) -> Bool {
        guard let index = slices.firstIndex(where: { $0.id == id }) else { return false }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return false }
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let people = peopleText
            .split(separator: ",", omittingEmptySubsequences: true)
            .flatMap { $0.split(separator: "，", omittingEmptySubsequences: true) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let cleanMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        slices[index].title = cleanTitle
        slices[index].body = cleanBody
        slices[index].people = people.isEmpty ? nil : people
        slices[index].meaning = cleanMeaning.isEmpty ? nil : cleanMeaning
        if !slices[index].sources.contains("用户编辑") {
            slices[index].sources.append("用户编辑")
        }
        markVaultChanged()
        return true
    }

    @discardableResult
    public mutating func attachMedia(_ media: MediaAnchor, to sliceID: UUID) -> Bool {
        guard let index = slices.firstIndex(where: { $0.id == sliceID }) else { return false }
        slices[index] = SliceFactory.attach(media, to: slices[index])
        markVaultChanged()
        return true
    }

    @discardableResult
    public mutating func detachMedia(from sliceID: UUID) -> MediaAnchor? {
        guard let index = slices.firstIndex(where: { $0.id == sliceID }),
              let media = slices[index].media else { return nil }
        slices[index].media = nil
        slices[index].tags.removeAll { $0 == "照片" || $0 == "视频" }
        if !slices[index].sources.contains("用户移除影像") {
            slices[index].sources.append("用户移除影像")
        }
        markVaultChanged()
        return media
    }

    @discardableResult
    public mutating func deleteSlice(id: UUID) -> NativeDeletedMemorySlice? {
        guard let index = slices.firstIndex(where: { $0.id == id }) else { return nil }
        let slice = slices.remove(at: index)
        let relatedRevisits = revisits.filter { $0.sliceID == id }
        revisits.removeAll { $0.sliceID == id }
        markVaultChanged()
        selectedRoute = .slices
        return NativeDeletedMemorySlice(slice: slice, index: index, revisits: relatedRevisits)
    }

    @discardableResult
    public mutating func restoreDeletedSlice(_ deleted: NativeDeletedMemorySlice) -> Bool {
        guard !slices.contains(where: { $0.id == deleted.slice.id }) else { return false }
        slices.insert(deleted.slice, at: min(max(0, deleted.index), slices.count))
        for revisit in deleted.revisits where !revisits.contains(where: { $0.id == revisit.id }) {
            revisits.append(revisit)
        }
        markVaultChanged()
        selectedRoute = .slices
        return true
    }

    @discardableResult
    public mutating func updatePrivacyBoundary(_ boundary: PrivacyBoundary) -> Bool {
        guard boundary != privacyBoundary else { return false }
        privacyBoundary = boundary
        markVaultChanged()
        return true
    }

    public func memoryExportRequest(
        now: Date = Date(),
        thumbnailDirectory: URL = NativeMediaThumbnailStore.defaultDirectory
    ) -> NativeMemoryExportRequest {
        let key = KeychainVaultStub.bootstrapDeviceKey(
            accountID: "guest-pass",
            deviceName: "This iPhone",
            createdAt: now
        )
        let chapter = SliceFactory.compileWeeklyChapter(
            title: "本周没有消失",
            claimed: Array(slices.prefix(3))
        )
        let manifest = ExportManifestSigner.sign(
            slices: slices,
            chapters: [chapter],
            with: key,
            generatedAt: now
        )
        let plan = ExportArchivePlan.zipPlan(for: manifest)
        let deletionReceipt = DeletionReceipt.issue(
            scopes: [.localCache, .encryptedCloudBackup, .aiDrafts, .mediaThumbnails],
            requestedAt: now
        )
        return NativeMemoryExportRequest(
            plan: plan,
            slices: slices,
            chapters: [chapter],
            revisits: revisits,
            deletionReceipt: deletionReceipt,
            thumbnailDirectory: thumbnailDirectory
        )
    }

    @discardableResult
    public mutating func exportMemoryVault(
        now: Date = Date(),
        thumbnailDirectory: URL = NativeMediaThumbnailStore.defaultDirectory
    ) throws -> ExportZIPPackage {
        let request = memoryExportRequest(now: now, thumbnailDirectory: thumbnailDirectory)
        let thumbnailPairs: [(String, Data)] = slices.compactMap { slice in
            guard let media = slice.media,
                  let fileName = media.thumbnailFileName,
                  let data = NativeMediaThumbnailStore.data(
                      fileName: fileName,
                      directory: thumbnailDirectory
                  ) else {
                return nil
            }
            return (media.id.uuidString, data)
        }
        let thumbnailDataByAnchorID = thumbnailPairs.reduce(into: [String: Data]()) { result, pair in
            result[pair.0] = pair.1
        }
        let package = try OnDeviceExportZIPBuilder.package(
            for: request.plan,
            slices: request.slices,
            chapters: request.chapters,
            revisits: request.revisits,
            deletionReceipt: request.deletionReceipt,
            thumbnailDataByAnchorID: thumbnailDataByAnchorID
        )
        latestExportSummary = NativeExportSummary.from(package)
        latestExportError = nil
        selectedRoute = .account
        return package
    }

    public mutating func recordExportError(_ message: String) {
        latestExportError = message
        selectedRoute = .account
    }

    public mutating func beginExport() {
        latestExportError = nil
        selectedRoute = .account
    }

    public mutating func recordExportSuccess(_ artifact: NativeExportFileArtifact) {
        latestExportSummary = NativeExportSummary.from(artifact)
        latestExportError = nil
        selectedRoute = .account
    }

    private mutating func markVaultChanged() {
        vaultRevision &+= 1
    }

    public func weeklyPreviewTitle() -> String {
        let chapter = SliceFactory.compileWeeklyChapter(title: "本周没有消失", claimed: Array(slices.prefix(3)))
        return chapter.title
    }
}
