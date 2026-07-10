import Foundation
#if canImport(ImageIO)
import ImageIO
import UniformTypeIdentifiers
#endif

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

public struct MemoryCameraSelection: Equatable, Sendable {
    public var anchor: MediaAnchor
    public var thumbnailData: Data?
    public var issue: String?

    public init(anchor: MediaAnchor, thumbnailData: Data? = nil, issue: String? = nil) {
        self.anchor = anchor
        self.thumbnailData = thumbnailData
        self.issue = issue
    }
}

public enum MediaThumbnailError: Error, Equatable, Sendable {
    case unsupportedImage
    case renderFailed
    case invalidFileName
    case thumbnailTooLarge(Int)
}

public enum MediaThumbnailRenderer {
    public static func jpegThumbnail(
        from sourceData: Data,
        maxPixelSize: Int = 1_200,
        quality: Double = 0.82
    ) throws -> Data {
#if canImport(ImageIO)
        guard let source = CGImageSourceCreateWithData(sourceData as CFData, [
            kCGImageSourceShouldCache: false
        ] as CFDictionary) else {
            throw MediaThumbnailError.unsupportedImage
        }
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary) else {
            throw MediaThumbnailError.renderFailed
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw MediaThumbnailError.renderFailed
        }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: min(1, max(0.2, quality))
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw MediaThumbnailError.renderFailed
        }
        let data = output as Data
        guard data.count <= NativeMediaThumbnailStore.maximumThumbnailBytes else {
            throw MediaThumbnailError.thumbnailTooLarge(data.count)
        }
        return data
#else
        throw MediaThumbnailError.unsupportedImage
#endif
    }
}

public enum NativeMediaThumbnailStore {
    public static let maximumThumbnailBytes = 3_000_000

    public static var defaultDirectory: URL {
        NativeShellPersistence.defaultURL
            .deletingLastPathComponent()
            .appendingPathComponent("MediaThumbnails", isDirectory: true)
    }

