import Foundation

public enum ProductionTrustLevel: String, Codable, Equatable, Sendable {
    case developmentStub
    case productionRequired
}

public enum TrustDigest {
    public static func checksum(_ parts: [String]) -> String {
        let joined = parts.joined(separator: "\u{1F}")
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in joined.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }
}

public struct DeviceKeyRecord: Codable, Equatable, Sendable {
    public var keyID: String
    public var accountID: String
    public var deviceName: String
    public var storageClass: String
    public var createdAt: Date
    public var trustLevel: ProductionTrustLevel
    public var privateKeyExtractable: Bool
    public var secretMaterialPersistedInRepo: Bool

    public init(
        keyID: String,
        accountID: String,
        deviceName: String,
        storageClass: String = "keychain-this-device-only",
        createdAt: Date = Date(),
        trustLevel: ProductionTrustLevel = .developmentStub,
        privateKeyExtractable: Bool = false,
        secretMaterialPersistedInRepo: Bool = false
    ) {
        self.keyID = keyID
        self.accountID = accountID
        self.deviceName = deviceName
        self.storageClass = storageClass
        self.createdAt = createdAt
        self.trustLevel = trustLevel
        self.privateKeyExtractable = privateKeyExtractable
        self.secretMaterialPersistedInRepo = secretMaterialPersistedInRepo
    }
}

public enum KeychainVaultStub {
    public static func bootstrapDeviceKey(
        accountID: String,
        deviceName: String,
        createdAt: Date = Date()
    ) -> DeviceKeyRecord {
        let keyID = "tsd-device-\(TrustDigest.checksum([accountID, deviceName]).prefix(12))"
        return DeviceKeyRecord(
            keyID: String(keyID),
            accountID: accountID,
            deviceName: deviceName,
            createdAt: createdAt
        )
    }
}

public struct E2EEEnvelope: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var keyID: String
    public var algorithm: String
    public var plaintextPolicy: String
    public var containsRawMemoryBody: Bool
    public var containsRawMedia: Bool
    public var additionalAuthenticatedData: [String]
    public var ciphertextDigest: String
    public var trustLevel: ProductionTrustLevel

    public init(
        id: String,
        keyID: String,
        algorithm: String = "sealed-box-contract-v1-production-required",
        plaintextPolicy: String = "metadata-only-development-envelope",
        containsRawMemoryBody: Bool = false,
        containsRawMedia: Bool = false,
        additionalAuthenticatedData: [String],
        ciphertextDigest: String,
        trustLevel: ProductionTrustLevel = .developmentStub
    ) {
        self.id = id
        self.keyID = keyID
        self.algorithm = algorithm
        self.plaintextPolicy = plaintextPolicy
        self.containsRawMemoryBody = containsRawMemoryBody
        self.containsRawMedia = containsRawMedia
        self.additionalAuthenticatedData = additionalAuthenticatedData
        self.ciphertextDigest = ciphertextDigest
        self.trustLevel = trustLevel
    }

    public static func sealMetadataOnly(_ slice: MemorySlice, with key: DeviceKeyRecord) -> E2EEEnvelope {
        let mediaKind = slice.media?.kind.rawValue ?? "none"
        let aad = [
            "slice:\(slice.id.uuidString)",
            "media-kind:\(mediaKind)",
            "sources:\(slice.sources.sorted().joined(separator: ","))"
        ]
        return E2EEEnvelope(
            id: "env-\(TrustDigest.checksum(aad).prefix(12))",
            keyID: key.keyID,
            additionalAuthenticatedData: aad,
            ciphertextDigest: TrustDigest.checksum([key.keyID] + aad)
        )
    }
}

