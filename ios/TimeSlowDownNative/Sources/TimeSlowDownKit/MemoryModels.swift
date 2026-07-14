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

public enum ActiveRecallMode: String, Codable, Equatable, Sendable {
    case remembered
    case neededCue

    public var sourceLabel: String {
        switch self {
        case .remembered: "主动回访·主动想起"
        case .neededCue: "主动回访·线索唤回"
        }
    }
}

public enum RecallInteractionOutcome: String, Codable, Equatable, Sendable {
    case revisited
    case skipped
}

public struct RecallInteraction: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var sliceID: UUID
    public var occurredAt: Date
    public var outcome: RecallInteractionOutcome
    public var mode: ActiveRecallMode?
    public var revisitID: UUID?
    public var source: String

    public init(
        id: UUID = UUID(),
        sliceID: UUID,
        occurredAt: Date = Date(),
        outcome: RecallInteractionOutcome,
        mode: ActiveRecallMode? = nil,
        revisitID: UUID? = nil,
        source: String = "今日回望"
    ) {
        self.id = id
        self.sliceID = sliceID
        self.occurredAt = occurredAt
        self.outcome = outcome
        self.mode = mode
        self.revisitID = revisitID
        self.source = source
    }
}

public enum ActiveRecallReason: String, Codable, Equatable, Sendable {
    case firstReturn
    case spacedReturn
    case longUnseen
}

public struct ActiveRecallCandidate: Equatable, Identifiable, Sendable {
    public var id: UUID { slice.id }
    public var slice: MemorySlice
    public var previousRevisitCount: Int
    public var dueAfterDays: Int
    public var daysSinceLastReview: Int
    public var reason: ActiveRecallReason

    public init(
        slice: MemorySlice,
        previousRevisitCount: Int,
        dueAfterDays: Int,
        daysSinceLastReview: Int,
        reason: ActiveRecallReason
    ) {
        self.slice = slice
        self.previousRevisitCount = previousRevisitCount
        self.dueAfterDays = dueAfterDays
        self.daysSinceLastReview = daysSinceLastReview
        self.reason = reason
    }

    public var daysOverdue: Int {
        max(0, daysSinceLastReview - dueAfterDays)
    }
}

public enum ActiveRecallScheduler {
    public static let revisitIntervalsInDays = [1, 3, 7, 30, 90, 180]
    public static let quietSkipCooldownInDays = 7
    public static let maximumInteractionsPerDay = 1

    public static func next(
        from slices: [MemorySlice],
        revisits: [MemoryRevisit],
        interactions: [RecallInteraction],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ActiveRecallCandidate? {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        guard !interactions.contains(where: {
            $0.occurredAt >= startOfToday && $0.occurredAt < startOfTomorrow
        }) else {
            return nil
        }
        let recentSkippedSliceIDs = Set(
            interactions.lazy
                .filter {
                    guard $0.outcome == .skipped else { return false }
                    let cooldownEnds = calendar.date(
                        byAdding: .day,
                        value: quietSkipCooldownInDays,
                        to: $0.occurredAt
                    ) ?? $0.occurredAt
                    return cooldownEnds > now
                }
                .map(\.sliceID)
        )
        let revisitsBySlice = Dictionary(grouping: revisits, by: \.sliceID)

        return slices.compactMap { slice -> ActiveRecallCandidate? in
            guard slice.capturedAt < startOfToday,
                  !recentSkippedSliceIDs.contains(slice.id) else {
                return nil
            }
            let sourceRevisits = revisitsBySlice[slice.id, default: []]
            let revisitCount = sourceRevisits.count
            let dueAfterDays = revisitIntervalsInDays[min(revisitCount, revisitIntervalsInDays.count - 1)]
            let lastReview = sourceRevisits.map(\.revisitedAt).max() ?? slice.capturedAt
            let daysSinceLastReview = max(
                0,
                calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: lastReview),
                    to: startOfToday
                ).day ?? 0
            )
            guard daysSinceLastReview >= dueAfterDays else { return nil }
            let reason: ActiveRecallReason
            if revisitCount == 0 {
                reason = daysSinceLastReview >= 30 ? .longUnseen : .firstReturn
            } else {
                reason = dueAfterDays >= 30 ? .longUnseen : .spacedReturn
            }
            return ActiveRecallCandidate(
                slice: slice,
                previousRevisitCount: revisitCount,
                dueAfterDays: dueAfterDays,
                daysSinceLastReview: daysSinceLastReview,
                reason: reason
            )
        }.sorted(by: isHigherPriority).first
    }

    private static func isHigherPriority(_ lhs: ActiveRecallCandidate, _ rhs: ActiveRecallCandidate) -> Bool {
        let lhsUrgency = lhs.daysSinceLastReview * rhs.dueAfterDays
        let rhsUrgency = rhs.daysSinceLastReview * lhs.dueAfterDays
        if lhsUrgency != rhsUrgency {
            return lhsUrgency > rhsUrgency
        }
        if lhs.previousRevisitCount != rhs.previousRevisitCount {
            return lhs.previousRevisitCount < rhs.previousRevisitCount
        }
        if lhs.daysSinceLastReview != rhs.daysSinceLastReview {
            return lhs.daysSinceLastReview > rhs.daysSinceLastReview
        }
        let lhsStrength = sourceStrength(lhs.slice)
        let rhsStrength = sourceStrength(rhs.slice)
        if lhsStrength != rhsStrength {
            return lhsStrength > rhsStrength
        }
        if lhs.slice.capturedAt != rhs.slice.capturedAt {
            return lhs.slice.capturedAt < rhs.slice.capturedAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func sourceStrength(_ slice: MemorySlice) -> Int {
        var score = 0
        if slice.media != nil { score += 2 }
        if slice.people?.isEmpty == false { score += 1 }
        if slice.meaning?.isEmpty == false { score += 1 }
        if !slice.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 1 }
        if !slice.sources.isEmpty { score += 1 }
        return score
    }
}

