import Foundation

public enum KeychainAccessiblePolicy: String, Codable, Equatable, Sendable {
    case afterFirstUnlockThisDeviceOnly
    case whenUnlockedThisDeviceOnly
}

public struct KeychainPersistencePlan: Codable, Equatable, Sendable {
    public var service: String
    public var account: String
    public var accessGroup: String?
    public var accessible: KeychainAccessiblePolicy
    public var synchronizable: Bool
    public var thisDeviceOnly: Bool
    public var storesSecretMaterialOutsideKeychain: Bool
    public var migrationAllowed: Bool
    public var requiresUserPresence: Bool

    public init(
        service: String,
        account: String,
        accessGroup: String? = nil,
        accessible: KeychainAccessiblePolicy = .whenUnlockedThisDeviceOnly,
        synchronizable: Bool = false,
        thisDeviceOnly: Bool = true,
        storesSecretMaterialOutsideKeychain: Bool = false,
        migrationAllowed: Bool = false,
        requiresUserPresence: Bool = false
    ) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
        self.accessible = accessible
        self.synchronizable = synchronizable
        self.thisDeviceOnly = thisDeviceOnly
        self.storesSecretMaterialOutsideKeychain = storesSecretMaterialOutsideKeychain
        self.migrationAllowed = migrationAllowed
        self.requiresUserPresence = requiresUserPresence
    }

    public var isSafeDefault: Bool {
        service == "com.raingodprc.timeslowdown.device-key" &&
        !synchronizable &&
        thisDeviceOnly &&
        !storesSecretMaterialOutsideKeychain &&
        !migrationAllowed
    }

    public static func deviceKeyPlan(for record: DeviceKeyRecord) -> KeychainPersistencePlan {
        KeychainPersistencePlan(
            service: "com.raingodprc.timeslowdown.device-key",
            account: record.keyID,
            accessGroup: nil,
            accessible: .whenUnlockedThisDeviceOnly,
            synchronizable: false,
            thisDeviceOnly: true,
            storesSecretMaterialOutsideKeychain: false,
            migrationAllowed: false,
            requiresUserPresence: false
        )
    }
}

public struct DeepSeekGatewayRequest: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var method: String
    public var endpointPath: String
    public var provider: String
    public var model: String
    public var task: DeepSeekTaskEnvelope
    public var idempotencyKey: String
    public var requiresServerSideCredential: Bool
    public var containsProviderAPIKey: Bool
    public var sendsRawMedia: Bool
    public var sendsFullArchive: Bool
    public var fallbackMode: String

    public init(
        id: String,
        method: String = "POST",
        endpointPath: String = "/v1/ai/tasks/weekly-chapter",
        provider: String,
        model: String,
        task: DeepSeekTaskEnvelope,
        idempotencyKey: String,
        requiresServerSideCredential: Bool = true,
        containsProviderAPIKey: Bool = false,
        sendsRawMedia: Bool = false,
        sendsFullArchive: Bool = false,
        fallbackMode: String
    ) {
        self.id = id
        self.method = method
        self.endpointPath = endpointPath
        self.provider = provider
        self.model = model
        self.task = task
        self.idempotencyKey = idempotencyKey
        self.requiresServerSideCredential = requiresServerSideCredential
        self.containsProviderAPIKey = containsProviderAPIKey
        self.sendsRawMedia = sendsRawMedia
        self.sendsFullArchive = sendsFullArchive
        self.fallbackMode = fallbackMode
    }
}

public enum DeepSeekGatewayClientPlan {
    public static func request(for task: DeepSeekTaskEnvelope, accountID: String) -> DeepSeekGatewayRequest {
        let idempotencyKey = TrustDigest.checksum([accountID, task.id, task.minimalPayloadDigest])
        return DeepSeekGatewayRequest(
            id: "gateway-\(idempotencyKey.prefix(12))",
            provider: task.provider,
            model: task.model,
            task: task,
            idempotencyKey: idempotencyKey,
            fallbackMode: task.fallbackMode
        )
    }
}

public struct DeepSeekGatewayResponseContract: Codable, Equatable, Sendable {
    public var acceptedStatusCode: Int
    public var completedStatusCode: Int
    public var localFallbackStatusCode: Int
    public var providerUnavailableStatusCode: Int
    public var budgetExceededStatusCode: Int
    public var responseContainsProviderAPIKey: Bool
    public var responseContainsRawMedia: Bool
    public var responseContainsFullMemoryArchive: Bool
    public var returnsGatewayJobID: Bool
    public var returnsAuditEventID: Bool
    public var returnsModelName: Bool
    public var returnsCostEstimate: Bool
    public var preservesUserEditableDraft: Bool

