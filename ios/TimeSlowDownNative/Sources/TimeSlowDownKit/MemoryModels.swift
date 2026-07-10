import Foundation

public enum MediaKind: String, Codable, Equatable, Sendable {
    case image
    case video
    case link
}

public struct MediaAnchor: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var kind: MediaKind
    public var label: String
    public var note: String
    public var storage: String
    public var source: String
    public var thumbnailFileName: String?
    public var thumbnailByteCount: Int?
    public var thumbnailIssue: String?

    public init(
        id: UUID = UUID(),
        kind: MediaKind,
        label: String,
        note: String = "",
        storage: String = "photos-picker-limited",
        source: String = "user-selected-media",
        thumbnailFileName: String? = nil,
        thumbnailByteCount: Int? = nil,
        thumbnailIssue: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.note = note
        self.storage = storage
        self.source = source
        self.thumbnailFileName = thumbnailFileName
        self.thumbnailByteCount = thumbnailByteCount
        self.thumbnailIssue = thumbnailIssue
    }

    public var hasLocalThumbnailReference: Bool {
        thumbnailFileName?.isEmpty == false && (thumbnailByteCount ?? 0) > 0
    }
}

public struct MemorySlice: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var body: String
    public var tags: [String]
    public var capturedAt: Date
    public var media: MediaAnchor?
    public var people: [String]?
    public var meaning: String?
    public var sources: [String]

    public init(
        id: UUID = UUID(),
        title: String,
        body: String,
        tags: [String] = [],
        capturedAt: Date = Date(),
        media: MediaAnchor? = nil,
        people: [String]? = nil,
        meaning: String? = nil,
        sources: [String] = []
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.tags = tags
        self.capturedAt = capturedAt
        self.media = media
        self.people = people
        self.meaning = meaning
        self.sources = sources
    }

    public var hasMediaAnchor: Bool {
        media != nil
    }
}

public struct WeeklyChapter: Codable, Equatable, Sendable {
    public var title: String
    public var claimedSliceIDs: [UUID]
    public var narrative: String
    public var sources: [String]

    public init(title: String, claimedSliceIDs: [UUID], narrative: String, sources: [String]) {
        self.title = title
        self.claimedSliceIDs = claimedSliceIDs
        self.narrative = narrative
        self.sources = sources
    }
}

public enum DailyDifferenceCandidateKind: String, Codable, Equatable, Sendable {
    case mediaAnchor
    case relationship
    case turningPoint
}

public struct DailyDifferenceCandidate: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: DailyDifferenceCandidateKind
    public var title: String
    public var prompt: String
    public var suggestedBody: String
    public var tags: [String]
    public var sourceSliceID: UUID?
    public var source: String

    public init(
        id: String,
        kind: DailyDifferenceCandidateKind,
        title: String,
        prompt: String,
        suggestedBody: String,
        tags: [String],
        sourceSliceID: UUID? = nil,
        source: String = "今日差异雷达"
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.prompt = prompt
        self.suggestedBody = suggestedBody
        self.tags = tags
        self.sourceSliceID = sourceSliceID
        self.source = source
    }
}

public struct DailyDifferenceRadar: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var candidates: [DailyDifferenceCandidate]

    public init(generatedAt: Date = Date(), candidates: [DailyDifferenceCandidate]) {
        self.generatedAt = generatedAt
        self.candidates = candidates
    }

    public var isTSDDailyLoopReady: Bool {
        candidates.count == 3 &&
        Set(candidates.map(\.kind)).count == 3 &&
        candidates.allSatisfy { !$0.title.isEmpty && $0.source == "今日差异雷达" }
    }
}

public struct NinetyDayTellableProgress: Codable, Equatable, Sendable {
    public var tellableCount: Int
    public var minimumTarget: Int
    public var aspirationalTarget: Int
    public var mediaAnchorCount: Int
    public var weeklyClaimedCount: Int
    public var weeklyClaimMissing: Int
    public var sourceSliceIDs: [UUID]
    public var nextAction: String

