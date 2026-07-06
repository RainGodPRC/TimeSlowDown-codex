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

public enum RawMediaExportMode: String, Codable, Equatable, Sendable {
    case thumbnailsOnly
    case selectedOriginals
}

public struct RawMediaExportSelection: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var mode: RawMediaExportMode
    public var selectedAnchorIDs: [String]
    public var userExplicitlyOptedIn: Bool
    public var consentReceiptID: String?
    public var includesAITranscripts: Bool
    public var requestedBy: String
    public var canBeGeneratedAfterSubscriptionEnds: Bool

    public init(
        id: String,
        mode: RawMediaExportMode,
        selectedAnchorIDs: [String],
        userExplicitlyOptedIn: Bool = false,
        consentReceiptID: String? = nil,
        includesAITranscripts: Bool = false,
        requestedBy: String = "account-rights-export",
        canBeGeneratedAfterSubscriptionEnds: Bool = true
    ) {
        self.id = id
        self.mode = mode
        self.selectedAnchorIDs = selectedAnchorIDs
        self.userExplicitlyOptedIn = userExplicitlyOptedIn
        self.consentReceiptID = consentReceiptID
        self.includesAITranscripts = includesAITranscripts
        self.requestedBy = requestedBy
        self.canBeGeneratedAfterSubscriptionEnds = canBeGeneratedAfterSubscriptionEnds
    }

    public var allowsRawOriginals: Bool {
        mode == .selectedOriginals &&
        userExplicitlyOptedIn &&
        consentReceiptID != nil &&
        !selectedAnchorIDs.isEmpty &&
        !includesAITranscripts
    }
}

public struct RawMediaExportManifestItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String { anchorID }
    public var anchorID: String
    public var sliceID: String
    public var kind: MediaKind
    public var label: String
    public var thumbnailPath: String
    public var originalPath: String?
    public var includesRawOriginal: Bool
    public var requiresFamilyMediaReview: Bool
    public var checksum: String

    public init(
        anchorID: String,
        sliceID: String,
        kind: MediaKind,
        label: String,
        thumbnailPath: String,
        originalPath: String?,
        includesRawOriginal: Bool,
        requiresFamilyMediaReview: Bool,
        checksum: String
    ) {
        self.anchorID = anchorID
        self.sliceID = sliceID
        self.kind = kind
        self.label = label
        self.thumbnailPath = thumbnailPath
        self.originalPath = originalPath
        self.includesRawOriginal = includesRawOriginal
        self.requiresFamilyMediaReview = requiresFamilyMediaReview
        self.checksum = checksum
    }
}

public struct RawMediaExportResponseContract: Codable, Equatable, Sendable {
    public var stagedStatusCode: Int
    public var completedStatusCode: Int
    public var storageLimitStatusCode: Int
    public var returnsMediaManifest: Bool
    public var returnsExportReceiptID: Bool
    public var returnsStagedFileToken: Bool
    public var responseContainsProviderCredential: Bool
    public var responseContainsAITranscript: Bool
    public var uploadsToCloudByDefault: Bool
    public var userCanCancelStaging: Bool
    public var supportsResume: Bool

    public init(
        stagedStatusCode: Int = 202,
        completedStatusCode: Int = 200,
        storageLimitStatusCode: Int = 413,
        returnsMediaManifest: Bool = true,
        returnsExportReceiptID: Bool = true,
        returnsStagedFileToken: Bool = true,
        responseContainsProviderCredential: Bool = false,
        responseContainsAITranscript: Bool = false,
        uploadsToCloudByDefault: Bool = false,
        userCanCancelStaging: Bool = true,
        supportsResume: Bool = true
    ) {
        self.stagedStatusCode = stagedStatusCode
        self.completedStatusCode = completedStatusCode
        self.storageLimitStatusCode = storageLimitStatusCode
        self.returnsMediaManifest = returnsMediaManifest
        self.returnsExportReceiptID = returnsExportReceiptID
        self.returnsStagedFileToken = returnsStagedFileToken
        self.responseContainsProviderCredential = responseContainsProviderCredential
        self.responseContainsAITranscript = responseContainsAITranscript
        self.uploadsToCloudByDefault = uploadsToCloudByDefault
        self.userCanCancelStaging = userCanCancelStaging
        self.supportsResume = supportsResume
    }
}

