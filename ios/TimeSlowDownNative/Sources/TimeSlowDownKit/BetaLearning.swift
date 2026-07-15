import Foundation

public enum BetaLearningEventKind: String, Codable, CaseIterable, Equatable, Sendable {
    case appOpened = "app_opened"
    case nowOpened = "now_opened"
    case timelineOpened = "timeline_opened"
    case meadowOpened = "meadow_opened"
    case achievementsOpened = "achievements_opened"
    case accountOpened = "account_opened"
    case quickMarkStarted = "quick_mark_started"
    case quickMarkCompleted = "quick_mark_completed"
    case memoryCompleted = "memory_completed"
    case mediaMemoryCompleted = "media_memory_completed"
    case weeklyReviewOpened = "weekly_review_opened"
    case activeRecallOpened = "active_recall_opened"
    case activeRecallCompleted = "active_recall_completed"
    case activeRecallSkipped = "active_recall_skipped"
    case experimentBaselineCompleted = "experiment_baseline_completed"
    case experimentFinalFreeRecallCompleted = "experiment_final_free_recall_completed"
    case experimentTimelineOpened = "experiment_timeline_opened"
    case experimentCompleted = "experiment_completed"
    case reminderAuthorizationChanged = "reminder_authorization_changed"
    case reminderScheduled = "reminder_scheduled"
    case reminderDisabled = "reminder_disabled"
}

public enum BetaLearningDurationBucket: String, Codable, Equatable, Sendable {
    case underThirtySeconds = "under_30_seconds"
    case thirtyToSixtySeconds = "30_to_60_seconds"
    case oneToThreeMinutes = "1_to_3_minutes"
    case threeToFiveMinutes = "3_to_5_minutes"
    case overFiveMinutes = "over_5_minutes"

    public init(seconds: TimeInterval) {
        switch max(0, seconds) {
        case ..<30: self = .underThirtySeconds
        case ..<60: self = .thirtyToSixtySeconds
        case ..<180: self = .oneToThreeMinutes
        case ..<300: self = .threeToFiveMinutes
        default: self = .overFiveMinutes
        }
    }
}

public enum BetaLearningCoarseState: String, Codable, Equatable, Sendable {
    case firstUse = "first_use"
    case returning = "returning"
    case enabled
    case disabled
    case granted
    case denied
    case unknown
}

public struct BetaLearningEvent: Codable, Equatable, Sendable {
    public var kind: BetaLearningEventKind
    public var occurredAt: Date
    public var durationBucket: BetaLearningDurationBucket?
    public var count: Int?
    public var state: BetaLearningCoarseState?

    public init(
        kind: BetaLearningEventKind,
        occurredAt: Date = Date(),
        durationBucket: BetaLearningDurationBucket? = nil,
        count: Int? = nil,
        state: BetaLearningCoarseState? = nil
    ) {
        self.kind = kind
        self.occurredAt = occurredAt
        self.durationBucket = durationBucket
        self.count = count.map { max(0, $0) }
        self.state = state
    }

    public var isPrivacySafe: Bool {
        count.map { $0 >= 0 } ?? true
    }
}

public struct BetaLearningLedger: Codable, Equatable, Sendable {
    public static let maximumEventCount = 2_000

    public private(set) var events: [BetaLearningEvent]

    public init(events: [BetaLearningEvent] = []) {
        self.events = Array(events.filter(\.isPrivacySafe).suffix(Self.maximumEventCount))
    }

    public mutating func append(_ event: BetaLearningEvent) {
        guard event.isPrivacySafe else { return }
        events.append(event)
        if events.count > Self.maximumEventCount {
            events.removeFirst(events.count - Self.maximumEventCount)
        }
    }

    public var isPrivacySafe: Bool { events.allSatisfy(\.isPrivacySafe) }

    public func count(of kind: BetaLearningEventKind) -> Int {
        events.reduce(0) { $0 + ($1.kind == kind ? 1 : 0) }
    }

    public func activeDayCount(
        calendar: Calendar = .current,
        since startDate: Date? = nil
    ) -> Int {
        Set(events.lazy.filter { event in
            guard let startDate else { return true }
            return event.occurredAt >= startDate
        }.map { calendar.startOfDay(for: $0.occurredAt) }).count
    }
}

public struct BetaMemoryAssessment: Codable, Equatable, Sendable {
    public var specificMomentCount: Int
    public var detailScore: Int
    public var blurScore: Int

    public init(specificMomentCount: Int, detailScore: Int, blurScore: Int) {
        self.specificMomentCount = min(max(0, specificMomentCount), 100)
        self.detailScore = min(max(1, detailScore), 5)
        self.blurScore = min(max(1, blurScore), 5)
    }
}

public enum BetaMemoryExperimentPhase: Equatable, Sendable {
    case baseline
    case waiting(daysRemaining: Int)
    case finalFreeRecall
    case timelineAssistedRecall
    case completed
}

