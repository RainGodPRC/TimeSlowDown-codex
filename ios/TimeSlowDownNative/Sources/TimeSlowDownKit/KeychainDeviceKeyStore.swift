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

public enum KeychainProductionChecklist {
    public static let rows: [ReadinessRow] = [
        .init(id: "keychain-record-store", title: "Keychain record store", status: .poc, owner: "iOS", evidence: "Security.framework save/load/delete adapter exists; automated checks verify safe query contracts without writing to the user's Keychain."),
        .init(id: "cryptokit-media-vault-plan", title: "CryptoKit media vault plan", status: .poc, owner: "iOS/privacy", evidence: "v52 adds a CryptoKit AES.GCM media vault envelope contract with Secure Enclave key agreement, HKDF, random nonce, AAD, and no plaintext/CEK persistence; signed-device validation remains required."),
        .init(id: "secure-enclave-key-plan", title: "Secure Enclave key plan", status: .poc, owner: "iOS", evidence: "v53 adds a Secure Enclave device-key generation request and reference receipt contract: P256 key agreement, this-device-only Keychain metadata, user presence, no private-key bytes, no software fallback; real signed-device validation still required."),
        .init(id: "keychain-integration-test", title: "Signed-device Keychain test", status: .todo, owner: "release/iOS", evidence: "Run save/load/delete on a physical device or simulator with the production bundle id and Apple Developer Team.")
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