    public init(
        acceptedStatusCode: Int = 202,
        completedStatusCode: Int = 200,
        localFallbackStatusCode: Int = 206,
        providerUnavailableStatusCode: Int = 503,
        budgetExceededStatusCode: Int = 402,
        responseContainsProviderAPIKey: Bool = false,
        responseContainsRawMedia: Bool = false,
        responseContainsFullMemoryArchive: Bool = false,
        returnsGatewayJobID: Bool = true,
        returnsAuditEventID: Bool = true,
        returnsModelName: Bool = true,
        returnsCostEstimate: Bool = true,
        preservesUserEditableDraft: Bool = true
    ) {
        self.acceptedStatusCode = acceptedStatusCode
        self.completedStatusCode = completedStatusCode
        self.localFallbackStatusCode = localFallbackStatusCode
        self.providerUnavailableStatusCode = providerUnavailableStatusCode
        self.budgetExceededStatusCode = budgetExceededStatusCode
        self.responseContainsProviderAPIKey = responseContainsProviderAPIKey
        self.responseContainsRawMedia = responseContainsRawMedia
        self.responseContainsFullMemoryArchive = responseContainsFullMemoryArchive
        self.returnsGatewayJobID = returnsGatewayJobID
        self.returnsAuditEventID = returnsAuditEventID
        self.returnsModelName = returnsModelName
        self.returnsCostEstimate = returnsCostEstimate
        self.preservesUserEditableDraft = preservesUserEditableDraft
    }
}

public struct DeepSeekServerGatewayEnvelope: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var request: DeepSeekGatewayRequest
    public var headers: [String: String]
    public var requestBodyDigest: String
    public var consentReceiptID: String
    public var auditEventName: String
    public var serverCredentialLocation: String
    public var providerCredentialVisibleToClient: Bool
    public var requiresAuthenticatedAccount: Bool
    public var requiresUserConsent: Bool
    public var budgetCeilingCents: Int
    public var retentionHours: Int
    public var dataResidencyPolicy: String
    public var queueName: String
    public var mockableWithoutProviderCall: Bool
    public var responseContract: DeepSeekGatewayResponseContract

    public init(
        id: String,
        request: DeepSeekGatewayRequest,
        headers: [String: String],
        requestBodyDigest: String,
        consentReceiptID: String,
        auditEventName: String = "ai.weekly_chapter.requested",
        serverCredentialLocation: String = "server-secret-manager",
        providerCredentialVisibleToClient: Bool = false,
        requiresAuthenticatedAccount: Bool = true,
        requiresUserConsent: Bool = true,
        budgetCeilingCents: Int,
        retentionHours: Int = 24,
        dataResidencyPolicy: String = "user-region-pinned",
        queueName: String = "ai-weekly-chapter",
        mockableWithoutProviderCall: Bool = true,
        responseContract: DeepSeekGatewayResponseContract = DeepSeekGatewayResponseContract()
    ) {
        self.id = id
        self.request = request
        self.headers = headers
        self.requestBodyDigest = requestBodyDigest
        self.consentReceiptID = consentReceiptID
        self.auditEventName = auditEventName
        self.serverCredentialLocation = serverCredentialLocation
        self.providerCredentialVisibleToClient = providerCredentialVisibleToClient
        self.requiresAuthenticatedAccount = requiresAuthenticatedAccount
        self.requiresUserConsent = requiresUserConsent
        self.budgetCeilingCents = budgetCeilingCents
        self.retentionHours = retentionHours
        self.dataResidencyPolicy = dataResidencyPolicy
        self.queueName = queueName
        self.mockableWithoutProviderCall = mockableWithoutProviderCall
        self.responseContract = responseContract
    }

    public var isProductionSafeBoundary: Bool {
        request.requiresServerSideCredential &&
        !request.containsProviderAPIKey &&
        !request.sendsRawMedia &&
        !request.sendsFullArchive &&
        !providerCredentialVisibleToClient &&
        requiresAuthenticatedAccount &&
        requiresUserConsent &&
        budgetCeilingCents <= request.task.maxBudgetCents &&
        retentionHours <= 24 &&
        mockableWithoutProviderCall &&
        !responseContract.responseContainsProviderAPIKey &&
        !responseContract.responseContainsRawMedia &&
        !responseContract.responseContainsFullMemoryArchive &&
        responseContract.returnsGatewayJobID &&
        responseContract.returnsAuditEventID &&
        responseContract.preservesUserEditableDraft
    }
}

