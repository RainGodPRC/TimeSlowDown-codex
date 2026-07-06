#if canImport(SwiftUI) && canImport(PhotosUI)
import SwiftUI
import PhotosUI

@available(iOS 17.0, macOS 14.0, *)
public struct MemoryCameraPicker: View {
    private let onPicked: (MediaAnchor) -> Void
    @State private var selectedItem: PhotosPickerItem?

    public init(onPicked: @escaping (MediaAnchor) -> Void) {
        self.onPicked = onPicked
    }

    public var body: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .any(of: [.images, .videos]),
            photoLibrary: .shared()
        ) {
            Label("添加照片/视频", systemImage: "camera.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            onPicked(MediaAnchor(
                kind: inferredKind(from: newItem),
                label: newItem.itemIdentifier ?? "PhotosPicker media",
                note: "来自系统照片选择器，文字可以以后再补。",
                storage: "photos-picker-limited",
                source: "PhotosPicker"
            ))
        }
    }

    private func inferredKind(from item: PhotosPickerItem) -> MediaKind {
        let supported = item.supportedContentTypes
        if supported.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) }) {
            return .video
        }
        return .image
    }
}
#elseif canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct MemoryCameraPicker: View {
    private let onPicked: (MediaAnchor) -> Void

    public init(onPicked: @escaping (MediaAnchor) -> Void) {
        self.onPicked = onPicked
    }

    public var body: some View {
        Button {
            onPicked(MediaAnchor(
                kind: .image,
                label: "photos-picker-unavailable",
                note: "当前编译环境没有 PhotosUI；真实 iOS target 应接入 PhotosPicker。",
                storage: "photos-picker-unavailable",
                source: "PhotosPicker fallback"
            ))
        } label: {
            Label("添加照片/视频", systemImage: "camera.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }
}
#endif
