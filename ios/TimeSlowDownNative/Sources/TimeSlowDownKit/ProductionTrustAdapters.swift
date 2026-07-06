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

public enum ProductionImplementationChecklist {
    public static let rows: [ReadinessRow] = [
        .init(id: "keychain-persistence-plan", title: "Keychain persistence plan", status: .poc, owner: "iOS", evidence: "Device key storage plan uses this-device-only Keychain defaults and no access group until Team ID exists; v41 adds a Security.framework Keychain record store adapter."),
        .init(id: "deepseek-gateway-request", title: "DeepSeek gateway request", status: .poc, owner: "backend/AI", evidence: "Client request targets TSD backend, never carries provider API key, and keeps local-rules fallback."),
        .init(id: "export-archive-plan", title: "Export archive plan", status: .poc, owner: "iOS/backend", evidence: "ZIP package plan includes manifest/slices/chapters/media index/deletion rights and remains available after subscription ends."),
        .init(id: "deletion-api-request", title: "Deletion API request", status: .poc, owner: "backend/legal", evidence: "Deletion receipt request is idempotent, authenticated, raw-memory-free, and available after subscription ends.")
    ]
}