public struct BetaMemoryExperiment: Codable, Equatable, Sendable {
    public static let durationDays = 14

    public var startedAt: Date?
    public var baseline: BetaMemoryAssessment?
    public var finalFreeRecall: BetaMemoryAssessment?
    public var didOpenTimelineForFinal: Bool
    public var assistedAdditionalMomentCount: Int?
    public var assistedBlurScore: Int?
    public var completedAt: Date?

    public init(
        startedAt: Date? = nil,
        baseline: BetaMemoryAssessment? = nil,
        finalFreeRecall: BetaMemoryAssessment? = nil,
        didOpenTimelineForFinal: Bool = false,
        assistedAdditionalMomentCount: Int? = nil,
        assistedBlurScore: Int? = nil,
        completedAt: Date? = nil
    ) {
        self.startedAt = startedAt
        self.baseline = baseline
        self.finalFreeRecall = finalFreeRecall
        self.didOpenTimelineForFinal = didOpenTimelineForFinal
        self.assistedAdditionalMomentCount = assistedAdditionalMomentCount.map { min(max(0, $0), 100) }
        self.assistedBlurScore = assistedBlurScore.map { min(max(1, $0), 5) }
        self.completedAt = completedAt
    }

    public func finalDate(calendar: Calendar = .current) -> Date? {
        guard let startedAt else { return nil }
        return calendar.date(byAdding: .day, value: Self.durationDays, to: startedAt)
    }

    public func phase(now: Date = Date(), calendar: Calendar = .current) -> BetaMemoryExperimentPhase {
        guard completedAt == nil else { return .completed }
        guard baseline != nil, let finalDate = finalDate(calendar: calendar) else { return .baseline }
        if now < finalDate {
            let today = calendar.startOfDay(for: now)
            let end = calendar.startOfDay(for: finalDate)
            let remaining = calendar.dateComponents([.day], from: today, to: end).day ?? 1
            return .waiting(daysRemaining: max(1, remaining))
        }
        guard finalFreeRecall != nil else { return .finalFreeRecall }
        guard didOpenTimelineForFinal else { return .timelineAssistedRecall }
        return .timelineAssistedRecall
    }

    public var totalFinalMomentCount: Int? {
        guard let finalFreeRecall, let assistedAdditionalMomentCount else { return nil }
        return finalFreeRecall.specificMomentCount + assistedAdditionalMomentCount
    }
}

public enum BetaReminderAuthorization: String, Codable, Equatable, Sendable {
    case unknown
    case granted
    case denied
}

public struct BetaReminderPreferences: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var dailyHour: Int
    public var dailyMinute: Int
    public var includesWeekendCompletion: Bool
    public var includesGentleRevisit: Bool
    public var authorization: BetaReminderAuthorization

    public init(
        isEnabled: Bool = false,
        dailyHour: Int = 20,
        dailyMinute: Int = 30,
        includesWeekendCompletion: Bool = true,
        includesGentleRevisit: Bool = true,
        authorization: BetaReminderAuthorization = .unknown
    ) {
        self.isEnabled = isEnabled
        self.dailyHour = min(max(0, dailyHour), 23)
        self.dailyMinute = min(max(0, dailyMinute), 59)
        self.includesWeekendCompletion = includesWeekendCompletion
        self.includesGentleRevisit = includesGentleRevisit
        self.authorization = authorization
    }
}