public enum LifeMarkKind: String, Codable, CaseIterable, Equatable, Sendable {
    case firstLeaf
    case mediaAnchor
    case timeLayer
    case threeMoments
}

public struct LifeMarkEvidence: Codable, Equatable, Sendable {
    public var sliceIDs: [UUID]
    public var mediaAnchorIDs: [UUID]
    public var revisitIDs: [UUID]

    public init(
        sliceIDs: [UUID] = [],
        mediaAnchorIDs: [UUID] = [],
        revisitIDs: [UUID] = []
    ) {
        self.sliceIDs = sliceIDs
        self.mediaAnchorIDs = mediaAnchorIDs
        self.revisitIDs = revisitIDs
    }
}

public struct LifeMark: Codable, Equatable, Identifiable, Sendable {
    public var kind: LifeMarkKind
    public var unlockedAt: Date
    public var evidence: LifeMarkEvidence

    public var id: String { kind.rawValue }

    public init(kind: LifeMarkKind, unlockedAt: Date, evidence: LifeMarkEvidence) {
        self.kind = kind
        self.unlockedAt = unlockedAt
        self.evidence = evidence
    }
}

public struct LifeMarkEvidenceDetail: Equatable, Sendable {
    public var mark: LifeMark
    public var slices: [MemorySlice]
    public var mediaAnchors: [MediaAnchor]
    public var revisits: [MemoryRevisit]

    public init(
        mark: LifeMark,
        slices: [MemorySlice],
        mediaAnchors: [MediaAnchor],
        revisits: [MemoryRevisit]
    ) {
        self.mark = mark
        self.slices = slices
        self.mediaAnchors = mediaAnchors
        self.revisits = revisits
    }