public struct RawMediaExportPolicyEnvelope: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var baseArchivePlan: ExportArchivePlan
    public var selection: RawMediaExportSelection
    public var manifestPath: String
    public var thumbnailDirectoryPath: String
    public var rawOriginalDirectoryPath: String
    public var manifestItems: [RawMediaExportManifestItem]
    public var encryptionPolicy: String
    public var stagingPolicy: String
    public var maxStageSizeMB: Int
    public var defaultIncludesRawOriginals: Bool
    public var includesRawOriginals: Bool
    public var includesAITranscripts: Bool
    public var generatedOnDevice: Bool
    public var cloudUploadRequired: Bool
    public var syncRequired: Bool
    public var providerUploadRequired: Bool
    public var canBeGeneratedAfterSubscriptionEnds: Bool
    public var postSubscriptionAccessAllowed: Bool
    public var childOrFamilyMediaCaution: Bool
    public var filesAppExportReady: Bool
    public var auditEventName: String
    public var responseContract: RawMediaExportResponseContract

    public init(
        id: String,
        baseArchivePlan: ExportArchivePlan,
        selection: RawMediaExportSelection,
        manifestPath: String = "media/raw-media-manifest.json",
        thumbnailDirectoryPath: String = "media/thumbnails/",
        rawOriginalDirectoryPath: String = "media/originals/",
        manifestItems: [RawMediaExportManifestItem],
        encryptionPolicy: String = "device-key-encrypted-staging",
        stagingPolicy: String = "staged-files-export-with-user-confirmation",
        maxStageSizeMB: Int = 2048,
        defaultIncludesRawOriginals: Bool = false,
        includesRawOriginals: Bool,
        includesAITranscripts: Bool = false,
        generatedOnDevice: Bool = true,
        cloudUploadRequired: Bool = false,
        syncRequired: Bool = false,
        providerUploadRequired: Bool = false,
        canBeGeneratedAfterSubscriptionEnds: Bool = true,
        postSubscriptionAccessAllowed: Bool = true,
        childOrFamilyMediaCaution: Bool,
        filesAppExportReady: Bool = true,
        auditEventName: String = "export.raw_media.policy_reviewed",
        responseContract: RawMediaExportResponseContract = RawMediaExportResponseContract()
    ) {
        self.id = id
        self.baseArchivePlan = baseArchivePlan
        self.selection = selection
        self.manifestPath = manifestPath
        self.thumbnailDirectoryPath = thumbnailDirectoryPath
        self.rawOriginalDirectoryPath = rawOriginalDirectoryPath
        self.manifestItems = manifestItems
        self.encryptionPolicy = encryptionPolicy
        self.stagingPolicy = stagingPolicy
        self.maxStageSizeMB = maxStageSizeMB
        self.defaultIncludesRawOriginals = defaultIncludesRawOriginals
        self.includesRawOriginals = includesRawOriginals
        self.includesAITranscripts = includesAITranscripts
        self.generatedOnDevice = generatedOnDevice
        self.cloudUploadRequired = cloudUploadRequired
        self.syncRequired = syncRequired
        self.providerUploadRequired = providerUploadRequired
        self.canBeGeneratedAfterSubscriptionEnds = canBeGeneratedAfterSubscriptionEnds
        self.postSubscriptionAccessAllowed = postSubscriptionAccessAllowed
        self.childOrFamilyMediaCaution = childOrFamilyMediaCaution
        self.filesAppExportReady = filesAppExportReady
        self.auditEventName = auditEventName
        self.responseContract = responseContract
    }

    public var isMemoryRightsSafe: Bool {
        baseArchivePlan.generatedOnDevice &&
        baseArchivePlan.canBeGeneratedAfterSubscriptionEnds &&
        baseArchivePlan.entries.allSatisfy { !$0.containsRawMedia && !$0.containsAITranscript } &&
        !baseArchivePlan.manifest.includesRawMedia &&
        !baseArchivePlan.manifest.includesAITranscripts &&
        selection.canBeGeneratedAfterSubscriptionEnds &&
        generatedOnDevice &&
        !cloudUploadRequired &&
        !syncRequired &&
        !providerUploadRequired &&
        canBeGeneratedAfterSubscriptionEnds &&
        postSubscriptionAccessAllowed &&
        !defaultIncludesRawOriginals &&
        !includesAITranscripts &&
        maxStageSizeMB <= 2048 &&
        encryptionPolicy == "device-key-encrypted-staging" &&
        stagingPolicy == "staged-files-export-with-user-confirmation" &&
        filesAppExportReady &&
        responseContract.returnsMediaManifest &&
        responseContract.returnsExportReceiptID &&
        responseContract.returnsStagedFileToken &&
        !responseContract.responseContainsProviderCredential &&
        !responseContract.responseContainsAITranscript &&
        !responseContract.uploadsToCloudByDefault &&
        responseContract.userCanCancelStaging &&
        responseContract.supportsResume &&
        (!includesRawOriginals || selection.allowsRawOriginals) &&
        manifestItems.allSatisfy { $0.includesRawOriginal == ($0.originalPath != nil) }
    }
}