public struct BetaLearningState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public private(set) var ledger: BetaLearningLedger
    public private(set) var experiment: BetaMemoryExperiment
    public private(set) var reminders: BetaReminderPreferences
    public private(set) var revision: UInt64

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        ledger: BetaLearningLedger = BetaLearningLedger(),
        experiment: BetaMemoryExperiment = BetaMemoryExperiment(),
        reminders: BetaReminderPreferences = BetaReminderPreferences(),
        revision: UInt64 = 0
    ) {
        self.schemaVersion = schemaVersion
        self.ledger = ledger
        self.experiment = experiment
        self.reminders = reminders
        self.revision = revision
    }

    public var isPrivacySafe: Bool {
        schemaVersion == Self.currentSchemaVersion && ledger.isPrivacySafe
    }

    public mutating func record(_ event: BetaLearningEvent) {
        ledger.append(event)
        revision &+= 1
    }

    public mutating func completeBaseline(
        _ assessment: BetaMemoryAssessment,
        now: Date = Date()
    ) {
        guard experiment.baseline == nil else { return }
        experiment.startedAt = now
        experiment.baseline = assessment
        record(BetaLearningEvent(kind: .experimentBaselineCompleted, occurredAt: now))
    }

    public mutating func completeFinalFreeRecall(
        _ assessment: BetaMemoryAssessment,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        guard case .finalFreeRecall = experiment.phase(now: now, calendar: calendar) else { return }
        experiment.finalFreeRecall = assessment
        record(BetaLearningEvent(kind: .experimentFinalFreeRecallCompleted, occurredAt: now))
    }

    public mutating func markFinalTimelineOpened(now: Date = Date()) {
        guard experiment.finalFreeRecall != nil else { return }
        experiment.didOpenTimelineForFinal = true
        record(BetaLearningEvent(kind: .experimentTimelineOpened, occurredAt: now))
    }

    public mutating func completeExperiment(
        assistedAdditionalMomentCount: Int,
        assistedBlurScore: Int,
        now: Date = Date()
    ) {
        guard experiment.finalFreeRecall != nil,
              experiment.didOpenTimelineForFinal,
              experiment.completedAt == nil else { return }
        experiment.assistedAdditionalMomentCount = min(max(0, assistedAdditionalMomentCount), 100)
        experiment.assistedBlurScore = min(max(1, assistedBlurScore), 5)
        experiment.completedAt = now
        record(BetaLearningEvent(
            kind: .experimentCompleted,
            occurredAt: now,
            count: experiment.totalFinalMomentCount
        ))
    }

    public mutating func updateReminders(
        _ preferences: BetaReminderPreferences,
        now: Date = Date(),
        recordEvent: Bool = true
    ) {
        guard reminders != preferences else { return }
        let old = reminders
        reminders = preferences
        revision &+= 1
        guard recordEvent else { return }
        if old.authorization != preferences.authorization {
            record(BetaLearningEvent(
                kind: .reminderAuthorizationChanged,
                occurredAt: now,
                state: preferences.authorization.coarseState
            ))
        }
        if old.isEnabled != preferences.isEnabled {
            record(BetaLearningEvent(
                kind: preferences.isEnabled ? .reminderScheduled : .reminderDisabled,
                occurredAt: now,
                state: preferences.isEnabled ? .enabled : .disabled
            ))
        }
    }
}

private extension BetaReminderAuthorization {
    var coarseState: BetaLearningCoarseState {
        switch self {
        case .unknown: .unknown
        case .granted: .granted
        case .denied: .denied
        }
    }
}

public struct BetaLearningEnvelope: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var state: BetaLearningState

    public init(
        schemaVersion: Int = BetaLearningState.currentSchemaVersion,
        createdAt: Date,
        updatedAt: Date,
        state: BetaLearningState
    ) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.state = state
    }
}

public enum BetaLearningPersistenceError: Error, Equatable, Sendable {
    case unsupportedSchema(Int)
    case privacyBoundaryViolation
}

public enum BetaLearningPersistence {
    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("TimeSlowDown", isDirectory: true)
            .appendingPathComponent("beta-learning-v1.json", isDirectory: false)
    }

    public static func load(from url: URL = defaultURL) throws -> BetaLearningState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let envelope = try JSONDecoder.tsdBetaLearning.decode(
            BetaLearningEnvelope.self,
            from: Data(contentsOf: url)
        )
        guard envelope.schemaVersion <= BetaLearningState.currentSchemaVersion else {
            throw BetaLearningPersistenceError.unsupportedSchema(envelope.schemaVersion)
        }
        guard envelope.state.isPrivacySafe else {
            throw BetaLearningPersistenceError.privacyBoundaryViolation
        }
        return envelope.state
    }

    public static func save(
        _ state: BetaLearningState,
        to url: URL = defaultURL,
        now: Date = Date()
    ) throws {
        guard state.isPrivacySafe else {
            throw BetaLearningPersistenceError.privacyBoundaryViolation
        }
        let existingCreatedAt: Date
        if let data = try? Data(contentsOf: url),
           let existing = try? JSONDecoder.tsdBetaLearning.decode(BetaLearningEnvelope.self, from: data) {
            guard existing.schemaVersion <= BetaLearningState.currentSchemaVersion else {
                throw BetaLearningPersistenceError.unsupportedSchema(existing.schemaVersion)
            }
            existingCreatedAt = existing.createdAt
        } else {
            existingCreatedAt = now
        }
        let envelope = BetaLearningEnvelope(
            createdAt: existingCreatedAt,
            updatedAt: now,
            state: state
        )
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder.tsdBetaLearning.encode(envelope).write(to: url, options: .atomic)
    }
}

public actor BetaLearningPersistenceCoordinator {
    public let url: URL
    public private(set) var latestRequestedRevision: UInt64 = 0
    public private(set) var latestCommittedRevision: UInt64 = 0

    public init(url: URL) {
        self.url = url
    }

    public func saveDebounced(
        _ state: BetaLearningState,
        delayNanoseconds: UInt64 = 200_000_000
    ) async throws {
        latestRequestedRevision &+= 1
        let revision = latestRequestedRevision
        try await Task.sleep(nanoseconds: delayNanoseconds)
        try Task.checkCancellation()
        guard revision == latestRequestedRevision else { throw CancellationError() }
        try BetaLearningPersistence.save(state, to: url)
        latestCommittedRevision = revision
    }
}

private extension JSONEncoder {
    static var tsdBetaLearning: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var tsdBetaLearning: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
