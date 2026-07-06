import Foundation

#if canImport(Security)
import Security
#endif

public struct KeychainDeviceKeyPayload: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var record: DeviceKeyRecord
    public var keyReferenceDigest: String
    public var containsPrivateKeyMaterial: Bool
    public var createdAt: Date

    public init(
        schemaVersion: Int = 1,
        record: DeviceKeyRecord,
        keyReferenceDigest: String,
        containsPrivateKeyMaterial: Bool = false,
        createdAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.record = record
        self.keyReferenceDigest = keyReferenceDigest
        self.containsPrivateKeyMaterial = containsPrivateKeyMaterial
        self.createdAt = createdAt
    }

    public static func metadataOnly(for record: DeviceKeyRecord) -> KeychainDeviceKeyPayload {
        KeychainDeviceKeyPayload(
            record: record,
            keyReferenceDigest: TrustDigest.checksum([record.keyID, record.accountID, record.deviceName]),
            containsPrivateKeyMaterial: false,
            createdAt: record.createdAt
        )
    }

    public var isMetadataOnly: Bool {
        !containsPrivateKeyMaterial &&
        !record.privateKeyExtractable &&
        !record.secretMaterialPersistedInRepo
    }
}

public struct KeychainQuerySnapshot: Codable, Equatable, Sendable {
    public var service: String
    public var account: String
    public var accessGroup: String?
    public var accessible: KeychainAccessiblePolicy
    public var synchronizable: Bool
    public var thisDeviceOnly: Bool
    public var operation: String

    public init(
        service: String,
        account: String,
        accessGroup: String?,
        accessible: KeychainAccessiblePolicy,
        synchronizable: Bool,
        thisDeviceOnly: Bool,
        operation: String
    ) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
        self.accessible = accessible
        self.synchronizable = synchronizable
        self.thisDeviceOnly = thisDeviceOnly
        self.operation = operation
    }

    public var isSafeTSDDeviceKeyQuery: Bool {
        service == "com.raingodprc.timeslowdown.device-key" &&
        accessGroup == nil &&
        !synchronizable &&
        thisDeviceOnly &&
        accessible == .whenUnlockedThisDeviceOnly
    }
}

public enum KeychainDeviceKeyStoreError: Error, Equatable, Sendable {
    case unsupportedPlatform
    case unsafePlan(String)
    case encodingFailed
    case decodingFailed
    case itemNotFound
    case keychainStatus(Int32)
}

public struct KeychainDeviceKeyStore: Sendable {
    public var plan: KeychainPersistencePlan
    public var encoder: JSONEncoder
    public var decoder: JSONDecoder

    public init(
        plan: KeychainPersistencePlan,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.plan = plan
        self.encoder = encoder
        self.decoder = decoder
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func querySnapshot(operation: String) -> KeychainQuerySnapshot {
        KeychainQuerySnapshot(
            service: plan.service,
            account: plan.account,
            accessGroup: plan.accessGroup,
            accessible: plan.accessible,
            synchronizable: plan.synchronizable,
            thisDeviceOnly: plan.thisDeviceOnly,
            operation: operation
        )
    }

    public var canUseProductionKeychain: Bool {
        #if canImport(Security)
        plan.isSafeDefault
        #else
        false
        #endif
    }

    public func encodedPayload(_ payload: KeychainDeviceKeyPayload) throws -> Data {
        do {
            return try encoder.encode(payload)
        } catch {
            throw KeychainDeviceKeyStoreError.encodingFailed
        }
    }

    public func decodedPayload(from data: Data) throws -> KeychainDeviceKeyPayload {
        do {
            return try decoder.decode(KeychainDeviceKeyPayload.self, from: data)
        } catch {
            throw KeychainDeviceKeyStoreError.decodingFailed
        }
    }

    public func save(_ payload: KeychainDeviceKeyPayload) throws {
        try ensureSafePlan()
        let data = try encodedPayload(payload)
        #if canImport(Security)
        var query = baseQuery()
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let attributes = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(baseQuery() as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainDeviceKeyStoreError.keychainStatus(updateStatus)
            }
            return
        }
        guard status == errSecSuccess else {
            throw KeychainDeviceKeyStoreError.keychainStatus(status)
        }
        #else
        _ = data
        throw KeychainDeviceKeyStoreError.unsupportedPlatform
        #endif
    }

