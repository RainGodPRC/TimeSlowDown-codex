#if canImport(SwiftUI)
import SwiftUI
import UniformTypeIdentifiers
#if canImport(ImageIO)
import ImageIO
#endif

@available(iOS 17.0, macOS 14.0, *)
public struct TSDExportZIPDocument: FileDocument, Equatable {
    public static let exportedContentType = UTType(filenameExtension: "zip") ?? .data
    public static let exportedFilenameExtension = "zip"
    public static var readableContentTypes: [UTType] { [exportedContentType] }

    public var fileName: String
    public var data: Data
    public var entryCount: Int
    public var isMemoryRightsSafe: Bool

    public init(package: ExportZIPPackage) {
        self.fileName = package.fileName
        self.data = package.data
        self.entryCount = package.entries.count
        self.isMemoryRightsSafe = package.isMemorySafeDefault
    }

    public init(configuration: ReadConfiguration) throws {
        self.fileName = "imported-timeslowdown-export.zip"
        self.data = configuration.file.regularFileContents ?? Data()
        self.entryCount = 0
        self.isMemoryRightsSafe = false
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    public var byteCount: Int { data.count }

    public var isReadyForSystemExporter: Bool {
        fileName.hasSuffix(".\(Self.exportedFilenameExtension)") &&
        byteCount > 22 &&
        entryCount >= 5 &&
        isMemoryRightsSafe
    }
}

@available(iOS 17.0, macOS 14.0, *)
public struct TSDNativeShellView: View {
    @State private var store: NativeShellStore
    @State private var persistenceMessage: String?
    @State private var persistenceEnabled: Bool
    @Environment(\.scenePhase) private var scenePhase
    private let persistenceCoordinator: NativeShellPersistenceCoordinator?

    public init(
        store: NativeShellStore? = nil,
        persistenceURL: URL? = NativeShellPersistence.defaultURL
    ) {
        var resolvedStore = store ?? NativeShellStore()
        var message: String?
        var canPersist = persistenceURL != nil
        if store == nil, let persistenceURL {
            do {
                let result = try NativeShellPersistence.loadRecovering(from: persistenceURL)
                resolvedStore = result.store
                if case .recoveredCorruptBackup(let fileName) = result.source {
                    message = "旧数据无法读取，已安全保留为 \(fileName)。新记录不会覆盖它。"
                }
            } catch {
                message = "本地记忆暂时无法读取。为保护数据，本次启动不会覆盖原文件。"
                canPersist = false
            }
        }
        self._store = State(initialValue: resolvedStore)
        self._persistenceMessage = State(initialValue: message)
        self._persistenceEnabled = State(initialValue: canPersist)
        self.persistenceCoordinator = persistenceURL.map(NativeShellPersistenceCoordinator.init(url:))
    }