    public init(
        tellableCount: Int,
        minimumTarget: Int = 5,
        aspirationalTarget: Int = 10,
        mediaAnchorCount: Int,
        weeklyClaimedCount: Int,
        weeklyClaimMissing: Int,
        sourceSliceIDs: [UUID],
        nextAction: String
    ) {
        self.tellableCount = tellableCount
        self.minimumTarget = minimumTarget
        self.aspirationalTarget = aspirationalTarget
        self.mediaAnchorCount = mediaAnchorCount
        self.weeklyClaimedCount = weeklyClaimedCount
        self.weeklyClaimMissing = weeklyClaimMissing
        self.sourceSliceIDs = sourceSliceIDs
        self.nextAction = nextAction
    }

    public var progressPercent: Int {
        min(100, Int((Double(tellableCount) / Double(minimumTarget)) * 100))
    }

    public var isTSDNorthStarAligned: Bool {
        minimumTarget == 5 &&
        aspirationalTarget == 10 &&
        weeklyClaimMissing >= 0 &&
        !nextAction.localizedCaseInsensitiveContains("fail") &&
        !nextAction.contains("失败")
    }
}

public struct MemoryRevisit: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var sliceID: UUID
    public var revisitedAt: Date
    public var reflection: String
    public var source: String

    public init(
        id: UUID = UUID(),
        sliceID: UUID,
        revisitedAt: Date = Date(),
        reflection: String = "",
        source: String = "昨日回声"
    ) {
        self.id = id
        self.sliceID = sliceID
        self.revisitedAt = revisitedAt
        self.reflection = reflection
        self.source = source
    }
}

public struct YesterdayEcho: Codable, Equatable, Sendable {
    public var sliceID: UUID
    public var title: String
    public var body: String
    public var media: MediaAnchor?
    public var previousRevisitCount: Int
    public var prompt: String

    public init(
        sliceID: UUID,
        title: String,
        body: String,
        media: MediaAnchor?,
        previousRevisitCount: Int,
        prompt: String = "现在再看，我想补一句……"
    ) {
        self.sliceID = sliceID
        self.title = title
        self.body = body
        self.media = media
        self.previousRevisitCount = previousRevisitCount
        self.prompt = prompt
    }

    public var isGentleReturnReady: Bool {
        !title.isEmpty && !body.isEmpty && prompt.contains("现在再看")
    }
}

public enum WeeklyStoryGapKind: String, Codable, CaseIterable, Equatable, Sendable {
    case media
    case people
    case meaning

    public var title: String {
        switch self {
        case .media: "一张影像"
        case .people: "一个人物"
        case .meaning: "一句为什么"
        }
    }
}

public struct WeeklyStoryCandidate: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID { sliceID }
    public var sliceID: UUID
    public var title: String
    public var missing: [WeeklyStoryGapKind]

    public init(sliceID: UUID, title: String, missing: [WeeklyStoryGapKind]) {
        self.sliceID = sliceID
        self.title = title
        self.missing = missing
    }

    public var isReady: Bool { missing.isEmpty }
}

public struct WeeklyStoryProgress: Codable, Equatable, Sendable {
    public var claimedCount: Int
    public var target: Int
    public var readyCount: Int
    public var completeFieldCount: Int
    public var totalFieldCount: Int
    public var candidates: [WeeklyStoryCandidate]
    public var nextAction: String

    public init(
        claimedCount: Int,
        target: Int = 3,
        readyCount: Int,
        completeFieldCount: Int,
        totalFieldCount: Int,
        candidates: [WeeklyStoryCandidate],
        nextAction: String
    ) {
        self.claimedCount = claimedCount
        self.target = target
        self.readyCount = readyCount
        self.completeFieldCount = completeFieldCount
        self.totalFieldCount = totalFieldCount
        self.candidates = candidates
        self.nextAction = nextAction
    }

    public var percent: Int {
        guard totalFieldCount > 0 else { return 0 }
        return Int((Double(completeFieldCount) / Double(totalFieldCount)) * 100)
    }

