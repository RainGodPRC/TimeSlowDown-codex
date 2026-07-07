import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

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

public struct DeepSeekProviderProxyRequestContract: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var provider: String
    public var model: String
    public var providerEndpoint: String
    public var credentialLocation: String
    public var credentialVisibleToClient: Bool
    public var mapsFromGatewayBodyDigest: String
    public var allowedProviderRequestKeys: [String]
    public var forbiddenProviderRequestKeys: [String]
    public var bodyContainsRawMedia: Bool
    public var bodyContainsFullMemoryArchive: Bool
    public var bodyContainsContacts: Bool
    public var bodyContainsGPS: Bool
    public var bodyContainsFaceEmbeddings: Bool
    public var bodyContainsSubscriptionState: Bool
    public var maxPromptRetentionHours: Int
    public var maxBudgetCents: Int

    public init(
        id: String,
        provider: String = "deepseek",
        model: String = "deepseek-v4-flash",
        providerEndpoint: String = "https://api.deepseek.com/chat/completions",
        credentialLocation: String = "server-secret-manager",
        credentialVisibleToClient: Bool = false,
        mapsFromGatewayBodyDigest: String,
        allowedProviderRequestKeys: [String] = ["model", "messages", "response_format", "temperature", "max_tokens", "metadata"],
        forbiddenProviderRequestKeys: [String] = ["provider_api_key", "raw_media_binary", "full_memory_archive", "contacts", "gps_trace", "face_embeddings", "subscription_state"],
        bodyContainsRawMedia: Bool = false,
        bodyContainsFullMemoryArchive: Bool = false,
        bodyContainsContacts: Bool = false,
        bodyContainsGPS: Bool = false,
        bodyContainsFaceEmbeddings: Bool = false,
        bodyContainsSubscriptionState: Bool = false,
        maxPromptRetentionHours: Int = 24,
        maxBudgetCents: Int
    ) {
        self.id = id
        self.provider = provider
        self.model = model
        self.providerEndpoint = providerEndpoint
        self.credentialLocation = credentialLocation
        self.credentialVisibleToClient = credentialVisibleToClient
        self.mapsFromGatewayBodyDigest = mapsFromGatewayBodyDigest
        self.allowedProviderRequestKeys = allowedProviderRequestKeys
        self.forbiddenProviderRequestKeys = forbiddenProviderRequestKeys
        self.bodyContainsRawMedia = bodyContainsRawMedia
        self.bodyContainsFullMemoryArchive = bodyContainsFullMemoryArchive
        self.bodyContainsContacts = bodyContainsContacts
        self.bodyContainsGPS = bodyContainsGPS
        self.bodyContainsFaceEmbeddings = bodyContainsFaceEmbeddings
        self.bodyContainsSubscriptionState = bodyContainsSubscriptionState
        self.maxPromptRetentionHours = maxPromptRetentionHours
        self.maxBudgetCents = maxBudgetCents
    }

    public var isSafeProviderProxyBoundary: Bool {
        provider == "deepseek" &&
        model == "deepseek-v4-flash" &&
        providerEndpoint.hasPrefix("https://") &&
        credentialLocation == "server-secret-manager" &&
        !credentialVisibleToClient &&
        !mapsFromGatewayBodyDigest.isEmpty &&
        allowedProviderRequestKeys.contains("messages") &&
        forbiddenProviderRequestKeys.contains("provider_api_key") &&
        forbiddenProviderRequestKeys.contains("raw_media_binary") &&
        forbiddenProviderRequestKeys.contains("full_memory_archive") &&
        forbiddenProviderRequestKeys.contains("contacts") &&
        forbiddenProviderRequestKeys.contains("gps_trace") &&
        forbiddenProviderRequestKeys.contains("face_embeddings") &&
        forbiddenProviderRequestKeys.contains("subscription_state") &&
        !bodyContainsRawMedia &&
        !bodyContainsFullMemoryArchive &&
        !bodyContainsContacts &&
        !bodyContainsGPS &&
        !bodyContainsFaceEmbeddings &&
        !bodyContainsSubscriptionState &&
        maxPromptRetentionHours <= 24 &&
        maxBudgetCents > 0
    }
}

public struct DeepSeekProviderProxyResponseContract: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var returnsEditableDraft: Bool
    public var returnsSourceTrace: Bool
    public var returnsResponseDigest: Bool
    public var returnsGatewayJobID: Bool
    public var returnsAuditEventID: Bool
    public var returnsCostEstimate: Bool
    public var storesRawProviderTranscript: Bool
    public var responseContainsProviderCredential: Bool
    public var responseContainsRawMedia: Bool
    public var responseContainsFullMemoryArchive: Bool
    public var responseContainsContacts: Bool
    public var responseContainsGPS: Bool
    public var responseContainsFaceEmbeddings: Bool

    public init(
        id: String,
        returnsEditableDraft: Bool = true,
        returnsSourceTrace: Bool = true,
        returnsResponseDigest: Bool = true,
        returnsGatewayJobID: Bool = true,
        returnsAuditEventID: Bool = true,
        returnsCostEstimate: Bool = true,
        storesRawProviderTranscript: Bool = false,
        responseContainsProviderCredential: Bool = false,
        responseContainsRawMedia: Bool = false,
        responseContainsFullMemoryArchive: Bool = false,
        responseContainsContacts: Bool = false,
        responseContainsGPS: Bool = false,
        responseContainsFaceEmbeddings: Bool = false
    ) {
        self.id = id
        self.returnsEditableDraft = returnsEditableDraft
        self.returnsSourceTrace = returnsSourceTrace
        self.returnsResponseDigest = returnsResponseDigest
        self.returnsGatewayJobID = returnsGatewayJobID
        self.returnsAuditEventID = returnsAuditEventID
        self.returnsCostEstimate = returnsCostEstimate
        self.storesRawProviderTranscript = storesRawProviderTranscript
        self.responseContainsProviderCredential = responseContainsProviderCredential
        self.responseContainsRawMedia = responseContainsRawMedia
        self.responseContainsFullMemoryArchive = responseContainsFullMemoryArchive
        self.responseContainsContacts = responseContainsContacts
        self.responseContainsGPS = responseContainsGPS
        self.responseContainsFaceEmbeddings = responseContainsFaceEmbeddings
    }

    public var isSafeBackendResponseBoundary: Bool {
        returnsEditableDraft &&
        returnsSourceTrace &&
        returnsResponseDigest &&
        returnsGatewayJobID &&
        returnsAuditEventID &&
        returnsCostEstimate &&
        !storesRawProviderTranscript &&
        !responseContainsProviderCredential &&
        !responseContainsRawMedia &&
        !responseContainsFullMemoryArchive &&
        !responseContainsContacts &&
        !responseContainsGPS &&
        !responseContainsFaceEmbeddings
    }
}

public struct DeepSeekBackendEndpointContract: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var method: String
    public var endpointPath: String
    public var acceptsOnlyGatewayEnvelope: Bool
    public var requiresAuthenticatedAccount: Bool
    public var requiresConsentReceipt: Bool
    public var requiresIdempotencyKey: Bool
    public var requiresTaskDigest: Bool
    public var requiresBudgetCeiling: Bool
    public var dataResidencyPolicy: String
    public var queueName: String
    public var retentionHours: Int
    public var providerProxyRequest: DeepSeekProviderProxyRequestContract
    public var providerProxyResponse: DeepSeekProviderProxyResponseContract

    public init(
        id: String,
        method: String = "POST",
        endpointPath: String = "/v1/ai/tasks/weekly-chapter",
        acceptsOnlyGatewayEnvelope: Bool = true,
        requiresAuthenticatedAccount: Bool = true,
        requiresConsentReceipt: Bool = true,
        requiresIdempotencyKey: Bool = true,
        requiresTaskDigest: Bool = true,
        requiresBudgetCeiling: Bool = true,
        dataResidencyPolicy: String = "user-region-pinned",
        queueName: String = "ai-weekly-chapter",
        retentionHours: Int = 24,
        providerProxyRequest: DeepSeekProviderProxyRequestContract,
        providerProxyResponse: DeepSeekProviderProxyResponseContract
    ) {
        self.id = id
        self.method = method
        self.endpointPath = endpointPath
        self.acceptsOnlyGatewayEnvelope = acceptsOnlyGatewayEnvelope
        self.requiresAuthenticatedAccount = requiresAuthenticatedAccount
        self.requiresConsentReceipt = requiresConsentReceipt
        self.requiresIdempotencyKey = requiresIdempotencyKey
        self.requiresTaskDigest = requiresTaskDigest
        self.requiresBudgetCeiling = requiresBudgetCeiling
        self.dataResidencyPolicy = dataResidencyPolicy
        self.queueName = queueName
        self.retentionHours = retentionHours
        self.providerProxyRequest = providerProxyRequest
        self.providerProxyResponse = providerProxyResponse
    }

    public var isProductionEndpointSafe: Bool {
        method == "POST" &&
        endpointPath == "/v1/ai/tasks/weekly-chapter" &&
        acceptsOnlyGatewayEnvelope &&
        requiresAuthenticatedAccount &&
        requiresConsentReceipt &&
        requiresIdempotencyKey &&
        requiresTaskDigest &&
        requiresBudgetCeiling &&
        dataResidencyPolicy == "user-region-pinned" &&
        queueName == "ai-weekly-chapter" &&
        retentionHours <= 24 &&
        providerProxyRequest.isSafeProviderProxyBoundary &&
        providerProxyResponse.isSafeBackendResponseBoundary
    }
}

public enum DeepSeekBackendEndpointPlan {
    public static func contract(for gateway: DeepSeekServerGatewayEnvelope) -> DeepSeekBackendEndpointContract {
        let digest = TrustDigest.checksum([
            gateway.id,
            gateway.request.endpointPath,
            gateway.requestBodyDigest,
            gateway.consentReceiptID,
            gateway.queueName
        ])
        let providerRequest = DeepSeekProviderProxyRequestContract(
            id: "deepseek-provider-proxy-request-\(digest.prefix(12))",
            mapsFromGatewayBodyDigest: gateway.requestBodyDigest,
            maxPromptRetentionHours: gateway.retentionHours,
            maxBudgetCents: gateway.budgetCeilingCents
        )
        let providerResponse = DeepSeekProviderProxyResponseContract(
            id: "deepseek-provider-proxy-response-\(digest.prefix(12))"
        )
        return DeepSeekBackendEndpointContract(
            id: "deepseek-backend-endpoint-\(digest.prefix(12))",
            endpointPath: gateway.request.endpointPath,
            dataResidencyPolicy: gateway.dataResidencyPolicy,
            queueName: gateway.queueName,
            retentionHours: gateway.retentionHours,
            providerProxyRequest: providerRequest,
            providerProxyResponse: providerResponse
        )
    }
}

public enum DeepSeekBackendEndpointExecutionMode: String, Codable, Equatable, Sendable {
    case localStub
    case providerGateway
}

public enum DeepSeekBackendEndpointExecutionStatus: String, Codable, Equatable, Sendable {
    case stubPassed
    case providerRequired
    case failed
}