public enum RawMediaExportPolicyPlan {
    public static func thumbnailsOnlyEnvelope(
        for baseArchivePlan: ExportArchivePlan,
        slices: [MemorySlice]
    ) -> RawMediaExportPolicyEnvelope {
        let selection = RawMediaExportSelection(
            id: "raw-media-selection-thumbnails-\(baseArchivePlan.id)",
            mode: .thumbnailsOnly,
            selectedAnchorIDs: [],
            userExplicitlyOptedIn: false
        )
        return envelope(for: baseArchivePlan, slices: slices, selection: selection)
    }

    public static func selectedOriginalsEnvelope(
        for baseArchivePlan: ExportArchivePlan,
        slices: [MemorySlice],
        selectedAnchorIDs: [String],
        consentReceiptID: String
    ) -> RawMediaExportPolicyEnvelope {
        let selection = RawMediaExportSelection(
            id: "raw-media-selection-originals-\(baseArchivePlan.id)",
            mode: .selectedOriginals,
            selectedAnchorIDs: selectedAnchorIDs.sorted(),
            userExplicitlyOptedIn: true,
            consentReceiptID: consentReceiptID
        )
        return envelope(for: baseArchivePlan, slices: slices, selection: selection)
    }

    private static func envelope(
        for baseArchivePlan: ExportArchivePlan,
        slices: [MemorySlice],
        selection: RawMediaExportSelection
    ) -> RawMediaExportPolicyEnvelope {
        let items = slices.compactMap { slice -> RawMediaExportManifestItem? in
            guard let media = slice.media else { return nil }
            let anchorID = media.id.uuidString
            let canIncludeOriginal = selection.allowsRawOriginals &&
                selection.selectedAnchorIDs.contains(anchorID) &&
                media.kind != .link
            let familyReview = slice.tags.contains { tag in
                ["家人", "孩子", "family", "child"].contains(tag.localizedLowercase)
            } || media.note.localizedCaseInsensitiveContains("孩子")
            let checksum = TrustDigest.checksum([
                slice.id.uuidString,
                anchorID,
                media.kind.rawValue,
                media.label,
                canIncludeOriginal ? "original" : "thumbnail"
            ])
            return RawMediaExportManifestItem(
                anchorID: anchorID,
                sliceID: slice.id.uuidString,
                kind: media.kind,
                label: media.label,
                thumbnailPath: "media/thumbnails/\(anchorID).jpg",
                originalPath: canIncludeOriginal ? "media/originals/\(anchorID)-\(safeFilename(media.label))" : nil,
                includesRawOriginal: canIncludeOriginal,
                requiresFamilyMediaReview: familyReview,
                checksum: checksum
            )
        }.sorted { $0.anchorID < $1.anchorID }
        let includesRawOriginals = items.contains { $0.includesRawOriginal }
        let digest = TrustDigest.checksum([
            baseArchivePlan.id,
            selection.id,
            selection.mode.rawValue,
            items.map(\.checksum).joined(separator: "|")
        ])
        return RawMediaExportPolicyEnvelope(
            id: "raw-media-export-\(digest.prefix(12))",
            baseArchivePlan: baseArchivePlan,
            selection: selection,
            manifestItems: items,
            includesRawOriginals: includesRawOriginals,
            includesAITranscripts: selection.includesAITranscripts,
            childOrFamilyMediaCaution: items.contains { $0.requiresFamilyMediaReview }
        )
    }