    public func load() throws -> KeychainDeviceKeyPayload {
        try ensureSafePlan()
        #if canImport(Security)
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            throw KeychainDeviceKeyStoreError.itemNotFound
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainDeviceKeyStoreError.keychainStatus(status)
        }
        return try decodedPayload(from: data)
        #else
        throw KeychainDeviceKeyStoreError.unsupportedPlatform
        #endif
    }

    public func delete() throws {
        try ensureSafePlan()
        #if canImport(Security)
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainDeviceKeyStoreError.keychainStatus(status)
        }
        #else
        throw KeychainDeviceKeyStoreError.unsupportedPlatform
        #endif
    }

    private func ensureSafePlan() throws {
        guard plan.isSafeDefault else {
            throw KeychainDeviceKeyStoreError.unsafePlan("Device key store requires this-device-only, non-synchronizable Keychain defaults.")
        }
        guard plan.accessGroup == nil else {
            throw KeychainDeviceKeyStoreError.unsafePlan("Access group must stay nil until a real Apple Developer Team ID exists.")
        }
    }

    #if canImport(Security)
    private func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: plan.service,
            kSecAttrAccount as String: plan.account,
            kSecAttrAccessible as String: plan.secAccessibleValue,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        if let accessGroup = plan.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
    #endif
}

public struct SecureEnclaveDeviceKeyPlan: Codable, Equatable, Sendable {
    public var keyType: String
    public var tokenID: String
    public var accessControlPolicy: String
    public var keychainAccessiblePolicy: KeychainAccessiblePolicy
    public var keyUsage: String
    public var keySizeBits: Int
    public var privateKeyExtractable: Bool
    public var publicKeyExportAllowed: Bool
    public var storesPrivateKeyBytesInAppData: Bool
    public var storesPrivateKeyBytesInKeychainPayload: Bool
    public var keychainRecordOnlyStoresMetadata: Bool
    public var allowsSoftwareFallback: Bool
    public var requiresBiometryOrDevicePasscode: Bool
    public var requiresRealDeviceForValidation: Bool
    public var requiresSignedBuildForValidation: Bool

    public init(
        keyType: String = "SecureEnclave.P256.KeyAgreement.PrivateKey",
        tokenID: String = "SecureEnclave",
        accessControlPolicy: String = "private-key-usage-biometry-current-set-or-device-passcode",
        keychainAccessiblePolicy: KeychainAccessiblePolicy = .whenUnlockedThisDeviceOnly,
        keyUsage: String = "media-vault-key-agreement",
        keySizeBits: Int = 256,
        privateKeyExtractable: Bool = false,
        publicKeyExportAllowed: Bool = true,
        storesPrivateKeyBytesInAppData: Bool = false,
        storesPrivateKeyBytesInKeychainPayload: Bool = false,
        keychainRecordOnlyStoresMetadata: Bool = true,
        allowsSoftwareFallback: Bool = false,
        requiresBiometryOrDevicePasscode: Bool = true,
        requiresRealDeviceForValidation: Bool = true,
        requiresSignedBuildForValidation: Bool = true
    ) {
        self.keyType = keyType
        self.tokenID = tokenID
        self.accessControlPolicy = accessControlPolicy
        self.keychainAccessiblePolicy = keychainAccessiblePolicy
        self.keyUsage = keyUsage
        self.keySizeBits = keySizeBits
        self.privateKeyExtractable = privateKeyExtractable
        self.publicKeyExportAllowed = publicKeyExportAllowed
        self.storesPrivateKeyBytesInAppData = storesPrivateKeyBytesInAppData
        self.storesPrivateKeyBytesInKeychainPayload = storesPrivateKeyBytesInKeychainPayload
        self.keychainRecordOnlyStoresMetadata = keychainRecordOnlyStoresMetadata
        self.allowsSoftwareFallback = allowsSoftwareFallback
        self.requiresBiometryOrDevicePasscode = requiresBiometryOrDevicePasscode
        self.requiresRealDeviceForValidation = requiresRealDeviceForValidation
        self.requiresSignedBuildForValidation = requiresSignedBuildForValidation
    }