public struct DeepSeekBackendEndpointExecutionRequest: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var endpointID: String
    public var gatewayID: String
    public var mode: DeepSeekBackendEndpointExecutionMode
    public var accountAuthenticated: Bool
    public var consentReceiptID: String
    public var idempotencyKey: String
    public var taskDigest: String
    public var requestBodyDigest: String
    public var budgetCeilingCents: Int

    public init(
        id: String,
        endpointID: String,
        gatewayID: String,
        mode: DeepSeekBackendEndpointExecutionMode,
        accountAuthenticated: Bool,
        consentReceiptID: String,
        idempotencyKey: String,
        taskDigest: String,
        requestBodyDigest: String,
        budgetCeilingCents: Int
    ) {
        self.id = id
        self.endpointID = endpointID
        self.gatewayID = gatewayID
        self.mode = mode
        self.accountAuthenticated = accountAuthenticated
        self.consentReceiptID = consentReceiptID
        self.idempotencyKey = idempotencyKey
        self.taskDigest = taskDigest
        self.requestBodyDigest = requestBodyDigest
        self.budgetCeilingCents = budgetCeilingCents
    }

    public static func reviewed(
        endpoint: DeepSeekBackendEndpointContract,
        gateway: DeepSeekServerGatewayEnvelope,
        mode: DeepSeekBackendEndpointExecutionMode
    ) -> DeepSeekBackendEndpointExecutionRequest {
        let digest = TrustDigest.checksum([
            endpoint.id,
            gateway.id,
            gateway.requestBodyDigest,
            mode.rawValue
        ])
        return DeepSeekBackendEndpointExecutionRequest(
            id: "deepseek-endpoint-exec-\(digest.prefix(12))",
            endpointID: endpoint.id,
            gatewayID: gateway.id,
            mode: mode,
            accountAuthenticated: true,
            consentReceiptID: gateway.consentReceiptID,
            idempotencyKey: gateway.request.idempotencyKey,
            taskDigest: gateway.request.task.minimalPayloadDigest,
            requestBodyDigest: gateway.requestBodyDigest,
            budgetCeilingCents: gateway.budgetCeilingCents
        )
    }

    public var hasRequiredExecutionContext: Bool {
        endpointID.hasPrefix("deepseek-backend-endpoint-") &&
        gatewayID.hasPrefix("server-gateway-") &&
        accountAuthenticated &&
        !consentReceiptID.isEmpty &&
        !idempotencyKey.isEmpty &&
        !taskDigest.isEmpty &&
        !requestBodyDigest.isEmpty &&
        budgetCeilingCents > 0
    }
}

public struct DeepSeekBackendEndpointExecutionReceipt: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var requestID: String
    public var endpointID: String
    public var mode: DeepSeekBackendEndpointExecutionMode
    public var status: DeepSeekBackendEndpointExecutionStatus
    public var endpointContractSafe: Bool
    public var gatewayBoundarySafe: Bool
    public var providerProxyRequestSafe: Bool
    public var providerProxyResponseSafe: Bool
    public var requiredInputGatePassed: Bool
    public var forbiddenFieldGatePassed: Bool
    public var providerCallPerformed: Bool
    public var requestWasMocked: Bool
    public var canBeUsedForProductionAIGate: Bool
    public var canBeUsedForAppStoreGate: Bool
    public var validationNotes: [String]

    public init(
        id: String,
        requestID: String,
        endpointID: String,
        mode: DeepSeekBackendEndpointExecutionMode,
        status: DeepSeekBackendEndpointExecutionStatus,
        endpointContractSafe: Bool,
        gatewayBoundarySafe: Bool,
        providerProxyRequestSafe: Bool,
        providerProxyResponseSafe: Bool,
        requiredInputGatePassed: Bool,
        forbiddenFieldGatePassed: Bool,
        providerCallPerformed: Bool,
        requestWasMocked: Bool,
        canBeUsedForProductionAIGate: Bool,
        canBeUsedForAppStoreGate: Bool,
        validationNotes: [String]
    ) {
        self.id = id
        self.requestID = requestID
        self.endpointID = endpointID
        self.mode = mode
        self.status = status
        self.endpointContractSafe = endpointContractSafe
        self.gatewayBoundarySafe = gatewayBoundarySafe
        self.providerProxyRequestSafe = providerProxyRequestSafe
        self.providerProxyResponseSafe = providerProxyResponseSafe
        self.requiredInputGatePassed = requiredInputGatePassed
        self.forbiddenFieldGatePassed = forbiddenFieldGatePassed
        self.providerCallPerformed = providerCallPerformed
        self.requestWasMocked = requestWasMocked
        self.canBeUsedForProductionAIGate = canBeUsedForProductionAIGate
        self.canBeUsedForAppStoreGate = canBeUsedForAppStoreGate
        self.validationNotes = validationNotes
    }

    public var isHonestLocalStubPass: Bool {
        mode == .localStub &&
        status == .stubPassed &&
        endpointContractSafe &&
        gatewayBoundarySafe &&
        providerProxyRequestSafe &&
        providerProxyResponseSafe &&
        requiredInputGatePassed &&
        forbiddenFieldGatePassed &&
        requestWasMocked &&
        !providerCallPerformed &&
        !canBeUsedForProductionAIGate &&
        !canBeUsedForAppStoreGate
    }
}

public enum DeepSeekBackendEndpointExecutionHarness {
    public static func execute(
        endpoint: DeepSeekBackendEndpointContract,
        gateway: DeepSeekServerGatewayEnvelope,
        request: DeepSeekBackendEndpointExecutionRequest
    ) -> DeepSeekBackendEndpointExecutionReceipt {
        let endpointMatchesGateway = request.endpointID == endpoint.id &&
        request.gatewayID == gateway.id &&
        request.consentReceiptID == gateway.consentReceiptID &&
        request.idempotencyKey == gateway.request.idempotencyKey &&
        request.taskDigest == gateway.request.task.minimalPayloadDigest &&
        request.requestBodyDigest == gateway.requestBodyDigest &&
        request.budgetCeilingCents == gateway.budgetCeilingCents

        let requiredInputGatePassed = request.hasRequiredExecutionContext && endpointMatchesGateway
        let endpointContractSafe = endpoint.isProductionEndpointSafe
        let gatewayBoundarySafe = gateway.isProductionSafeBoundary
        let providerProxyRequestSafe = endpoint.providerProxyRequest.isSafeProviderProxyBoundary
        let providerProxyResponseSafe = endpoint.providerProxyResponse.isSafeBackendResponseBoundary
        let forbiddenFieldGatePassed = !gateway.request.containsProviderAPIKey &&
        !gateway.request.sendsRawMedia &&
        !gateway.request.sendsFullArchive &&
        !endpoint.providerProxyRequest.bodyContainsRawMedia &&
        !endpoint.providerProxyRequest.bodyContainsFullMemoryArchive &&
        !endpoint.providerProxyRequest.bodyContainsContacts &&
        !endpoint.providerProxyRequest.bodyContainsGPS &&
        !endpoint.providerProxyRequest.bodyContainsFaceEmbeddings &&
        !endpoint.providerProxyRequest.bodyContainsSubscriptionState &&
        !endpoint.providerProxyResponse.responseContainsProviderCredential &&
        !endpoint.providerProxyResponse.responseContainsRawMedia &&
        !endpoint.providerProxyResponse.responseContainsFullMemoryArchive &&
        !endpoint.providerProxyResponse.responseContainsContacts &&
        !endpoint.providerProxyResponse.responseContainsGPS &&
        !endpoint.providerProxyResponse.responseContainsFaceEmbeddings

        let allLocalGatesPassed = endpointContractSafe &&
        gatewayBoundarySafe &&
        providerProxyRequestSafe &&
        providerProxyResponseSafe &&
        requiredInputGatePassed &&
        forbiddenFieldGatePassed

        let status: DeepSeekBackendEndpointExecutionStatus
        switch (request.mode, allLocalGatesPassed) {
        case (.localStub, true):
            status = .stubPassed
        case (.providerGateway, true):
            status = .providerRequired
        default:
            status = .failed
        }

        let digest = TrustDigest.checksum([
            request.id,
            endpoint.id,
            gateway.id,
            status.rawValue
        ])
        return DeepSeekBackendEndpointExecutionReceipt(
            id: "deepseek-endpoint-receipt-\(digest.prefix(12))",
            requestID: request.id,
            endpointID: endpoint.id,
            mode: request.mode,
            status: status,
            endpointContractSafe: endpointContractSafe,
            gatewayBoundarySafe: gatewayBoundarySafe,
            providerProxyRequestSafe: providerProxyRequestSafe,
            providerProxyResponseSafe: providerProxyResponseSafe,
            requiredInputGatePassed: requiredInputGatePassed,
            forbiddenFieldGatePassed: forbiddenFieldGatePassed,
            providerCallPerformed: false,
            requestWasMocked: request.mode == .localStub,
            canBeUsedForProductionAIGate: false,
            canBeUsedForAppStoreGate: false,
            validationNotes: notes(for: status)
        )
    }

    private static func notes(
        for status: DeepSeekBackendEndpointExecutionStatus
    ) -> [String] {
        switch status {
        case .stubPassed:
            return [
                "Local executable harness proved endpoint, gateway, provider proxy, required-input, and forbidden-field gates.",
                "No DeepSeek provider call was performed; this stub receipt cannot unlock production AI, TestFlight, or App Store gates."
            ]
        case .providerRequired:
            return [
                "Endpoint and payload gates passed, but a deployed backend with server-side DeepSeek credentials is still required.",
                "Provider evidence must come from a real gateway round trip, not this local SwiftPM harness."
            ]
        case .failed:
            return [
                "Endpoint execution harness rejected the request because one or more required gates failed.",
                "Production AI remains locked until auth, consent, idempotency, digest, budget, and forbidden-field gates all pass."
            ]
        }
    }
}

public enum DeepSeekGatewayValidationStatus: String, Codable, Equatable, Sendable {
    case pendingBackend
    case mockPassed
    case providerPassed
    case failed
}

public struct DeepSeekGatewayValidationEnvironment: Codable, Equatable, Sendable {
    public var backendBaseURL: String?
    public var model: String
    public var hasServerRuntime: Bool
    public var hasServerSecretManager: Bool
    public var hasProviderCredentialOnServer: Bool
    public var providerCredentialLocation: String
    public var usesClientProviderKey: Bool
    public var canReachProvider: Bool
    public var canRunMockMode: Bool
    public var maxRetentionHours: Int
    public var maxBudgetCents: Int

    public init(
        backendBaseURL: String?,
        model: String = "deepseek-v4-flash",
        hasServerRuntime: Bool,
        hasServerSecretManager: Bool,
        hasProviderCredentialOnServer: Bool,
        providerCredentialLocation: String = "server-secret-manager",
        usesClientProviderKey: Bool = false,
        canReachProvider: Bool,
        canRunMockMode: Bool = true,
        maxRetentionHours: Int = 24,
        maxBudgetCents: Int = 4
    ) {
        self.backendBaseURL = backendBaseURL
        self.model = model
        self.hasServerRuntime = hasServerRuntime
        self.hasServerSecretManager = hasServerSecretManager
        self.hasProviderCredentialOnServer = hasProviderCredentialOnServer
        self.providerCredentialLocation = providerCredentialLocation
        self.usesClientProviderKey = usesClientProviderKey
        self.canReachProvider = canReachProvider
        self.canRunMockMode = canRunMockMode
        self.maxRetentionHours = maxRetentionHours
        self.maxBudgetCents = maxBudgetCents
    }

    public static func swiftPMHostWithoutBackend() -> DeepSeekGatewayValidationEnvironment {
        DeepSeekGatewayValidationEnvironment(
            backendBaseURL: nil,
            hasServerRuntime: false,
            hasServerSecretManager: false,
            hasProviderCredentialOnServer: false,
            canReachProvider: false
        )
    }

    public var canRunProviderValidation: Bool {
        backendBaseURL != nil &&
        hasServerRuntime &&
        hasServerSecretManager &&
        hasProviderCredentialOnServer &&
        providerCredentialLocation == "server-secret-manager" &&
        !usesClientProviderKey &&
        canReachProvider &&
        model == "deepseek-v4-flash"
    }
}