public enum DeepSeekServerGatewayPlan {
    public static func envelope(
        for request: DeepSeekGatewayRequest,
        accountID: String,
        consentReceiptID: String
    ) -> DeepSeekServerGatewayEnvelope {
        let bodyDigest = TrustDigest.checksum([
            accountID,
            request.id,
            request.task.minimalPayloadDigest,
            consentReceiptID
        ])
        return DeepSeekServerGatewayEnvelope(
            id: "server-gateway-\(bodyDigest.prefix(12))",
            request: request,
            headers: [
                "Content-Type": "application/json",
                "Idempotency-Key": request.idempotencyKey,
                "X-TSD-AI-Consent": consentReceiptID,
                "X-TSD-Task-Digest": request.task.minimalPayloadDigest
            ],
            requestBodyDigest: bodyDigest,
            consentReceiptID: consentReceiptID,
            budgetCeilingCents: request.task.maxBudgetCents
        )
    }
}

public enum ExportArchiveEntryKind: String, Codable, Equatable, Sendable {
    case manifest
    case slices
    case chapters
    case mediaIndex
    case deletionRights
}

public struct ExportArchiveEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: ExportArchiveEntryKind
    public var path: String
    public var containsRawMedia: Bool
    public var containsAITranscript: Bool

    public init(
        id: String,
        kind: ExportArchiveEntryKind,
        path: String,
        containsRawMedia: Bool = false,
        containsAITranscript: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.path = path
        self.containsRawMedia = containsRawMedia
        self.containsAITranscript = containsAITranscript
    }
}

public struct ExportArchivePlan: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var fileName: String
    public var format: String
    public var manifest: ExportPackageManifest
    public var entries: [ExportArchiveEntry]
    public var generatedOnDevice: Bool
    public var canBeGeneratedAfterSubscriptionEnds: Bool

    public init(
        id: String,
        fileName: String,
        format: String = "zip",
        manifest: ExportPackageManifest,
        entries: [ExportArchiveEntry],
        generatedOnDevice: Bool = true,
        canBeGeneratedAfterSubscriptionEnds: Bool = true
    ) {
        self.id = id
        self.fileName = fileName
        self.format = format
        self.manifest = manifest
        self.entries = entries
        self.generatedOnDevice = generatedOnDevice
        self.canBeGeneratedAfterSubscriptionEnds = canBeGeneratedAfterSubscriptionEnds
    }

    public static func zipPlan(for manifest: ExportPackageManifest) -> ExportArchivePlan {
        let entries: [ExportArchiveEntry] = [
            .init(id: "manifest", kind: .manifest, path: "manifest.json"),
            .init(id: "slices", kind: .slices, path: "memories/slices.json"),
            .init(id: "chapters", kind: .chapters, path: "memories/chapters.json"),
            .init(id: "media-index", kind: .mediaIndex, path: "media/index.json"),
            .init(id: "deletion-rights", kind: .deletionRights, path: "rights/deletion-receipt-template.json")
        ]
        return ExportArchivePlan(
            id: "archive-\(manifest.checksum.prefix(12))",
            fileName: "timeslowdown-export-\(manifest.generatedAt.timeIntervalSince1970.rounded()).zip",
            manifest: manifest,
            entries: entries
        )
    }
}

public struct ExportZIPEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String { path }
    public var path: String
    public var crc32: UInt32
    public var uncompressedSize: Int
    public var containsRawMedia: Bool
    public var containsAITranscript: Bool

    public init(
        path: String,
        crc32: UInt32,
        uncompressedSize: Int,
        containsRawMedia: Bool = false,
        containsAITranscript: Bool = false
    ) {
        self.path = path
        self.crc32 = crc32
        self.uncompressedSize = uncompressedSize
        self.containsRawMedia = containsRawMedia
        self.containsAITranscript = containsAITranscript
    }
}

public struct ExportZIPPackage: Codable, Equatable, Sendable {
    public var fileName: String
    public var data: Data
    public var entries: [ExportZIPEntry]
    public var generatedOnDevice: Bool
    public var canBeGeneratedAfterSubscriptionEnds: Bool

    public init(
        fileName: String,
        data: Data,
        entries: [ExportZIPEntry],
        generatedOnDevice: Bool,
        canBeGeneratedAfterSubscriptionEnds: Bool
    ) {
        self.fileName = fileName
        self.data = data
        self.entries = entries
        self.generatedOnDevice = generatedOnDevice
        self.canBeGeneratedAfterSubscriptionEnds = canBeGeneratedAfterSubscriptionEnds
    }

    public var hasZIPMagic: Bool {
        data.starts(with: [0x50, 0x4B, 0x03, 0x04])
    }