    public var preservesTSDKeyBoundary: Bool {
        keyType == "SecureEnclave.P256.KeyAgreement.PrivateKey" &&
        tokenID == "SecureEnclave" &&
        accessControlPolicy == "private-key-usage-biometry-current-set-or-device-passcode" &&
        keychainAccessiblePolicy == .whenUnlockedThisDeviceOnly &&
        keyUsage == "media-vault-key-agreement" &&
        keySizeBits == 256 &&
        !privateKeyExtractable &&
        publicKeyExportAllowed &&
        !storesPrivateKeyBytesInAppData &&
        !storesPrivateKeyBytesInKeychainPayload &&
        keychainRecordOnlyStoresMetadata &&
        !allowsSoftwareFallback &&
        requiresBiometryOrDevicePasscode &&
        requiresRealDeviceForValidation &&
        requiresSignedBuildForValidation
    }
}

public struct SecureEnclaveDeviceKeyGenerationRequest: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var accountID: String
    public var deviceName: String
    public var createdAt: Date
    public var plan: SecureEnclaveDeviceKeyPlan
    public var keychainPlan: KeychainPersistencePlan
    public var storesPrivateKeyBytesInRequest: Bool
    public var storesPrivateKeyBytesInRepo: Bool
    public var requiresLocalAuthenticationPrompt: Bool
    public var signedDeviceValidationStatus: String

    public init(
        id: String,
        accountID: String,
        deviceName: String,
        createdAt: Date = Date(),
        plan: SecureEnclaveDeviceKeyPlan = SecureEnclaveDeviceKeyPlan(),
        keychainPlan: KeychainPersistencePlan,
        storesPrivateKeyBytesInRequest: Bool = false,
        storesPrivateKeyBytesInRepo: Bool = false,
        requiresLocalAuthenticationPrompt: Bool = true,
        signedDeviceValidationStatus: String = "required-before-testflight"
    ) {
        self.id = id
        self.accountID = accountID
        self.deviceName = deviceName
        self.createdAt = createdAt
        self.plan = plan
        self.keychainPlan = keychainPlan
        self.storesPrivateKeyBytesInRequest = storesPrivateKeyBytesInRequest
        self.storesPrivateKeyBytesInRepo = storesPrivateKeyBytesInRepo
        self.requiresLocalAuthenticationPrompt = requiresLocalAuthenticationPrompt
        self.signedDeviceValidationStatus = signedDeviceValidationStatus
    }

    public var isTSDProductionKeyGenerationSafe: Bool {
        id.hasPrefix("secure-enclave-keygen-") &&
        !accountID.isEmpty &&
        !deviceName.isEmpty &&
        plan.preservesTSDKeyBoundary &&
        keychainPlan.isSafeDefault &&
        keychainPlan.accessible == .whenUnlockedThisDeviceOnly &&
        keychainPlan.requiresUserPresence &&
        !keychainPlan.synchronizable &&
        keychainPlan.thisDeviceOnly &&
        !keychainPlan.storesSecretMaterialOutsideKeychain &&
        !keychainPlan.migrationAllowed &&
        !storesPrivateKeyBytesInRequest &&
        !storesPrivateKeyBytesInRepo &&
        requiresLocalAuthenticationPrompt &&
        signedDeviceValidationStatus == "required-before-testflight"
    }
}