    public var isNonPunitive: Bool {
        target == 3 &&
        readyCount <= candidates.count &&
        !nextAction.contains("欠") &&
        !nextAction.contains("断签") &&
        !nextAction.contains("失败")
    }
}

public enum SliceFactory {
    public static func quickMark(
        title: String,
        body: String = "",
        tags: [String] = [],
        media: MediaAnchor? = nil,
        now: Date = Date(),
        sources extraSources: [String] = []
    ) -> MemorySlice {
        var nextTags = tags
        var sources = ["quick-mark"] + extraSources
        if let media {
            let mediaTag = media.kind == .video ? "视频" : "照片"
            if !nextTags.contains(mediaTag) {
                nextTags.append(mediaTag)
            }
            sources.append("影像线索")
        }

        return MemorySlice(
            title: title,
            body: body.isEmpty ? defaultBody(for: title, media: media) : body,
            tags: nextTags,
            capturedAt: now,
            media: media,
            sources: sources
        )
    }

    public static func quickMark(from candidate: DailyDifferenceCandidate, media: MediaAnchor? = nil, now: Date = Date()) -> MemorySlice {
        quickMark(
            title: candidate.title,
            body: candidate.suggestedBody,
            tags: candidate.tags,
            media: media,
            now: now,
            sources: [candidate.source] + (candidate.sourceSliceID.map { ["source:\($0.uuidString)"] } ?? [])
        )
    }

    public static func attach(_ media: MediaAnchor, to slice: MemorySlice) -> MemorySlice {
        var next = slice
        next.media = media
        if !next.sources.contains("切片补影像") {
            next.sources.append("切片补影像")
        }
        let mediaTag = media.kind == .video ? "视频" : "照片"
        if !next.tags.contains(mediaTag) {
            next.tags.append(mediaTag)
        }
        return next
    }

    public static func compileWeeklyChapter(title: String, claimed slices: [MemorySlice]) -> WeeklyChapter {
        let claimed = Array(slices.prefix(3))
        let mediaCount = claimed.filter(\.hasMediaAnchor).count
        let narrative = [
            "这一周没有消失。",
            "我认领了 \(claimed.count) 个瞬间，其中 \(mediaCount) 个有照片或视频锚点。",
            claimed.map { "・\($0.title)" }.joined(separator: "\n")
        ].joined(separator: "\n")
        let sources = claimed.flatMap(\.sources) + claimed.map { "slice:\($0.id.uuidString)" }
        return WeeklyChapter(
            title: title,
            claimedSliceIDs: claimed.map(\.id),
            narrative: narrative,
            sources: sources
        )
    }

    public static func dailyDifferenceRadar(from slices: [MemorySlice], now: Date = Date()) -> DailyDifferenceRadar {
        DailyDifferenceRadar(generatedAt: now, candidates: dailyDifferenceCandidates(from: slices, now: now))
    }

