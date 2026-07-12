import Foundation

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
        if let store = decode(data) {
            return NativeShellPersistenceLoadResult(store: store, source: .restored)
        }

        let backupURL = url
            .deletingPathExtension()
            .appendingPathExtension("corrupt-\(UUID().uuidString).json")
        try fileManager.moveItem(at: url, to: backupURL)
        return NativeShellPersistenceLoadResult(
            store: NativeShellStore(),
            source: .recoveredCorruptBackup(backupURL.lastPathComponent)
        )
    }

    public static func save(_ store: NativeShellStore, to url: URL = defaultURL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(store)
#if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
#else
        try data.write(to: url, options: .atomic)
#endif
    }

    private static func decode(_ data: Data) -> NativeShellStore? {
        let isoDecoder = JSONDecoder()
        isoDecoder.dateDecodingStrategy = .iso8601
        if let store = try? isoDecoder.decode(NativeShellStore.self, from: data) {
            return store
        }
        return try? JSONDecoder().decode(NativeShellStore.self, from: data)
    }
}

public struct NativeShellStore: Codable, Equatable, Sendable {
    public var selectedRoute: NativeShellRoute
    public var slices: [MemorySlice]
    public var revisits: [MemoryRevisit]
    public var privacyBoundary: PrivacyBoundary
    public var latestExportSummary: NativeExportSummary?
    public var latestExportError: String?

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
        selectedRoute = .now
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
        return true
    }

    @discardableResult
    public mutating func attachMedia(_ media: MediaAnchor, to sliceID: UUID) -> Bool {
        guard let index = slices.firstIndex(where: { $0.id == sliceID }) else { return false }
        slices[index] = SliceFactory.attach(media, to: slices[index])
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
        return media
    }

    @discardableResult
    public mutating func deleteSlice(id: UUID) -> NativeDeletedMemorySlice? {
        guard let index = slices.firstIndex(where: { $0.id == id }) else { return nil }
        let slice = slices.remove(at: index)
        let relatedRevisits = revisits.filter { $0.sliceID == id }
        revisits.removeAll { $0.sliceID == id }
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
        selectedRoute = .slices
        return true
    }

    @discardableResult
    public mutating func exportMemoryVault(
        now: Date = Date(),
        thumbnailDirectory: URL = NativeMediaThumbnailStore.defaultDirectory
    ) throws -> ExportZIPPackage {
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
            for: plan,
            slices: slices,
            chapters: [chapter],
            revisits: revisits,
            deletionReceipt: deletionReceipt,
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

    public func weeklyPreviewTitle() -> String {
        let chapter = SliceFactory.compileWeeklyChapter(title: "本周没有消失", claimed: Array(slices.prefix(3)))
        return chapter.title
    }
}