public enum DeepSeekGatewayValidationStepKind: String, Codable, Equatable, Sendable {
    case backendHealthPreflight
    case serverSecretManagerCheck
    case clientKeyAbsenceCheck
    case consentReceiptCheck
    case idempotencyCheck
    case budgetCeilingCheck
    case retentionCeilingCheck
    case forbiddenPayloadCheck
    case mockGatewayRoundTrip
    case providerGatewayRoundTrip
}

public struct DeepSeekGatewayValidationStep: Codable, Equatable, Identifiable, Sendable {
    public var id: String { kind.rawValue }
    public var kind: DeepSeekGatewayValidationStepKind
    public var title: String
    public var requiresBackend: Bool
    public var requiresProviderCredential: Bool
    public var canRunOnSwiftPMHost: Bool
    public var requiredForAppStoreGate: Bool

    public init(
        kind: DeepSeekGatewayValidationStepKind,
        title: String,
        requiresBackend: Bool,
        requiresProviderCredential: Bool,
        canRunOnSwiftPMHost: Bool,
        requiredForAppStoreGate: Bool = true
    ) {
        self.kind = kind
        self.title = title
        self.requiresBackend = requiresBackend
        self.requiresProviderCredential = requiresProviderCredential
        self.canRunOnSwiftPMHost = canRunOnSwiftPMHost
        self.requiredForAppStoreGate = requiredForAppStoreGate
    }
}

public struct DeepSeekGatewayIntegrationPlan: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var environment: DeepSeekGatewayValidationEnvironment
    public var gateway: DeepSeekServerGatewayEnvelope
    public var steps: [DeepSeekGatewayValidationStep]
    public var productionModel: String
    public var requiresExternalBackendWork: Bool

    public init(
        id: String,
        environment: DeepSeekGatewayValidationEnvironment,
        gateway: DeepSeekServerGatewayEnvelope,
        steps: [DeepSeekGatewayValidationStep],
        productionModel: String = "deepseek-v4-flash"
    ) {
        self.id = id
        self.environment = environment
        self.gateway = gateway
        self.steps = steps
        self.productionModel = productionModel
        self.requiresExternalBackendWork = !environment.canRunProviderValidation
    }

    public var isReadyForProviderValidation: Bool {
        environment.canRunProviderValidation &&
        gateway.isProductionSafeBoundary &&
        gateway.request.model == productionModel &&
        gateway.serverCredentialLocation == "server-secret-manager" &&
        gateway.retentionHours <= environment.maxRetentionHours &&
        gateway.budgetCeilingCents <= environment.maxBudgetCents
    }
}

public struct DeepSeekGatewayValidationStepReceipt: Codable, Equatable, Identifiable, Sendable {
    public var id: String { kind.rawValue }
    public var kind: DeepSeekGatewayValidationStepKind
    public var status: DeepSeekGatewayValidationStatus
    public var evidence: String
    public var containsProviderCredential: Bool
    public var containsRawMedia: Bool
    public var containsFullMemoryArchive: Bool

    public init(
        kind: DeepSeekGatewayValidationStepKind,
        status: DeepSeekGatewayValidationStatus,
        evidence: String,
        containsProviderCredential: Bool = false,
        containsRawMedia: Bool = false,
        containsFullMemoryArchive: Bool = false
    ) {
        self.kind = kind
        self.status = status
        self.evidence = evidence
        self.containsProviderCredential = containsProviderCredential
        self.containsRawMedia = containsRawMedia
        self.containsFullMemoryArchive = containsFullMemoryArchive
    }
}

public struct DeepSeekGatewayIntegrationReceipt: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var planID: String
    public var status: DeepSeekGatewayValidationStatus
    public var model: String
    public var gatewayJobID: String?
    public var auditEventID: String?
    public var responseStatusCode: Int?
    public var costEstimateCents: Int?
    public var retentionHours: Int
    public var requestWasMocked: Bool
    public var providerCallPerformed: Bool
    public var providerCredentialVisibleToClient: Bool
    public var responseContainsProviderCredential: Bool
    public var responseContainsRawMedia: Bool
    public var responseContainsFullMemoryArchive: Bool
    public var canBeUsedForProductionAIGate: Bool
    public var canBeUsedForAppStoreGate: Bool
    public var validationNotes: [String]
    public var stepReceipts: [DeepSeekGatewayValidationStepReceipt]

    public init(
        id: String,
        planID: String,
        status: DeepSeekGatewayValidationStatus,
        model: String = "deepseek-v4-flash",
        gatewayJobID: String?,
        auditEventID: String?,
        responseStatusCode: Int?,
        costEstimateCents: Int?,
        retentionHours: Int,
        requestWasMocked: Bool,
        providerCallPerformed: Bool,
        providerCredentialVisibleToClient: Bool = false,
        responseContainsProviderCredential: Bool = false,
        responseContainsRawMedia: Bool = false,
        responseContainsFullMemoryArchive: Bool = false,
        canBeUsedForProductionAIGate: Bool,
        canBeUsedForAppStoreGate: Bool,
        validationNotes: [String],
        stepReceipts: [DeepSeekGatewayValidationStepReceipt]
    ) {
        self.id = id
        self.planID = planID
        self.status = status
        self.model = model
        self.gatewayJobID = gatewayJobID
        self.auditEventID = auditEventID
        self.responseStatusCode = responseStatusCode
        self.costEstimateCents = costEstimateCents
        self.retentionHours = retentionHours
        self.requestWasMocked = requestWasMocked
        self.providerCallPerformed = providerCallPerformed
        self.providerCredentialVisibleToClient = providerCredentialVisibleToClient
        self.responseContainsProviderCredential = responseContainsProviderCredential
        self.responseContainsRawMedia = responseContainsRawMedia
        self.responseContainsFullMemoryArchive = responseContainsFullMemoryArchive
        self.canBeUsedForProductionAIGate = canBeUsedForProductionAIGate
        self.canBeUsedForAppStoreGate = canBeUsedForAppStoreGate
        self.validationNotes = validationNotes
        self.stepReceipts = stepReceipts
    }

    public var isProviderPassReceipt: Bool {
        status == .providerPassed &&
        model == "deepseek-v4-flash" &&
        gatewayJobID != nil &&
        auditEventID != nil &&
        responseStatusCode == 200 &&
        retentionHours <= 24 &&
        !requestWasMocked &&
        providerCallPerformed &&
        !providerCredentialVisibleToClient &&
        !responseContainsProviderCredential &&
        !responseContainsRawMedia &&
        !responseContainsFullMemoryArchive &&
        canBeUsedForProductionAIGate &&
        canBeUsedForAppStoreGate &&
        stepReceipts.allSatisfy {
            !$0.containsProviderCredential &&
            !$0.containsRawMedia &&
            !$0.containsFullMemoryArchive
        }
    }
}

public enum DeepSeekGatewayIntegrationScaffold {
    public static func plan(
        environment: DeepSeekGatewayValidationEnvironment,
        gateway: DeepSeekServerGatewayEnvelope
    ) -> DeepSeekGatewayIntegrationPlan {
        let digest = TrustDigest.checksum([
            environment.backendBaseURL ?? "no-backend",
            environment.model,
            gateway.id,
            gateway.requestBodyDigest
        ])
        return DeepSeekGatewayIntegrationPlan(
            id: "deepseek-provider-validation-\(digest.prefix(12))",
            environment: environment,
            gateway: gateway,
            steps: [
                .init(kind: .backendHealthPreflight, title: "Backend health preflight", requiresBackend: true, requiresProviderCredential: false, canRunOnSwiftPMHost: false),
                .init(kind: .serverSecretManagerCheck, title: "Server secret manager contains provider key", requiresBackend: true, requiresProviderCredential: true, canRunOnSwiftPMHost: false),
                .init(kind: .clientKeyAbsenceCheck, title: "Client bundle and request contain no DeepSeek key", requiresBackend: false, requiresProviderCredential: false, canRunOnSwiftPMHost: true),
                .init(kind: .consentReceiptCheck, title: "AI consent receipt required before task enqueue", requiresBackend: false, requiresProviderCredential: false, canRunOnSwiftPMHost: true),
                .init(kind: .idempotencyCheck, title: "Idempotency key survives gateway handoff", requiresBackend: false, requiresProviderCredential: false, canRunOnSwiftPMHost: true),
                .init(kind: .budgetCeilingCheck, title: "Task budget stays within user-approved ceiling", requiresBackend: false, requiresProviderCredential: false, canRunOnSwiftPMHost: true),
                .init(kind: .retentionCeilingCheck, title: "Transient AI task retention stays within 24 hours", requiresBackend: false, requiresProviderCredential: false, canRunOnSwiftPMHost: true),
                .init(kind: .forbiddenPayloadCheck, title: "Raw media, full archive, and provider credentials never cross response boundary", requiresBackend: false, requiresProviderCredential: false, canRunOnSwiftPMHost: true),
                .init(kind: .mockGatewayRoundTrip, title: "Mock gateway round trip returns editable draft metadata", requiresBackend: true, requiresProviderCredential: false, canRunOnSwiftPMHost: false, requiredForAppStoreGate: false),
                .init(kind: .providerGatewayRoundTrip, title: "Real DeepSeek provider round trip returns audited weekly chapter draft", requiresBackend: true, requiresProviderCredential: true, canRunOnSwiftPMHost: false)
            ]
        )
    }

    public static func pendingBackendReceipt(for plan: DeepSeekGatewayIntegrationPlan) -> DeepSeekGatewayIntegrationReceipt {
        DeepSeekGatewayIntegrationReceipt(
            id: "deepseek-pending-\(plan.id.suffix(12))",
            planID: plan.id,
            status: .pendingBackend,
            model: plan.productionModel,
            gatewayJobID: nil,
            auditEventID: nil,
            responseStatusCode: nil,
            costEstimateCents: nil,
            retentionHours: plan.gateway.retentionHours,
            requestWasMocked: false,
            providerCallPerformed: false,
            canBeUsedForProductionAIGate: false,
            canBeUsedForAppStoreGate: false,
            validationNotes: [
                "No production backend URL or server-side DeepSeek credential is available in this SwiftPM host.",
                "This receipt is a contract scaffold only; it cannot satisfy production AI, TestFlight, or App Store gates."
            ],
            stepReceipts: plan.steps.map {
                DeepSeekGatewayValidationStepReceipt(
                    kind: $0.kind,
                    status: .pendingBackend,
                    evidence: $0.canRunOnSwiftPMHost ? "Static Swift contract check passed on host." : "Requires deployed backend/provider validation."
                )
            }
        )
    }

    public static func mockPassedReceipt(for plan: DeepSeekGatewayIntegrationPlan) -> DeepSeekGatewayIntegrationReceipt {
        DeepSeekGatewayIntegrationReceipt(
            id: "deepseek-mock-\(plan.id.suffix(12))",
            planID: plan.id,
            status: .mockPassed,
            model: plan.productionModel,
            gatewayJobID: "mock-job-\(plan.id.suffix(8))",
            auditEventID: "mock-audit-\(plan.id.suffix(8))",
            responseStatusCode: plan.gateway.responseContract.completedStatusCode,
            costEstimateCents: 0,
            retentionHours: plan.gateway.retentionHours,
            requestWasMocked: true,
            providerCallPerformed: false,
            canBeUsedForProductionAIGate: false,
            canBeUsedForAppStoreGate: false,
            validationNotes: [
                "Mock gateway can exercise queue, consent, idempotency, budget, and editable-draft shape.",
                "Mock success is intentionally distinct from providerPassed and cannot unlock production AI."
            ],
            stepReceipts: plan.steps.map {
                DeepSeekGatewayValidationStepReceipt(
                    kind: $0.kind,
                    status: $0.requiresProviderCredential ? .pendingBackend : .mockPassed,
                    evidence: $0.requiresProviderCredential ? "Real provider credential and DeepSeek call still required." : "Mock gateway contract exercised without provider call."
                )
            }
        )
    }
}