    private static func safeFilename(_ label: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        let scalars = label.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let sanitized = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-."))
        return sanitized.isEmpty ? "media-original" : sanitized
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

public struct RawMediaAssetPayload: Codable, Equatable, Identifiable, Sendable {
    public var id: String { anchorID }
    public var anchorID: String
    public var thumbnailData: Data
    public var originalData: Data?

    public init(anchorID: String, thumbnailData: Data, originalData: Data? = nil) {
        self.anchorID = anchorID
        self.thumbnailData = thumbnailData
        self.originalData = originalData
    }
}

public struct E2EEMediaVaultSealRequest: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var payload: RawMediaAssetPayload
    public var deviceKey: DeviceKeyRecord
    public var sourceRequestID: String?
    public var consentReceiptID: String?
    public var createdAt: Date
    public var algorithm: String
    public var storagePolicy: String
    public var storesPlaintextThumbnail: Bool
    public var storesPlaintextOriginal: Bool
    public var uploadsToCloud: Bool
    public var allowsAIProviderAccess: Bool
    public var canExportAfterSubscriptionEnds: Bool
    public var canDeleteAfterSubscriptionEnds: Bool
    public var trustLevel: ProductionTrustLevel

    public init(
        id: String,
        payload: RawMediaAssetPayload,
        deviceKey: DeviceKeyRecord,
        sourceRequestID: String? = nil,
        consentReceiptID: String? = nil,
        createdAt: Date = Date(),
        algorithm: String = "tsd-media-vault-xor-poc-production-crypto-required",
        storagePolicy: String = "local-device-e2ee-media-vault",
        storesPlaintextThumbnail: Bool = false,
        storesPlaintextOriginal: Bool = false,
        uploadsToCloud: Bool = false,
        allowsAIProviderAccess: Bool = false,
        canExportAfterSubscriptionEnds: Bool = true,
        canDeleteAfterSubscriptionEnds: Bool = true,
        trustLevel: ProductionTrustLevel = .developmentStub
    ) {
        self.id = id
        self.payload = payload
        self.deviceKey = deviceKey
        self.sourceRequestID = sourceRequestID
        self.consentReceiptID = consentReceiptID
        self.createdAt = createdAt
        self.algorithm = algorithm
        self.storagePolicy = storagePolicy
        self.storesPlaintextThumbnail = storesPlaintextThumbnail
        self.storesPlaintextOriginal = storesPlaintextOriginal
        self.uploadsToCloud = uploadsToCloud
        self.allowsAIProviderAccess = allowsAIProviderAccess
        self.canExportAfterSubscriptionEnds = canExportAfterSubscriptionEnds
        self.canDeleteAfterSubscriptionEnds = canDeleteAfterSubscriptionEnds
        self.trustLevel = trustLevel
    }

    public var isTSDMediaVaultSealSafe: Bool {
        !payload.thumbnailData.isEmpty &&
        deviceKey.storageClass == "keychain-this-device-only" &&
        !deviceKey.privateKeyExtractable &&
        !deviceKey.secretMaterialPersistedInRepo &&
        storagePolicy == "local-device-e2ee-media-vault" &&
        !storesPlaintextThumbnail &&
        !storesPlaintextOriginal &&
        !uploadsToCloud &&
        !allowsAIProviderAccess &&
        canExportAfterSubscriptionEnds &&
        canDeleteAfterSubscriptionEnds
    }
}

public struct E2EEMediaVaultRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var anchorID: String
    public var keyID: String
    public var sourceRequestID: String?
    public var consentReceiptID: String?
    public var createdAt: Date
    public var algorithm: String
    public var nonce: String
    public var additionalAuthenticatedData: [String]
    public var thumbnailCiphertext: Data
    public var originalCiphertext: Data?
    public var thumbnailDigest: String
    public var originalDigest: String?
    public var rawPlaintextPersistedInRecord: Bool
    public var uploadsToCloud: Bool
    public var allowsAIProviderAccess: Bool
    public var canExportAfterSubscriptionEnds: Bool
    public var canDeleteAfterSubscriptionEnds: Bool
    public var trustLevel: ProductionTrustLevel

    public init(
        id: String,
        anchorID: String,
        keyID: String,
        sourceRequestID: String?,
        consentReceiptID: String?,
        createdAt: Date,
        algorithm: String,
        nonce: String,
        additionalAuthenticatedData: [String],
        thumbnailCiphertext: Data,
        originalCiphertext: Data?,
        thumbnailDigest: String,
        originalDigest: String?,
        rawPlaintextPersistedInRecord: Bool = false,
        uploadsToCloud: Bool = false,
        allowsAIProviderAccess: Bool = false,
        canExportAfterSubscriptionEnds: Bool = true,
        canDeleteAfterSubscriptionEnds: Bool = true,
        trustLevel: ProductionTrustLevel = .developmentStub
    ) {
        self.id = id
        self.anchorID = anchorID
        self.keyID = keyID
        self.sourceRequestID = sourceRequestID
        self.consentReceiptID = consentReceiptID
        self.createdAt = createdAt
        self.algorithm = algorithm
        self.nonce = nonce
        self.additionalAuthenticatedData = additionalAuthenticatedData
        self.thumbnailCiphertext = thumbnailCiphertext
        self.originalCiphertext = originalCiphertext
        self.thumbnailDigest = thumbnailDigest
        self.originalDigest = originalDigest
        self.rawPlaintextPersistedInRecord = rawPlaintextPersistedInRecord
        self.uploadsToCloud = uploadsToCloud
        self.allowsAIProviderAccess = allowsAIProviderAccess
        self.canExportAfterSubscriptionEnds = canExportAfterSubscriptionEnds
        self.canDeleteAfterSubscriptionEnds = canDeleteAfterSubscriptionEnds
        self.trustLevel = trustLevel
    }

    public var containsOriginalCiphertext: Bool {
        originalCiphertext?.isEmpty == false
    }