    public static func save(
        _ data: Data,
        anchorID: UUID,
        directory: URL = defaultDirectory
    ) throws -> String {
        guard !data.isEmpty else { throw MediaThumbnailError.renderFailed }
        guard data.count <= maximumThumbnailBytes else {
            throw MediaThumbnailError.thumbnailTooLarge(data.count)
        }
        let fileName = "\(anchorID.uuidString.lowercased()).jpg"
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName, isDirectory: false)
#if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
#else
        try data.write(to: url, options: .atomic)
#endif
        return fileName
    }

    public static func data(
        fileName: String,
        directory: URL = defaultDirectory
    ) -> Data? {
        guard isSafeFileName(fileName) else { return nil }
        return try? Data(contentsOf: directory.appendingPathComponent(fileName, isDirectory: false))
    }

    public static func remove(
        fileName: String,
        directory: URL = defaultDirectory
    ) throws {
        guard isSafeFileName(fileName) else { throw MediaThumbnailError.invalidFileName }
        let url = directory.appendingPathComponent(fileName, isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    public static func restoreAfterUndo(
        _ anchor: MediaAnchor,
        thumbnailData: Data?,
        directory: URL = defaultDirectory
    ) -> MediaAnchor {
        guard anchor.thumbnailFileName != nil else { return anchor }
        var restored = anchor
        restored.thumbnailFileName = nil
        restored.thumbnailByteCount = nil
        guard let thumbnailData else {
            restored.thumbnailIssue = "切片已恢复，影像缩略图需重新选择。"
            return restored
        }
        do {
            restored.thumbnailFileName = try save(
                thumbnailData,
                anchorID: anchor.id,
                directory: directory
            )
            restored.thumbnailByteCount = thumbnailData.count
            restored.thumbnailIssue = nil
        } catch {
            restored.thumbnailIssue = "切片已恢复，影像缩略图需重新选择。"
        }
        return restored
    }

    public static func persist(
        _ selection: MemoryCameraSelection,
        directory: URL = defaultDirectory
    ) throws -> MediaAnchor {
        var anchor = selection.anchor
        anchor.thumbnailIssue = selection.issue
        guard let thumbnailData = selection.thumbnailData else {
            if anchor.kind == .image {
                throw MediaThumbnailError.renderFailed
            }
            return anchor
        }
        let fileName = try save(thumbnailData, anchorID: anchor.id, directory: directory)
        anchor.thumbnailFileName = fileName
        anchor.thumbnailByteCount = thumbnailData.count
        anchor.thumbnailIssue = nil
        anchor.storage = "protected-local-thumbnail"
        return anchor
    }

    private static func isSafeFileName(_ fileName: String) -> Bool {
        !fileName.isEmpty &&
        URL(fileURLWithPath: fileName).lastPathComponent == fileName &&
        !fileName.contains("..")
    }
}

public enum SignedDeviceMediaPermissionMode: String, Codable, Equatable, Sendable {
    case notDetermined
    case limitedLibrary
    case fullLibrary
    case denied
}

public struct SignedDeviceMediaValidationEnvironment: Codable, Equatable, Sendable {
    public var bundleIdentifier: String
    public var teamID: String?
    public var deviceName: String
    public var deviceUDID: String?
    public var osVersion: String
    public var hasFullXcode: Bool
    public var hasAppleDeveloperTeam: Bool
    public var usesProductionBundleIdentifier: Bool
    public var signedBundleInstalled: Bool
    public var runningOnPhysicalDevice: Bool
    public var photosPermissionMode: SignedDeviceMediaPermissionMode
    public var filesExporterAvailable: Bool
    public var networkRequired: Bool

    public init(
        bundleIdentifier: String = "com.raingodprc.timeslowdown",
        teamID: String? = nil,
        deviceName: String,
        deviceUDID: String? = nil,
        osVersion: String,
        hasFullXcode: Bool,
        hasAppleDeveloperTeam: Bool,
        usesProductionBundleIdentifier: Bool = true,
        signedBundleInstalled: Bool,
        runningOnPhysicalDevice: Bool,
        photosPermissionMode: SignedDeviceMediaPermissionMode,
        filesExporterAvailable: Bool,
        networkRequired: Bool = false
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.teamID = teamID
        self.deviceName = deviceName
        self.deviceUDID = deviceUDID
        self.osVersion = osVersion
        self.hasFullXcode = hasFullXcode
        self.hasAppleDeveloperTeam = hasAppleDeveloperTeam
        self.usesProductionBundleIdentifier = usesProductionBundleIdentifier
        self.signedBundleInstalled = signedBundleInstalled
        self.runningOnPhysicalDevice = runningOnPhysicalDevice
        self.photosPermissionMode = photosPermissionMode
        self.filesExporterAvailable = filesExporterAvailable
        self.networkRequired = networkRequired
    }

    public static func unsignedSwiftPMHost(deviceName: String = "local-swiftpm-host") -> SignedDeviceMediaValidationEnvironment {
        SignedDeviceMediaValidationEnvironment(
            deviceName: deviceName,
            osVersion: "host-swiftpm",
            hasFullXcode: false,
            hasAppleDeveloperTeam: false,
            signedBundleInstalled: false,
            runningOnPhysicalDevice: false,
            photosPermissionMode: .notDetermined,
            filesExporterAvailable: false
        )
    }

    public var canRunSignedDeviceMediaValidation: Bool {
        bundleIdentifier == "com.raingodprc.timeslowdown" &&
        teamID != nil &&
        hasFullXcode &&
        hasAppleDeveloperTeam &&
        usesProductionBundleIdentifier &&
        signedBundleInstalled &&
        runningOnPhysicalDevice &&
        photosPermissionMode == .limitedLibrary &&
        filesExporterAvailable &&
        !networkRequired
    }
}

public enum SignedDeviceMediaValidationStepKind: String, Codable, Equatable, Sendable {
    case signingPreflight
    case limitedLibraryPickerOpen
    case userSelectedPhotoImport
    case userSelectedVideoImport
    case originalBytesConsentGate
    case noFullLibraryScan
    case noGPSFaceCloudLeak
    case fileExporterPresentation
    case exportedZIPReopen
    case exportAfterSubscriptionUnavailable
}

public struct SignedDeviceMediaValidationStep: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: SignedDeviceMediaValidationStepKind
    public var title: String
    public var requiresPhysicalDevice: Bool
    public var forbidsRawMediaEvidence: Bool
    public var expectedEvidence: String

    public init(
        id: String,
        kind: SignedDeviceMediaValidationStepKind,
        title: String,
        requiresPhysicalDevice: Bool = true,
        forbidsRawMediaEvidence: Bool = true,
        expectedEvidence: String
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.requiresPhysicalDevice = requiresPhysicalDevice
        self.forbidsRawMediaEvidence = forbidsRawMediaEvidence
        self.expectedEvidence = expectedEvidence
    }

    public var preservesTSDMediaValidationBoundary: Bool {
        id.hasPrefix("signed-device-media-") &&
        requiresPhysicalDevice &&
        forbidsRawMediaEvidence &&
        !expectedEvidence.isEmpty
    }
}

