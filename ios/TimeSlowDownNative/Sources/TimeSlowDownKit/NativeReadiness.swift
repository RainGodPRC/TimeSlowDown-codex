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
        .init(id: "swiftui-shell", title: "SwiftUI shell", status: .poc, owner: "iOS", evidence: "SwiftUI shell, app entry, Xcode project skeleton, launch screen, real App Icon PNG asset catalog, main navigation."),
        .init(id: "photos-picker", title: "PhotosPicker", status: .poc, owner: "iOS", evidence: "Limited library picker, no full-library scan; v50 adds a Photos-library byte import adapter that turns user-selected media bytes into RawMediaAssetPayload without GPS/contact/face inference or cloud upload; v66 adds a signed-device media validation packet for future physical-device Photos import evidence."),
        .init(id: "keychain-e2ee", title: "Keychain + E2EE", status: .poc, owner: "iOS/backend", evidence: "v38 trust contracts cover device key record and E2EE envelope; v41 adds a Security.framework Keychain record store adapter; v51 adds a local E2EE media vault adapter; v52 adds a CryptoKit AES.GCM + Secure Enclave implementation contract; v53 adds a Secure Enclave device-key generation/reference contract; v54 adds a signed-device validation scaffold; real signed-device pass receipt still required."),
        .init(id: "media-package", title: "Media package", status: .poc, owner: "iOS/backend", evidence: "v38 export manifest signature and deletion receipt contracts cover package integrity and user rights; v49/v50 connect user-selected media bytes to staged export; v51 adds encrypted media vault records before export; v52 adds the CryptoKit production envelope path; v53 defines the non-extractable device-key reference boundary; v60 adds a deletion service live probe for real backend job/audit/tombstone evidence; v66 adds a signed-device media validation packet for system Files/share export and ZIP re-open evidence."),
        .init(id: "deepseek-gateway", title: "DeepSeek gateway", status: .poc, owner: "backend", evidence: "v38 DeepSeek task envelope constrains provider, budget, fallback, and forbidden fields; v46 adds the server gateway envelope; v55 adds pending/mock/provider validation receipts so mock success cannot unlock production AI; v56 adds redacted integration test request/result contracts for future backend provider pass evidence; v57 adds the backend endpoint/provider proxy contract; v58 adds a local executable endpoint harness that validates endpoint/gateway/proxy gates without claiming a real provider call; v59 adds an optional live backend probe that can POST to a configured TSD backend and promote only real provider evidence; real deployed gateway and provider pass receipt still required."),
        .init(id: "app-privacy-details", title: "App Privacy Details", status: .poc, owner: "App Store Connect", evidence: "v64 adds a machine-checkable questionnaire packet for user content, photos/videos, account identifiers, purchases, diagnostics, AI processing, and optional encrypted sync; final App Store Connect/legal review remains required."),
        .init(id: "privacy-manifest", title: "Privacy Manifest / required reason API", status: .todo, owner: "release", evidence: "Required reason API audit and dependency privacy manifests."),
        .init(id: "testflight-packet", title: "TestFlight packet", status: .poc, owner: "release", evidence: "v40 TestFlight build notes, App Review route, signing plan, and launch asset checklist exist as Swift-verifiable contracts; v67 adds an archive/signing readiness packet for future full-Xcode archive and TestFlight upload evidence; v68 adds an App Store metadata/legal review packet; real archive/upload still requires full Xcode and Apple Developer team.")
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
        .init(id: "privacy-questionnaire-packet", title: "Privacy questionnaire packet", status: .poc, owner: "legal/release", evidence: "v64 Swift-verifiable answer packet maps TSD data types, no-tracking/default privacy boundaries, AI minimal-payload rules, and export/delete rights before formal App Store Connect entry."),
        .init(id: "age-rating", title: "Age rating", status: .todo, owner: "legal/release", evidence: "12+ direction must be rechecked against UGC, family media, AI, links."),
        .init(id: "age-rating-review-packet", title: "Age Rating review packet", status: .poc, owner: "legal/release", evidence: "v65 Swift-verifiable packet maps private memory/media UGC, no public social feed, no Kids Category claim, bounded AI editing, external links, purchases, and support path before formal App Store Connect age-rating review."),
        .init(id: "review-notes", title: "Review notes", status: .poc, owner: "release", evidence: "Route: media capture → slice → media wall → account rights → privacy center → export/delete."),
        .init(id: "support-privacy-urls", title: "Support / Privacy URLs", status: .todo, owner: "release/legal", evidence: "Public support, privacy, export, deletion, subscription rights pages."),
        .init(id: "subscription-copy", title: "Subscription wording", status: .poc, owner: "product/legal", evidence: "Sync, AI, and storage are enhancements; memories are never held hostage."),
        .init(id: "metadata-legal-review-packet", title: "Metadata/legal review packet", status: .poc, owner: "release/legal", evidence: "v68 Swift-verifiable packet maps product page positioning, screenshots/app preview, review notes, support/privacy/data-rights URLs, subscription wording, AI disclosure, and legal/release checklist before formal App Store Connect entry."),
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