public struct SecureEnclaveDeviceKeyReferenceReceipt: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var requestID: String
    public var record: DeviceKeyRecord
    public var keyReferenceDigest: String
    public var publicKeyDigest: String
    public var keychainService: String
    public var keychainAccount: String
    public var keychainAccessiblePolicy: KeychainAccessiblePolicy
    public var accessControlPolicy: String
    public var generatedInsideSecureEnclave: Bool
    public var privateKeyExtractable: Bool
    public var containsPrivateKeyBytes: Bool
    public var keychainPayloadContainsPrivateKeyBytes: Bool
    public var storesOnlyReferenceMetadata: Bool
    public var allowsSoftwareFallback: Bool
    public var requiresSignedDeviceValidation: Bool
    public var trustLevel: ProductionTrustLevel

    public init(
        id: String,
        requestID: String,
        record: DeviceKeyRecord,
        keyReferenceDigest: String,
        publicKeyDigest: String,
        keychainService: String,
        keychainAccount: String,
        keychainAccessiblePolicy: KeychainAccessiblePolicy,
        accessControlPolicy: String,
        generatedInsideSecureEnclave: Bool = true,
        privateKeyExtractable: Bool = false,
        containsPrivateKeyBytes: Bool = false,
        keychainPayloadContainsPrivateKeyBytes: Bool = false,
        storesOnlyReferenceMetadata: Bool = true,
        allowsSoftwareFallback: Bool = false,
        requiresSignedDeviceValidation: Bool = true,
        trustLevel: ProductionTrustLevel = .productionRequired
    ) {
        self.id = id
        self.requestID = requestID
        self.record = record
        self.keyReferenceDigest = keyReferenceDigest
        self.publicKeyDigest = publicKeyDigest
        self.keychainService = keychainService
        self.keychainAccount = keychainAccount
        self.keychainAccessiblePolicy = keychainAccessiblePolicy
        self.accessControlPolicy = accessControlPolicy
        self.generatedInsideSecureEnclave = generatedInsideSecureEnclave
        self.privateKeyExtractable = privateKeyExtractable
        self.containsPrivateKeyBytes = containsPrivateKeyBytes
        self.keychainPayloadContainsPrivateKeyBytes = keychainPayloadContainsPrivateKeyBytes
        self.storesOnlyReferenceMetadata = storesOnlyReferenceMetadata
        self.allowsSoftwareFallback = allowsSoftwareFallback
        self.requiresSignedDeviceValidation = requiresSignedDeviceValidation
        self.trustLevel = trustLevel
    }

    public var isTSDProductionKeyReferenceSafe: Bool {
        id.hasPrefix("secure-enclave-keyref-") &&
        requestID.hasPrefix("secure-enclave-keygen-") &&
        record.keyID.hasPrefix("tsd-device-") &&
        record.storageClass == "secure-enclave-this-device-only" &&
        record.trustLevel == .productionRequired &&
        !record.privateKeyExtractable &&
        !record.secretMaterialPersistedInRepo &&
        !keyReferenceDigest.isEmpty &&
        !publicKeyDigest.isEmpty &&
        keychainService == "com.raingodprc.timeslowdown.device-key" &&
        keychainAccount == record.keyID &&
        keychainAccessiblePolicy == .whenUnlockedThisDeviceOnly &&
        accessControlPolicy == "private-key-usage-biometry-current-set-or-device-passcode" &&
        generatedInsideSecureEnclave &&
        !privateKeyExtractable &&
        !containsPrivateKeyBytes &&
        !keychainPayloadContainsPrivateKeyBytes &&
        storesOnlyReferenceMetadata &&
        !allowsSoftwareFallback &&
        requiresSignedDeviceValidation &&
        trustLevel == .productionRequired
    }
}

public enum SecureEnclaveDeviceKeyFactoryError: Error, Equatable, Sendable {
    case unsafeRequest(String)
}

public enum SecureEnclaveDeviceKeyFactory {
    public static var canCompileSecureEnclaveContract: Bool {
        #if canImport(CryptoKit) && canImport(Security)
        true
        #else
        false
        #endif
    }

