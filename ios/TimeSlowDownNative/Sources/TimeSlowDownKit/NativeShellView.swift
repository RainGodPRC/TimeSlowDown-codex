#if canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct TSDNativeShellView: View {
    @State private var store: NativeShellStore

    public init(store: NativeShellStore = .seeded()) {
        self._store = State(initialValue: store)
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

            NativeLaunchView()
                .tabItem { Label(NativeShellRoute.launch.title, systemImage: "checklist") }
                .tag(NativeShellRoute.launch)

            NativeAccountView(store: $store)
                .tabItem { Label(NativeShellRoute.account.title, systemImage: "person.crop.circle") }
                .tag(NativeShellRoute.account)
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeNowView: View {
    @Binding var store: NativeShellStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("不是活一辈子，而是活几个瞬间。")
                        .font(.largeTitle.weight(.bold))
                    Text("先用照片或视频钉住现场，文字可以以后再补。")
                        .foregroundStyle(.secondary)

                    MemoryCameraPicker { anchor in
                        _ = store.captureFromMemoryCamera(anchor)
                    }

                    Button("用示例照片先占位") {
                        _ = store.captureFromMemoryCamera(
                            MediaAnchor(kind: .image, label: "memory-camera-demo.jpg", note: "来自 Memory Camera 主入口")
                        )
                    }
                    .buttonStyle(.borderedProminent)

                    NativeMetricGrid(snapshot: store.snapshot)
                }
                .padding()
            }
            .navigationTitle("TimeSlowDown")
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeSliceListView: View {
    @Binding var store: NativeShellStore

    var body: some View {
        NavigationStack {
            List(store.slices) { slice in
                VStack(alignment: .leading, spacing: 6) {
                    Text(slice.title).font(.headline)
                    Text(slice.body).font(.subheadline).foregroundStyle(.secondary)
                    if let media = slice.media {
                        Label(media.label, systemImage: media.kind == .video ? "video" : "photo")
                            .font(.caption.weight(.semibold))
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("今日切片")
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeMeadowView: View {
    @Binding var store: NativeShellStore

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("人生旷野")
                    .font(.largeTitle.weight(.bold))
                Text("这一周有 \(store.slices.count) 张切片，\(store.snapshot.mediaAnchorCount) 个影像锚点。")
                Text("章节预览：\(store.weeklyPreviewTitle())")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("旷野")
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeLaunchView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Native Handoff") {
                    ForEach(NativeHandoffLedger.rows) { row in
                        NativeReadinessRowView(row: row)
                    }
                }
                Section("Submission Packet") {
                    ForEach(SubmissionPacket.rows) { row in
                        NativeReadinessRowView(row: row)
                    }
                }
            }
            .navigationTitle("上架就绪")
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAccountView: View {
    @Binding var store: NativeShellStore

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
                        _ = try store.exportMemoryVault()
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
