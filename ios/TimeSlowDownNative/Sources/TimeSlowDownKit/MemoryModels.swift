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

    public init(
        id: UUID = UUID(),
        kind: MediaKind,
        label: String,
        note: String = "",
        storage: String = "photos-picker-limited",
        source: String = "user-selected-media"
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.note = note
        self.storage = storage
        self.source = source
    }
}

public struct MemorySlice: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var body: String
    public var tags: [String]
    public var capturedAt: Date
    public var media: MediaAnchor?
    public var sources: [String]

    public init(
        id: UUID = UUID(),
        title: String,
        body: String,
        tags: [String] = [],
        capturedAt: Date = Date(),
        media: MediaAnchor? = nil,
        sources: [String] = []
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.tags = tags
        self.capturedAt = capturedAt
        self.media = media
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

public enum SliceFactory {
    public static func quickMark(
        title: String,
        body: String = "",
        tags: [String] = [],
        media: MediaAnchor? = nil,
        now: Date = Date()
    ) -> MemorySlice {
        var nextTags = tags
        var sources = ["quick-mark"]
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

    private static func defaultBody(for title: String, media: MediaAnchor?) -> String {
        if let media {
            let medium = media.kind == .video ? "这段视频" : "这张照片"
            return "\(medium) 先把现场钉住了；文字可以以后再补。"
        }
        return title
    }
}