    public var isTSDMediaVaultSafe: Bool {
        !anchorID.isEmpty &&
        keyID.hasPrefix("tsd-device-") &&
        algorithm == "tsd-media-vault-xor-poc-production-crypto-required" &&
        !nonce.isEmpty &&
        additionalAuthenticatedData.contains("anchor:\(anchorID)") &&
        !thumbnailCiphertext.isEmpty &&
        !thumbnailDigest.isEmpty &&
        !rawPlaintextPersistedInRecord &&
        !uploadsToCloud &&
        !allowsAIProviderAccess &&
        canExportAfterSubscriptionEnds &&
        canDeleteAfterSubscriptionEnds
    }
}

public struct E2EEMediaVaultDeletionReceipt: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var recordID: String
    public var anchorID: String
    public var keyID: String
    public var deletedAt: Date
    public var deletedLocalCiphertext: Bool
    public var deletedThumbnailCiphertext: Bool
    public var deletedOriginalCiphertext: Bool
    public var canBeRequestedAfterSubscriptionEnds: Bool
    public var containsRawMediaPayload: Bool

    public init(
        id: String,
        recordID: String,
        anchorID: String,
        keyID: String,
        deletedAt: Date = Date(),
        deletedLocalCiphertext: Bool = true,
        deletedThumbnailCiphertext: Bool = true,
        deletedOriginalCiphertext: Bool = true,
        canBeRequestedAfterSubscriptionEnds: Bool = true,
        containsRawMediaPayload: Bool = false
    ) {
        self.id = id
        self.recordID = recordID
        self.anchorID = anchorID
        self.keyID = keyID
        self.deletedAt = deletedAt
        self.deletedLocalCiphertext = deletedLocalCiphertext
        self.deletedThumbnailCiphertext = deletedThumbnailCiphertext
        self.deletedOriginalCiphertext = deletedOriginalCiphertext
        self.canBeRequestedAfterSubscriptionEnds = canBeRequestedAfterSubscriptionEnds
        self.containsRawMediaPayload = containsRawMediaPayload
    }

    public var isTSDMediaDeletionSafe: Bool {
        deletedLocalCiphertext &&
        deletedThumbnailCiphertext &&
        deletedOriginalCiphertext &&
        canBeRequestedAfterSubscriptionEnds &&
        !containsRawMediaPayload
    }
}

public enum E2EEMediaVaultAdapterError: Error, Equatable, Sendable {
    case unsafeSealRequest(String)
    case unsafeRecord(String)
    case wrongDeviceKey(String)
    case integrityCheckFailed(String)
}

public enum E2EEMediaVaultAdapter {
    public static func sealRequest(
        payload: RawMediaAssetPayload,
        deviceKey: DeviceKeyRecord,
        sourceRequestID: String? = nil,
        consentReceiptID: String? = nil,
        createdAt: Date = Date()
    ) -> E2EEMediaVaultSealRequest {
        let digest = TrustDigest.checksum([
            payload.anchorID,
            deviceKey.keyID,
            sourceRequestID ?? "no-source-request",
            consentReceiptID ?? "no-consent",
            "\(payload.thumbnailData.count)",
            "\(payload.originalData?.count ?? 0)"
        ])
        return E2EEMediaVaultSealRequest(
            id: "media-vault-seal-\(digest.prefix(12))",
            payload: payload,
            deviceKey: deviceKey,
            sourceRequestID: sourceRequestID,
            consentReceiptID: consentReceiptID,
            createdAt: createdAt
        )
    }

    public static func seal(_ request: E2EEMediaVaultSealRequest) throws -> E2EEMediaVaultRecord {
        guard request.isTSDMediaVaultSealSafe else {
            throw E2EEMediaVaultAdapterError.unsafeSealRequest(request.id)
        }
        let aad = additionalAuthenticatedData(for: request)
        let nonce = TrustDigest.checksum([request.id, request.deviceKey.keyID] + aad)
        let thumbnailCiphertext = crypt(
            request.payload.thumbnailData,
            keyID: request.deviceKey.keyID,
            nonce: nonce,
            label: "thumbnail"
        )
        let originalCiphertext = request.payload.originalData.map {
            crypt($0, keyID: request.deviceKey.keyID, nonce: nonce, label: "original")
        }
        return E2EEMediaVaultRecord(
            id: "media-vault-\(nonce.prefix(12))",
            anchorID: request.payload.anchorID,
            keyID: request.deviceKey.keyID,
            sourceRequestID: request.sourceRequestID,
            consentReceiptID: request.consentReceiptID,
            createdAt: request.createdAt,
            algorithm: request.algorithm,
            nonce: nonce,
            additionalAuthenticatedData: aad,
            thumbnailCiphertext: thumbnailCiphertext,
            originalCiphertext: originalCiphertext,
            thumbnailDigest: dataDigest(request.payload.thumbnailData),
            originalDigest: request.payload.originalData.map(dataDigest)
        )
    }

