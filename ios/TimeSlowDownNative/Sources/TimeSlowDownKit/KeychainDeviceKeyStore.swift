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
    public var privateKeyExtractable: Bool
    public var storesPrivateKeyBytesInAppData: Bool
    public var keychainRecordOnlyStoresMetadata: Bool
    public var requiresRealDeviceForValidation: Bool

    public init(
        keyType: String = "P256.Signing.PrivateKey",
        tokenID: String = "SecureEnclave",
        privateKeyExtractable: Bool = false,
        storesPrivateKeyBytesInAppData: Bool = false,
        keychainRecordOnlyStoresMetadata: Bool = true,
        requiresRealDeviceForValidation: Bool = true
    ) {
        self.keyType = keyType
        self.tokenID = tokenID
        self.privateKeyExtractable = privateKeyExtractable
        self.storesPrivateKeyBytesInAppData = storesPrivateKeyBytesInAppData
        self.keychainRecordOnlyStoresMetadata = keychainRecordOnlyStoresMetadata
        self.requiresRealDeviceForValidation = requiresRealDeviceForValidation
    }

    public var preservesTSDKeyBoundary: Bool {
        tokenID == "SecureEnclave" &&
        !privateKeyExtractable &&
        !storesPrivateKeyBytesInAppData &&
        keychainRecordOnlyStoresMetadata &&
        requiresRealDeviceForValidation
    }
}

public enum KeychainProductionChecklist {
    public static let rows: [ReadinessRow] = [
        .init(id: "keychain-record-store", title: "Keychain record store", status: .poc, owner: "iOS", evidence: "Security.framework save/load/delete adapter exists; automated checks verify safe query contracts without writing to the user's Keychain."),
        .init(id: "secure-enclave-key-plan", title: "Secure Enclave key plan", status: .todo, owner: "iOS", evidence: "Plan forbids extractable private keys, but real device key generation and validation still require a signed iOS build."),
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