    public static func dailyDifferenceCandidates(from slices: [MemorySlice], now: Date = Date()) -> [DailyDifferenceCandidate] {
        let media = slices.first(where: \.hasMediaAnchor)
        let relationship = slices.first { matches($0, tokens: ["爸爸", "妈妈", "家人", "孩子", "朋友", "同事", "吃面", "通话"]) && $0.id != media?.id }
        let turning = slices.first { matches($0, tokens: ["第一次", "第一个", "跑完", "完成", "成就", "学会", "低落", "工作", "烦"]) && $0.id != media?.id && $0.id != relationship?.id }

        return [
            DailyDifferenceCandidate(
                id: "radar-media",
                kind: .mediaAnchor,
                title: media.map { "\($0.media?.kind == .video ? "视频" : "照片")里有一个今天" } ?? "先用照片/视频占住今天",
                prompt: media.map { "影像已经在，给它认领成一个可讲述切片：\($0.title)" } ?? "如果今天拍过什么，不必先写长文，先选一张。",
                suggestedBody: media.map { "\($0.title)。\($0.media?.note.isEmpty == false ? $0.media!.note : "这条影像能把我带回当时。")" } ?? "今天有一张照片/视频，先把现场钉住；文字可以以后再补。",
                tags: ["影像线索", "普通但值得"],
                sourceSliceID: media?.id
            ),
            DailyDifferenceCandidate(
                id: "radar-person",
                kind: .relationship,
                title: relationship.map { "今天从“\($0.title)”讲起" } ?? "今天有没有一个人更清晰？",
                prompt: "关系记忆通常不是大道理，而是一句话、一顿饭、一个表情。",
                suggestedBody: relationship.map { "\($0.title)。\($0.body)" } ?? "今天有一个人比平时更清晰，我想先把这个瞬间留下。",
                tags: ["人", "普通但值得"],
                sourceSliceID: relationship?.id
            ),
            DailyDifferenceCandidate(
                id: "radar-turn",
                kind: .turningPoint,
                title: turning.map { "\($0.title)值得留下" } ?? "今天有没有一个小小转弯？",
                prompt: "第一次、完成、低落后的路，都算时间里的差异。",
                suggestedBody: turning.map { "\($0.title)。\($0.body)" } ?? "今天有一个小小转弯：它不一定宏大，但我想以后还能想起。",
                tags: ["情绪转弯", "普通但值得"],
                sourceSliceID: turning?.id
            )
        ]
    }

    public static func ninetyDayTellableProgress(
        from slices: [MemorySlice],
        claimedSliceIDs: [UUID] = [],
        now: Date = Date()
    ) -> NinetyDayTellableProgress {
        let threshold = Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now
        let recent = slices.filter { $0.capturedAt >= threshold }
        let tellable = recent.filter { tellableScore($0) >= 2 }.prefix(10)
        let claimedCount = claimedSliceIDs.filter { id in slices.contains(where: { $0.id == id }) }.count
        let weeklyMissing = max(0, 3 - claimedCount)
        let missingToMinimum = max(0, 5 - tellable.count)
        let action = weeklyMissing > 0
            ? "本周再认领 \(weeklyMissing) 个瞬间，就能编成一段可讲述章节。"
            : missingToMinimum > 0
                ? "再留下 \(missingToMinimum) 个有画面/人物/转弯的切片，90 天会更好讲。"
                : "已经有一组能讲起的季度记忆，可以进入 90 天回忆仪式。"
        return NinetyDayTellableProgress(
            tellableCount: tellable.count,
            mediaAnchorCount: recent.filter(\.hasMediaAnchor).count,
            weeklyClaimedCount: claimedCount,
            weeklyClaimMissing: weeklyMissing,
            sourceSliceIDs: tellable.map(\.id),
            nextAction: action
        )
    }