    public var hasEndOfCentralDirectory: Bool {
        data.count >= 22 &&
        data.suffix(22).starts(with: [0x50, 0x4B, 0x05, 0x06])
    }

    public var centralDirectoryRecordCount: Int {
        guard data.count >= 22 else { return 0 }
        let offset = data.count - 22 + 10
        return Int(data[offset]) | (Int(data[offset + 1]) << 8)
    }

    public var isMemorySafeDefault: Bool {
        generatedOnDevice &&
        canBeGeneratedAfterSubscriptionEnds &&
        entries.allSatisfy { !$0.containsRawMedia && !$0.containsAITranscript }
    }
}

public enum ExportZIPBuilderError: Error, Equatable, Sendable {
    case unsafePlan(String)
    case encodingFailed(String)
    case zipSizeOverflow(String)
}

public enum OnDeviceExportZIPBuilder {
    public static func package(
        for plan: ExportArchivePlan,
        slices: [MemorySlice],
        chapters: [WeeklyChapter],
        deletionReceipt: DeletionReceipt
    ) throws -> ExportZIPPackage {
        try validate(plan)

        let files = try exportFiles(
            plan: plan,
            slices: slices,
            chapters: chapters,
            deletionReceipt: deletionReceipt
        )
        let zipData = try buildZIP(files: files)
        let entries = files.map {
            ExportZIPEntry(
                path: $0.path,
                crc32: CRC32.checksum($0.data),
                uncompressedSize: $0.data.count,
                containsRawMedia: $0.containsRawMedia,
                containsAITranscript: $0.containsAITranscript
            )
        }
        return ExportZIPPackage(
            fileName: plan.fileName,
            data: zipData,
            entries: entries,
            generatedOnDevice: plan.generatedOnDevice,
            canBeGeneratedAfterSubscriptionEnds: plan.canBeGeneratedAfterSubscriptionEnds
        )
    }

    private static func validate(_ plan: ExportArchivePlan) throws {
        guard plan.format == "zip" else {
            throw ExportZIPBuilderError.unsafePlan("Only zip export archives are supported.")
        }
        guard plan.generatedOnDevice else {
            throw ExportZIPBuilderError.unsafePlan("TSD memory exports must be generated on device by default.")
        }
        guard plan.canBeGeneratedAfterSubscriptionEnds else {
            throw ExportZIPBuilderError.unsafePlan("Export must remain available after subscription ends.")
        }
        guard plan.entries.allSatisfy({ !$0.containsRawMedia && !$0.containsAITranscript }) else {
            throw ExportZIPBuilderError.unsafePlan("Default export package must not include raw media or AI transcripts.")
        }
    }

    private static func exportFiles(
        plan: ExportArchivePlan,
        slices: [MemorySlice],
        chapters: [WeeklyChapter],
        deletionReceipt: DeletionReceipt
    ) throws -> [ExportFile] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        func encode<T: Encodable>(_ value: T, label: String) throws -> Data {
            do {
                return try encoder.encode(value)
            } catch {
                throw ExportZIPBuilderError.encodingFailed(label)
            }
        }

        let mediaIndex = MediaIndexDocument(
            generatedFromExportID: plan.manifest.id,
            anchors: slices.compactMap { slice -> MediaIndexAnchor? in
                guard let media = slice.media else { return nil }
                return MediaIndexAnchor(
                    sliceID: slice.id.uuidString,
                    kind: media.kind.rawValue,
                    label: media.label,
                    noteDigest: media.note.isEmpty ? nil : TrustDigest.checksum([media.note]),
                    containsRawMedia: false
                )
            }
        )
        let deletionRights = DeletionRightsDocument(
            exportID: plan.manifest.id,
            receiptID: deletionReceipt.id,
            scopes: deletionReceipt.scopes.map(\.rawValue).sorted(),
            userCanExportBeforeDeletion: deletionReceipt.userCanExportBeforeDeletion,
            canRequestDeletionAfterSubscriptionEnds: true
        )