public struct SignedDeviceMediaExportProbe: Codable, Equatable, Sendable {
    public var fileName: String
    public var byteCount: Int
    public var entryCount: Int
    public var memoryRightsSafe: Bool
    public var canExportAfterSubscriptionEnds: Bool

    public init(
        fileName: String = "timeslowdown-export.zip",
        byteCount: Int,
        entryCount: Int,
        memoryRightsSafe: Bool = true,
        canExportAfterSubscriptionEnds: Bool = true
    ) {
        self.fileName = fileName
        self.byteCount = byteCount
        self.entryCount = entryCount
        self.memoryRightsSafe = memoryRightsSafe
        self.canExportAfterSubscriptionEnds = canExportAfterSubscriptionEnds
    }

    public var isTSDExportProbeSafe: Bool {
        fileName.hasSuffix(".zip") &&
        byteCount > 22 &&
        entryCount >= 5 &&
        memoryRightsSafe &&
        canExportAfterSubscriptionEnds
    }
}

public struct SignedDeviceMediaValidationPlan: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var environment: SignedDeviceMediaValidationEnvironment
    public var importRequests: [PhotosLibraryByteImportRequest]
    public var exportProbe: SignedDeviceMediaExportProbe
    public var steps: [SignedDeviceMediaValidationStep]
    public var status: SignedDeviceValidationStatus
    public var productionValidationClaimed: Bool
    public var generatedAt: Date

    public init(
        id: String,
        environment: SignedDeviceMediaValidationEnvironment,
        importRequests: [PhotosLibraryByteImportRequest],
        exportProbe: SignedDeviceMediaExportProbe,
        steps: [SignedDeviceMediaValidationStep],
        status: SignedDeviceValidationStatus,
        productionValidationClaimed: Bool = false,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.environment = environment
        self.importRequests = importRequests
        self.exportProbe = exportProbe
        self.steps = steps
        self.status = status
        self.productionValidationClaimed = productionValidationClaimed
        self.generatedAt = generatedAt
    }

    public var isTSDMediaValidationPlanSafe: Bool {
        id.hasPrefix("signed-device-media-plan-") &&
        importRequests.count >= 2 &&
        importRequests.allSatisfy(\.isTSDPhotosImportSafe) &&
        importRequests.contains { $0.anchor.kind == .image } &&
        importRequests.contains { $0.anchor.kind == .video } &&
        exportProbe.isTSDExportProbeSafe &&
        steps.count == SignedDeviceMediaValidationScaffold.defaultSteps.count &&
        Set(steps.map(\.kind)).count == steps.count &&
        steps.allSatisfy(\.preservesTSDMediaValidationBoundary) &&
        !productionValidationClaimed &&
        (status == .pendingSignedDevice || status == .readyToRun) &&
        (status == .readyToRun) == environment.canRunSignedDeviceMediaValidation
    }

    public var requiresExternalSignedDeviceWork: Bool {
        status == .pendingSignedDevice &&
        !environment.canRunSignedDeviceMediaValidation &&
        !productionValidationClaimed
    }
}

