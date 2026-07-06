import Foundation

public enum ReadinessStatus: String, Codable, Equatable, Sendable {
    case ready
    case poc
    case todo
}

public struct ReadinessRow: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var title: String
    public var status: ReadinessStatus
    public var owner: String
    public var evidence: String

    public init(id: String, title: String, status: ReadinessStatus, owner: String, evidence: String) {
        self.id = id
        self.title = title
        self.status = status
        self.owner = owner
        self.evidence = evidence
    }
}

public enum NativeHandoffLedger {
    public static let rows: [ReadinessRow] = [
        .init(id: "swiftui-shell", title: "SwiftUI shell", status: .poc, owner: "iOS", evidence: "SwiftUI shell, app entry, Xcode project skeleton, launch screen, App Icon asset catalog, main navigation."),
        .init(id: "photos-picker", title: "PhotosPicker", status: .todo, owner: "iOS", evidence: "Limited library picker, media import pipeline, no full-library scan."),
        .init(id: "keychain-e2ee", title: "Keychain + E2EE", status: .poc, owner: "iOS/backend", evidence: "v38 trust contracts cover device key record and E2EE envelope; real Secure Enclave/Keychain and cryptography still required."),
        .init(id: "media-package", title: "Media package", status: .poc, owner: "iOS/backend", evidence: "v38 export manifest signature and deletion receipt contracts cover package integrity and user rights; real media storage still required."),
        .init(id: "deepseek-gateway", title: "DeepSeek gateway", status: .poc, owner: "backend", evidence: "v38 DeepSeek task envelope constrains provider, budget, fallback, and forbidden fields; real server gateway still required."),
        .init(id: "app-privacy-details", title: "App Privacy Details", status: .todo, owner: "App Store Connect", evidence: "User content, photos/videos, account, purchases, diagnostics, AI processing."),
        .init(id: "privacy-manifest", title: "Privacy Manifest / required reason API", status: .todo, owner: "release", evidence: "Required reason API audit and dependency privacy manifests."),
        .init(id: "testflight-packet", title: "TestFlight packet", status: .todo, owner: "release", evidence: "Build notes, test account, review notes, support and privacy URLs.")
    ]
}

public enum XcodeProjectContract {
    public static let projectPath = "TimeSlowDown.xcodeproj/project.pbxproj"
    public static let appSourcePath = "TimeSlowDownApp/TimeSlowDownApp.swift"
    public static let launchScreenPath = "TimeSlowDownApp/Base.lproj/LaunchScreen.storyboard"
    public static let assetCatalogPath = "TimeSlowDownApp/Assets.xcassets/Contents.json"
    public static let appIconPath = "TimeSlowDownApp/Assets.xcassets/AppIcon.appiconset/Contents.json"
    public static let accentColorPath = "TimeSlowDownApp/Assets.xcassets/AccentColor.colorset/Contents.json"
    public static let infoPlistPath = "AppStore/Info.plist"
    public static let privacyManifestPath = "AppStore/PrivacyInfo.xcprivacy"
    public static let entitlementsPath = "AppStore/TimeSlowDown.entitlements"

    public static let requiredProjectTokens = [
        "PBXNativeTarget",
        "TimeSlowDown.app",
        "com.apple.product-type.application",
        "XCLocalSwiftPackageReference",
        "TimeSlowDownKit",
        "INFOPLIST_FILE = AppStore/Info.plist",
        "CODE_SIGN_ENTITLEMENTS = AppStore/TimeSlowDown.entitlements",
        "PrivacyInfo.xcprivacy",
        "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon"
    ]
}

public enum SubmissionPacket {
    public static let rows: [ReadinessRow] = [
        .init(id: "product-page", title: "Product page positioning", status: .poc, owner: "release", evidence: "Not a diary, not a photo album; memory slices become tellable stories."),
        .init(id: "screenshots", title: "Screenshots / App Preview", status: .poc, owner: "design/release", evidence: "Memory Camera, today slice, weekly chapter, life meadow, media wall, privacy rights."),
        .init(id: "privacy-questionnaire", title: "Privacy questionnaire", status: .todo, owner: "legal/release", evidence: "Map user content, media, accounts, purchases, diagnostics, AI, sync."),
        .init(id: "age-rating", title: "Age rating", status: .todo, owner: "legal/release", evidence: "12+ direction must be rechecked against UGC, family media, AI, links."),
        .init(id: "review-notes", title: "Review notes", status: .poc, owner: "release", evidence: "Route: media capture → slice → media wall → account rights → privacy center → export/delete."),
        .init(id: "support-privacy-urls", title: "Support / Privacy URLs", status: .todo, owner: "release/legal", evidence: "Public support, privacy, export, deletion, subscription rights pages."),
        .init(id: "subscription-copy", title: "Subscription wording", status: .poc, owner: "product/legal", evidence: "Sync, AI, and storage are enhancements; memories are never held hostage."),
        .init(id: "submission-packet", title: "Submission evidence packet", status: .poc, owner: "release", evidence: "Copyable packet for release, legal, and App Store Connect.")
    ]
}

public struct PrivacyBoundary: Codable, Equatable, Sendable {
    public var allowsRawMediaUpload: Bool
    public var allowsContactsAccess: Bool
    public var allowsGPSInference: Bool
    public var allowsFaceRecognition: Bool
    public var subscriptionCanBlockExport: Bool

    public init(
        allowsRawMediaUpload: Bool = false,
        allowsContactsAccess: Bool = false,
        allowsGPSInference: Bool = false,
        allowsFaceRecognition: Bool = false,
        subscriptionCanBlockExport: Bool = false
    ) {
        self.allowsRawMediaUpload = allowsRawMediaUpload
        self.allowsContactsAccess = allowsContactsAccess
        self.allowsGPSInference = allowsGPSInference
        self.allowsFaceRecognition = allowsFaceRecognition
        self.subscriptionCanBlockExport = subscriptionCanBlockExport
    }

    public var isAppStoreSafeDefault: Bool {
        !allowsRawMediaUpload &&
        !allowsContactsAccess &&
        !allowsGPSInference &&
        !allowsFaceRecognition &&
        !subscriptionCanBlockExport
    }
}