        return try [
            ExportFile(path: "manifest.json", data: encode(plan.manifest, label: "manifest")),
            ExportFile(path: "memories/slices.json", data: encode(slices, label: "slices")),
            ExportFile(path: "memories/chapters.json", data: encode(chapters, label: "chapters")),
            ExportFile(path: "media/index.json", data: encode(mediaIndex, label: "media-index")),
            ExportFile(path: "rights/deletion-receipt-template.json", data: encode(deletionRights, label: "deletion-rights"))
        ].sorted { $0.path < $1.path }
    }

    private static func buildZIP(files: [ExportFile]) throws -> Data {
        var archive = Data()
        var centralDirectory = Data()
        var localHeaderOffsets: [String: UInt32] = [:]

        for file in files {
            let pathData = Data(file.path.utf8)
            guard archive.count <= Int(UInt32.max),
                  file.data.count <= Int(UInt32.max),
                  pathData.count <= Int(UInt16.max) else {
                throw ExportZIPBuilderError.zipSizeOverflow(file.path)
            }

            let offset = UInt32(archive.count)
            localHeaderOffsets[file.path] = offset
            let crc = CRC32.checksum(file.data)
            let size = UInt32(file.data.count)

            archive.appendUInt32LE(0x04034B50)
            archive.appendUInt16LE(20)
            archive.appendUInt16LE(0)
            archive.appendUInt16LE(0)
            archive.appendUInt16LE(0)
            archive.appendUInt16LE(0)
            archive.appendUInt32LE(crc)
            archive.appendUInt32LE(size)
            archive.appendUInt32LE(size)
            archive.appendUInt16LE(UInt16(pathData.count))
            archive.appendUInt16LE(0)
            archive.append(pathData)
            archive.append(file.data)

            centralDirectory.appendUInt32LE(0x02014B50)
            centralDirectory.appendUInt16LE(20)
            centralDirectory.appendUInt16LE(20)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt32LE(crc)
            centralDirectory.appendUInt32LE(size)
            centralDirectory.appendUInt32LE(size)
            centralDirectory.appendUInt16LE(UInt16(pathData.count))
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt32LE(0)
            centralDirectory.appendUInt32LE(offset)
            centralDirectory.append(pathData)
        }

        guard centralDirectory.count <= Int(UInt32.max),
              archive.count <= Int(UInt32.max),
              files.count <= Int(UInt16.max) else {
            throw ExportZIPBuilderError.zipSizeOverflow("central-directory")
        }

        let centralDirectoryOffset = UInt32(archive.count)
        archive.append(centralDirectory)
        archive.appendUInt32LE(0x06054B50)
        archive.appendUInt16LE(0)
        archive.appendUInt16LE(0)
        archive.appendUInt16LE(UInt16(files.count))
        archive.appendUInt16LE(UInt16(files.count))
        archive.appendUInt32LE(UInt32(centralDirectory.count))
        archive.appendUInt32LE(centralDirectoryOffset)
        archive.appendUInt16LE(0)

        return archive
    }
}

private struct ExportFile: Equatable {
    var path: String
    var data: Data
    var containsRawMedia: Bool
    var containsAITranscript: Bool

    init(
        path: String,
        data: Data,
        containsRawMedia: Bool = false,
        containsAITranscript: Bool = false
    ) {
        self.path = path
        self.data = data
        self.containsRawMedia = containsRawMedia
        self.containsAITranscript = containsAITranscript
    }
}

private struct MediaIndexDocument: Codable, Equatable {
    var generatedFromExportID: String
    var anchors: [MediaIndexAnchor]
}

private struct MediaIndexAnchor: Codable, Equatable {
    var sliceID: String
    var kind: String
    var label: String
    var noteDigest: String?
    var containsRawMedia: Bool
}

private struct DeletionRightsDocument: Codable, Equatable {
    var exportID: String
    var receiptID: String
    var scopes: [String]
    var userCanExportBeforeDeletion: Bool
    var canRequestDeletionAfterSubscriptionEnds: Bool
}

private enum CRC32 {
    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            var value = (crc ^ UInt32(byte)) & 0xFF
            for _ in 0..<8 {
                if value & 1 == 1 {
                    value = (value >> 1) ^ 0xEDB8_8320
                } else {
                    value >>= 1
                }
            }
            crc = (crc >> 8) ^ value
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}

public struct DeletionAPIRequest: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var method: String
    public var endpointPath: String
    public var receipt: DeletionReceipt
    public var idempotencyKey: String
    public var requiresAuthenticatedUser: Bool
    public var canBeCreatedAfterSubscriptionEnds: Bool
    public var containsRawMemoryPayload: Bool
    public var retryPolicy: String

    public init(
        id: String,
        method: String = "POST",
        endpointPath: String = "/v1/account/deletion-receipts",
        receipt: DeletionReceipt,
        idempotencyKey: String,
        requiresAuthenticatedUser: Bool = true,
        canBeCreatedAfterSubscriptionEnds: Bool = true,
        containsRawMemoryPayload: Bool = false,
        retryPolicy: String = "idempotent-retry-24h"
    ) {
        self.id = id
        self.method = method
        self.endpointPath = endpointPath
        self.receipt = receipt
        self.idempotencyKey = idempotencyKey
        self.requiresAuthenticatedUser = requiresAuthenticatedUser
        self.canBeCreatedAfterSubscriptionEnds = canBeCreatedAfterSubscriptionEnds
        self.containsRawMemoryPayload = containsRawMemoryPayload
        self.retryPolicy = retryPolicy
    }

    public static func request(for receipt: DeletionReceipt, accountID: String) -> DeletionAPIRequest {
        let key = TrustDigest.checksum([accountID, receipt.id, receipt.checksum])
        return DeletionAPIRequest(
            id: "delete-api-\(key.prefix(12))",
            receipt: receipt,
            idempotencyKey: key
        )
    }
}