public struct SignedDeviceMediaValidationStepReceipt: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var stepID: String
    public var status: SignedDeviceValidationStatus
    public var evidenceDigest: String?
    public var errorMessage: String?
    public var containsRawMediaEvidence: Bool

    public init(
        id: String,
        stepID: String,
        status: SignedDeviceValidationStatus,
        evidenceDigest: String? = nil,
        errorMessage: String? = nil,
        containsRawMediaEvidence: Bool = false
    ) {
        self.id = id
        self.stepID = stepID
        self.status = status
        self.evidenceDigest = evidenceDigest
        self.errorMessage = errorMessage
        self.containsRawMediaEvidence = containsRawMediaEvidence
    }

    public var isHonestTSDMediaStepReceipt: Bool {
        id.hasPrefix("signed-device-media-step-receipt-") &&
        !stepID.isEmpty &&
        !containsRawMediaEvidence &&
        (status != .passed || evidenceDigest != nil) &&
        (status != .failed || errorMessage != nil)
    }
}

public struct SignedDeviceMediaValidationReceipt: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var planID: String
    public var status: SignedDeviceValidationStatus
    public var stepReceipts: [SignedDeviceMediaValidationStepReceipt]
    public var productionValidationClaimed: Bool
    public var canSatisfyPhotosImportGate: Bool
    public var canSatisfyFilesExportGate: Bool
    public var containsRawMediaInEvidence: Bool
    public var createdAt: Date

    public init(
        id: String,
        planID: String,
        status: SignedDeviceValidationStatus,
        stepReceipts: [SignedDeviceMediaValidationStepReceipt],
        productionValidationClaimed: Bool,
        canSatisfyPhotosImportGate: Bool,
        canSatisfyFilesExportGate: Bool,
        containsRawMediaInEvidence: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.planID = planID
        self.status = status
        self.stepReceipts = stepReceipts
        self.productionValidationClaimed = productionValidationClaimed
        self.canSatisfyPhotosImportGate = canSatisfyPhotosImportGate
        self.canSatisfyFilesExportGate = canSatisfyFilesExportGate
        self.containsRawMediaInEvidence = containsRawMediaInEvidence
        self.createdAt = createdAt
    }

    private var passedStepIDs: Set<String> {
        Set(stepReceipts.filter { $0.status == .passed && $0.isHonestTSDMediaStepReceipt }.map(\.stepID))
    }

    public var isHonestPendingReceipt: Bool {
        id.hasPrefix("signed-device-media-receipt-") &&
        status == .pendingSignedDevice &&
        stepReceipts.allSatisfy { $0.status == .pendingSignedDevice && $0.isHonestTSDMediaStepReceipt } &&
        !productionValidationClaimed &&
        !canSatisfyPhotosImportGate &&
        !canSatisfyFilesExportGate &&
        !containsRawMediaInEvidence
    }

    public var isProductionPhotosImportPassReceipt: Bool {
        id.hasPrefix("signed-device-media-receipt-") &&
        status == .passed &&
        productionValidationClaimed &&
        canSatisfyPhotosImportGate &&
        !containsRawMediaInEvidence &&
        SignedDeviceMediaValidationScaffold.requiredPhotosStepIDs.isSubset(of: passedStepIDs)
    }

    public var isProductionFilesExportPassReceipt: Bool {
        id.hasPrefix("signed-device-media-receipt-") &&
        status == .passed &&
        productionValidationClaimed &&
        canSatisfyFilesExportGate &&
        !containsRawMediaInEvidence &&
        SignedDeviceMediaValidationScaffold.requiredFilesStepIDs.isSubset(of: passedStepIDs)
    }

    public var isProductionPassReceipt: Bool {
        stepReceipts.count == SignedDeviceMediaValidationScaffold.defaultSteps.count &&
        stepReceipts.allSatisfy { $0.status == .passed && $0.isHonestTSDMediaStepReceipt } &&
        isProductionPhotosImportPassReceipt &&
        isProductionFilesExportPassReceipt
    }
}

