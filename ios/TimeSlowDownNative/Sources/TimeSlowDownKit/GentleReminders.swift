import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

public enum GentleReminderKind: String, Codable, Equatable, Sendable {
    case dailyMark
    case weekendCompletion
    case memoryRevisit
}

public struct GentleReminderRequest: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: GentleReminderKind
    public var weekday: Int
    public var hour: Int
    public var minute: Int
    public var title: String
    public var body: String

    public init(
        id: String,
        kind: GentleReminderKind,
        weekday: Int,
        hour: Int,
        minute: Int,
        title: String,
        body: String
    ) {
        self.id = id
        self.kind = kind
        self.weekday = min(max(1, weekday), 7)
        self.hour = min(max(0, hour), 23)
        self.minute = min(max(0, minute), 59)
        self.title = title
        self.body = body
    }
}

public enum GentleReminderSchedule {
    public static let identifierPrefix = "com.raingodprc.timeslowdown.gentle."

    public static func plan(
        preferences: BetaReminderPreferences,
        hasMemories: Bool
    ) -> [GentleReminderRequest] {
        guard preferences.isEnabled,
              preferences.authorization == .granted else { return [] }

        return (1...7).map { weekday in
            let kind: GentleReminderKind
            if weekday == 1, preferences.includesWeekendCompletion {
                kind = .weekendCompletion
            } else if weekday == 4, preferences.includesGentleRevisit, hasMemories {
                kind = .memoryRevisit
            } else {
                kind = .dailyMark
            }
            let copy = copy(for: kind)
            return GentleReminderRequest(
                id: "\(identifierPrefix)weekday-\(weekday)",
                kind: kind,
                weekday: weekday,
                hour: preferences.dailyHour,
                minute: preferences.dailyMinute,
                title: copy.title,
                body: copy.body
            )
        }
    }

    public static var ownedIdentifiers: [String] {
        (1...7).map { "\(identifierPrefix)weekday-\($0)" }
    }

    private static func copy(for kind: GentleReminderKind) -> (title: String, body: String) {
        switch kind {
        case .dailyMark:
            ("今天有一刻，值得留下吗？", "用一分钟占个位。完整不完整，都可以。")
        case .weekendCompletion:
            ("这一周，有哪一刻还想留得更清楚？", "可以补一张照片、一个人，或一句为什么。")
        case .memoryRevisit:
            ("过去的一刻，正在等你认出来", "有空时回望一下；没空，安静略过就好。")
        }
    }
}

#if canImport(UserNotifications)
public enum GentleReminderService {
    public static func currentAuthorization() async -> BetaReminderAuthorization {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return authorization(from: settings.authorizationStatus)
    }

    public static func requestAuthorization() async -> BetaReminderAuthorization {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert])
            return granted ? .granted : .denied
        } catch {
            return .denied
        }
    }

    public static func apply(
        preferences: BetaReminderPreferences,
        hasMemories: Bool
    ) async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(
            withIdentifiers: GentleReminderSchedule.ownedIdentifiers
        )
        guard preferences.isEnabled else { return }
        for reminder in GentleReminderSchedule.plan(
            preferences: preferences,
            hasMemories: hasMemories
        ) {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.interruptionLevel = .passive
            content.sound = nil
            content.badge = nil
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(
                    calendar: Calendar.current,
                    timeZone: TimeZone.current,
                    hour: reminder.hour,
                    minute: reminder.minute,
                    weekday: reminder.weekday
                ),
                repeats: true
            )
            try await center.add(UNNotificationRequest(
                identifier: reminder.id,
                content: content,
                trigger: trigger
            ))
        }
    }

    private static func authorization(
        from status: UNAuthorizationStatus
    ) -> BetaReminderAuthorization {
        switch status {
        case .authorized, .provisional, .ephemeral:
            .granted
        case .denied:
            .denied
        case .notDetermined:
            .unknown
        @unknown default:
            .unknown
        }
    }
}
#endif