public struct ExportPackageManifest: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var generatedAt: Date
    public var sliceCount: Int
    public var mediaAnchorCount: Int
    public var chapterCount: Int
    public var includesRawMedia: Bool
    public var includesAITranscripts: Bool
    public var userCanExportWithoutSubscription: Bool
    public var checksum: String
    public var signature: String
    public var trustLevel: ProductionTrustLevel

    public init(
        id: String,
        generatedAt: Date = Date(),
        sliceCount: Int,
        mediaAnchorCount: Int,
        chapterCount: Int,
        includesRawMedia: Bool,
        includesAITranscripts: Bool,
        userCanExportWithoutSubscription: Bool,
        checksum: String,
        signature: String,
        trustLevel: ProductionTrustLevel = .developmentStub
    ) {
        self.id = id
        self.generatedAt = generatedAt
        self.sliceCount = sliceCount
        self.mediaAnchorCount = mediaAnchorCount
        self.chapterCount = chapterCount
        self.includesRawMedia = includesRawMedia
        self.includesAITranscripts = includesAITranscripts
        self.userCanExportWithoutSubscription = userCanExportWithoutSubscription
        self.checksum = checksum
        self.signature = signature
        self.trustLevel = trustLevel
    }
}

public enum ExportManifestSigner {
    public static func sign(
        slices: [MemorySlice],
        chapters: [WeeklyChapter],
        with key: DeviceKeyRecord,
        generatedAt: Date = Date()
    ) -> ExportPackageManifest {
        let stableParts = slices.map(\.id.uuidString).sorted() + chapters.map(\.title).sorted()
        let checksum = TrustDigest.checksum(stableParts)
        let signature = "stub-signature-v1:\(TrustDigest.checksum([key.keyID, checksum]))"
        return ExportPackageManifest(
            id: "export-\(checksum.prefix(12))",
            generatedAt: generatedAt,
            sliceCount: slices.count,
            mediaAnchorCount: slices.filter(\.hasMediaAnchor).count,
            chapterCount: chapters.count,
            includesRawMedia: false,
            includesAITranscripts: false,
            userCanExportWithoutSubscription: true,
            checksum: checksum,
            signature: signature
        )
    }
}

public enum DeletionScope: String, Codable, Equatable, CaseIterable, Sendable {
    case localCache
    case encryptedCloudBackup
    case aiDrafts
    case mediaThumbnails
}

public enum DeletionReceiptStatus: String, Codable, Equatable, Sendable {
    case accepted
    case completed
}

public struct DeletionReceipt: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var requestedAt: Date
    public var scopes: [DeletionScope]
    public var status: DeletionReceiptStatus
    public var retentionWindowDays: Int
    public var userCanExportBeforeDeletion: Bool
    public var affectedRemoteSystems: [String]
    public var checksum: String

    public init(
        id: String,
        requestedAt: Date = Date(),
        scopes: [DeletionScope],
        status: DeletionReceiptStatus,
        retentionWindowDays: Int,
        userCanExportBeforeDeletion: Bool,
        affectedRemoteSystems: [String],
        checksum: String
    ) {
        self.id = id
        self.requestedAt = requestedAt
        self.scopes = scopes
        self.status = status
        self.retentionWindowDays = retentionWindowDays
        self.userCanExportBeforeDeletion = userCanExportBeforeDeletion
        self.affectedRemoteSystems = affectedRemoteSystems
        self.checksum = checksum
    }

    public static func issue(
        scopes: [DeletionScope],
        requestedAt: Date = Date(),
        retentionWindowDays: Int = 7
    ) -> DeletionReceipt {
        let scopeIDs = scopes.map(\.rawValue).sorted()
        let checksum = TrustDigest.checksum(scopeIDs + ["retention:\(retentionWindowDays)"])
        return DeletionReceipt(
            id: "delete-\(checksum.prefix(12))",
            requestedAt: requestedAt,
            scopes: scopes,
            status: .accepted,
            retentionWindowDays: retentionWindowDays,
            userCanExportBeforeDeletion: true,
            affectedRemoteSystems: ["encrypted-backup", "ai-draft-cache", "thumbnail-cache"],
            checksum: checksum
        )
    }
}