public enum SignedDeviceMediaValidationScaffold {
    public static func plan(
        environment: SignedDeviceMediaValidationEnvironment,
        importRequests: [PhotosLibraryByteImportRequest],
        exportProbe: SignedDeviceMediaExportProbe,
        generatedAt: Date = Date()
    ) -> SignedDeviceMediaValidationPlan {
        let digest = TrustDigest.checksum([
            environment.bundleIdentifier,
            environment.teamID ?? "no-team",
            importRequests.map(\.id).joined(separator: "|"),
            exportProbe.fileName
        ])
        return SignedDeviceMediaValidationPlan(
            id: "signed-device-media-plan-\(digest.prefix(12))",
            environment: environment,
            importRequests: importRequests,
            exportProbe: exportProbe,
            steps: defaultSteps,
            status: environment.canRunSignedDeviceMediaValidation ? .readyToRun : .pendingSignedDevice,
            generatedAt: generatedAt
        )
    }

    public static func pendingReceipt(
        for plan: SignedDeviceMediaValidationPlan,
        createdAt: Date = Date()
    ) -> SignedDeviceMediaValidationReceipt {
        let stepReceipts = plan.steps.map { step in
            SignedDeviceMediaValidationStepReceipt(
                id: "signed-device-media-step-receipt-\(TrustDigest.checksum([plan.id, step.id]).prefix(12))",
                stepID: step.id,
                status: .pendingSignedDevice
            )
        }
        let digest = TrustDigest.checksum([plan.id, "pending-media"])
        return SignedDeviceMediaValidationReceipt(
            id: "signed-device-media-receipt-\(digest.prefix(12))",
            planID: plan.id,
            status: .pendingSignedDevice,
            stepReceipts: stepReceipts,
            productionValidationClaimed: false,
            canSatisfyPhotosImportGate: false,
            canSatisfyFilesExportGate: false,
            createdAt: createdAt
        )
    }

    public static var defaultSteps: [SignedDeviceMediaValidationStep] {
        [
            .init(id: "signed-device-media-signing-preflight", kind: .signingPreflight, title: "Verify signed production bundle on physical device", expectedEvidence: "bundle-id, Team ID, device UDID, installed build number"),
            .init(id: "signed-device-media-limited-library-picker-open", kind: .limitedLibraryPickerOpen, title: "Open PhotosPicker with limited-library permission", expectedEvidence: "limited-library permission state and picker presentation digest"),
            .init(id: "signed-device-media-user-selected-photo-import", kind: .userSelectedPhotoImport, title: "Import one user-selected photo anchor", expectedEvidence: "photo anchor ID, byte-count digest, no raw photo evidence"),
            .init(id: "signed-device-media-user-selected-video-import", kind: .userSelectedVideoImport, title: "Import one user-selected video anchor", expectedEvidence: "video anchor ID, byte-count digest, no raw video evidence"),
            .init(id: "signed-device-media-original-bytes-consent-gate", kind: .originalBytesConsentGate, title: "Require explicit consent before original bytes export", expectedEvidence: "consent receipt ID and selected-anchor digest"),
            .init(id: "signed-device-media-no-full-library-scan", kind: .noFullLibraryScan, title: "Verify no full-library scan or background enumeration", expectedEvidence: "request flags showing user-initiated limited import only"),
            .init(id: "signed-device-media-no-gps-face-cloud-leak", kind: .noGPSFaceCloudLeak, title: "Verify no GPS inference, face recognition, or cloud/provider upload", expectedEvidence: "privacy boundary digest and zero network requirement"),
            .init(id: "signed-device-media-file-exporter-presentation", kind: .fileExporterPresentation, title: "Present system Files/share export sheet for memory ZIP", expectedEvidence: "fileExporter presentation receipt and ZIP metadata digest"),
            .init(id: "signed-device-media-exported-zip-reopen", kind: .exportedZIPReopen, title: "Re-open exported ZIP package from Files", expectedEvidence: "manifest/slices/chapters/media-index/rights entries verified by digest"),
            .init(id: "signed-device-media-export-after-subscription-unavailable", kind: .exportAfterSubscriptionUnavailable, title: "Verify export remains available without active subscription", expectedEvidence: "non-hostage export policy receipt")
        ]
    }