public enum DeletionAPIResponseStatus: String, Codable, Equatable, Sendable {
    case accepted
    case alreadyQueued
    case requiresReauthentication
}

public struct DeletionAPIResponseContract: Codable, Equatable, Sendable {
    public var acceptedStatusCode: Int
    public var alreadyQueuedStatusCode: Int
    public var reauthenticationStatusCode: Int
    public var responseContainsRawMemoryPayload: Bool
    public var returnsDeletionReceiptID: Bool
    public var returnsAuditEventID: Bool
    public var userCanExportBeforeDeletion: Bool

    public init(
        acceptedStatusCode: Int = 202,
        alreadyQueuedStatusCode: Int = 200,
        reauthenticationStatusCode: Int = 401,
        responseContainsRawMemoryPayload: Bool = false,
        returnsDeletionReceiptID: Bool = true,
        returnsAuditEventID: Bool = true,
        userCanExportBeforeDeletion: Bool = true
    ) {
        self.acceptedStatusCode = acceptedStatusCode
        self.alreadyQueuedStatusCode = alreadyQueuedStatusCode
        self.reauthenticationStatusCode = reauthenticationStatusCode
        self.responseContainsRawMemoryPayload = responseContainsRawMemoryPayload
        self.returnsDeletionReceiptID = returnsDeletionReceiptID
        self.returnsAuditEventID = returnsAuditEventID
        self.userCanExportBeforeDeletion = userCanExportBeforeDeletion
    }
}

public struct DeletionAPIClientEnvelope: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var request: DeletionAPIRequest
    public var headers: [String: String]
    public var bodyDigest: String
    public var auditEventName: String
    public var exportFileName: String?
    public var requiresExportOpportunityBeforeSubmission: Bool
    public var userCanRetainExportAfterSubscriptionEnds: Bool
    public var transportContainsRawMemoryPayload: Bool
    public var responseContract: DeletionAPIResponseContract

    public init(
        id: String,
        request: DeletionAPIRequest,
        headers: [String: String],
        bodyDigest: String,
        auditEventName: String = "account.deletion.requested",
        exportFileName: String?,
        requiresExportOpportunityBeforeSubmission: Bool = true,
        userCanRetainExportAfterSubscriptionEnds: Bool = true,
        transportContainsRawMemoryPayload: Bool = false,
        responseContract: DeletionAPIResponseContract = DeletionAPIResponseContract()
    ) {
        self.id = id
        self.request = request
        self.headers = headers
        self.bodyDigest = bodyDigest
        self.auditEventName = auditEventName
        self.exportFileName = exportFileName
        self.requiresExportOpportunityBeforeSubmission = requiresExportOpportunityBeforeSubmission
        self.userCanRetainExportAfterSubscriptionEnds = userCanRetainExportAfterSubscriptionEnds
        self.transportContainsRawMemoryPayload = transportContainsRawMemoryPayload
        self.responseContract = responseContract
    }

    public var isPrivacyReviewSafe: Bool {
        request.requiresAuthenticatedUser &&
        request.canBeCreatedAfterSubscriptionEnds &&
        !request.containsRawMemoryPayload &&
        !transportContainsRawMemoryPayload &&
        requiresExportOpportunityBeforeSubmission &&
        userCanRetainExportAfterSubscriptionEnds &&
        responseContract.userCanExportBeforeDeletion &&
        !responseContract.responseContainsRawMemoryPayload &&
        responseContract.returnsDeletionReceiptID &&
        responseContract.returnsAuditEventID
    }
}