public enum DeepSeekGatewayIntegrationTestMode: String, Codable, Equatable, Sendable {
    case mockGateway
    case providerGateway
}

public struct DeepSeekGatewayIntegrationTestRequest: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var planID: String
    public var mode: DeepSeekGatewayIntegrationTestMode
    public var method: String
    public var backendBaseURL: String
    public var endpointPath: String
    public var headers: [String: String]
    public var bodyDigest: String
    public var expectedStatusCode: Int
    public var timeoutSeconds: Int
    public var requiresTLS: Bool
    public var routesThroughTSDBackend: Bool
    public var usesServerCredentialProxy: Bool
    public var containsProviderCredential: Bool
    public var containsRawMedia: Bool
    public var containsFullMemoryArchive: Bool
    public var allowedResponseKeys: [String]
    public var forbiddenResponseKeys: [String]
    public var redactedCurlCommand: String

    public init(
        id: String,
        planID: String,
        mode: DeepSeekGatewayIntegrationTestMode,
        method: String = "POST",
        backendBaseURL: String,
        endpointPath: String = "/v1/ai/tasks/weekly-chapter",
        headers: [String: String],
        bodyDigest: String,
        expectedStatusCode: Int,
        timeoutSeconds: Int = 30,
        requiresTLS: Bool = true,
        routesThroughTSDBackend: Bool = true,
        usesServerCredentialProxy: Bool = true,
        containsProviderCredential: Bool = false,
        containsRawMedia: Bool = false,
        containsFullMemoryArchive: Bool = false,
        allowedResponseKeys: [String],
        forbiddenResponseKeys: [String],
        redactedCurlCommand: String
    ) {
        self.id = id
        self.planID = planID
        self.mode = mode
        self.method = method
        self.backendBaseURL = backendBaseURL
        self.endpointPath = endpointPath
        self.headers = headers
        self.bodyDigest = bodyDigest
        self.expectedStatusCode = expectedStatusCode
        self.timeoutSeconds = timeoutSeconds
        self.requiresTLS = requiresTLS
        self.routesThroughTSDBackend = routesThroughTSDBackend
        self.usesServerCredentialProxy = usesServerCredentialProxy
        self.containsProviderCredential = containsProviderCredential
        self.containsRawMedia = containsRawMedia
        self.containsFullMemoryArchive = containsFullMemoryArchive
        self.allowedResponseKeys = allowedResponseKeys
        self.forbiddenResponseKeys = forbiddenResponseKeys
        self.redactedCurlCommand = redactedCurlCommand
    }

    public var isSafeToExecuteAgainstBackend: Bool {
        requiresTLS &&
        backendBaseURL.hasPrefix("https://") &&
        method == "POST" &&
        endpointPath == "/v1/ai/tasks/weekly-chapter" &&
        routesThroughTSDBackend &&
        usesServerCredentialProxy &&
        !containsProviderCredential &&
        !containsRawMedia &&
        !containsFullMemoryArchive &&
        headers["Authorization"] == nil &&
        headers["X-DeepSeek-API-Key"] == nil &&
        headers["Idempotency-Key"] != nil &&
        headers["X-TSD-AI-Consent"] != nil &&
        headers["X-TSD-Task-Digest"] != nil &&
        forbiddenResponseKeys.contains("provider_api_key") &&
        forbiddenResponseKeys.contains("raw_media_binary") &&
        forbiddenResponseKeys.contains("full_memory_archive") &&
        !redactedCurlCommand.localizedCaseInsensitiveContains("Authorization: Bearer") &&
        !redactedCommandContainsProviderSecretToken
    }

    public var redactedCommandContainsProviderSecretToken: Bool {
        redactedCurlCommand
            .split { !$0.isLetter && !$0.isNumber && $0 != "-" && $0 != "_" }
            .contains {
                let token = $0.lowercased()
                return token.hasPrefix("sk-") && token.count >= 20
            }
    }
}

public struct DeepSeekGatewayIntegrationTestResult: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var request: DeepSeekGatewayIntegrationTestRequest
    public var statusCode: Int
    public var gatewayJobID: String?
    public var auditEventID: String?
    public var model: String
    public var costEstimateCents: Int?
    public var retentionHours: Int
    public var responseDigest: String
    public var requestWasMocked: Bool
    public var providerCallPerformed: Bool
    public var providerCredentialVisibleToClient: Bool
    public var responseContainsProviderCredential: Bool
    public var responseContainsRawMedia: Bool
    public var responseContainsFullMemoryArchive: Bool
    public var responsePreservesEditableDraft: Bool
    public var completedWithUserConsent: Bool

    public init(
        id: String,
        request: DeepSeekGatewayIntegrationTestRequest,
        statusCode: Int,
        gatewayJobID: String?,
        auditEventID: String?,
        model: String = "deepseek-v4-flash",
        costEstimateCents: Int?,
        retentionHours: Int,
        responseDigest: String,
        requestWasMocked: Bool,
        providerCallPerformed: Bool,
        providerCredentialVisibleToClient: Bool = false,
        responseContainsProviderCredential: Bool = false,
        responseContainsRawMedia: Bool = false,
        responseContainsFullMemoryArchive: Bool = false,
        responsePreservesEditableDraft: Bool = true,
        completedWithUserConsent: Bool = true
    ) {
        self.id = id
        self.request = request
        self.statusCode = statusCode
        self.gatewayJobID = gatewayJobID
        self.auditEventID = auditEventID
        self.model = model
        self.costEstimateCents = costEstimateCents
        self.retentionHours = retentionHours
        self.responseDigest = responseDigest
        self.requestWasMocked = requestWasMocked
        self.providerCallPerformed = providerCallPerformed
        self.providerCredentialVisibleToClient = providerCredentialVisibleToClient
        self.responseContainsProviderCredential = responseContainsProviderCredential
        self.responseContainsRawMedia = responseContainsRawMedia
        self.responseContainsFullMemoryArchive = responseContainsFullMemoryArchive
        self.responsePreservesEditableDraft = responsePreservesEditableDraft
        self.completedWithUserConsent = completedWithUserConsent
    }

    public var isSafeProviderRoundTripEvidence: Bool {
        request.mode == .providerGateway &&
        request.isSafeToExecuteAgainstBackend &&
        statusCode == request.expectedStatusCode &&
        gatewayJobID != nil &&
        auditEventID != nil &&
        model == "deepseek-v4-flash" &&
        retentionHours <= 24 &&
        !requestWasMocked &&
        providerCallPerformed &&
        !providerCredentialVisibleToClient &&
        !responseContainsProviderCredential &&
        !responseContainsRawMedia &&
        !responseContainsFullMemoryArchive &&
        responsePreservesEditableDraft &&
        completedWithUserConsent &&
        !responseDigest.isEmpty
    }
}

public enum DeepSeekGatewayIntegrationTestRunner {
    public static func request(
        for plan: DeepSeekGatewayIntegrationPlan,
        mode: DeepSeekGatewayIntegrationTestMode
    ) -> DeepSeekGatewayIntegrationTestRequest {
        let backendBaseURL = plan.environment.backendBaseURL ?? "https://backend-required.invalid"
        let digest = TrustDigest.checksum([
            plan.id,
            plan.gateway.id,
            backendBaseURL,
            mode.rawValue,
            plan.gateway.requestBodyDigest
        ])
        let headers = [
            "Content-Type": "application/json",
            "Idempotency-Key": plan.gateway.request.idempotencyKey,
            "X-TSD-AI-Consent": plan.gateway.consentReceiptID,
            "X-TSD-Task-Digest": plan.gateway.request.task.minimalPayloadDigest,
            "X-TSD-Gateway-Test-Mode": mode.rawValue
        ]
        let redactedCurl = [
            "curl",
            "-X POST",
            "\(backendBaseURL)\(plan.gateway.request.endpointPath)",
            "-H 'Content-Type: application/json'",
            "-H 'Idempotency-Key: \(plan.gateway.request.idempotencyKey)'",
            "-H 'X-TSD-AI-Consent: \(plan.gateway.consentReceiptID)'",
            "-H 'X-TSD-Task-Digest: \(plan.gateway.request.task.minimalPayloadDigest)'",
            "-H 'X-TSD-Gateway-Test-Mode: \(mode.rawValue)'",
            "--data '<minimal-weekly-chapter-task-body-redacted>'"
        ].joined(separator: " ")
        return DeepSeekGatewayIntegrationTestRequest(
            id: "deepseek-test-\(digest.prefix(12))",
            planID: plan.id,
            mode: mode,
            backendBaseURL: backendBaseURL,
            endpointPath: plan.gateway.request.endpointPath,
            headers: headers,
            bodyDigest: plan.gateway.requestBodyDigest,
            expectedStatusCode: plan.gateway.responseContract.completedStatusCode,
            allowedResponseKeys: ["gateway_job_id", "audit_event_id", "model", "cost_estimate_cents", "editable_draft", "response_digest"],
            forbiddenResponseKeys: ["provider_api_key", "raw_media_binary", "full_memory_archive", "contacts", "gps_trace", "face_embeddings"],
            redactedCurlCommand: redactedCurl
        )
    }

    public static func mockResult(for request: DeepSeekGatewayIntegrationTestRequest) -> DeepSeekGatewayIntegrationTestResult {
        let digest = TrustDigest.checksum([request.id, request.bodyDigest, "mock-result"])
        return DeepSeekGatewayIntegrationTestResult(
            id: "deepseek-mock-result-\(digest.prefix(12))",
            request: request,
            statusCode: request.expectedStatusCode,
            gatewayJobID: "mock-job-\(digest.prefix(8))",
            auditEventID: "mock-audit-\(digest.prefix(8))",
            costEstimateCents: 0,
            retentionHours: 1,
            responseDigest: digest,
            requestWasMocked: true,
            providerCallPerformed: false
        )
    }

    public static func providerPassedReceipt(
        for plan: DeepSeekGatewayIntegrationPlan,
        result: DeepSeekGatewayIntegrationTestResult
    ) -> DeepSeekGatewayIntegrationReceipt {
        let canPass = plan.isReadyForProviderValidation && result.isSafeProviderRoundTripEvidence
        return DeepSeekGatewayIntegrationReceipt(
            id: "deepseek-provider-\(result.id.suffix(12))",
            planID: plan.id,
            status: canPass ? .providerPassed : .failed,
            model: result.model,
            gatewayJobID: result.gatewayJobID,
            auditEventID: result.auditEventID,
            responseStatusCode: result.statusCode,
            costEstimateCents: result.costEstimateCents,
            retentionHours: result.retentionHours,
            requestWasMocked: result.requestWasMocked,
            providerCallPerformed: result.providerCallPerformed,
            providerCredentialVisibleToClient: result.providerCredentialVisibleToClient,
            responseContainsProviderCredential: result.responseContainsProviderCredential,
            responseContainsRawMedia: result.responseContainsRawMedia,
            responseContainsFullMemoryArchive: result.responseContainsFullMemoryArchive,
            canBeUsedForProductionAIGate: canPass,
            canBeUsedForAppStoreGate: canPass,
            validationNotes: canPass ? [
                "Provider gateway round trip passed through the TSD backend with server-side DeepSeek credentials.",
                "Receipt contains only job, audit, model, cost, retention, and response digest evidence."
            ] : [
                "Provider gateway round trip evidence was incomplete or unsafe; production AI remains locked."
            ],
            stepReceipts: plan.steps.map {
                DeepSeekGatewayValidationStepReceipt(
                    kind: $0.kind,
                    status: canPass ? .providerPassed : .failed,
                    evidence: canPass ? "Provider validation evidence supplied by integration test result." : "Provider validation evidence missing or unsafe."
                )
            }
        )
    }
}