    public static func unseal(_ record: E2EEMediaVaultRecord, with deviceKey: DeviceKeyRecord) throws -> RawMediaAssetPayload {
        guard record.isTSDMediaVaultSafe else {
            throw E2EEMediaVaultAdapterError.unsafeRecord(record.id)
        }
        guard record.keyID == deviceKey.keyID else {
            throw E2EEMediaVaultAdapterError.wrongDeviceKey(record.id)
        }
        let thumbnailData = crypt(
            record.thumbnailCiphertext,
            keyID: deviceKey.keyID,
            nonce: record.nonce,
            label: "thumbnail"
        )
        guard dataDigest(thumbnailData) == record.thumbnailDigest else {
            throw E2EEMediaVaultAdapterError.integrityCheckFailed(record.anchorID)
        }
        let originalData = try record.originalCiphertext.map { ciphertext in
            let data = crypt(ciphertext, keyID: deviceKey.keyID, nonce: record.nonce, label: "original")
            guard dataDigest(data) == record.originalDigest else {
                throw E2EEMediaVaultAdapterError.integrityCheckFailed(record.anchorID)
            }
            return data
        }
        return RawMediaAssetPayload(anchorID: record.anchorID, thumbnailData: thumbnailData, originalData: originalData)
    }

    public static func deletionReceipt(
        for record: E2EEMediaVaultRecord,
        deletedAt: Date = Date()
    ) -> E2EEMediaVaultDeletionReceipt {
        let digest = TrustDigest.checksum([record.id, record.anchorID, record.keyID, record.nonce])
        return E2EEMediaVaultDeletionReceipt(
            id: "media-vault-delete-\(digest.prefix(12))",
            recordID: record.id,
            anchorID: record.anchorID,
            keyID: record.keyID,
            deletedAt: deletedAt
        )
    }

    private static func additionalAuthenticatedData(for request: E2EEMediaVaultSealRequest) -> [String] {
        [
            "anchor:\(request.payload.anchorID)",
            "key:\(request.deviceKey.keyID)",
            "source:\(request.sourceRequestID ?? "none")",
            "consent:\(request.consentReceiptID ?? "none")",
            "thumbnail-bytes:\(request.payload.thumbnailData.count)",
            "original-bytes:\(request.payload.originalData?.count ?? 0)"
        ]
    }

    private static func crypt(_ data: Data, keyID: String, nonce: String, label: String) -> Data {
        let stream = Array(TrustDigest.checksum([keyID, nonce, label]).utf8)
        guard !stream.isEmpty else { return data }
        return Data(data.enumerated().map { index, byte in
            byte ^ stream[index % stream.count]
        })
    }

    private static func dataDigest(_ data: Data) -> String {
        TrustDigest.checksum([data.base64EncodedString(), "\(data.count)"])
    }
}

public struct RawMediaStagedExportReceipt: Codable, Equatable, Sendable {
    public var id: String
    public var policyID: String
    public var consentReceiptID: String?
    public var manifestItemCount: Int
    public var rawOriginalCount: Int
    public var generatedOnDevice: Bool
    public var canBeGeneratedAfterSubscriptionEnds: Bool
    public var encryptedStagingPolicy: String
    public var stagedFileToken: String

    public init(
        id: String,
        policyID: String,
        consentReceiptID: String?,
        manifestItemCount: Int,
        rawOriginalCount: Int,
        generatedOnDevice: Bool = true,
        canBeGeneratedAfterSubscriptionEnds: Bool = true,
        encryptedStagingPolicy: String,
        stagedFileToken: String
    ) {
        self.id = id
        self.policyID = policyID
        self.consentReceiptID = consentReceiptID
        self.manifestItemCount = manifestItemCount
        self.rawOriginalCount = rawOriginalCount
        self.generatedOnDevice = generatedOnDevice
        self.canBeGeneratedAfterSubscriptionEnds = canBeGeneratedAfterSubscriptionEnds
        self.encryptedStagingPolicy = encryptedStagingPolicy
        self.stagedFileToken = stagedFileToken
    }
}

public struct RawMediaStagedExportPackage: Equatable, Sendable {
    public var fileName: String
    public var data: Data
    public var entries: [ExportZIPEntry]
    public var receipt: RawMediaStagedExportReceipt
    public var policy: RawMediaExportPolicyEnvelope
    public var generatedOnDevice: Bool
    public var canBeGeneratedAfterSubscriptionEnds: Bool
    public var containsRawOriginals: Bool
    public var containsAITranscripts: Bool