public enum DeletionAPIClientPlan {
    public static func envelope(
        for request: DeletionAPIRequest,
        exportPackage: ExportZIPPackage?
    ) -> DeletionAPIClientEnvelope {
        let bodyDigest = TrustDigest.checksum([
            request.id,
            request.receipt.id,
            request.receipt.checksum,
            exportPackage?.fileName ?? "no-export-package"
        ])
        return DeletionAPIClientEnvelope(
            id: "delete-envelope-\(bodyDigest.prefix(12))",
            request: request,
            headers: [
                "Content-Type": "application/json",
                "Idempotency-Key": request.idempotencyKey,
                "X-TSD-Deletion-Receipt": request.receipt.id
            ],
            bodyDigest: bodyDigest,
            exportFileName: exportPackage?.fileName,
            requiresExportOpportunityBeforeSubmission: true,
            userCanRetainExportAfterSubscriptionEnds: exportPackage?.canBeGeneratedAfterSubscriptionEnds ?? true,
            transportContainsRawMemoryPayload: false
        )
    }
}

public struct DeletionServiceResponseContract: Codable, Equatable, Sendable {
    public var acceptedStatusCode: Int
    public var completedStatusCode: Int
    public var alreadyCompletedStatusCode: Int
    public var cancellationWindowStatusCode: Int
    public var returnsDeletionReceiptID: Bool
    public var returnsAuditEventID: Bool
    public var returnsTombstoneID: Bool
    public var returnsPerSystemResults: Bool
    public var responseContainsRawMemoryPayload: Bool
    public var responseContainsRawMedia: Bool
    public var userCanDownloadReceiptAfterCompletion: Bool

    public init(
        acceptedStatusCode: Int = 202,
        completedStatusCode: Int = 200,
        alreadyCompletedStatusCode: Int = 208,
        cancellationWindowStatusCode: Int = 409,
        returnsDeletionReceiptID: Bool = true,
        returnsAuditEventID: Bool = true,
        returnsTombstoneID: Bool = true,
        returnsPerSystemResults: Bool = true,
        responseContainsRawMemoryPayload: Bool = false,
        responseContainsRawMedia: Bool = false,
        userCanDownloadReceiptAfterCompletion: Bool = true
    ) {
        self.acceptedStatusCode = acceptedStatusCode
        self.completedStatusCode = completedStatusCode
        self.alreadyCompletedStatusCode = alreadyCompletedStatusCode
        self.cancellationWindowStatusCode = cancellationWindowStatusCode
        self.returnsDeletionReceiptID = returnsDeletionReceiptID
        self.returnsAuditEventID = returnsAuditEventID
        self.returnsTombstoneID = returnsTombstoneID
        self.returnsPerSystemResults = returnsPerSystemResults
        self.responseContainsRawMemoryPayload = responseContainsRawMemoryPayload
        self.responseContainsRawMedia = responseContainsRawMedia
        self.userCanDownloadReceiptAfterCompletion = userCanDownloadReceiptAfterCompletion
    }
}