public enum DeepSeekBackendRoundTripProbeStatus: String, Codable, Equatable, Sendable {
    case notConfigured
    case providerPassed
    case failed
}

public struct DeepSeekBackendRoundTripProbePayload: Codable, Equatable, Sendable {
    public var taskID: String
    public var model: String
    public var purpose: DeepSeekTaskPurpose
    public var minimalPayloadDigest: String
    public var requestBodyDigest: String
    public var budgetCeilingCents: Int
    public var consentReceiptID: String
    public var allowedPayloadKeys: [String]
    public var forbiddenPayloadKeys: [String]
    public var userSelectedClaims: [String]
    public var mediaKindsOnly: [String]
    public var containsRawMedia: Bool
    public var containsFullMemoryArchive: Bool
    public var clientProviderCredentialPresent: Bool

    enum CodingKeys: String, CodingKey {
        case taskID = "task_id"
        case model
        case purpose
        case minimalPayloadDigest = "minimal_payload_digest"
        case requestBodyDigest = "request_body_digest"
        case budgetCeilingCents = "budget_ceiling_cents"
        case consentReceiptID = "consent_receipt_id"
        case allowedPayloadKeys = "allowed_payload_keys"
        case forbiddenPayloadKeys = "forbidden_payload_keys"
        case userSelectedClaims = "user_selected_claims"
        case mediaKindsOnly = "media_kinds_only"
        case containsRawMedia = "contains_raw_media"
        case containsFullMemoryArchive = "contains_full_memory_archive"
        case clientProviderCredentialPresent = "client_provider_credential_present"
    }

    public init(
        taskID: String,
        model: String,
        purpose: DeepSeekTaskPurpose,
        minimalPayloadDigest: String,
        requestBodyDigest: String,
        budgetCeilingCents: Int,
        consentReceiptID: String,
        allowedPayloadKeys: [String],
        forbiddenPayloadKeys: [String],
        userSelectedClaims: [String],
        mediaKindsOnly: [String],
        containsRawMedia: Bool = false,
        containsFullMemoryArchive: Bool = false,
        clientProviderCredentialPresent: Bool = false
    ) {
        self.taskID = taskID
        self.model = model
        self.purpose = purpose
        self.minimalPayloadDigest = minimalPayloadDigest
        self.requestBodyDigest = requestBodyDigest
        self.budgetCeilingCents = budgetCeilingCents
        self.consentReceiptID = consentReceiptID
        self.allowedPayloadKeys = allowedPayloadKeys
        self.forbiddenPayloadKeys = forbiddenPayloadKeys
        self.userSelectedClaims = userSelectedClaims
        self.mediaKindsOnly = mediaKindsOnly
        self.containsRawMedia = containsRawMedia
        self.containsFullMemoryArchive = containsFullMemoryArchive
        self.clientProviderCredentialPresent = clientProviderCredentialPresent
    }

    public var isSafeForBackendRoundTrip: Bool {
        model == "deepseek-v4-flash" &&
        !minimalPayloadDigest.isEmpty &&
        !requestBodyDigest.isEmpty &&
        !consentReceiptID.isEmpty &&
        budgetCeilingCents <= 4 &&
        allowedPayloadKeys.contains("user_selected_claims") &&
        forbiddenPayloadKeys.contains("raw_media_binary") &&
        forbiddenPayloadKeys.contains("full_memory_archive") &&
        userSelectedClaims.count <= 3 &&
        mediaKindsOnly.allSatisfy { ["image", "video", "link", "none"].contains($0) } &&
        !containsRawMedia &&
        !containsFullMemoryArchive &&
        !clientProviderCredentialPresent
    }
}

public struct DeepSeekBackendRoundTripProbeResponse: Codable, Equatable, Sendable {
    public var gatewayJobID: String?
    public var auditEventID: String?
    public var model: String
    public var costEstimateCents: Int?
    public var retentionHours: Int
    public var responseDigest: String
    public var requestWasMocked: Bool
    public var providerCallPerformed: Bool
    public var providerCredentialVisibleToClient: Bool
    public var responseContainsProviderCredential: Bool
    public var responseContainsRawMedia: Bool
    public var responseContainsFullMemoryArchive: Bool
    public var responsePreservesEditableDraft: Bool
    public var completedWithUserConsent: Bool

    enum CodingKeys: String, CodingKey {
        case gatewayJobID = "gateway_job_id"
        case auditEventID = "audit_event_id"
        case model
        case costEstimateCents = "cost_estimate_cents"
        case retentionHours = "retention_hours"
        case responseDigest = "response_digest"
        case requestWasMocked = "request_was_mocked"
        case providerCallPerformed = "provider_call_performed"
        case providerCredentialVisibleToClient = "provider_credential_visible_to_client"
        case responseContainsProviderCredential = "response_contains_provider_credential"
        case responseContainsRawMedia = "response_contains_raw_media"
        case responseContainsFullMemoryArchive = "response_contains_full_memory_archive"
        case responsePreservesEditableDraft = "response_preserves_editable_draft"
        case completedWithUserConsent = "completed_with_user_consent"
    }

    public init(
        gatewayJobID: String?,
        auditEventID: String?,
        model: String = "deepseek-v4-flash",
        costEstimateCents: Int?,
        retentionHours: Int,
        responseDigest: String,
        requestWasMocked: Bool,
        providerCallPerformed: Bool,
        providerCredentialVisibleToClient: Bool = false,
        responseContainsProviderCredential: Bool = false,
        responseContainsRawMedia: Bool = false,
        responseContainsFullMemoryArchive: Bool = false,
        responsePreservesEditableDraft: Bool = true,
        completedWithUserConsent: Bool = true
    ) {
        self.gatewayJobID = gatewayJobID
        self.auditEventID = auditEventID
        self.model = model
        self.costEstimateCents = costEstimateCents
        self.retentionHours = retentionHours
        self.responseDigest = responseDigest
        self.requestWasMocked = requestWasMocked
        self.providerCallPerformed = providerCallPerformed
        self.providerCredentialVisibleToClient = providerCredentialVisibleToClient
        self.responseContainsProviderCredential = responseContainsProviderCredential
        self.responseContainsRawMedia = responseContainsRawMedia
        self.responseContainsFullMemoryArchive = responseContainsFullMemoryArchive
        self.responsePreservesEditableDraft = responsePreservesEditableDraft
        self.completedWithUserConsent = completedWithUserConsent
    }
}

public struct DeepSeekBackendRoundTripProbeReceipt: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var status: DeepSeekBackendRoundTripProbeStatus
    public var requestID: String?
    public var backendBaseURL: String?
    public var providerReceipt: DeepSeekGatewayIntegrationReceipt?
    public var payloadSafeForBackend: Bool
    public var validationNotes: [String]

    public init(
        id: String,
        status: DeepSeekBackendRoundTripProbeStatus,
        requestID: String?,
        backendBaseURL: String?,
        providerReceipt: DeepSeekGatewayIntegrationReceipt?,
        payloadSafeForBackend: Bool,
        validationNotes: [String]
    ) {
        self.id = id
        self.status = status
        self.requestID = requestID
        self.backendBaseURL = backendBaseURL
        self.providerReceipt = providerReceipt
        self.payloadSafeForBackend = payloadSafeForBackend
        self.validationNotes = validationNotes
    }

    public var canUnlockProductionAI: Bool {
        status == .providerPassed &&
        payloadSafeForBackend &&
        providerReceipt?.isProviderPassReceipt == true
    }

    public var canUnlockAppStoreAIGate: Bool {
        canUnlockProductionAI && providerReceipt?.canBeUsedForAppStoreGate == true
    }
}

public enum DeepSeekBackendRoundTripProbe {
    public static func payload(
        for plan: DeepSeekGatewayIntegrationPlan,
        claimed slices: [MemorySlice]
    ) -> DeepSeekBackendRoundTripProbePayload {
        DeepSeekBackendRoundTripProbePayload(
            taskID: plan.gateway.request.task.id,
            model: plan.productionModel,
            purpose: plan.gateway.request.task.purpose,
            minimalPayloadDigest: plan.gateway.request.task.minimalPayloadDigest,
            requestBodyDigest: plan.gateway.requestBodyDigest,
            budgetCeilingCents: plan.gateway.budgetCeilingCents,
            consentReceiptID: plan.gateway.consentReceiptID,
            allowedPayloadKeys: plan.gateway.request.task.allowedPayloadKeys,
            forbiddenPayloadKeys: plan.gateway.request.task.forbiddenPayloadKeys,
            userSelectedClaims: Array(slices.prefix(3)).map(\.title),
            mediaKindsOnly: Array(slices.prefix(3)).map { $0.media?.kind.rawValue ?? "none" }
        )
    }

    public static func encodedPayload(_ payload: DeepSeekBackendRoundTripProbePayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(payload)
    }

    public static func result(
        from response: DeepSeekBackendRoundTripProbeResponse,
        statusCode: Int,
        request: DeepSeekGatewayIntegrationTestRequest
    ) -> DeepSeekGatewayIntegrationTestResult {
        DeepSeekGatewayIntegrationTestResult(
            id: "deepseek-live-result-\(TrustDigest.checksum([request.id, response.responseDigest, "\(statusCode)"]).prefix(12))",
            request: request,
            statusCode: statusCode,
            gatewayJobID: response.gatewayJobID,
            auditEventID: response.auditEventID,
            model: response.model,
            costEstimateCents: response.costEstimateCents,
            retentionHours: response.retentionHours,
            responseDigest: response.responseDigest,
            requestWasMocked: response.requestWasMocked,
            providerCallPerformed: response.providerCallPerformed,
            providerCredentialVisibleToClient: response.providerCredentialVisibleToClient,
            responseContainsProviderCredential: response.responseContainsProviderCredential,
            responseContainsRawMedia: response.responseContainsRawMedia,
            responseContainsFullMemoryArchive: response.responseContainsFullMemoryArchive,
            responsePreservesEditableDraft: response.responsePreservesEditableDraft,
            completedWithUserConsent: response.completedWithUserConsent
        )
    }

    public static func receipt(
        plan: DeepSeekGatewayIntegrationPlan,
        request: DeepSeekGatewayIntegrationTestRequest,
        payload: DeepSeekBackendRoundTripProbePayload,
        statusCode: Int,
        response: DeepSeekBackendRoundTripProbeResponse
    ) -> DeepSeekBackendRoundTripProbeReceipt {
        let result = result(from: response, statusCode: statusCode, request: request)
        let providerReceipt = DeepSeekGatewayIntegrationTestRunner.providerPassedReceipt(
            for: plan,
            result: result
        )
        let passed = payload.isSafeForBackendRoundTrip && providerReceipt.isProviderPassReceipt
        let digest = TrustDigest.checksum([
            request.id,
            payload.requestBodyDigest,
            response.responseDigest,
            passed ? "passed" : "failed"
        ])
        return DeepSeekBackendRoundTripProbeReceipt(
            id: "deepseek-live-probe-\(digest.prefix(12))",
            status: passed ? .providerPassed : .failed,
            requestID: request.id,
            backendBaseURL: request.backendBaseURL,
            providerReceipt: providerReceipt,
            payloadSafeForBackend: payload.isSafeForBackendRoundTrip,
            validationNotes: passed ? [
                "Live backend response promoted to providerPassed through the existing provider receipt gate.",
                "Payload carried only minimal user-selected claims, media kinds, consent, digests, and budget metadata."
            ] : [
                "Live backend response could not be promoted to providerPassed.",
                "Production AI remains locked until payload, backend, and provider evidence all satisfy the gate."
            ]
        )
    }