    public var body: some View {
        TabView(selection: $store.selectedRoute) {
            NativeNowView(store: $store)
                .tabItem { Label(NativeShellRoute.now.title, systemImage: "sparkles") }
                .tag(NativeShellRoute.now)

            NativeSliceListView(store: $store)
                .tabItem { Label(NativeShellRoute.slices.title, systemImage: "circle.grid.2x2") }
                .tag(NativeShellRoute.slices)

            NativeMeadowView(store: $store)
                .tabItem { Label(NativeShellRoute.meadow.title, systemImage: "leaf") }
                .tag(NativeShellRoute.meadow)

            NativeAchievementView(store: $store)
                .tabItem { Label(NativeShellRoute.launch.title, systemImage: "seal") }
                .tag(NativeShellRoute.launch)

            NativeAccountView(store: $store)
                .tabItem { Label(NativeShellRoute.account.title, systemImage: "person.crop.circle") }
                .tag(NativeShellRoute.account)
        }
        .tint(TSDPalette.moss)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let persistenceMessage {
                NativePersistenceBanner(message: persistenceMessage) {
                    self.persistenceMessage = nil
                }
            }
        }
        .task(id: store) {
            guard persistenceEnabled, let persistenceCoordinator else { return }
            let snapshot = store
            do {
                try await persistenceCoordinator.saveDebounced(snapshot)
            } catch is CancellationError {
                return
            } catch {
                persistenceMessage = "这次改动尚未保存到本机，请稍后重试。"
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active,
                  persistenceEnabled,
                  let persistenceCoordinator else { return }
            let snapshot = store
            Task {
                do {
                    try await persistenceCoordinator.flush(snapshot)
                } catch {
                    persistenceMessage = "进入后台前未能保存最后一次改动，请重新打开确认。"
                }
            }
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativePersistenceBanner: View {
    var message: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .foregroundStyle(TSDPalette.amber)
            Text(message)
                .font(.caption)
                .foregroundStyle(TSDPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭提示")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(TSDPalette.paper)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.45)
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeNowView: View {
    @Binding var store: NativeShellStore
    @State private var activeSheet: NativeNowSheet?
    @State private var mediaIssue: String?

    private var echo: YesterdayEcho? {
        SliceFactory.yesterdayEcho(from: store.slices, revisits: store.revisits)
    }

    private var weeklyProgress: WeeklyStoryProgress {
        SliceFactory.weeklyStoryProgress(
            from: store.slices,
            claimedSliceIDs: Array(store.slices.prefix(3)).map(\.id)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TSDPalette.canvas.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        NativeNowHeader()

                        NativeMemoryCameraCard(
                            onPicked: { selection in
                                do {
                                    let anchor = try NativeMediaThumbnailStore.persist(selection)
                                    _ = store.captureFromMemoryCamera(anchor)
                                    mediaIssue = nil
                                } catch {
                                    mediaIssue = "影像没有安全保存，请重新选择。"
                                }
                            },
                            onWrite: { activeSheet = .quickMark },
                            mediaIssue: mediaIssue
                        )

                        if store.slices.isEmpty {
                            NativeFirstMemoryCard()
                        } else {
                            if let echo {
                                NativeYesterdayEchoCard(
                                    echo: echo,
                                    latestRevisit: store.revisits
                                        .filter { $0.sliceID == echo.sliceID }
                                        .sorted { $0.revisitedAt > $1.revisitedAt }
                                        .first,
                                    onRevisit: { activeSheet = .revisit }
                                )
                            }

                            NativeWeeklyStoryCard(
                                progress: weeklyProgress,
                                onOpen: { activeSheet = .weekend }
                            )
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield")
                            Text("原始影像留在你的照片图库；TSD 只保存记忆线索。")
                        }
                        .font(.caption)
                        .foregroundStyle(TSDPalette.inkSoft)
                        .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .tsdHideNavigationChrome()
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .quickMark:
                    NativeQuickMarkComposer(store: $store)
                case .revisit:
                    if let echo {
                        NativeRevisitComposer(store: $store, echo: echo)
                    }
                case .weekend:
                    NativeWeekendWorkbench(store: $store)
                }
            }
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeFirstMemoryCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(TSDPalette.sage.opacity(0.28))
                Image(systemName: "leaf")
                    .font(.title2)
                    .foregroundStyle(TSDPalette.moss)
            }
            .frame(width: 58, height: 58)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text("你的旷野还很安静")
                    .font(.headline)
                    .foregroundStyle(TSDPalette.ink)
                Text("留下第一刻后，这里会开始长出回声和故事。")
                    .font(.subheadline)
                    .foregroundStyle(TSDPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TSDPalette.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private extension View {
    @ViewBuilder
    func tsdHideNavigationChrome() -> some View {
#if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
#else
        self
#endif
    }
}

private enum NativeNowSheet: String, Identifiable {
    case quickMark
    case revisit
    case weekend

    var id: String { rawValue }
}

private enum TSDPalette {
    static let canvas = Color(red: 0.96, green: 0.95, blue: 0.91)
    static let paper = Color(red: 1.00, green: 0.99, blue: 0.96)
    static let moss = Color(red: 0.19, green: 0.36, blue: 0.25)
    static let mossDeep = Color(red: 0.11, green: 0.25, blue: 0.17)
    static let sage = Color(red: 0.72, green: 0.79, blue: 0.66)
    static let amber = Color(red: 0.82, green: 0.57, blue: 0.27)
    static let rose = Color(red: 0.72, green: 0.39, blue: 0.36)
    static let ink = Color(red: 0.12, green: 0.15, blue: 0.12)
    static let inkSoft = Color(red: 0.34, green: 0.38, blue: 0.33)
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeNowHeader: View {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 · EEEE"
        return formatter
    }()

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text(Self.formatter.string(from: Date()))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TSDPalette.moss)
                Text("把今天留在这里")
                    .font(.title.bold())
                    .foregroundStyle(TSDPalette.ink)
            }
            Spacer()
            ZStack {
                Circle().fill(TSDPalette.sage.opacity(0.38))
                Image(systemName: "leaf.fill")
                    .foregroundStyle(TSDPalette.moss)
            }
            .frame(width: 46, height: 46)
            .accessibilityHidden(true)
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeMemoryCameraCard: View {
    var onPicked: (MemoryCameraSelection) -> Void
    var onWrite: () -> Void
    var mediaIssue: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [TSDPalette.mossDeep, TSDPalette.moss, Color(red: 0.35, green: 0.48, blue: 0.31)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 170, height: 170)
                .offset(x: 58, y: -72)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 14) {
                Label("MEMORY CAMERA", systemImage: "viewfinder")
                    .font(.caption2.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.72))

                Text("今天，哪一刻\n不想弄丢？")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("先留画面，文字可以以后再补。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))

                MemoryCameraPicker(onPicked: onPicked)

                if let mediaIssue {
                    Label(mediaIssue, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.84))
                }

                Button(action: onWrite) {
                    Label("只写一句", systemImage: "square.and.pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .shadow(color: TSDPalette.mossDeep.opacity(0.16), radius: 22, y: 10)
        .accessibilityElement(children: .contain)
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeYesterdayEchoCard: View {
    var echo: YesterdayEcho
    var latestRevisit: MemoryRevisit?
    var onRevisit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("昨日回声", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundStyle(TSDPalette.ink)
                Spacer()
                if echo.previousRevisitCount > 0 {
                    Text("已回望 (echo.previousRevisitCount) 次")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(TSDPalette.moss)
                }
            }

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(TSDPalette.sage.opacity(0.30))
                    Image(systemName: echo.media == nil ? "text.quote" : (echo.media?.kind == .video ? "video.fill" : "photo.fill"))
                        .foregroundStyle(TSDPalette.moss)
                }
                .frame(width: 58, height: 58)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(echo.title)
                        .font(.headline)
                        .foregroundStyle(TSDPalette.ink)
                        .lineLimit(1)
                    Text(echo.body)
                        .font(.subheadline)
                        .foregroundStyle(TSDPalette.inkSoft)
                        .lineLimit(2)
                }
            }

            if let latestRevisit, !latestRevisit.reflection.isEmpty {
                Text("“\(latestRevisit.reflection)”")
                    .font(.subheadline.italic())
                    .foregroundStyle(TSDPalette.moss)
                    .padding(.leading, 8)
                    .overlay(alignment: .leading) {
                        Capsule().fill(TSDPalette.amber).frame(width: 3)
                    }
            }

            Button(action: onRevisit) {
                HStack {
                    Text("现在再看")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TSDPalette.moss)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(TSDPalette.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(TSDPalette.moss.opacity(0.08))
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeWeeklyStoryCard: View {
    var progress: WeeklyStoryProgress
    var onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("本周故事")
                        .font(.headline)
                        .foregroundStyle(TSDPalette.ink)
                    Text(progress.readyCount == progress.target ? "已经可以讲起这一周" : "让三个瞬间慢慢长成故事")
                        .font(.caption)
                        .foregroundStyle(TSDPalette.inkSoft)
                }
                Spacer()
                Text("\(progress.readyCount)/\(progress.target)")
                    .font(.title3.bold())
                    .foregroundStyle(TSDPalette.moss)
                    .accessibilityLabel("三个瞬间中已有 \(progress.readyCount) 个可以讲述")
            }

            ProgressView(value: Double(progress.completeFieldCount), total: Double(max(1, progress.totalFieldCount)))
                .tint(TSDPalette.moss)

            HStack(spacing: 8) {
                ForEach(progress.candidates) { candidate in
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: candidate.isReady ? "checkmark.circle.fill" : "circle.dotted")
                            .foregroundStyle(candidate.isReady ? TSDPalette.moss : TSDPalette.amber)
                        Text(candidate.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TSDPalette.ink)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
                    .padding(10)
                    .background(TSDPalette.canvas.opacity(0.74), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
            }

            Button(action: onOpen) {
                HStack {
                    Text(progress.readyCount == progress.target ? "查看本周章节" : "周末补一小步")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TSDPalette.moss)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(TSDPalette.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeQuickMarkComposer: View {
    @Binding var store: NativeShellStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("先占住这个瞬间") {
                    TextField("发生了什么？", text: $title)
                    TextField("想多留一句也可以（可选）", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section {
                    Text("不必完整。周末再补照片、人物或为什么值得记。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("快速记一下")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("留下") {
                        if store.captureQuickMark(title: title, body: note) != nil { dismiss() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeRevisitComposer: View {
    @Binding var store: NativeShellStore
    var echo: YesterdayEcho
    @Environment(\.dismiss) private var dismiss
    @State private var reflection = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(echo.title)
                    .font(.title2.bold())
                    .foregroundStyle(TSDPalette.ink)
                Text(echo.body)
                    .foregroundStyle(TSDPalette.inkSoft)
                TextField(echo.prompt, text: $reflection, axis: .vertical)
                    .lineLimit(3...7)
                    .padding(14)
                    .background(TSDPalette.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text("新的感受会叠在原记忆上，不会改写当时的你。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(20)
            .background(TSDPalette.canvas.ignoresSafeArea())
            .navigationTitle("现在再看")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("叠进记忆") {
                        if store.revisitYesterdayEcho(reflection: reflection) != nil { dismiss() }
                    }
                    .disabled(reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeWeekendWorkbench: View {
    @Binding var store: NativeShellStore
    @Environment(\.dismiss) private var dismiss
    @State private var value = ""
    @State private var mediaMessage: String?

    private var progress: WeeklyStoryProgress {
        SliceFactory.weeklyStoryProgress(
            from: store.slices,
            claimedSliceIDs: Array(store.slices.prefix(3)).map(\.id)
        )
    }

    private var nextGap: (WeeklyStoryCandidate, WeeklyStoryGapKind)? {
        guard let candidate = progress.candidates.first(where: { !$0.missing.isEmpty }),
              let gap = candidate.missing.first else { return nil }
        return (candidate, gap)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(progress.readyCount)/\(progress.target) 个瞬间可以讲起")
                            .font(.headline)
                        Text("一次只补一个线索，不补也不会失去什么。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(progress.percent)%")
                        .font(.title2.bold())
                        .foregroundStyle(TSDPalette.moss)
                }

                ProgressView(value: Double(progress.completeFieldCount), total: Double(max(1, progress.totalFieldCount)))
                    .tint(TSDPalette.moss)

                if let (candidate, gap) = nextGap {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(candidate.title)
                            .font(.title3.bold())
                            .foregroundStyle(TSDPalette.ink)
                        Label("补\(gap.title)", systemImage: icon(for: gap))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(TSDPalette.moss)

                        if gap == .media {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(TSDPalette.moss)
                                MemoryCameraPicker { selection in
                                    do {
                                        let anchor = try NativeMediaThumbnailStore.persist(selection)
                                        _ = store.completeWeekendGap(
                                            sliceID: candidate.sliceID,
                                            kind: .media,
                                            media: anchor
                                        )
                                        mediaMessage = nil
                                    } catch {
                                        mediaMessage = "影像没有安全保存，请重新选择。"
                                    }
                                }
                                .padding(12)
                            }
                            if let mediaMessage {
                                Label(mediaMessage, systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(TSDPalette.amber)
                            }
                        } else {
                            TextField(prompt(for: gap), text: $value, axis: .vertical)
                                .lineLimit(2...5)
                                .padding(14)
                                .background(TSDPalette.canvas, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                            Button("补进这个瞬间") {
                                if store.completeWeekendGap(sliceID: candidate.sliceID, kind: gap, value: value) {
                                    value = ""
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(TSDPalette.moss)
                            .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(18)
                    .background(TSDPalette.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.title)
                            .foregroundStyle(TSDPalette.amber)
                        Text("这一周已经长出故事了")
                            .font(.title2.bold())
                        Text("影像、人物和意义都在。现在可以慢慢读回这一周。")
                            .foregroundStyle(.secondary)
                        Button("完成") { dismiss() }
                            .buttonStyle(.borderedProminent)
                            .tint(TSDPalette.moss)
                    }
                }
                Spacer()
            }
            .padding(20)
            .background(TSDPalette.canvas.ignoresSafeArea())
            .navigationTitle("周末补全")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func icon(for gap: WeeklyStoryGapKind) -> String {
        switch gap {
        case .media: "photo"
        case .people: "person.2"
        case .meaning: "quote.bubble"
        }
    }

    private func prompt(for gap: WeeklyStoryGapKind) -> String {
        switch gap {
        case .media: ""
        case .people: "当时和谁在一起？"
        case .meaning: "为什么还想记得它？"
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeSliceListView: View {
    @Binding var store: NativeShellStore
    @State private var pendingDeletion: NativePendingSliceDeletion?

    var body: some View {
        NavigationStack {
            Group {
                if store.slices.isEmpty {
                    NativeEmptyDestination(
                        symbol: "square.stack.3d.up",
                        title: "还没有切片",
                        note: "照片或一句话，都可以成为第一张。",
                        actionTitle: "去留下第一刻"
                    ) {
                        store.selectedRoute = .now
                    }
                } else {
                    List(store.slices) { slice in
                        NavigationLink {
                            NativeSliceDetailView(store: $store, sliceID: slice.id) {
                                delete(sliceID: slice.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                if let media = slice.media {
                                    NativeMediaPreview(media: media, height: 72, cornerRadius: 14)
                                        .frame(width: 72)
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(slice.title).font(.headline)
                                    Text(slice.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                                    if let media = slice.media {
                                        Label(media.label, systemImage: media.kind == .video ? "video" : "photo")
                                            .font(.caption.weight(.semibold))
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                delete(sliceID: slice.id)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(TSDPalette.canvas)
                }
            }
            .navigationTitle("切片")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let pendingDeletion {
                    HStack(spacing: 12) {
                        Text("已删除“\(pendingDeletion.deleted.slice.title)”")
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Button("撤销") { undo(pendingDeletion) }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(TSDPalette.moss)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .background(TSDPalette.paper)
                    .overlay(alignment: .top) { Divider() }
                }
            }
            .task(id: pendingDeletion?.deleted.slice.id) {
                guard let deletionID = pendingDeletion?.deleted.slice.id else { return }
                do {
                    try await Task.sleep(nanoseconds: 8_000_000_000)
                    if pendingDeletion?.deleted.slice.id == deletionID {
                        pendingDeletion = nil
                    }
                } catch {
                    return
                }
            }
        }
    }

    private func delete(sliceID: UUID) {
        guard let deleted = store.deleteSlice(id: sliceID) else { return }
        let thumbnailData = deleted.slice.media?.thumbnailFileName.flatMap {
            NativeMediaThumbnailStore.data(fileName: $0)
        }
        if let fileName = deleted.slice.media?.thumbnailFileName {
            try? NativeMediaThumbnailStore.remove(fileName: fileName)
        }
        pendingDeletion = NativePendingSliceDeletion(deleted: deleted, thumbnailData: thumbnailData)
    }

    private func undo(_ pending: NativePendingSliceDeletion) {
        var deleted = pending.deleted
        if let media = deleted.slice.media {
            deleted.slice.media = NativeMediaThumbnailStore.restoreAfterUndo(
                media,
                thumbnailData: pending.thumbnailData
            )
        }
        _ = store.restoreDeletedSlice(deleted)
        pendingDeletion = nil
    }
}

private struct NativePendingSliceDeletion: Equatable {
    var deleted: NativeDeletedMemorySlice
    var thumbnailData: Data?
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeSliceDetailView: View {
    @Binding var store: NativeShellStore
    var sliceID: UUID
    var onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var bodyText: String
    @State private var peopleText: String
    @State private var meaning: String
    @State private var mediaMessage: String?

    init(store: Binding<NativeShellStore>, sliceID: UUID, onDelete: @escaping () -> Void) {
        self._store = store
        self.sliceID = sliceID
        self.onDelete = onDelete
        let slice = store.wrappedValue.slices.first(where: { $0.id == sliceID })
        self._title = State(initialValue: slice?.title ?? "")
        self._bodyText = State(initialValue: slice?.body ?? "")
        self._peopleText = State(initialValue: slice?.people?.joined(separator: "，") ?? "")
        self._meaning = State(initialValue: slice?.meaning ?? "")
        self._mediaMessage = State(initialValue: nil)
    }

    private var slice: MemorySlice? {
        store.slices.first(where: { $0.id == sliceID })
    }

    var body: some View {
        ZStack {
            TSDPalette.canvas.ignoresSafeArea()
            if let slice {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let media = slice.media {
                            NativeMediaPreview(media: media, height: 220, cornerRadius: 24)
                            if let issue = media.thumbnailIssue {
                                Label(issue, systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(TSDPalette.amber)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            TextField("这一刻叫什么？", text: $title)
                                .font(.title2.bold())
                            TextField("发生了什么？", text: $bodyText, axis: .vertical)
                                .lineLimit(3...8)
                            Divider()
                            TextField("当时和谁在一起？", text: $peopleText)
                            TextField("为什么还想记得它？", text: $meaning, axis: .vertical)
                                .lineLimit(2...5)
                        }
                        .padding(18)
                        .background(TSDPalette.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                        VStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(TSDPalette.moss)
                                MemoryCameraPicker { selection in
                                    replaceMedia(with: selection)
                                }
                                .padding(12)
                            }
                            if slice.media != nil {
                                Button(role: .destructive) {
                                    removeMedia()
                                } label: {
                                    Label("移除当前影像", systemImage: "photo.badge.minus")
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(.plain)
                            }
                            if let mediaMessage {
                                Text(mediaMessage)
                                    .font(.caption)
                                    .foregroundStyle(TSDPalette.amber)
                            }
                        }

                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Label("删除这张切片", systemImage: "trash")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(18)
                    .padding(.bottom, 24)
                }
            } else {
                NativeEmptyDestination(
                    symbol: "questionmark.folder",
                    title: "这张切片已不在这里",
                    note: "它可能刚刚被删除或移动。",
                    actionTitle: "返回切片"
                ) { dismiss() }
            }
        }
        .navigationTitle("记忆切片")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    _ = store.updateSlice(
                        id: sliceID,
                        title: title,
                        body: bodyText,
                        peopleText: peopleText,
                        meaning: meaning
                    )
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func replaceMedia(with selection: MemoryCameraSelection) {
        mediaMessage = nil
        let media: MediaAnchor
        do {
            media = try NativeMediaThumbnailStore.persist(selection)
        } catch {
            mediaMessage = "影像没有安全保存，当前影像保持不变。"
            return
        }
        if let currentFileName = slice?.media?.thumbnailFileName {
            try? NativeMediaThumbnailStore.remove(fileName: currentFileName)
        }
        _ = store.attachMedia(media, to: sliceID)
    }

    private func removeMedia() {
        guard let media = store.detachMedia(from: sliceID) else { return }
        if let fileName = media.thumbnailFileName {
            try? NativeMediaThumbnailStore.remove(fileName: fileName)
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeMediaPreview: View {
    var media: MediaAnchor
    var height: CGFloat
    var cornerRadius: CGFloat
    @State private var thumbnailData: Data?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(TSDPalette.sage.opacity(0.24))
            if let image = decodedImage {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: 7) {
                    Image(systemName: placeholderSymbol)
                        .font(.title2)
                        .foregroundStyle(TSDPalette.moss)
                    if media.thumbnailFileName != nil {
                        Text(height > 100 ? "影像需重新选择" : "需重选")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(TSDPalette.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .padding(8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: media.thumbnailFileName) {
            thumbnailData = media.thumbnailFileName.flatMap {
                NativeMediaThumbnailStore.data(fileName: $0)
            }
        }
        .accessibilityLabel(media.kind == .video ? "记忆视频" : "记忆照片")
    }

    private var placeholderSymbol: String {
        if media.thumbnailFileName != nil { return "photo.badge.exclamationmark" }
        return media.kind == .video ? "video.fill" : "photo.fill"
    }

    private var decodedImage: CGImage? {
#if canImport(ImageIO)
        guard let thumbnailData,
              let source = CGImageSourceCreateWithData(thumbnailData as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
#else
        return nil
#endif
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeMeadowView: View {
    @Binding var store: NativeShellStore

    var body: some View {
        NavigationStack {
            Group {
                if store.slices.isEmpty {
                    NativeEmptyDestination(
                        symbol: "leaf.circle",
                        title: "旷野还没发芽",
                        note: "第一张切片留下后，这里才开始生长。",
                        actionTitle: "回到此刻"
                    ) {
                        store.selectedRoute = .now
                    }
                } else {
                    ZStack {
                        TSDPalette.canvas.ignoresSafeArea()
                        VStack(alignment: .leading, spacing: 16) {
                            Text("人生旷野")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(TSDPalette.ink)
                            Text("这一周有 \(store.slices.count) 张切片，\(store.snapshot.mediaAnchorCount) 个影像锚点。")
                            Text("章节预览：\(store.weeklyPreviewTitle())")
                                .foregroundStyle(TSDPalette.inkSoft)
                            Spacer()
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("旷野")
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeEmptyDestination: View {
    var symbol: String
    var title: String
    var note: String
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        ZStack {
            TSDPalette.canvas.ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(TSDPalette.sage.opacity(0.30))
                    Image(systemName: symbol)
                        .font(.largeTitle)
                        .foregroundStyle(TSDPalette.moss)
                }
                .frame(width: 88, height: 88)
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(TSDPalette.ink)
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(TSDPalette.inkSoft)
                    .multilineTextAlignment(.center)
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(TSDPalette.moss)
                    .controlSize(.large)
            }
            .padding(28)
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAchievementView: View {
    @Binding var store: NativeShellStore

    private var unlocked: [NativeAchievement] {
        var items: [NativeAchievement] = []
        if !store.slices.isEmpty {
            items.append(.init(id: "first-leaf", title: "第一片叶", note: "留下第一个瞬间", symbol: "leaf.fill", color: TSDPalette.moss))
        }
        if store.slices.contains(where: \.hasMediaAnchor) {
            items.append(.init(id: "media-anchor", title: "现场还在", note: "为记忆留下影像锚点", symbol: "photo.fill", color: TSDPalette.amber))
        }
        if !store.revisits.isEmpty {
            items.append(.init(id: "time-layer", title: "时间层叠", note: "让今天与过去相遇", symbol: "clock.arrow.2.circlepath", color: TSDPalette.rose))
        }
        let progress = SliceFactory.weeklyStoryProgress(
            from: store.slices,
            claimedSliceIDs: Array(store.slices.prefix(3)).map(\.id)
        )
        if progress.readyCount == progress.target {
            items.append(.init(id: "weekly-story", title: "一周成章", note: "三个瞬间长成了故事", symbol: "book.closed.fill", color: TSDPalette.mossDeep))
        }
        return items
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TSDPalette.canvas.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("人生印记")
                                .font(.largeTitle.bold())
                                .foregroundStyle(TSDPalette.ink)
                            Text("它们不是任务清单，而是某天回头时，会认出自己的证据。")
                                .font(.subheadline)
                                .foregroundStyle(TSDPalette.inkSoft)
                        }

                        if !unlocked.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                                ForEach(unlocked) { achievement in
                                    NativeAchievementCard(achievement: achievement)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("还有一些相遇")
                                .font(.headline)
                                .foregroundStyle(TSDPalette.ink)
                            HStack(spacing: 12) {
                                NativeMysteryAchievement(seed: 1)
                                NativeMysteryAchievement(seed: 2)
                            }
                            Text("不展示总数，也不催你完成。它们会在合适的时候出现。")
                                .font(.caption)
                                .foregroundStyle(TSDPalette.inkSoft)
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("印记")
        }
    }
}

private struct NativeAchievement: Identifiable {
    var id: String
    var title: String
    var note: String
    var symbol: String
    var color: Color
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAchievementCard: View {
    var achievement: NativeAchievement

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(achievement.color.opacity(0.14))
                Image(systemName: achievement.symbol)
                    .font(.title2)
                    .foregroundStyle(achievement.color)
            }
            .frame(width: 52, height: 52)
            Text(achievement.title)
                .font(.headline)
                .foregroundStyle(TSDPalette.ink)
            Text(achievement.note)
                .font(.caption)
                .foregroundStyle(TSDPalette.inkSoft)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .padding(16)
        .background(TSDPalette.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("已获得印记：\(achievement.title)，\(achievement.note)")
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeMysteryAchievement: View {
    var seed: Int

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(TSDPalette.sage.opacity(seed == 1 ? 0.22 : 0.15))
                Text("?")
                    .font(.title2.bold())
                    .foregroundStyle(TSDPalette.moss.opacity(0.62))
            }
            .frame(width: 56, height: 56)
            Text("未知印记")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TSDPalette.inkSoft)
        }
        .frame(maxWidth: .infinity, minHeight: 112)
        .background(TSDPalette.paper.opacity(0.68), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityLabel("一枚尚未相遇的未知印记")
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAccountView: View {
    @Binding var store: NativeShellStore
    @State private var exportDocument: TSDExportZIPDocument?
    @State private var isFileExporterPresented = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("账号是钥匙，不是牢笼。")
                    .font(.title.weight(.bold))
                Label("不上传原始影像", systemImage: store.privacyBoundary.allowsRawMediaUpload ? "xmark.circle" : "checkmark.circle")
                Label("不读取通讯录/GPS/人脸", systemImage: store.privacyBoundary.isAppStoreSafeDefault ? "checkmark.circle" : "exclamationmark.triangle")
                Label("订阅不得扣留导出", systemImage: store.privacyBoundary.subscriptionCanBlockExport ? "xmark.circle" : "checkmark.circle")
                Button("导出我的记忆 ZIP") {
                    do {
                        let package = try store.exportMemoryVault()
                        exportDocument = TSDExportZIPDocument(package: package)
                        isFileExporterPresented = true
                    } catch {
                        store.recordExportError("导出失败：\(error)")
                    }
                }
                .buttonStyle(.borderedProminent)

                if let summary = store.latestExportSummary {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(summary.fileName, systemImage: "archivebox")
                            .font(.headline)
                        Text("\(summary.entryCount) 个文档 · \(summary.fileSizeBytes) bytes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Label("设备本地生成，退订后仍可导出", systemImage: summary.isTSDMemoryRightsSafe ? "checkmark.seal" : "exclamationmark.triangle")
                            .font(.caption.weight(.semibold))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                }

                if let exportError = store.latestExportError {
                    Text(exportError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("我的")
            .fileExporter(
                isPresented: $isFileExporterPresented,
                document: exportDocument,
                contentType: TSDExportZIPDocument.exportedContentType,
                defaultFilename: exportDocument?.fileName ?? "timeslowdown-export.zip"
            ) { result in
                if case .failure(let error) = result {
                    store.recordExportError("系统导出失败：\(error.localizedDescription)")
                }
            }
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeMetricGrid: View {
    var snapshot: NativeShellSnapshot

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
            GridRow {
                NativeMetric(title: "切片", value: "\(snapshot.sliceCount)")
                NativeMetric(title: "影像", value: "\(snapshot.mediaAnchorCount)")
            }
            GridRow {
                NativeMetric(title: "原生待做", value: "\(snapshot.nativeTodoCount)")
                NativeMetric(title: "隐私安全", value: snapshot.privacySafe ? "YES" : "NO")
            }
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeMetric: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(value).font(.title2.weight(.bold))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeReadinessRowView: View {
    var row: ReadinessRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(row.title).font(.headline)
                Spacer()
                Text(row.status.rawValue.uppercased()).font(.caption.weight(.bold))
            }
            Text(row.owner).font(.caption).foregroundStyle(.secondary)
            Text(row.evidence).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
#endif