public struct DeletionServiceIntegrationEnvelope: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var clientEnvelope: DeletionAPIClientEnvelope
    public var serviceEndpointPath: String
    public var queueName: String
    public var jobID: String
    public var deletionReceiptID: String
    public var exportFileName: String?
    public var systemsToErase: [String]
    public var systemsRequiringTombstone: [String]
    public var freezesNewWritesBeforeErase: Bool
    public var requiresReauthentication: Bool
    public var requiresExportOpportunity: Bool
    public var availableAfterSubscriptionEnds: Bool
    public var containsRawMemoryPayload: Bool
    public var containsRawMedia: Bool
    public var maxCompletionHours: Int
    public var auditRetentionDays: Int
    public var backupErasePolicy: String
    public var aiDraftErasePolicy: String
    public var responseContract: DeletionServiceResponseContract

    public init(
        id: String,
        clientEnvelope: DeletionAPIClientEnvelope,
        serviceEndpointPath: String = "/v1/account/deletion-jobs",
        queueName: String = "account-deletion",
        jobID: String,
        deletionReceiptID: String,
        exportFileName: String?,
        systemsToErase: [String],
        systemsRequiringTombstone: [String],
        freezesNewWritesBeforeErase: Bool = true,
        requiresReauthentication: Bool = true,
        requiresExportOpportunity: Bool = true,
        availableAfterSubscriptionEnds: Bool = true,
        containsRawMemoryPayload: Bool = false,
        containsRawMedia: Bool = false,
        maxCompletionHours: Int = 24,
        auditRetentionDays: Int = 30,
        backupErasePolicy: String = "delete-encrypted-backup-and-next-snapshot",
        aiDraftErasePolicy: String = "purge-ai-draft-cache",
        responseContract: DeletionServiceResponseContract = DeletionServiceResponseContract()
    ) {
        self.id = id
        self.clientEnvelope = clientEnvelope
        self.serviceEndpointPath = serviceEndpointPath
        self.queueName = queueName
        self.jobID = jobID
        self.deletionReceiptID = deletionReceiptID
        self.exportFileName = exportFileName
        self.systemsToErase = systemsToErase
        self.systemsRequiringTombstone = systemsRequiringTombstone
        self.freezesNewWritesBeforeErase = freezesNewWritesBeforeErase
        self.requiresReauthentication = requiresReauthentication
        self.requiresExportOpportunity = requiresExportOpportunity
        self.availableAfterSubscriptionEnds = availableAfterSubscriptionEnds
        self.containsRawMemoryPayload = containsRawMemoryPayload
        self.containsRawMedia = containsRawMedia
        self.maxCompletionHours = maxCompletionHours
        self.auditRetentionDays = auditRetentionDays
        self.backupErasePolicy = backupErasePolicy
        self.aiDraftErasePolicy = aiDraftErasePolicy
        self.responseContract = responseContract
    }

    public var isDeletionRightsSafe: Bool {
        clientEnvelope.isPrivacyReviewSafe &&
        serviceEndpointPath == "/v1/account/deletion-jobs" &&
        !jobID.isEmpty &&
        deletionReceiptID == clientEnvelope.request.receipt.id &&
        systemsToErase.contains("encrypted-backup") &&
        systemsToErase.contains("ai-draft-cache") &&
        systemsToErase.contains("thumbnail-cache") &&
        systemsRequiringTombstone.contains("account-ledger") &&
        freezesNewWritesBeforeErase &&
        requiresReauthentication &&
        requiresExportOpportunity &&
        availableAfterSubscriptionEnds &&
        !containsRawMemoryPayload &&
        !containsRawMedia &&
        maxCompletionHours <= 24 &&
        auditRetentionDays >= 30 &&
        backupErasePolicy == "delete-encrypted-backup-and-next-snapshot" &&
        aiDraftErasePolicy == "purge-ai-draft-cache" &&
        responseContract.returnsDeletionReceiptID &&
        responseContract.returnsAuditEventID &&
        responseContract.returnsTombstoneID &&
        responseContract.returnsPerSystemResults &&
        !responseContract.responseContainsRawMemoryPayload &&
        !responseContract.responseContainsRawMedia &&
        responseContract.userCanDownloadReceiptAfterCompletion
    }
}

public enum DeletionServiceIntegrationPlan {
    public static func envelope(for clientEnvelope: DeletionAPIClientEnvelope) -> DeletionServiceIntegrationEnvelope {
        let digest = TrustDigest.checksum([
            clientEnvelope.id,
            clientEnvelope.request.receipt.id,
            clientEnvelope.request.idempotencyKey,
            clientEnvelope.exportFileName ?? "no-export-file"
        ])
        return DeletionServiceIntegrationEnvelope(
            id: "deletion-service-\(digest.prefix(12))",
            clientEnvelope: clientEnvelope,
            jobID: "delete-job-\(digest.prefix(12))",
            deletionReceiptID: clientEnvelope.request.receipt.id,
            exportFileName: clientEnvelope.exportFileName,
            systemsToErase: clientEnvelope.request.receipt.affectedRemoteSystems.sorted(),
            systemsRequiringTombstone: ["account-ledger", "billing-entitlement-ledger"]
        )
    }
}

public enum ProductionImplementationChecklist {
    public static let rows: [ReadinessRow] = [
        .init(id: "keychain-persistence-plan", title: "Keychain persistence plan", status: .poc, owner: "iOS", evidence: "Device key storage plan uses this-device-only Keychain defaults and no access group until Team ID exists; v41 adds a Security.framework Keychain record store adapter."),
        .init(id: "deepseek-gateway-request", title: "DeepSeek gateway request", status: .poc, owner: "backend/AI", evidence: "Client request targets TSD backend, never carries provider API key, keeps local-rules fallback, and v46 adds a server gateway envelope with budget, consent, retention, data residency, and mockable response contracts."),
        .init(id: "export-archive-plan", title: "Export archive plan", status: .poc, owner: "iOS/backend", evidence: "ZIP package plan includes manifest/slices/chapters/media index/deletion rights and remains available after subscription ends; v42 adds an on-device store-only ZIP builder."),
        .init(id: "deletion-api-request", title: "Deletion API request", status: .poc, owner: "backend/legal", evidence: "Deletion receipt request is idempotent, authenticated, raw-memory-free, available after subscription ends; v45 adds a privacy-review-safe client audit envelope and v47 adds a deletion service integration boundary.")
    ]
}