    public var isComplete: Bool {
        slices.map(\.id) == mark.evidence.sliceIDs &&
        mediaAnchors.map(\.id) == mark.evidence.mediaAnchorIDs &&
        revisits.map(\.id) == mark.evidence.revisitIDs
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

public enum LifeMeadowScale: String, CaseIterable, Codable, Equatable, Sendable {
    case week
    case month
    case year
    case decade

    public var title: String {
        switch self {
        case .week: "周"
        case .month: "月"
        case .year: "年"
        case .decade: "十年"
        }
    }
}

public enum LifeMeadowGrowth: Int, Codable, Equatable, Comparable, Sendable {
    case quiet
    case grass
    case bloom
    case grove

    public static func < (lhs: LifeMeadowGrowth, rhs: LifeMeadowGrowth) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var accessibilityName: String {
        switch self {
        case .quiet: "安静的草地"
        case .grass: "长出青草"
        case .bloom: "长出花朵"
        case .grove: "长成花丛和树林"
        }
    }
}

public struct LifeMeadowPeriod: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var start: Date
    public var end: Date
    public var title: String
    public var subtitle: String
    public var sliceIDs: [UUID]
    public var mediaAnchorCount: Int
    public var revisitCount: Int
    public var growth: LifeMeadowGrowth
    public var prominentSliceID: UUID?

    public init(
        id: String,
        start: Date,
        end: Date,
        title: String,
        subtitle: String,
        sliceIDs: [UUID],
        mediaAnchorCount: Int,
        revisitCount: Int,
        growth: LifeMeadowGrowth,
        prominentSliceID: UUID?
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.title = title
        self.subtitle = subtitle
        self.sliceIDs = sliceIDs
        self.mediaAnchorCount = mediaAnchorCount
        self.revisitCount = revisitCount
        self.growth = growth
        self.prominentSliceID = prominentSliceID
    }

    public var memoryCount: Int { sliceIDs.count }
    public var hasMemories: Bool { !sliceIDs.isEmpty }
}

public struct LifeMeadowSnapshot: Codable, Equatable, Sendable {
    public var scale: LifeMeadowScale
    public var anchorDate: Date
    public var intervalStart: Date
    public var intervalEnd: Date
    public var title: String
    public var periods: [LifeMeadowPeriod]
    public var memoryCount: Int
    public var mediaAnchorCount: Int
    public var revisitCount: Int

    public init(
        scale: LifeMeadowScale,
        anchorDate: Date,
        intervalStart: Date,
        intervalEnd: Date,
        title: String,
        periods: [LifeMeadowPeriod],
        memoryCount: Int,
        mediaAnchorCount: Int,
        revisitCount: Int
    ) {
        self.scale = scale
        self.anchorDate = anchorDate
        self.intervalStart = intervalStart
        self.intervalEnd = intervalEnd
        self.title = title
        self.periods = periods
        self.memoryCount = memoryCount
        self.mediaAnchorCount = mediaAnchorCount
        self.revisitCount = revisitCount
    }

    public var isSourceBacked: Bool {
        memoryCount == periods.reduce(0) { $0 + $1.memoryCount } &&
        mediaAnchorCount == periods.reduce(0) { $0 + $1.mediaAnchorCount } &&
        revisitCount == periods.reduce(0) { $0 + $1.revisitCount }
    }
}

public enum LifeMeadowFactory {
    public static func snapshot(
        from slices: [MemorySlice],
        revisits: [MemoryRevisit],
        scale: LifeMeadowScale,
        anchorDate: Date = Date(),
        calendar: Calendar = .current
    ) -> LifeMeadowSnapshot {
        let interval = displayInterval(for: scale, anchorDate: anchorDate, calendar: calendar)
        let slots = periodIntervals(for: scale, within: interval, calendar: calendar)
        let periods = slots.enumerated().map { index, slot in
            let matchingSlices = slices
                .filter { slot.contains($0.capturedAt) }
                .sorted { $0.capturedAt > $1.capturedAt }
            let sliceIDs = Set(matchingSlices.map(\.id))
            let matchingRevisits = revisits.filter { sliceIDs.contains($0.sliceID) }
            let mediaCount = matchingSlices.filter(\.hasMediaAnchor).count
            let score = matchingSlices.count + mediaCount + matchingRevisits.count
            let prominent = matchingSlices.first(where: \.hasMediaAnchor) ?? matchingSlices.first
            return LifeMeadowPeriod(
                id: "\(scale.rawValue)-\(Int(slot.start.timeIntervalSince1970))-\(index)",
                start: slot.start,
                end: slot.end,
                title: periodTitle(for: scale, date: slot.start, calendar: calendar),
                subtitle: periodSubtitle(for: scale, date: slot.start, calendar: calendar),
                sliceIDs: matchingSlices.map(\.id),
                mediaAnchorCount: mediaCount,
                revisitCount: matchingRevisits.count,
                growth: growth(for: score),
                prominentSliceID: prominent?.id
            )
        }
        return LifeMeadowSnapshot(
            scale: scale,
            anchorDate: anchorDate,
            intervalStart: interval.start,
            intervalEnd: interval.end,
            title: rangeTitle(for: scale, interval: interval, calendar: calendar),
            periods: periods,
            memoryCount: periods.reduce(0) { $0 + $1.memoryCount },
            mediaAnchorCount: periods.reduce(0) { $0 + $1.mediaAnchorCount },
            revisitCount: periods.reduce(0) { $0 + $1.revisitCount }
        )
    }