    public static func generationRequest(
        accountID: String,
        deviceName: String,
        createdAt: Date = Date()
    ) -> SecureEnclaveDeviceKeyGenerationRequest {
        let keyID = "tsd-device-\(TrustDigest.checksum([accountID, deviceName]).prefix(12))"
        let keychainPlan = KeychainPersistencePlan(
            service: "com.raingodprc.timeslowdown.device-key",
            account: String(keyID),
            accessGroup: nil,
            accessible: .whenUnlockedThisDeviceOnly,
            synchronizable: false,
            thisDeviceOnly: true,
            storesSecretMaterialOutsideKeychain: false,
            migrationAllowed: false,
            requiresUserPresence: true
        )
        let digest = TrustDigest.checksum([
            accountID,
            deviceName,
            keyID,
            "secure-enclave-p256-key-agreement",
            "user-presence"
        ])
        return SecureEnclaveDeviceKeyGenerationRequest(
            id: "secure-enclave-keygen-\(digest.prefix(12))",
            accountID: accountID,
            deviceName: deviceName,
            createdAt: createdAt,
            keychainPlan: keychainPlan
        )
    }

    public static func referenceReceipt(
        for request: SecureEnclaveDeviceKeyGenerationRequest,
        publicKeyDigest: String? = nil
    ) throws -> SecureEnclaveDeviceKeyReferenceReceipt {
        guard request.isTSDProductionKeyGenerationSafe else {
            throw SecureEnclaveDeviceKeyFactoryError.unsafeRequest(request.id)
        }
        let keyDigest = TrustDigest.checksum([
            request.id,
            request.keychainPlan.service,
            request.keychainPlan.account,
            request.plan.keyType,
            request.plan.accessControlPolicy
        ])
        let record = DeviceKeyRecord(
            keyID: request.keychainPlan.account,
            accountID: request.accountID,
            deviceName: request.deviceName,
            storageClass: "secure-enclave-this-device-only",
            createdAt: request.createdAt,
            trustLevel: .productionRequired,
            privateKeyExtractable: false,
            secretMaterialPersistedInRepo: false
        )
        return SecureEnclaveDeviceKeyReferenceReceipt(
            id: "secure-enclave-keyref-\(keyDigest.prefix(12))",
            requestID: request.id,
            record: record,
            keyReferenceDigest: keyDigest,
            publicKeyDigest: publicKeyDigest ?? TrustDigest.checksum([record.keyID, request.plan.keyUsage, "public-key-reference"]),
            keychainService: request.keychainPlan.service,
            keychainAccount: request.keychainPlan.account,
            keychainAccessiblePolicy: request.keychainPlan.accessible,
            accessControlPolicy: request.plan.accessControlPolicy
        )
    }
}

public enum SignedDeviceValidationStatus: String, Codable, Equatable, Sendable {
    case pendingSignedDevice
    case readyToRun
    case passed
    case failed
}

public struct SignedDeviceKeychainValidationEnvironment: Codable, Equatable, Sendable {
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
    public var passcodeOrBiometryAvailable: Bool
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
        passcodeOrBiometryAvailable: Bool,
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
        self.passcodeOrBiometryAvailable = passcodeOrBiometryAvailable
        self.networkRequired = networkRequired
    }

    public static func unsignedSwiftPMHost(deviceName: String = "local-swiftpm-host") -> SignedDeviceKeychainValidationEnvironment {
        SignedDeviceKeychainValidationEnvironment(
            deviceName: deviceName,
            osVersion: "host-swiftpm",
            hasFullXcode: false,
            hasAppleDeveloperTeam: false,
            signedBundleInstalled: false,
            runningOnPhysicalDevice: false,
            passcodeOrBiometryAvailable: false
        )
    }

    public var canRunSignedDeviceKeychainValidation: Bool {
        bundleIdentifier == "com.raingodprc.timeslowdown" &&
        teamID != nil &&
        hasFullXcode &&
        hasAppleDeveloperTeam &&
        usesProductionBundleIdentifier &&
        signedBundleInstalled &&
        runningOnPhysicalDevice &&
        passcodeOrBiometryAvailable &&
        !networkRequired
    }
}