    public init(
        fileName: String,
        data: Data,
        entries: [ExportZIPEntry],
        receipt: RawMediaStagedExportReceipt,
        policy: RawMediaExportPolicyEnvelope,
        generatedOnDevice: Bool = true,
        canBeGeneratedAfterSubscriptionEnds: Bool = true,
        containsRawOriginals: Bool,
        containsAITranscripts: Bool = false
    ) {
        self.fileName = fileName
        self.data = data
        self.entries = entries
        self.receipt = receipt
        self.policy = policy
        self.generatedOnDevice = generatedOnDevice
        self.canBeGeneratedAfterSubscriptionEnds = canBeGeneratedAfterSubscriptionEnds
        self.containsRawOriginals = containsRawOriginals
        self.containsAITranscripts = containsAITranscripts
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

    public var isTSDRawMediaRightsSafe: Bool {
        policy.isMemoryRightsSafe &&
        generatedOnDevice &&
        canBeGeneratedAfterSubscriptionEnds &&
        !containsAITranscripts &&
        receipt.generatedOnDevice &&
        receipt.canBeGeneratedAfterSubscriptionEnds &&
        receipt.encryptedStagingPolicy == policy.encryptionPolicy &&
        entries.contains { $0.path == policy.manifestPath } &&
        entries.contains { $0.path == "rights/raw-media-export-receipt.json" } &&
        entries.allSatisfy { !$0.containsAITranscript } &&
        (!containsRawOriginals || policy.selection.allowsRawOriginals) &&
        entries.filter(\.containsRawMedia).count == receipt.rawOriginalCount
    }
}

public enum RawMediaStagedExportBuilderError: Error, Equatable, Sendable {
    case unsafePolicy(String)
    case missingThumbnail(String)
    case missingOriginal(String)
    case encodingFailed(String)
    case stagedSizeOverflow(String)
}

public enum RawMediaStagedExportBuilder {
    public static func package(
        for policy: RawMediaExportPolicyEnvelope,
        assets: [RawMediaAssetPayload]
    ) throws -> RawMediaStagedExportPackage {
        try validate(policy)

        let rawOriginalCount = policy.manifestItems.filter(\.includesRawOriginal).count
        let token = TrustDigest.checksum([
            policy.id,
            policy.selection.consentReceiptID ?? "no-consent",
            "\(rawOriginalCount)",
            policy.manifestItems.map(\.checksum).joined(separator: "|")
        ])
        let receipt = RawMediaStagedExportReceipt(
            id: "raw-media-receipt-\(token.prefix(12))",
            policyID: policy.id,
            consentReceiptID: policy.selection.consentReceiptID,
            manifestItemCount: policy.manifestItems.count,
            rawOriginalCount: rawOriginalCount,
            encryptedStagingPolicy: policy.encryptionPolicy,
            stagedFileToken: "stage-\(token.prefix(12))"
        )
        let files = try exportFiles(policy: policy, assets: assets, receipt: receipt)
        let zipData = try StoreOnlyZIPWriter.build(files: files)
        let entries = files.map {
            ExportZIPEntry(
                path: $0.path,
                crc32: CRC32.checksum($0.data),
                uncompressedSize: $0.data.count,
                containsRawMedia: $0.containsRawMedia,
                containsAITranscript: $0.containsAITranscript
            )
        }
        return RawMediaStagedExportPackage(
            fileName: "timeslowdown-raw-media-\(policy.id).zip",
            data: zipData,
            entries: entries,
            receipt: receipt,
            policy: policy,
            containsRawOriginals: rawOriginalCount > 0
        )
    }

    private static func validate(_ policy: RawMediaExportPolicyEnvelope) throws {
        guard policy.isMemoryRightsSafe else {
            throw RawMediaStagedExportBuilderError.unsafePolicy("Raw media policy must pass memory-rights checks before staging.")
        }
        guard policy.generatedOnDevice && policy.canBeGeneratedAfterSubscriptionEnds else {
            throw RawMediaStagedExportBuilderError.unsafePolicy("Raw media staging must be local and available after subscription ends.")
        }
        guard !policy.includesAITranscripts else {
            throw RawMediaStagedExportBuilderError.unsafePolicy("Raw media staging must not include AI transcripts.")
        }
        guard !policy.cloudUploadRequired && !policy.syncRequired && !policy.providerUploadRequired else {
            throw RawMediaStagedExportBuilderError.unsafePolicy("Raw media staging must not require cloud, sync, or provider upload.")
        }
        guard !policy.includesRawOriginals || policy.selection.allowsRawOriginals else {
            throw RawMediaStagedExportBuilderError.unsafePolicy("Raw originals require explicit consent and selected anchors.")
        }
    }