    public static var requiredPhotosStepIDs: Set<String> {
        Set(defaultSteps.filter {
            [
                .signingPreflight,
                .limitedLibraryPickerOpen,
                .userSelectedPhotoImport,
                .userSelectedVideoImport,
                .originalBytesConsentGate,
                .noFullLibraryScan,
                .noGPSFaceCloudLeak
            ].contains($0.kind)
        }.map(\.id))
    }

    public static var requiredFilesStepIDs: Set<String> {
        Set(defaultSteps.filter {
            [
                .signingPreflight,
                .fileExporterPresentation,
                .exportedZIPReopen,
                .exportAfterSubscriptionUnavailable
            ].contains($0.kind)
        }.map(\.id))
    }
}

#if canImport(SwiftUI) && canImport(PhotosUI)
import SwiftUI
import PhotosUI

@available(iOS 17.0, macOS 14.0, *)
public struct MemoryCameraPicker: View {
    private let onPicked: (MemoryCameraSelection) -> Void
    @State private var selectedItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var importIssue: String?

    public init(onPicked: @escaping (MemoryCameraSelection) -> Void) {
        self.onPicked = onPicked
    }

    public var body: some View {
        let importing = isImporting
        VStack(alignment: .leading, spacing: 7) {
            PhotosPicker(
                selection: $selectedItem,
                matching: .any(of: [.images, .videos]),
                photoLibrary: .shared()
            ) {
                HStack(spacing: 10) {
                    if importing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "camera.fill")
                    }
                    Text(importing ? "正在留下画面" : "照片或视频")
                        .fontWeight(.semibold)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(Color(red: 0.12, green: 0.18, blue: 0.14))
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 16)
                .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isImporting)

            if let importIssue {
                Text(importIssue)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task { await importSelection(newItem) }
        }
    }

    @MainActor
    private func importSelection(_ item: PhotosPickerItem) async {
        isImporting = true
        importIssue = nil
        let kind = inferredKind(from: item)
        var anchor = MediaAnchor(
            kind: kind,
            label: kind == .video ? "选中的视频" : "选中的照片",
            note: "来自系统照片选择器，文字可以以后再补。",
            storage: "photos-picker-limited",
            source: "PhotosPicker"
        )
        if kind == .video {
            let issue = "视频已作为记忆线索保存；本地封面将在后续版本生成。"
            anchor.thumbnailIssue = issue
            onPicked(MemoryCameraSelection(anchor: anchor, issue: issue))
        } else {
            do {
                guard let sourceData = try await item.loadTransferable(type: Data.self) else {
                    throw PhotosLibraryByteImporterError.missingThumbnail(anchor.id.uuidString)
                }
                let thumbnail = try MediaThumbnailRenderer.jpegThumbnail(from: sourceData)
                onPicked(MemoryCameraSelection(anchor: anchor, thumbnailData: thumbnail))
            } catch {
                let issue = "照片缩略图生成失败，尚未写入记忆，可重新选择。"
                importIssue = issue
            }
        }
        selectedItem = nil
        isImporting = false
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
    private let onPicked: (MemoryCameraSelection) -> Void

    public init(onPicked: @escaping (MemoryCameraSelection) -> Void) {
        self.onPicked = onPicked
    }

    public var body: some View {
        Button {
            let issue = "当前编译环境无法生成系统照片缩略图。"
            onPicked(MemoryCameraSelection(
                anchor: MediaAnchor(
                    kind: .image,
                    label: "photos-picker-unavailable",
                    note: "当前编译环境没有 PhotosUI；真实 iOS target 应接入 PhotosPicker。",
                    storage: "photos-picker-unavailable",
                    source: "PhotosPicker fallback",
                    thumbnailIssue: issue
                ),
                issue: issue
            ))
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "camera.fill")
                Text("照片或视频")
                    .fontWeight(.semibold)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(Color(red: 0.12, green: 0.18, blue: 0.14))
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 16)
            .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
#endif