public enum DeepSeekTaskPurpose: String, Codable, Equatable, Sendable {
    case weeklyChapterDraft
    case memoryRecallPrompt
}

public struct DeepSeekTaskEnvelope: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var provider: String
    public var model: String
    public var purpose: DeepSeekTaskPurpose
    public var allowedPayloadKeys: [String]
    public var forbiddenPayloadKeys: [String]
    public var containsRawMedia: Bool
    public var containsFullMemoryArchive: Bool
    public var userConsentRequired: Bool
    public var maxBudgetCents: Int
    public var fallbackMode: String
    public var minimalPayloadDigest: String
    public var trustLevel: ProductionTrustLevel

    public init(
        id: String,
        provider: String = "deepseek",
        model: String = "deepseek-v4-flash",
        purpose: DeepSeekTaskPurpose,
        allowedPayloadKeys: [String],
        forbiddenPayloadKeys: [String],
        containsRawMedia: Bool = false,
        containsFullMemoryArchive: Bool = false,
        userConsentRequired: Bool = true,
        maxBudgetCents: Int,
        fallbackMode: String = "local-rules",
        minimalPayloadDigest: String,
        trustLevel: ProductionTrustLevel = .developmentStub
    ) {
        self.id = id
        self.provider = provider
        self.model = model
        self.purpose = purpose
        self.allowedPayloadKeys = allowedPayloadKeys
        self.forbiddenPayloadKeys = forbiddenPayloadKeys
        self.containsRawMedia = containsRawMedia
        self.containsFullMemoryArchive = containsFullMemoryArchive
        self.userConsentRequired = userConsentRequired
        self.maxBudgetCents = maxBudgetCents
        self.fallbackMode = fallbackMode
        self.minimalPayloadDigest = minimalPayloadDigest
        self.trustLevel = trustLevel
    }

    public static func weeklyChapterDraft(
        claimed slices: [MemorySlice],
        maxBudgetCents: Int = 4
    ) -> DeepSeekTaskEnvelope {
        let claimed = Array(slices.prefix(3))
        let digestParts = claimed.flatMap { slice in
            [
                "slice:\(slice.id.uuidString)",
                "title:\(slice.title)",
                "tags:\(slice.tags.sorted().joined(separator: ","))",
                "media:\(slice.media?.kind.rawValue ?? "none")"
            ]
        }
        let digest = TrustDigest.checksum(digestParts)
        return DeepSeekTaskEnvelope(
            id: "ai-week-\(digest.prefix(12))",
            purpose: .weeklyChapterDraft,
            allowedPayloadKeys: ["slice_ids", "titles", "tags", "media_kinds", "user_selected_claims"],
            forbiddenPayloadKeys: ["raw_media_binary", "full_memory_archive", "contacts", "gps_trace", "face_embeddings", "subscription_state"],
            maxBudgetCents: maxBudgetCents,
            minimalPayloadDigest: digest
        )
    }
}

public enum ProductionTrustChecklist {
    public static let rows: [ReadinessRow] = [
        .init(id: "device-key-record", title: "Device key record", status: .poc, owner: "iOS", evidence: "Keychain-shaped record with non-extractable key contract; real Secure Enclave/Keychain storage still required."),
        .init(id: "e2ee-envelope", title: "E2EE envelope", status: .poc, owner: "iOS/backend", evidence: "Metadata-only sealed-envelope contract; production cryptography still required."),
        .init(id: "export-manifest-signature", title: "Export manifest signature", status: .poc, owner: "iOS/backend", evidence: "Deterministic manifest checksum/signature stub; export remains available without subscription."),
        .init(id: "deletion-receipt", title: "Deletion receipt", status: .poc, owner: "backend/legal", evidence: "Deletion scope, retention window, affected systems, and pre-deletion export right are explicit."),
        .init(id: "deepseek-task-envelope", title: "DeepSeek task envelope", status: .poc, owner: "backend/AI", evidence: "deepseek-v4-flash task contract sends only minimal fields and forbids raw media/full archive.")
    ]
}