public enum SignedDeviceKeychainValidationStepKind: String, Codable, Equatable, Sendable {
    case signingPreflight
    case secureEnclaveKeyGeneration
    case publicKeyDigestCapture
    case metadataReferenceSave
    case metadataReferenceLoad
    case accessControlChallenge
    case wrongDeviceRejection
    case deletion
}

public struct SignedDeviceKeychainValidationStep: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: SignedDeviceKeychainValidationStepKind
    public var title: String
    public var requiresPhysicalDevice: Bool
    public var requiresUserPresence: Bool
    public var forbidsPrivateKeyBytes: Bool
    public var expectedEvidence: String

    public init(
        id: String,
        kind: SignedDeviceKeychainValidationStepKind,
        title: String,
        requiresPhysicalDevice: Bool = true,
        requiresUserPresence: Bool = false,
        forbidsPrivateKeyBytes: Bool = true,
        expectedEvidence: String
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.requiresPhysicalDevice = requiresPhysicalDevice
        self.requiresUserPresence = requiresUserPresence
        self.forbidsPrivateKeyBytes = forbidsPrivateKeyBytes
        self.expectedEvidence = expectedEvidence
    }

    public var preservesTSDValidationBoundary: Bool {
        id.hasPrefix("signed-device-") &&
        requiresPhysicalDevice &&
        forbidsPrivateKeyBytes &&
        !expectedEvidence.isEmpty &&
        (kind != .accessControlChallenge || requiresUserPresence)
    }
}

public struct SignedDeviceKeychainValidationPlan: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var environment: SignedDeviceKeychainValidationEnvironment
    public var request: SecureEnclaveDeviceKeyGenerationRequest
    public var referenceReceipt: SecureEnclaveDeviceKeyReferenceReceipt
    public var steps: [SignedDeviceKeychainValidationStep]
    public var status: SignedDeviceValidationStatus
    public var productionValidationClaimed: Bool
    public var generatedAt: Date

    public init(
        id: String,
        environment: SignedDeviceKeychainValidationEnvironment,
        request: SecureEnclaveDeviceKeyGenerationRequest,
        referenceReceipt: SecureEnclaveDeviceKeyReferenceReceipt,
        steps: [SignedDeviceKeychainValidationStep],
        status: SignedDeviceValidationStatus,
        productionValidationClaimed: Bool = false,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.environment = environment
        self.request = request
        self.referenceReceipt = referenceReceipt
        self.steps = steps
        self.status = status
        self.productionValidationClaimed = productionValidationClaimed
        self.generatedAt = generatedAt
    }

    public var isTSDValidationPlanSafe: Bool {
        id.hasPrefix("signed-device-keychain-plan-") &&
        request.isTSDProductionKeyGenerationSafe &&
        referenceReceipt.isTSDProductionKeyReferenceSafe &&
        referenceReceipt.requestID == request.id &&
        steps.count == 8 &&
        Set(steps.map(\.kind)).count == steps.count &&
        steps.allSatisfy(\.preservesTSDValidationBoundary) &&
        !productionValidationClaimed &&
        (status == .pendingSignedDevice || status == .readyToRun) &&
        (status == .readyToRun) == environment.canRunSignedDeviceKeychainValidation
    }

    public var requiresExternalSignedDeviceWork: Bool {
        status == .pendingSignedDevice &&
        !environment.canRunSignedDeviceKeychainValidation &&
        !productionValidationClaimed
    }
}

public struct SignedDeviceKeychainValidationStepReceipt: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var stepID: String
    public var status: SignedDeviceValidationStatus
    public var evidenceDigest: String?
    public var errorMessage: String?
    public var containsPrivateKeyBytes: Bool

    public init(
        id: String,
        stepID: String,
        status: SignedDeviceValidationStatus,
        evidenceDigest: String? = nil,
        errorMessage: String? = nil,
        containsPrivateKeyBytes: Bool = false
    ) {
        self.id = id
        self.stepID = stepID
        self.status = status
        self.evidenceDigest = evidenceDigest
        self.errorMessage = errorMessage
        self.containsPrivateKeyBytes = containsPrivateKeyBytes
    }

    public var isHonestTSDStepReceipt: Bool {
        id.hasPrefix("signed-device-step-receipt-") &&
        !stepID.isEmpty &&
        !containsPrivateKeyBytes &&
        (status != .passed || evidenceDigest != nil) &&
        (status != .failed || errorMessage != nil)
    }
}