    public static func yesterdayEcho(
        from slices: [MemorySlice],
        revisits: [MemoryRevisit] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> YesterdayEcho? {
        let startOfToday = calendar.startOfDay(for: now)
        guard let slice = slices
            .filter({ $0.capturedAt < startOfToday })
            .sorted(by: { $0.capturedAt > $1.capturedAt })
            .first else { return nil }
        return YesterdayEcho(
            sliceID: slice.id,
            title: slice.title,
            body: slice.body,
            media: slice.media,
            previousRevisitCount: revisits.filter { $0.sliceID == slice.id }.count
        )
    }

    public static func revisit(
        _ echo: YesterdayEcho,
        reflection: String = "",
        now: Date = Date()
    ) -> MemoryRevisit {
        MemoryRevisit(
            sliceID: echo.sliceID,
            revisitedAt: now,
            reflection: reflection,
            source: "昨日回声"
        )
    }

    public static func weeklyStoryProgress(
        from slices: [MemorySlice],
        claimedSliceIDs: [UUID]
    ) -> WeeklyStoryProgress {
        var selected = claimedSliceIDs.compactMap { id in slices.first(where: { $0.id == id }) }
        for slice in slices where selected.count < 3 && !selected.contains(where: { $0.id == slice.id }) {
            selected.append(slice)
        }
        selected = Array(selected.prefix(3))
        let candidates = selected.map { slice -> WeeklyStoryCandidate in
            var missing: [WeeklyStoryGapKind] = []
            if !slice.hasMediaAnchor { missing.append(.media) }
            if !hasPersonSignal(slice) { missing.append(.people) }
            if !hasMeaningSignal(slice) { missing.append(.meaning) }
            return WeeklyStoryCandidate(sliceID: slice.id, title: slice.title, missing: missing)
        }
        let claimedCount = claimedSliceIDs.filter { id in slices.contains(where: { $0.id == id }) }.count
        let readyCount = candidates.filter(\.isReady).count
        let totalFields = candidates.count * WeeklyStoryGapKind.allCases.count
        let missingFields = candidates.reduce(0) { $0 + $1.missing.count }
        let nextCandidate = candidates.first(where: { !$0.missing.isEmpty })
        let nextAction: String
        if claimedCount < 3 {
            nextAction = "再认领 \(3 - claimedCount) 个瞬间，这一周就有故事骨架。"
        } else if let nextCandidate, let gap = nextCandidate.missing.first {
            nextAction = "\(nextCandidate.title)还可以补\(gap.title)。"
        } else {
            nextAction = "三个瞬间都已有影像、人物与意义线索，可以编译本周章节。"
        }
        return WeeklyStoryProgress(
            claimedCount: claimedCount,
            readyCount: readyCount,
            completeFieldCount: max(0, totalFields - missingFields),
            totalFieldCount: totalFields,
            candidates: candidates,
            nextAction: nextAction
        )
    }

    public static func completeWeekendGap(
        _ kind: WeeklyStoryGapKind,
        value: String,
        in slice: MemorySlice
    ) -> MemorySlice {
        var next = slice
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .media:
            break
        case .people:
            if !trimmed.isEmpty {
                next.people = [trimmed]
                if !next.tags.contains("人") { next.tags.append("人") }
                if !next.sources.contains("周末补全：人物") { next.sources.append("周末补全：人物") }
            }
        case .meaning:
            if !trimmed.isEmpty {
                next.meaning = trimmed
                if !next.sources.contains("周末补全：为什么重要") { next.sources.append("周末补全：为什么重要") }
            }
        }
        return next
    }

    private static func defaultBody(for title: String, media: MediaAnchor?) -> String {
        if let media {
            let medium = media.kind == .video ? "这段视频" : "这张照片"
            return "\(medium) 先把现场钉住了；文字可以以后再补。"
        }
        return title
    }

    private static func matches(_ slice: MemorySlice, tokens: [String]) -> Bool {
        let haystack = ([slice.title, slice.body] + slice.tags + slice.sources).joined(separator: " ")
        return tokens.contains { haystack.contains($0) }
    }

    private static func hasPersonSignal(_ slice: MemorySlice) -> Bool {
        if let people = slice.people, people.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return true
        }
        return matches(slice, tokens: ["我", "自己", "爸爸", "妈妈", "家人", "孩子", "朋友", "同事", "同学", "第一次", "工作"])
    }

    private static func hasMeaningSignal(_ slice: MemorySlice) -> Bool {
        if let meaning = slice.meaning, !meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return matches(slice, tokens: ["想记", "值得", "发现", "第一次", "还是跑完", "算人生", "不想说话", "记一下"])
    }

    private static func tellableScore(_ slice: MemorySlice) -> Int {
        var score = 0
        if slice.hasMediaAnchor { score += 2 }
        if slice.tags.contains("第一次") || slice.tags.contains("成就") { score += 2 }
        if slice.body.count >= 18 { score += 1 }
        if matches(slice, tokens: ["家人", "低落", "工作", "普通但值得", "情绪转弯", "人生补录"]) { score += 2 }
        if slice.sources.count >= 2 { score += 1 }
        return score
    }
}