    public static func notConfiguredReceipt() -> DeepSeekBackendRoundTripProbeReceipt {
        DeepSeekBackendRoundTripProbeReceipt(
            id: "deepseek-live-probe-not-configured",
            status: .notConfigured,
            requestID: nil,
            backendBaseURL: nil,
            providerReceipt: nil,
            payloadSafeForBackend: false,
            validationNotes: [
                "Set TSD_DEEPSEEK_BACKEND_BASE_URL and TSD_DEEPSEEK_TEST_TOKEN to run the optional live backend probe.",
                "The client never accepts a DeepSeek provider key; provider credentials must remain behind the TSD backend."
            ]
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

public struct CryptoKitMediaVaultImplementationPlan: Codable, Equatable, Sendable {
    public var keyID: String
    public var contentEncryptionAlgorithm: String
    public var keyAgreementAlgorithm: String
    public var keyDerivationAlgorithm: String
    public var secureEnclavePrivateKeyPolicy: String
    public var keychainAccessControlPolicy: String
    public var noncePolicy: String
    public var authenticatedDataRequired: Bool
    public var storesContentEncryptionKey: Bool
    public var storesPlaintextMedia: Bool
    public var allowsCloudUpload: Bool
    public var allowsAIProviderAccess: Bool
    public var supportsPostSubscriptionExport: Bool
    public var supportsPostSubscriptionDelete: Bool
    public var migratesFromDevelopmentVault: Bool
    public var requiresSignedDeviceValidation: Bool
    public var trustLevel: ProductionTrustLevel

    public init(
        keyID: String,
        contentEncryptionAlgorithm: String = "CryptoKit.AES.GCM",
        keyAgreementAlgorithm: String = "SecureEnclave.P256.KeyAgreement.PrivateKey",
        keyDerivationAlgorithm: String = "HKDF-SHA256-per-record",
        secureEnclavePrivateKeyPolicy: String = "non-extractable-this-device-only",
        keychainAccessControlPolicy: String = "biometry-current-set-or-device-passcode",
        noncePolicy: String = "random-96-bit-nonce-required",
        authenticatedDataRequired: Bool = true,
        storesContentEncryptionKey: Bool = false,
        storesPlaintextMedia: Bool = false,
        allowsCloudUpload: Bool = false,
        allowsAIProviderAccess: Bool = false,
        supportsPostSubscriptionExport: Bool = true,
        supportsPostSubscriptionDelete: Bool = true,
        migratesFromDevelopmentVault: Bool = true,
        requiresSignedDeviceValidation: Bool = true,
        trustLevel: ProductionTrustLevel = .productionRequired
    ) {
        self.keyID = keyID
        self.contentEncryptionAlgorithm = contentEncryptionAlgorithm
        self.keyAgreementAlgorithm = keyAgreementAlgorithm
        self.keyDerivationAlgorithm = keyDerivationAlgorithm
        self.secureEnclavePrivateKeyPolicy = secureEnclavePrivateKeyPolicy
        self.keychainAccessControlPolicy = keychainAccessControlPolicy
        self.noncePolicy = noncePolicy
        self.authenticatedDataRequired = authenticatedDataRequired
        self.storesContentEncryptionKey = storesContentEncryptionKey
        self.storesPlaintextMedia = storesPlaintextMedia
        self.allowsCloudUpload = allowsCloudUpload
        self.allowsAIProviderAccess = allowsAIProviderAccess
        self.supportsPostSubscriptionExport = supportsPostSubscriptionExport
        self.supportsPostSubscriptionDelete = supportsPostSubscriptionDelete
        self.migratesFromDevelopmentVault = migratesFromDevelopmentVault
        self.requiresSignedDeviceValidation = requiresSignedDeviceValidation
        self.trustLevel = trustLevel
    }

    public static func plan(for deviceKey: DeviceKeyRecord) -> CryptoKitMediaVaultImplementationPlan {
        CryptoKitMediaVaultImplementationPlan(keyID: deviceKey.keyID)
    }

    public var isTSDProductionCryptoPlanSafe: Bool {
        keyID.hasPrefix("tsd-device-") &&
        contentEncryptionAlgorithm == "CryptoKit.AES.GCM" &&
        keyAgreementAlgorithm == "SecureEnclave.P256.KeyAgreement.PrivateKey" &&
        keyDerivationAlgorithm == "HKDF-SHA256-per-record" &&
        secureEnclavePrivateKeyPolicy == "non-extractable-this-device-only" &&
        keychainAccessControlPolicy == "biometry-current-set-or-device-passcode" &&
        noncePolicy == "random-96-bit-nonce-required" &&
        authenticatedDataRequired &&
        !storesContentEncryptionKey &&
        !storesPlaintextMedia &&
        !allowsCloudUpload &&
        !allowsAIProviderAccess &&
        supportsPostSubscriptionExport &&
        supportsPostSubscriptionDelete &&
        migratesFromDevelopmentVault &&
        requiresSignedDeviceValidation &&
        trustLevel == .productionRequired
    }
}

public struct CryptoKitMediaVaultSealEnvelope: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var sourceRecordID: String
    public var anchorID: String
    public var keyID: String
    public var contentEncryptionAlgorithm: String
    public var keyAgreementAlgorithm: String
    public var keyDerivationAlgorithm: String
    public var noncePolicy: String
    public var additionalAuthenticatedData: [String]
    public var sealedBoxByteCount: Int
    public var authenticationTagByteCount: Int
    public var ciphertextDigest: String
    public var storesPlaintextMedia: Bool
    public var storesContentEncryptionKey: Bool
    public var allowsCloudUpload: Bool
    public var allowsAIProviderAccess: Bool
    public var requiresSignedDeviceValidation: Bool
    public var trustLevel: ProductionTrustLevel

    public init(
        id: String,
        sourceRecordID: String,
        anchorID: String,
        keyID: String,
        contentEncryptionAlgorithm: String,
        keyAgreementAlgorithm: String,
        keyDerivationAlgorithm: String,
        noncePolicy: String,
        additionalAuthenticatedData: [String],
        sealedBoxByteCount: Int,
        authenticationTagByteCount: Int,
        ciphertextDigest: String,
        storesPlaintextMedia: Bool = false,
        storesContentEncryptionKey: Bool = false,
        allowsCloudUpload: Bool = false,
        allowsAIProviderAccess: Bool = false,
        requiresSignedDeviceValidation: Bool = true,
        trustLevel: ProductionTrustLevel = .productionRequired
    ) {
        self.id = id
        self.sourceRecordID = sourceRecordID
        self.anchorID = anchorID
        self.keyID = keyID
        self.contentEncryptionAlgorithm = contentEncryptionAlgorithm
        self.keyAgreementAlgorithm = keyAgreementAlgorithm
        self.keyDerivationAlgorithm = keyDerivationAlgorithm
        self.noncePolicy = noncePolicy
        self.additionalAuthenticatedData = additionalAuthenticatedData
        self.sealedBoxByteCount = sealedBoxByteCount
        self.authenticationTagByteCount = authenticationTagByteCount
        self.ciphertextDigest = ciphertextDigest
        self.storesPlaintextMedia = storesPlaintextMedia
        self.storesContentEncryptionKey = storesContentEncryptionKey
        self.allowsCloudUpload = allowsCloudUpload
        self.allowsAIProviderAccess = allowsAIProviderAccess
        self.requiresSignedDeviceValidation = requiresSignedDeviceValidation
        self.trustLevel = trustLevel
    }

    public var isTSDCryptoKitEnvelopeSafe: Bool {
        !sourceRecordID.isEmpty &&
        !anchorID.isEmpty &&
        keyID.hasPrefix("tsd-device-") &&
        contentEncryptionAlgorithm == "CryptoKit.AES.GCM" &&
        keyAgreementAlgorithm == "SecureEnclave.P256.KeyAgreement.PrivateKey" &&
        keyDerivationAlgorithm == "HKDF-SHA256-per-record" &&
        noncePolicy == "random-96-bit-nonce-required" &&
        additionalAuthenticatedData.contains("anchor:\(anchorID)") &&
        sealedBoxByteCount > authenticationTagByteCount &&
        authenticationTagByteCount == 16 &&
        !ciphertextDigest.isEmpty &&
        !storesPlaintextMedia &&
        !storesContentEncryptionKey &&
        !allowsCloudUpload &&
        !allowsAIProviderAccess &&
        requiresSignedDeviceValidation &&
        trustLevel == .productionRequired
    }
}

public enum CryptoKitMediaVaultEnvelopeError: Error, Equatable, Sendable {
    case unsafePlan(String)
    case unsafeRecord(String)
    case cryptoKitUnavailable(String)
    case sealingFailed(String)
}

public enum CryptoKitMediaVaultEnvelopeFactory {
    public static var canUseCryptoKit: Bool {
        #if canImport(CryptoKit)
        true
        #else
        false
        #endif
    }

    public static func envelope(
        for record: E2EEMediaVaultRecord,
        plan: CryptoKitMediaVaultImplementationPlan
    ) throws -> CryptoKitMediaVaultSealEnvelope {
        guard plan.isTSDProductionCryptoPlanSafe else {
            throw CryptoKitMediaVaultEnvelopeError.unsafePlan(plan.keyID)
        }
        guard record.isTSDMediaVaultSafe else {
            throw CryptoKitMediaVaultEnvelopeError.unsafeRecord(record.id)
        }
        guard record.keyID == plan.keyID else {
            throw CryptoKitMediaVaultEnvelopeError.unsafeRecord(record.id)
        }

        #if canImport(CryptoKit)
        let payload = productionEnvelopePayload(for: record)
        let symmetricKey = derivedSymmetricKey(for: record, plan: plan)
        let sealedBox = try AES.GCM.seal(payload, using: symmetricKey, authenticating: Data(record.additionalAuthenticatedData.joined(separator: "|").utf8))
        guard let combined = sealedBox.combined else {
            throw CryptoKitMediaVaultEnvelopeError.sealingFailed(record.id)
        }
        let digest = SHA256.hash(data: combined).map { String(format: "%02x", $0) }.joined()
        return CryptoKitMediaVaultSealEnvelope(
            id: "cryptokit-media-vault-\(digest.prefix(12))",
            sourceRecordID: record.id,
            anchorID: record.anchorID,
            keyID: record.keyID,
            contentEncryptionAlgorithm: plan.contentEncryptionAlgorithm,
            keyAgreementAlgorithm: plan.keyAgreementAlgorithm,
            keyDerivationAlgorithm: plan.keyDerivationAlgorithm,
            noncePolicy: plan.noncePolicy,
            additionalAuthenticatedData: record.additionalAuthenticatedData,
            sealedBoxByteCount: combined.count,
            authenticationTagByteCount: sealedBox.tag.count,
            ciphertextDigest: digest,
            requiresSignedDeviceValidation: plan.requiresSignedDeviceValidation
        )
        #else
        throw CryptoKitMediaVaultEnvelopeError.cryptoKitUnavailable(record.id)
        #endif
    }

    private static func productionEnvelopePayload(for record: E2EEMediaVaultRecord) -> Data {
        var payload = Data()
        payload.append(record.thumbnailCiphertext)
        if let originalCiphertext = record.originalCiphertext {
            payload.append(originalCiphertext)
        }
        payload.append(Data(record.thumbnailDigest.utf8))
        if let originalDigest = record.originalDigest {
            payload.append(Data(originalDigest.utf8))
        }
        return payload
    }

    #if canImport(CryptoKit)
    private static func derivedSymmetricKey(
        for record: E2EEMediaVaultRecord,
        plan: CryptoKitMediaVaultImplementationPlan
    ) -> SymmetricKey {
        let material = Data([
            plan.keyID,
            record.id,
            record.nonce,
            plan.keyDerivationAlgorithm
        ].joined(separator: "|").utf8)
        let digest = SHA256.hash(data: material)
        return SymmetricKey(data: Data(digest))
    }
    #endif
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

public enum DeletionServiceLiveProbeStatus: String, Codable, Equatable, Sendable {
    case notConfigured
    case accepted
    case completed
    case failed
}

public struct DeletionServiceLiveProbePayload: Codable, Equatable, Sendable {
    public var deletionReceiptID: String
    public var deletionRequestID: String
    public var bodyDigest: String
    public var exportFileName: String?
    public var idempotencyKey: String
    public var systemsToErase: [String]
    public var systemsRequiringTombstone: [String]
    public var requiresReauthentication: Bool
    public var requiresExportOpportunity: Bool
    public var availableAfterSubscriptionEnds: Bool
    public var maxCompletionHours: Int
    public var containsRawMemoryPayload: Bool
    public var containsRawMedia: Bool
    public var testAccountOnly: Bool

    enum CodingKeys: String, CodingKey {
        case deletionReceiptID = "deletion_receipt_id"
        case deletionRequestID = "deletion_request_id"
        case bodyDigest = "body_digest"
        case exportFileName = "export_file_name"
        case idempotencyKey = "idempotency_key"
        case systemsToErase = "systems_to_erase"
        case systemsRequiringTombstone = "systems_requiring_tombstone"
        case requiresReauthentication = "requires_reauthentication"
        case requiresExportOpportunity = "requires_export_opportunity"
        case availableAfterSubscriptionEnds = "available_after_subscription_ends"
        case maxCompletionHours = "max_completion_hours"
        case containsRawMemoryPayload = "contains_raw_memory_payload"
        case containsRawMedia = "contains_raw_media"
        case testAccountOnly = "test_account_only"
    }

    public init(
        deletionReceiptID: String,
        deletionRequestID: String,
        bodyDigest: String,
        exportFileName: String?,
        idempotencyKey: String,
        systemsToErase: [String],
        systemsRequiringTombstone: [String],
        requiresReauthentication: Bool = true,
        requiresExportOpportunity: Bool = true,
        availableAfterSubscriptionEnds: Bool = true,
        maxCompletionHours: Int = 24,
        containsRawMemoryPayload: Bool = false,
        containsRawMedia: Bool = false,
        testAccountOnly: Bool = true
    ) {
        self.deletionReceiptID = deletionReceiptID
        self.deletionRequestID = deletionRequestID
        self.bodyDigest = bodyDigest
        self.exportFileName = exportFileName
        self.idempotencyKey = idempotencyKey
        self.systemsToErase = systemsToErase
        self.systemsRequiringTombstone = systemsRequiringTombstone
        self.requiresReauthentication = requiresReauthentication
        self.requiresExportOpportunity = requiresExportOpportunity
        self.availableAfterSubscriptionEnds = availableAfterSubscriptionEnds
        self.maxCompletionHours = maxCompletionHours
        self.containsRawMemoryPayload = containsRawMemoryPayload
        self.containsRawMedia = containsRawMedia
        self.testAccountOnly = testAccountOnly
    }

    public var isSafeForDeletionServiceProbe: Bool {
        !deletionReceiptID.isEmpty &&
        !deletionRequestID.isEmpty &&
        !bodyDigest.isEmpty &&
        !idempotencyKey.isEmpty &&
        systemsToErase.contains("encrypted-backup") &&
        systemsToErase.contains("ai-draft-cache") &&
        systemsToErase.contains("thumbnail-cache") &&
        systemsRequiringTombstone.contains("account-ledger") &&
        requiresReauthentication &&
        requiresExportOpportunity &&
        availableAfterSubscriptionEnds &&
        maxCompletionHours <= 24 &&
        !containsRawMemoryPayload &&
        !containsRawMedia &&
        testAccountOnly
    }
}

public struct DeletionServiceLiveProbeResponse: Codable, Equatable, Sendable {
    public var deletionReceiptID: String?
    public var deletionJobID: String?
    public var auditEventID: String?
    public var tombstoneID: String?
    public var perSystemResults: [String: String]
    public var completionReceiptDigest: String
    public var status: DeletionServiceLiveProbeStatus
    public var completedWithReauthentication: Bool
    public var exportOpportunityPreserved: Bool
    public var writeFreezeApplied: Bool
    public var receiptDownloadableAfterCompletion: Bool
    public var maxCompletionHours: Int
    public var responseContainsRawMemoryPayload: Bool
    public var responseContainsRawMedia: Bool
    public var testAccountOnly: Bool

    enum CodingKeys: String, CodingKey {
        case deletionReceiptID = "deletion_receipt_id"
        case deletionJobID = "deletion_job_id"
        case auditEventID = "audit_event_id"
        case tombstoneID = "tombstone_id"
        case perSystemResults = "per_system_results"
        case completionReceiptDigest = "completion_receipt_digest"
        case status
        case completedWithReauthentication = "completed_with_reauthentication"
        case exportOpportunityPreserved = "export_opportunity_preserved"
        case writeFreezeApplied = "write_freeze_applied"
        case receiptDownloadableAfterCompletion = "receipt_downloadable_after_completion"
        case maxCompletionHours = "max_completion_hours"
        case responseContainsRawMemoryPayload = "response_contains_raw_memory_payload"
        case responseContainsRawMedia = "response_contains_raw_media"
        case testAccountOnly = "test_account_only"
    }

    public init(
        deletionReceiptID: String?,
        deletionJobID: String?,
        auditEventID: String?,
        tombstoneID: String?,
        perSystemResults: [String: String],
        completionReceiptDigest: String,
        status: DeletionServiceLiveProbeStatus,
        completedWithReauthentication: Bool = true,
        exportOpportunityPreserved: Bool = true,
        writeFreezeApplied: Bool = true,
        receiptDownloadableAfterCompletion: Bool = true,
        maxCompletionHours: Int = 24,
        responseContainsRawMemoryPayload: Bool = false,
        responseContainsRawMedia: Bool = false,
        testAccountOnly: Bool = true
    ) {
        self.deletionReceiptID = deletionReceiptID
        self.deletionJobID = deletionJobID
        self.auditEventID = auditEventID
        self.tombstoneID = tombstoneID
        self.perSystemResults = perSystemResults
        self.completionReceiptDigest = completionReceiptDigest
        self.status = status
        self.completedWithReauthentication = completedWithReauthentication
        self.exportOpportunityPreserved = exportOpportunityPreserved
        self.writeFreezeApplied = writeFreezeApplied
        self.receiptDownloadableAfterCompletion = receiptDownloadableAfterCompletion
        self.maxCompletionHours = maxCompletionHours
        self.responseContainsRawMemoryPayload = responseContainsRawMemoryPayload
        self.responseContainsRawMedia = responseContainsRawMedia
        self.testAccountOnly = testAccountOnly
    }
}

public struct DeletionServiceLiveProbeReceipt: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var status: DeletionServiceLiveProbeStatus
    public var deletionReceiptID: String?
    public var deletionJobID: String?
    public var auditEventID: String?
    public var tombstoneID: String?
    public var backendBaseURL: String?
    public var payloadSafeForDeletionService: Bool
    public var responseSafeForDeletionRights: Bool
    public var validationNotes: [String]

    public init(
        id: String,
        status: DeletionServiceLiveProbeStatus,
        deletionReceiptID: String?,
        deletionJobID: String?,
        auditEventID: String?,
        tombstoneID: String?,
        backendBaseURL: String?,
        payloadSafeForDeletionService: Bool,
        responseSafeForDeletionRights: Bool,
        validationNotes: [String]
    ) {
        self.id = id
        self.status = status
        self.deletionReceiptID = deletionReceiptID
        self.deletionJobID = deletionJobID
        self.auditEventID = auditEventID
        self.tombstoneID = tombstoneID
        self.backendBaseURL = backendBaseURL
        self.payloadSafeForDeletionService = payloadSafeForDeletionService
        self.responseSafeForDeletionRights = responseSafeForDeletionRights
        self.validationNotes = validationNotes
    }

    public var canSatisfyProductionDeletionGate: Bool {
        [DeletionServiceLiveProbeStatus.accepted, .completed].contains(status) &&
        payloadSafeForDeletionService &&
        responseSafeForDeletionRights &&
        deletionReceiptID != nil &&
        deletionJobID != nil &&
        auditEventID != nil &&
        tombstoneID != nil
    }

    public var canSatisfyAppStoreDeletionGate: Bool {
        canSatisfyProductionDeletionGate && status == .completed
    }
}

public enum DeletionServiceLiveProbe {
    public static func payload(for service: DeletionServiceIntegrationEnvelope) -> DeletionServiceLiveProbePayload {
        DeletionServiceLiveProbePayload(
            deletionReceiptID: service.deletionReceiptID,
            deletionRequestID: service.clientEnvelope.request.id,
            bodyDigest: service.clientEnvelope.bodyDigest,
            exportFileName: service.exportFileName,
            idempotencyKey: service.clientEnvelope.request.idempotencyKey,
            systemsToErase: service.systemsToErase.sorted(),
            systemsRequiringTombstone: service.systemsRequiringTombstone.sorted(),
            requiresReauthentication: service.requiresReauthentication,
            requiresExportOpportunity: service.requiresExportOpportunity,
            availableAfterSubscriptionEnds: service.availableAfterSubscriptionEnds,
            maxCompletionHours: service.maxCompletionHours,
            containsRawMemoryPayload: service.containsRawMemoryPayload,
            containsRawMedia: service.containsRawMedia
        )
    }

    public static func encodedPayload(_ payload: DeletionServiceLiveProbePayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(payload)
    }

    public static func receipt(
        service: DeletionServiceIntegrationEnvelope,
        payload: DeletionServiceLiveProbePayload,
        statusCode: Int,
        backendBaseURL: String,
        response: DeletionServiceLiveProbeResponse
    ) -> DeletionServiceLiveProbeReceipt {
        let allowedStatus =
        (statusCode == service.responseContract.acceptedStatusCode && response.status == .accepted) ||
        (statusCode == service.responseContract.completedStatusCode && response.status == .completed)
        let responseSafe =
        allowedStatus &&
        response.deletionReceiptID == service.deletionReceiptID &&
        response.deletionJobID != nil &&
        response.auditEventID != nil &&
        response.tombstoneID != nil &&
        response.perSystemResults.keys.contains("encrypted-backup") &&
        response.perSystemResults.keys.contains("ai-draft-cache") &&
        response.perSystemResults.keys.contains("thumbnail-cache") &&
        !response.completionReceiptDigest.isEmpty &&
        response.completedWithReauthentication &&
        response.exportOpportunityPreserved &&
        response.writeFreezeApplied &&
        response.receiptDownloadableAfterCompletion &&
        response.maxCompletionHours <= service.maxCompletionHours &&
        !response.responseContainsRawMemoryPayload &&
        !response.responseContainsRawMedia &&
        response.testAccountOnly

        let canPass = service.isDeletionRightsSafe && payload.isSafeForDeletionServiceProbe && responseSafe
        let digest = TrustDigest.checksum([
            service.id,
            payload.bodyDigest,
            response.completionReceiptDigest,
            canPass ? "passed" : "failed"
        ])
        return DeletionServiceLiveProbeReceipt(
            id: "deletion-live-probe-\(digest.prefix(12))",
            status: canPass ? response.status : .failed,
            deletionReceiptID: response.deletionReceiptID,
            deletionJobID: response.deletionJobID,
            auditEventID: response.auditEventID,
            tombstoneID: response.tombstoneID,
            backendBaseURL: backendBaseURL,
            payloadSafeForDeletionService: payload.isSafeForDeletionServiceProbe,
            responseSafeForDeletionRights: responseSafe,
            validationNotes: canPass ? [
                "Deletion service live probe produced job, audit, tombstone, and per-system erasure evidence.",
                "Probe used a test account boundary and did not send or receive raw memory/media payloads."
            ] : [
                "Deletion service live probe evidence was incomplete or unsafe.",
                "Production deletion and App Store deletion gates remain locked until backend evidence satisfies the contract."
            ]
        )
    }

    public static func notConfiguredReceipt() -> DeletionServiceLiveProbeReceipt {
        DeletionServiceLiveProbeReceipt(
            id: "deletion-live-probe-not-configured",
            status: .notConfigured,
            deletionReceiptID: nil,
            deletionJobID: nil,
            auditEventID: nil,
            tombstoneID: nil,
            backendBaseURL: nil,
            payloadSafeForDeletionService: false,
            responseSafeForDeletionRights: false,
            validationNotes: [
                "Set TSD_DELETION_BACKEND_BASE_URL and TSD_DELETION_TEST_TOKEN to run the optional live deletion service probe.",
                "The probe must run against a TSD-owned test account boundary and must not send raw memory or raw media."
            ]
        )
    }
}

public struct TSDBackendReleaseManifest: Codable, Equatable, Sendable {
    public var baseURL: String?
    public var healthEndpointPath: String
    public var weeklyChapterEndpointPath: String
    public var deletionJobsEndpointPath: String
    public var serverRuntime: String
    public var serverSecretManager: String
    public var deepSeekProviderCredentialStoredServerSide: Bool
    public var deletionWorkerConfigured: Bool
    public var auditLogConfigured: Bool
    public var testAccountBoundaryEnabled: Bool
    public var rawMediaUploadDisabledForAI: Bool
    public var fullArchiveUploadDisabledForAI: Bool
    public var providerKeyBlockedFromClient: Bool
    public var deletionCompletionReceiptDownloadable: Bool

    public init(
        baseURL: String? = nil,
        healthEndpointPath: String = "/v1/health",
        weeklyChapterEndpointPath: String = "/v1/ai/tasks/weekly-chapter",
        deletionJobsEndpointPath: String = "/v1/account/deletion-jobs",
        serverRuntime: String = "not-deployed",
        serverSecretManager: String = "required-before-release",
        deepSeekProviderCredentialStoredServerSide: Bool = false,
        deletionWorkerConfigured: Bool = false,
        auditLogConfigured: Bool = false,
        testAccountBoundaryEnabled: Bool = false,
        rawMediaUploadDisabledForAI: Bool = true,
        fullArchiveUploadDisabledForAI: Bool = true,
        providerKeyBlockedFromClient: Bool = true,
        deletionCompletionReceiptDownloadable: Bool = false
    ) {
        self.baseURL = baseURL
        self.healthEndpointPath = healthEndpointPath
        self.weeklyChapterEndpointPath = weeklyChapterEndpointPath
        self.deletionJobsEndpointPath = deletionJobsEndpointPath
        self.serverRuntime = serverRuntime
        self.serverSecretManager = serverSecretManager
        self.deepSeekProviderCredentialStoredServerSide = deepSeekProviderCredentialStoredServerSide
        self.deletionWorkerConfigured = deletionWorkerConfigured
        self.auditLogConfigured = auditLogConfigured
        self.testAccountBoundaryEnabled = testAccountBoundaryEnabled
        self.rawMediaUploadDisabledForAI = rawMediaUploadDisabledForAI
        self.fullArchiveUploadDisabledForAI = fullArchiveUploadDisabledForAI
        self.providerKeyBlockedFromClient = providerKeyBlockedFromClient
        self.deletionCompletionReceiptDownloadable = deletionCompletionReceiptDownloadable
    }

    public var usesProductionHTTPSBaseURL: Bool {
        guard let baseURL else { return false }
        return baseURL.hasPrefix("https://") &&
        !baseURL.localizedCaseInsensitiveContains("localhost") &&
        !baseURL.localizedCaseInsensitiveContains("127.0.0.1") &&
        !baseURL.localizedCaseInsensitiveContains("example.com") &&
        !baseURL.localizedCaseInsensitiveContains("required") &&
        !baseURL.localizedCaseInsensitiveContains("todo")
    }

    public var endpointShapeMatchesNativeProbes: Bool {
        healthEndpointPath == "/v1/health" &&
        weeklyChapterEndpointPath == "/v1/ai/tasks/weekly-chapter" &&
        deletionJobsEndpointPath == "/v1/account/deletion-jobs"
    }

    public var hasServerSideCredentialBoundary: Bool {
        deepSeekProviderCredentialStoredServerSide &&
        providerKeyBlockedFromClient &&
        !serverSecretManager.isEmpty &&
        !serverSecretManager.localizedCaseInsensitiveContains("required") &&
        !serverSecretManager.localizedCaseInsensitiveContains("client")
    }

    public var hasDeletionServiceBoundary: Bool {
        deletionWorkerConfigured &&
        auditLogConfigured &&
        testAccountBoundaryEnabled &&
        deletionCompletionReceiptDownloadable
    }

    public var forbidsUnsafeAIPayloads: Bool {
        rawMediaUploadDisabledForAI && fullArchiveUploadDisabledForAI
    }

    public var hasDeployableShape: Bool {
        usesProductionHTTPSBaseURL &&
        endpointShapeMatchesNativeProbes &&
        serverRuntime != "not-deployed" &&
        hasServerSideCredentialBoundary &&
        hasDeletionServiceBoundary &&
        forbidsUnsafeAIPayloads
    }
}

public struct TSDBackendReleaseEvidence: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var manifest: TSDBackendReleaseManifest
    public var deepSeekReceipt: DeepSeekBackendRoundTripProbeReceipt?
    public var deletionReceipt: DeletionServiceLiveProbeReceipt?
    public var deploymentReviewCompleted: Bool

    public init(
        manifest: TSDBackendReleaseManifest = TSDBackendReleaseManifest(),
        deepSeekReceipt: DeepSeekBackendRoundTripProbeReceipt? = nil,
        deletionReceipt: DeletionServiceLiveProbeReceipt? = nil,
        deploymentReviewCompleted: Bool = false
    ) {
        let digest = TrustDigest.checksum([
            manifest.baseURL ?? "no-backend-url",
            manifest.weeklyChapterEndpointPath,
            manifest.deletionJobsEndpointPath,
            deepSeekReceipt?.id ?? "no-deepseek-receipt",
            deletionReceipt?.id ?? "no-deletion-receipt",
            deploymentReviewCompleted ? "reviewed" : "unreviewed"
        ])
        self.id = "tsd-backend-release-\(digest.prefix(12))"
        self.manifest = manifest
        self.deepSeekReceipt = deepSeekReceipt
        self.deletionReceipt = deletionReceipt
        self.deploymentReviewCompleted = deploymentReviewCompleted
    }

    public var canSatisfyBackendDeploymentGate: Bool {
        manifest.hasDeployableShape &&
        deepSeekReceipt?.canUnlockAppStoreAIGate == true &&
        deletionReceipt?.canSatisfyAppStoreDeletionGate == true &&
        deploymentReviewCompleted
    }

    public var blockerReasons: [String] {
        var reasons: [String] = []
        if !manifest.usesProductionHTTPSBaseURL {
            reasons.append("production HTTPS backend base URL missing")
        }
        if !manifest.endpointShapeMatchesNativeProbes {
            reasons.append("backend endpoint paths do not match native live probes")
        }
        if !manifest.hasServerSideCredentialBoundary {
            reasons.append("server-side DeepSeek credential boundary missing")
        }
        if !manifest.hasDeletionServiceBoundary {
            reasons.append("deletion worker/audit/test-account/completion receipt boundary missing")
        }
        if !manifest.forbidsUnsafeAIPayloads {
            reasons.append("AI payload policy still allows raw media or full archive upload")
        }
        if deepSeekReceipt?.canUnlockAppStoreAIGate != true {
            reasons.append("real DeepSeek provider round trip receipt missing")
        }
        if deletionReceipt?.canSatisfyAppStoreDeletionGate != true {
            reasons.append("completed deletion service receipt missing")
        }
        if !deploymentReviewCompleted {
            reasons.append("backend deployment review not completed")
        }
        return reasons
    }
}

public enum ProductionImplementationChecklist {
    public static let rows: [ReadinessRow] = [
        .init(id: "keychain-persistence-plan", title: "Keychain persistence plan", status: .poc, owner: "iOS", evidence: "Device key storage plan uses this-device-only Keychain defaults and no access group until Team ID exists; v41 adds a Security.framework Keychain record store adapter."),
        .init(id: "deepseek-gateway-request", title: "DeepSeek gateway request", status: .poc, owner: "backend/AI", evidence: "Client request targets TSD backend, never carries provider API key, keeps local-rules fallback, v46 adds a server gateway envelope with budget/consent/retention/data residency, v55 adds pending/mock/provider validation receipts, v56 adds redacted integration test request/result contracts, v57 adds the backend endpoint/provider proxy contract, v58 adds a local executable endpoint harness that validates gates without pretending to be a real provider pass, and v59 adds an optional live backend probe for real TSD backend/provider evidence."),
        .init(id: "backend-release-manifest", title: "Backend release manifest", status: .poc, owner: "backend/release", evidence: "v63 adds a backend release manifest gate for a real HTTPS TSD backend, server-side DeepSeek secret manager, weekly chapter endpoint, deletion jobs endpoint, audit log, deletion worker, and live provider/deletion receipts."),
        .init(id: "export-archive-plan", title: "Export archive plan", status: .poc, owner: "iOS/backend", evidence: "ZIP package plan includes manifest/slices/chapters/media index/deletion rights and remains available after subscription ends; v42 adds an on-device store-only ZIP builder."),
        .init(id: "raw-media-export-policy", title: "Raw media export policy", status: .poc, owner: "iOS/privacy", evidence: "v48 adds an explicit opt-in raw photo/video export envelope; v49 adds a staged file export builder that writes thumbnails and user-selected originals into a local ZIP package without cloud/provider upload or AI transcripts."),
        .init(id: "e2ee-media-vault-adapter", title: "E2EE media vault adapter", status: .poc, owner: "iOS/privacy", evidence: "v51 adds a local media vault adapter that seals user-selected media payloads into ciphertext records, unseals them for export after consent, and produces deletion receipts without cloud/provider upload or plaintext persistence; v52 adds a CryptoKit AES.GCM envelope contract for the production implementation path; v53 adds a Secure Enclave device-key request/reference contract; v54 adds the signed-device Keychain/Secure Enclave validation scaffold."),
        .init(id: "deletion-api-request", title: "Deletion API request", status: .poc, owner: "backend/legal", evidence: "Deletion receipt request is idempotent, authenticated, raw-memory-free, available after subscription ends; v45 adds a privacy-review-safe client audit envelope, v47 adds a deletion service integration boundary, and v60 adds an optional live deletion service probe for real backend job/audit/tombstone evidence.")
    ]
}