public struct SignedDeviceKeychainValidationReceipt: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var planID: String
    public var status: SignedDeviceValidationStatus
    public var stepReceipts: [SignedDeviceKeychainValidationStepReceipt]
    public var productionValidationClaimed: Bool
    public var canBeUsedForTestFlightGate: Bool
    public var canBeUsedForAppStoreGate: Bool
    public var containsPrivateKeyBytes: Bool
    public var createdAt: Date

    public init(
        id: String,
        planID: String,
        status: SignedDeviceValidationStatus,
        stepReceipts: [SignedDeviceKeychainValidationStepReceipt],
        productionValidationClaimed: Bool,
        canBeUsedForTestFlightGate: Bool,
        canBeUsedForAppStoreGate: Bool,
        containsPrivateKeyBytes: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.planID = planID
        self.status = status
        self.stepReceipts = stepReceipts
        self.productionValidationClaimed = productionValidationClaimed
        self.canBeUsedForTestFlightGate = canBeUsedForTestFlightGate
        self.canBeUsedForAppStoreGate = canBeUsedForAppStoreGate
        self.containsPrivateKeyBytes = containsPrivateKeyBytes
        self.createdAt = createdAt
    }

    public var isHonestPendingReceipt: Bool {
        id.hasPrefix("signed-device-keychain-receipt-") &&
        status == .pendingSignedDevice &&
        stepReceipts.allSatisfy { $0.status == .pendingSignedDevice && $0.isHonestTSDStepReceipt } &&
        !productionValidationClaimed &&
        !canBeUsedForTestFlightGate &&
        !canBeUsedForAppStoreGate &&
        !containsPrivateKeyBytes
    }

    public var isProductionPassReceipt: Bool {
        id.hasPrefix("signed-device-keychain-receipt-") &&
        status == .passed &&
        stepReceipts.count == 8 &&
        stepReceipts.allSatisfy { $0.status == .passed && $0.isHonestTSDStepReceipt } &&
        productionValidationClaimed &&
        canBeUsedForTestFlightGate &&
        canBeUsedForAppStoreGate &&
        !containsPrivateKeyBytes
    }
}

public enum SignedDeviceKeychainValidationScaffold {
    public static func plan(
        environment: SignedDeviceKeychainValidationEnvironment,
        request: SecureEnclaveDeviceKeyGenerationRequest,
        referenceReceipt: SecureEnclaveDeviceKeyReferenceReceipt,
        generatedAt: Date = Date()
    ) -> SignedDeviceKeychainValidationPlan {
        let digest = TrustDigest.checksum([
            environment.bundleIdentifier,
            environment.teamID ?? "no-team",
            request.id,
            referenceReceipt.id
        ])
        return SignedDeviceKeychainValidationPlan(
            id: "signed-device-keychain-plan-\(digest.prefix(12))",
            environment: environment,
            request: request,
            referenceReceipt: referenceReceipt,
            steps: defaultSteps,
            status: environment.canRunSignedDeviceKeychainValidation ? .readyToRun : .pendingSignedDevice,
            generatedAt: generatedAt
        )
    }

    public static func pendingReceipt(
        for plan: SignedDeviceKeychainValidationPlan,
        createdAt: Date = Date()
    ) -> SignedDeviceKeychainValidationReceipt {
        let digest = TrustDigest.checksum([plan.id, plan.status.rawValue, "pending"])
        let receipts = plan.steps.map { step in
            SignedDeviceKeychainValidationStepReceipt(
                id: "signed-device-step-receipt-\(TrustDigest.checksum([plan.id, step.id]).prefix(12))",
                stepID: step.id,
                status: .pendingSignedDevice
            )
        }
        return SignedDeviceKeychainValidationReceipt(
            id: "signed-device-keychain-receipt-\(digest.prefix(12))",
            planID: plan.id,
            status: .pendingSignedDevice,
            stepReceipts: receipts,
            productionValidationClaimed: false,
            canBeUsedForTestFlightGate: false,
            canBeUsedForAppStoreGate: false,
            createdAt: createdAt
        )
    }