    public static func shiftedAnchor(
        from anchorDate: Date,
        scale: LifeMeadowScale,
        direction: Int,
        calendar: Calendar = .current
    ) -> Date {
        let delta = direction < 0 ? -1 : 1
        switch scale {
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: delta, to: anchorDate) ?? anchorDate
        case .month:
            return calendar.date(byAdding: .month, value: delta, to: anchorDate) ?? anchorDate
        case .year:
            return calendar.date(byAdding: .year, value: delta, to: anchorDate) ?? anchorDate
        case .decade:
            return calendar.date(byAdding: .year, value: delta * 10, to: anchorDate) ?? anchorDate
        }
    }

    public static func leadingWeekdayPlaceholders(
        for intervalStart: Date,
        calendar: Calendar = .current
    ) -> Int {
        let weekday = calendar.component(.weekday, from: intervalStart)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private static func displayInterval(
        for scale: LifeMeadowScale,
        anchorDate: Date,
        calendar: Calendar
    ) -> DateInterval {
        if scale == .decade {
            let anchorYear = calendar.component(.year, from: anchorDate)
            let firstYear = anchorYear - (anchorYear % 10)
            var components = DateComponents()
            components.calendar = calendar
            components.timeZone = calendar.timeZone
            components.year = firstYear
            components.month = 1
            components.day = 1
            let start = calendar.date(from: components) ?? anchorDate
            let end = calendar.date(byAdding: .year, value: 10, to: start) ?? start
            return DateInterval(start: start, end: end)
        }
        let component: Calendar.Component = switch scale {
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        case .decade: .year
        }
        return calendar.dateInterval(of: component, for: anchorDate) ?? DateInterval(start: anchorDate, duration: 1)
    }

    private static func periodIntervals(
        for scale: LifeMeadowScale,
        within interval: DateInterval,
        calendar: Calendar
    ) -> [DateInterval] {
        let component: Calendar.Component = switch scale {
        case .week, .month: .day
        case .year: .month
        case .decade: .year
        }
        var result: [DateInterval] = []
        var cursor = interval.start
        while cursor < interval.end {
            let next = calendar.date(byAdding: component, value: 1, to: cursor) ?? interval.end
            let end = min(next, interval.end)
            guard cursor < end else { break }
            result.append(DateInterval(start: cursor, end: end))
            cursor = end
        }
        return result
    }

    private static func growth(for score: Int) -> LifeMeadowGrowth {
        switch score {
        case 0: .quiet
        case 1: .grass
        case 2...3: .bloom
        default: .grove
        }
    }

    private static func periodTitle(
        for scale: LifeMeadowScale,
        date: Date,
        calendar: Calendar
    ) -> String {
        let components = calendar.dateComponents([.day, .month, .year], from: date)
        return switch scale {
        case .week, .month: "\(components.day ?? 0)"
        case .year: "\(components.month ?? 0)月"
        case .decade: "\(components.year ?? 0)"
        }
    }

    private static func periodSubtitle(
        for scale: LifeMeadowScale,
        date: Date,
        calendar: Calendar
    ) -> String {
        switch scale {
        case .week:
            let weekday = calendar.component(.weekday, from: date)
            let names = calendar.shortWeekdaySymbols
            return names.indices.contains(weekday - 1) ? names[weekday - 1] : ""
        case .month:
            return ""
        case .year:
            return ""
        case .decade:
            return "年"
        }
    }

    private static func rangeTitle(
        for scale: LifeMeadowScale,
        interval: DateInterval,
        calendar: Calendar
    ) -> String {
        let start = calendar.dateComponents([.day, .month, .year], from: interval.start)
        let inclusiveEnd = calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
        let end = calendar.dateComponents([.day, .month, .year], from: inclusiveEnd)
        switch scale {
        case .week:
            return "\(start.month ?? 0)月\(start.day ?? 0)日 – \(end.month ?? 0)月\(end.day ?? 0)日"
        case .month:
            return "\(start.year ?? 0)年\(start.month ?? 0)月"
        case .year:
            return "\(start.year ?? 0)年"
        case .decade:
            return "\(start.year ?? 0) – \(end.year ?? 0)"
        }
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
