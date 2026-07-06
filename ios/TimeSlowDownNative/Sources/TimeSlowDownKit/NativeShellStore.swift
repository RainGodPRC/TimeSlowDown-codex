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
        case .launch: "上架"
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

    public init(
        routeCount: Int,
        sliceCount: Int,
        mediaAnchorCount: Int,
        nativeTodoCount: Int,
        submissionTodoCount: Int,
        privacySafe: Bool
    ) {
        self.routeCount = routeCount
        self.sliceCount = sliceCount
        self.mediaAnchorCount = mediaAnchorCount
        self.nativeTodoCount = nativeTodoCount
        self.submissionTodoCount = submissionTodoCount
        self.privacySafe = privacySafe
    }
}

public struct NativeShellStore: Codable, Equatable, Sendable {
    public var selectedRoute: NativeShellRoute
    public var slices: [MemorySlice]
    public var privacyBoundary: PrivacyBoundary

    public init(
        selectedRoute: NativeShellRoute = .now,
        slices: [MemorySlice] = [],
        privacyBoundary: PrivacyBoundary = PrivacyBoundary()
    ) {
        self.selectedRoute = selectedRoute
        self.slices = slices
        self.privacyBoundary = privacyBoundary
    }

    public static func seeded(now: Date = Date()) -> NativeShellStore {
        NativeShellStore(
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
                    now: now
                ),
                SliceFactory.quickMark(
                    title: "会议后的回家路",
                    body: "有点低落，也算这一周的一部分。",
                    tags: ["工作", "低落"],
                    now: now
                )
            ]
        )
    }

    public var snapshot: NativeShellSnapshot {
        NativeShellSnapshot(
            routeCount: NativeShellRoute.allCases.count,
            sliceCount: slices.count,
            mediaAnchorCount: slices.filter(\.hasMediaAnchor).count,
            nativeTodoCount: NativeHandoffLedger.rows.filter { $0.status == .todo }.count,
            submissionTodoCount: SubmissionPacket.rows.filter { $0.status == .todo }.count,
            privacySafe: privacyBoundary.isAppStoreSafeDefault
        )
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

    public func weeklyPreviewTitle() -> String {
        let chapter = SliceFactory.compileWeeklyChapter(title: "本周没有消失", claimed: Array(slices.prefix(3)))
        return chapter.title
    }
}