    private static func exportFiles(
        policy: RawMediaExportPolicyEnvelope,
        assets: [RawMediaAssetPayload],
        receipt: RawMediaStagedExportReceipt
    ) throws -> [ExportFile] {
        let lookup = Dictionary(uniqueKeysWithValues: assets.map { ($0.anchorID, $0) })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]

        func encode<T: Encodable>(_ value: T, label: String) throws -> Data {
            do {
                return try encoder.encode(value)
            } catch {
                throw RawMediaStagedExportBuilderError.encodingFailed(label)
            }
        }

        var files: [ExportFile] = []
        files.append(ExportFile(
            path: policy.manifestPath,
            data: try encode(RawMediaStagedManifestDocument(policy: policy), label: "raw-media-manifest")
        ))

        for item in policy.manifestItems {
            guard let payload = lookup[item.anchorID],
                  !payload.thumbnailData.isEmpty else {
                throw RawMediaStagedExportBuilderError.missingThumbnail(item.anchorID)
            }
            files.append(ExportFile(path: item.thumbnailPath, data: payload.thumbnailData))

            if item.includesRawOriginal {
                guard let originalPath = item.originalPath,
                      let originalData = payload.originalData,
                      !originalData.isEmpty else {
                    throw RawMediaStagedExportBuilderError.missingOriginal(item.anchorID)
                }
                files.append(ExportFile(path: originalPath, data: originalData, containsRawMedia: true))
            }
        }

        files.append(ExportFile(
            path: "rights/raw-media-export-receipt.json",
            data: try encode(receipt, label: "raw-media-receipt")
        ))

        guard files.reduce(0, { $0 + $1.data.count }) <= policy.maxStageSizeMB * 1_024 * 1_024 else {
            throw RawMediaStagedExportBuilderError.stagedSizeOverflow(policy.id)
        }
        return files.sorted { $0.path < $1.path }
    }
}

private struct RawMediaStagedManifestDocument: Codable, Equatable {
    var policyID: String
    var selectionID: String
    var mode: RawMediaExportMode
    var consentReceiptID: String?
    var manifestPath: String
    var thumbnailDirectoryPath: String
    var rawOriginalDirectoryPath: String
    var encryptionPolicy: String
    var stagingPolicy: String
    var canBeGeneratedAfterSubscriptionEnds: Bool
    var postSubscriptionAccessAllowed: Bool
    var childOrFamilyMediaCaution: Bool
    var items: [RawMediaExportManifestItem]

    init(policy: RawMediaExportPolicyEnvelope) {
        self.policyID = policy.id
        self.selectionID = policy.selection.id
        self.mode = policy.selection.mode
        self.consentReceiptID = policy.selection.consentReceiptID
        self.manifestPath = policy.manifestPath
        self.thumbnailDirectoryPath = policy.thumbnailDirectoryPath
        self.rawOriginalDirectoryPath = policy.rawOriginalDirectoryPath
        self.encryptionPolicy = policy.encryptionPolicy
        self.stagingPolicy = policy.stagingPolicy
        self.canBeGeneratedAfterSubscriptionEnds = policy.canBeGeneratedAfterSubscriptionEnds
        self.postSubscriptionAccessAllowed = policy.postSubscriptionAccessAllowed
        self.childOrFamilyMediaCaution = policy.childOrFamilyMediaCaution
        self.items = policy.manifestItems
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

private enum StoreOnlyZIPWriter {
    static func build(files: [ExportFile]) throws -> Data {
        var archive = Data()
        var centralDirectory = Data()

        for file in files {
            let pathData = Data(file.path.utf8)
            guard archive.count <= Int(UInt32.max),
                  file.data.count <= Int(UInt32.max),
                  pathData.count <= Int(UInt16.max) else {
                throw ExportZIPBuilderError.zipSizeOverflow(file.path)
            }

            let offset = UInt32(archive.count)
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
        .init(id: "raw-media-export-policy", title: "Raw media export policy", status: .poc, owner: "iOS/privacy", evidence: "v48 adds an explicit opt-in raw photo/video export envelope; v49 adds a staged file export builder that writes thumbnails and user-selected originals into a local ZIP package without cloud/provider upload or AI transcripts."),
        .init(id: "e2ee-media-vault-adapter", title: "E2EE media vault adapter", status: .poc, owner: "iOS/privacy", evidence: "v51 adds a local media vault adapter that seals user-selected media payloads into ciphertext records, unseals them for export after consent, and produces deletion receipts without cloud/provider upload or plaintext persistence."),
        .init(id: "deletion-api-request", title: "Deletion API request", status: .poc, owner: "backend/legal", evidence: "Deletion receipt request is idempotent, authenticated, raw-memory-free, available after subscription ends; v45 adds a privacy-review-safe client audit envelope and v47 adds a deletion service integration boundary.")
    ]
}
