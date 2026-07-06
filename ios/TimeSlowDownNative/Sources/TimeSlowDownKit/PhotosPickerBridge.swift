import Foundation

public enum PhotosLibraryImportRepresentation: String, Codable, Equatable, Sendable {
    case thumbnailOnly
    case selectedOriginal
}

public struct PhotosLibraryByteImportRequest: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var anchor: MediaAnchor
    public var representation: PhotosLibraryImportRepresentation
    public var userInitiated: Bool
    public var usesLimitedLibraryPicker: Bool
    public var readsEntireLibrary: Bool
    public var infersLocation: Bool
    public var performsFaceRecognition: Bool
    public var uploadsToCloud: Bool
    public var consentReceiptID: String?

    public init(
        id: String,
        anchor: MediaAnchor,
        representation: PhotosLibraryImportRepresentation,
        userInitiated: Bool = true,
        usesLimitedLibraryPicker: Bool = true,
        readsEntireLibrary: Bool = false,
        infersLocation: Bool = false,
        performsFaceRecognition: Bool = false,
        uploadsToCloud: Bool = false,
        consentReceiptID: String? = nil
    ) {
        self.id = id
        self.anchor = anchor
        self.representation = representation
        self.userInitiated = userInitiated
        self.usesLimitedLibraryPicker = usesLimitedLibraryPicker
        self.readsEntireLibrary = readsEntireLibrary
        self.infersLocation = infersLocation
        self.performsFaceRecognition = performsFaceRecognition
        self.uploadsToCloud = uploadsToCloud
        self.consentReceiptID = consentReceiptID
    }

    public var allowsOriginalBytes: Bool {
        representation == .selectedOriginal &&
        userInitiated &&
        usesLimitedLibraryPicker &&
        consentReceiptID != nil &&
        !readsEntireLibrary &&
        !uploadsToCloud
    }

    public var isTSDPhotosImportSafe: Bool {
        userInitiated &&
        usesLimitedLibraryPicker &&
        !readsEntireLibrary &&
        !infersLocation &&
        !performsFaceRecognition &&
        !uploadsToCloud
    }
}

public struct PhotosLibraryByteImportResult: Equatable, Sendable {
    public var request: PhotosLibraryByteImportRequest
    public var payload: RawMediaAssetPayload
    public var thumbnailByteCount: Int
    public var originalByteCount: Int
    public var source: String
    public var stripsLocationMetadataByPolicy: Bool
    public var preservesOriginalOnlyAfterConsent: Bool

    public init(
        request: PhotosLibraryByteImportRequest,
        payload: RawMediaAssetPayload,
        source: String = "PhotosPicker-limited-library",
        stripsLocationMetadataByPolicy: Bool = true,
        preservesOriginalOnlyAfterConsent: Bool = true
    ) {
        self.request = request
        self.payload = payload
        self.thumbnailByteCount = payload.thumbnailData.count
        self.originalByteCount = payload.originalData?.count ?? 0
        self.source = source
        self.stripsLocationMetadataByPolicy = stripsLocationMetadataByPolicy
        self.preservesOriginalOnlyAfterConsent = preservesOriginalOnlyAfterConsent
    }

    public var isTSDPhotosByteImportSafe: Bool {
        request.isTSDPhotosImportSafe &&
        !payload.thumbnailData.isEmpty &&
        stripsLocationMetadataByPolicy &&
        preservesOriginalOnlyAfterConsent &&
        (payload.originalData == nil || request.allowsOriginalBytes)
    }
}

public enum PhotosLibraryByteImporterError: Error, Equatable, Sendable {
    case unsafeRequest(String)
    case missingThumbnail(String)
    case originalBytesNotAllowed(String)
    case missingOriginal(String)
}

public enum PhotosLibraryByteImportAdapter {
    public static func request(
        for anchor: MediaAnchor,
        representation: PhotosLibraryImportRepresentation,
        consentReceiptID: String? = nil
    ) -> PhotosLibraryByteImportRequest {
        let digest = TrustDigest.checksum([
            anchor.id.uuidString,
            anchor.kind.rawValue,
            anchor.label,
            representation.rawValue,
            consentReceiptID ?? "no-consent"
        ])
        return PhotosLibraryByteImportRequest(
            id: "photos-import-\(digest.prefix(12))",
            anchor: anchor,
            representation: representation,
            consentReceiptID: consentReceiptID
        )
    }

    public static func importPayload(
        request: PhotosLibraryByteImportRequest,
        thumbnailData: Data,
        originalData: Data? = nil
    ) throws -> PhotosLibraryByteImportResult {
        guard request.isTSDPhotosImportSafe else {
            throw PhotosLibraryByteImporterError.unsafeRequest(request.id)
        }
        guard !thumbnailData.isEmpty else {
            throw PhotosLibraryByteImporterError.missingThumbnail(request.anchor.id.uuidString)
        }
        if originalData != nil && !request.allowsOriginalBytes {
            throw PhotosLibraryByteImporterError.originalBytesNotAllowed(request.anchor.id.uuidString)
        }
        if request.representation == .selectedOriginal,
           request.allowsOriginalBytes,
           originalData?.isEmpty != false {
            throw PhotosLibraryByteImporterError.missingOriginal(request.anchor.id.uuidString)
        }
        let payload = RawMediaAssetPayload(
            anchorID: request.anchor.id.uuidString,
            thumbnailData: thumbnailData,
            originalData: request.allowsOriginalBytes ? originalData : nil
        )
        return PhotosLibraryByteImportResult(request: request, payload: payload)
    }
}

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

@available(iOS 17.0, macOS 14.0, *)
public enum PhotosPickerByteBridge {
    public static func importPayload(
        from item: PhotosPickerItem,
        anchor: MediaAnchor,
        representation: PhotosLibraryImportRepresentation,
        consentReceiptID: String? = nil
    ) async throws -> PhotosLibraryByteImportResult {
        let request = PhotosLibraryByteImportAdapter.request(
            for: anchor,
            representation: representation,
            consentReceiptID: consentReceiptID
        )
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw PhotosLibraryByteImporterError.missingThumbnail(anchor.id.uuidString)
        }
        return try PhotosLibraryByteImportAdapter.importPayload(
            request: request,
            thumbnailData: data,
            originalData: representation == .selectedOriginal ? data : nil
        )
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