    public static var defaultSteps: [SignedDeviceKeychainValidationStep] {
        [
            .init(id: "signed-device-signing-preflight", kind: .signingPreflight, title: "Verify signed production bundle on physical device", expectedEvidence: "bundle-id, Team ID, device UDID, installed build number"),
            .init(id: "signed-device-secure-enclave-key-generation", kind: .secureEnclaveKeyGeneration, title: "Generate non-extractable Secure Enclave P256 key", requiresUserPresence: true, expectedEvidence: "key reference digest and Secure Enclave token evidence"),
            .init(id: "signed-device-public-key-digest-capture", kind: .publicKeyDigestCapture, title: "Export public key digest only", expectedEvidence: "public key digest without private key bytes"),
            .init(id: "signed-device-metadata-reference-save", kind: .metadataReferenceSave, title: "Save metadata-only Keychain reference", expectedEvidence: "Keychain add/update success for metadata payload"),
            .init(id: "signed-device-metadata-reference-load", kind: .metadataReferenceLoad, title: "Load metadata-only Keychain reference", expectedEvidence: "round-trip metadata digest matches saved reference"),
            .init(id: "signed-device-access-control-challenge", kind: .accessControlChallenge, title: "Require user presence for private key use", requiresUserPresence: true, expectedEvidence: "LocalAuthentication/access-control challenge result"),
            .init(id: "signed-device-wrong-device-rejection", kind: .wrongDeviceRejection, title: "Reject wrong-device media vault unseal", expectedEvidence: "wrong-key rejection without plaintext leakage"),
            .init(id: "signed-device-delete-test-record", kind: .deletion, title: "Delete test Keychain/Secure Enclave reference", expectedEvidence: "delete status and post-delete not-found check")
        ]
    }
}

public enum KeychainProductionChecklist {
    public static let rows: [ReadinessRow] = [
        .init(id: "keychain-record-store", title: "Keychain record store", status: .poc, owner: "iOS", evidence: "Security.framework save/load/delete adapter exists; automated checks verify safe query contracts without writing to the user's Keychain."),
        .init(id: "cryptokit-media-vault-plan", title: "CryptoKit media vault plan", status: .poc, owner: "iOS/privacy", evidence: "v52 adds a CryptoKit AES.GCM media vault envelope contract with Secure Enclave key agreement, HKDF, random nonce, AAD, and no plaintext/CEK persistence; signed-device validation remains required."),
        .init(id: "secure-enclave-key-plan", title: "Secure Enclave key plan", status: .poc, owner: "iOS", evidence: "v53 adds a Secure Enclave device-key generation request and reference receipt contract: P256 key agreement, this-device-only Keychain metadata, user presence, no private-key bytes, no software fallback; real signed-device validation still required."),
        .init(id: "signed-device-validation-scaffold", title: "Signed-device validation scaffold", status: .poc, owner: "release/iOS", evidence: "v54 adds a signed-device Keychain/Secure Enclave validation plan and pending receipt scaffold; it records required physical-device steps without claiming production validation on this SwiftPM host."),
        .init(id: "keychain-integration-test", title: "Signed-device Keychain test", status: .todo, owner: "release/iOS", evidence: "Run Secure Enclave generation, metadata save/load, access-control challenge, wrong-device rejection, and deletion on a signed physical device with the production bundle id and Apple Developer Team.")
    ]
}

#if canImport(Security)
private extension KeychainPersistencePlan {
    var secAccessibleValue: CFString {
        switch accessible {
        case .afterFirstUnlockThisDeviceOnly:
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        case .whenUnlockedThisDeviceOnly:
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
    }
}
#endif
