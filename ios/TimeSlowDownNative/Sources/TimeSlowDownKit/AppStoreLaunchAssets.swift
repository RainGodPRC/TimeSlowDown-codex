import Foundation

public struct AppIconSlot: Codable, Equatable, Identifiable, Sendable {
    public var id: String { filename }
    public var filename: String
    public var idiom: String
    public var pointSize: String
    public var scale: String
    public var pixelSize: Int
    public var designNote: String

    public init(
        filename: String,
        idiom: String = "iphone",
        pointSize: String,
        scale: String,
        pixelSize: Int,
        designNote: String = "Warm life-meadow gradient with a memory-slice mark; no third-party or copyrighted asset."
    ) {
        self.filename = filename
        self.idiom = idiom
        self.pointSize = pointSize
        self.scale = scale
        self.pixelSize = pixelSize
        self.designNote = designNote
    }
}

public enum AppIconAssetContract {
    public static let assetCatalogPath = "TimeSlowDownApp/Assets.xcassets/AppIcon.appiconset"

    public static let slots: [AppIconSlot] = [
        .init(filename: "AppIcon-20x20@2x.png", pointSize: "20x20", scale: "2x", pixelSize: 40),
        .init(filename: "AppIcon-20x20@3x.png", pointSize: "20x20", scale: "3x", pixelSize: 60),
        .init(filename: "AppIcon-29x29@2x.png", pointSize: "29x29", scale: "2x", pixelSize: 58),
        .init(filename: "AppIcon-29x29@3x.png", pointSize: "29x29", scale: "3x", pixelSize: 87),
        .init(filename: "AppIcon-40x40@2x.png", pointSize: "40x40", scale: "2x", pixelSize: 80),
        .init(filename: "AppIcon-40x40@3x.png", pointSize: "40x40", scale: "3x", pixelSize: 120),
        .init(filename: "AppIcon-60x60@2x.png", pointSize: "60x60", scale: "2x", pixelSize: 120),
        .init(filename: "AppIcon-60x60@3x.png", pointSize: "60x60", scale: "3x", pixelSize: 180),
        .init(filename: "AppIcon-1024x1024@1x.png", idiom: "ios-marketing", pointSize: "1024x1024", scale: "1x", pixelSize: 1024)
    ]

    public static let requiredVisualMotifs = [
        "life-meadow",
        "memory-slice",
        "warm-gradient",
        "no-copyrighted-asset",
        "no-alpha-channel"
    ]
}

public struct TestFlightBuildNotes: Codable, Equatable, Sendable {
    public var buildNumber: String
    public var summary: String
    public var testerRoute: [String]
    public var knownLimitations: [String]
    public var supportContact: String

    public init(
        buildNumber: String = "65",
        summary: String = "TimeSlowDown v65 tests the native Memory Camera shell, media-first slice capture, Photos-library byte import adapter, E2EE media vault adapter, CryptoKit media vault envelope contract, Secure Enclave device-key contract, signed-device validation scaffold, weekly chapter preview, App Store launch assets, Keychain record store adapter, Account Rights export UI state, SwiftUI fileExporter bridge, on-device export ZIP builder, raw media export policy, staged raw media export builder, deletion audit envelope, DeepSeek server gateway envelope, DeepSeek provider validation scaffold, DeepSeek integration test runner contract, DeepSeek backend endpoint/provider proxy contract, DeepSeek endpoint execution harness, optional live backend probe, deletion service boundary, deletion live probe, App Store submission gate, public URL packet, backend release manifest, App Privacy questionnaire packet, Age Rating review packet, and privacy/export/delete/AI trust boundaries.",
        testerRoute: [String] = [
            "Open Memory Camera and choose a photo or video as a memory anchor.",
            "Confirm the generated slice keeps media as the memory key, not a text attachment.",
            "Review the media wall and weekly chapter preview.",
            "Open account rights to verify export/delete remain available without subscription hostage.",
            "Open launch readiness to review App Store/TestFlight packet boundaries."
        ],
        knownLimitations: [String] = [
            "No production backend, account sync, or bundled DeepSeek provider key is included in this build; v55 separates pending backend, mock gateway, and future provider-passed validation receipts, v56 defines the redacted backend integration test request/result contract, v57 defines the backend endpoint contract plus provider proxy boundary, v58 adds a local endpoint execution harness that can pass only stub gates, v59 adds an optional live backend probe that requires TSD backend URL/token environment variables plus real provider evidence before any production AI/App Store AI gate can pass, and v60 adds an optional deletion live probe that requires TSD deletion backend URL/token plus real job/audit/tombstone/per-system evidence before deletion gates can pass.",
            "Secure Enclave generation request, reference receipt, and signed-device validation scaffold are now Swift-verifiable contracts, but no signed-device Secure Enclave/Keychain pass receipt, signed-device Photos import validation, or production E2EE media vault validation is claimed yet.",
            "v61 adds an App Store submission gate that remains blocked until full Xcode, Team ID, archive, TestFlight upload, App Store Connect metadata, support/privacy URLs, App Privacy questionnaire, age rating, DeepSeek provider pass, deletion completion, and signed-device privacy receipts exist.",
            "v62 adds a public URL packet with HTTPS support/privacy/export/delete/subscription/review deep links on the public GitHub Pages demo, while keeping formal legal review and final company support/privacy URLs as release blockers.",
            "v63 adds a backend release manifest gate that remains blocked until a real HTTPS TSD backend, server-side DeepSeek secret manager, weekly chapter endpoint, deletion jobs endpoint, audit/deletion worker, live provider receipt, completed deletion receipt, and deployment review exist.",
            "v64 adds an App Privacy questionnaire packet that maps user content, photo/video anchors, account identifiers, purchases, diagnostics, minimal AI task payloads, and optional encrypted sync to App Store privacy answers, but keeps final App Store Connect/legal completion blocked.",
            "v65 adds an Age Rating review packet that maps private user memory/media content, no public social feed, no Kids Category claim, AI editing boundaries, external links, purchases, and support contact requirements while keeping final legal/release age-rating review blocked.",
            "Archive, signing, signed-device Files export validation, TestFlight upload, App Store Connect metadata, and legal review require full Xcode and Apple Developer access."
        ],
        supportContact: String = "support-url-or-email-required-before-testflight"
    ) {
        self.buildNumber = buildNumber
        self.summary = summary
        self.testerRoute = testerRoute
        self.knownLimitations = knownLimitations
        self.supportContact = supportContact
    }

    public var namesAIPrivacyBoundary: Bool {
        summary.localizedCaseInsensitiveContains("AI") &&
        knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("DeepSeek")
    }
}

public struct AppReviewRoute: Codable, Equatable, Sendable {
    public var requiresLogin: Bool
    public var steps: [String]
    public var privacyRightsStep: String
    public var reviewerNotes: String

    public init(
        requiresLogin: Bool = false,
        steps: [String] = [
            "Start in guest mode; no login is required for the review route.",
            "Tap Memory Camera and pick a limited-library photo/video.",
            "Create a slice and confirm the media anchor is visible.",
            "Open Media Wall to see the same anchor in the recall timeline.",
            "Open Weekly Chapter to see user-claimed moments compiled with source trace.",
            "Open Account Rights / Privacy Center to inspect export, deletion, subscription, and AI boundaries."
        ],
        privacyRightsStep: String = "Account Rights / Privacy Center",
        reviewerNotes: String = "TSD is a memory-slice and weekly-story app, not a social network, not a full photo-library scanner, and not a medical or cognitive diagnostic tool."
    ) {
        self.requiresLogin = requiresLogin
        self.steps = steps
        self.privacyRightsStep = privacyRightsStep
        self.reviewerNotes = reviewerNotes
    }

    public var isGuestReviewFriendly: Bool {
        !requiresLogin && steps.count >= 5 && reviewerNotes.localizedCaseInsensitiveContains("not a social network")
    }
}

public struct SigningReadinessPlan: Codable, Equatable, Sendable {
    public var bundleIdentifier: String
    public var teamID: String?
    public var signingStyle: String
    public var requiresAppleDeveloperTeam: Bool
    public var fakeTeamIDForbidden: Bool
    public var archiveCommandWhenXcodeAvailable: String

    public init(
        bundleIdentifier: String = "com.raingodprc.timeslowdown",
        teamID: String? = nil,
        signingStyle: String = "Automatic",
        requiresAppleDeveloperTeam: Bool = true,
        fakeTeamIDForbidden: Bool = true,
        archiveCommandWhenXcodeAvailable: String = "xcodebuild -project TimeSlowDown.xcodeproj -scheme TimeSlowDown -configuration Release -destination generic/platform=iOS archive"
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.teamID = teamID
        self.signingStyle = signingStyle
        self.requiresAppleDeveloperTeam = requiresAppleDeveloperTeam
        self.fakeTeamIDForbidden = fakeTeamIDForbidden
        self.archiveCommandWhenXcodeAvailable = archiveCommandWhenXcodeAvailable
    }

    public var doesNotFakeSigning: Bool {
        teamID == nil && signingStyle == "Automatic" && requiresAppleDeveloperTeam && fakeTeamIDForbidden
    }
}

public enum AppStoreLaunchAssetChecklist {
    public static let rows: [ReadinessRow] = [
        .init(id: "app-icon-pngs", title: "App Icon PNG assets", status: .poc, owner: "design/iOS", evidence: "All iPhone and iOS marketing icon slots have deterministic PNG files referenced by AppIcon Contents.json."),
        .init(id: "testflight-build-notes", title: "TestFlight build notes", status: .poc, owner: "release", evidence: "v40 build notes name media capture, export/delete rights, AI boundary, and production limitations."),
        .init(id: "app-review-route", title: "App Review route", status: .poc, owner: "release", evidence: "Guest-friendly review route covers Memory Camera, slice, media wall, weekly chapter, account rights, and privacy center."),
        .init(id: "signing-readiness-plan", title: "Signing readiness plan", status: .poc, owner: "release/iOS", evidence: "Bundle ID and automatic signing are declared, but Team ID is intentionally blank until Apple Developer access exists.")
    ]
}

public struct AppStorePublicURLPacket: Codable, Equatable, Sendable {
    public var baseURL: String
    public var supportURL: String
    public var privacyURL: String
    public var exportRightsURL: String
    public var deletionRightsURL: String
    public var subscriptionRightsURL: String
    public var appReviewRouteURL: String
    public var legalReviewCompleted: Bool

    public init(
        baseURL: String = "https://raingodprc.github.io/TimeSlowDown-codex/",
        supportURL: String = "https://raingodprc.github.io/TimeSlowDown-codex/#support",
        privacyURL: String = "https://raingodprc.github.io/TimeSlowDown-codex/#privacy",
        exportRightsURL: String = "https://raingodprc.github.io/TimeSlowDown-codex/#export",
        deletionRightsURL: String = "https://raingodprc.github.io/TimeSlowDown-codex/#delete",
        subscriptionRightsURL: String = "https://raingodprc.github.io/TimeSlowDown-codex/#subscription",
        appReviewRouteURL: String = "https://raingodprc.github.io/TimeSlowDown-codex/#review",
        legalReviewCompleted: Bool = false
    ) {
        self.baseURL = baseURL
        self.supportURL = supportURL
        self.privacyURL = privacyURL
        self.exportRightsURL = exportRightsURL
        self.deletionRightsURL = deletionRightsURL
        self.subscriptionRightsURL = subscriptionRightsURL
        self.appReviewRouteURL = appReviewRouteURL
        self.legalReviewCompleted = legalReviewCompleted
    }

    public var urls: [String] {
        [
            supportURL,
            privacyURL,
            exportRightsURL,
            deletionRightsURL,
            subscriptionRightsURL,
            appReviewRouteURL
        ]
    }

    public var requiredFragments: [String] {
        ["#support", "#privacy", "#export", "#delete", "#subscription", "#review"]
    }

    public var isPublicDemoURLPacket: Bool {
        baseURL == "https://raingodprc.github.io/TimeSlowDown-codex/" &&
        urls.count == 6 &&
        urls.allSatisfy { url in
            url.hasPrefix(baseURL) &&
            url.hasPrefix("https://") &&
            !url.contains("localhost") &&
            !url.localizedCaseInsensitiveContains("todo") &&
            !url.localizedCaseInsensitiveContains("required")
        } &&
        zip(urls, requiredFragments).allSatisfy { url, fragment in
            url.hasSuffix(fragment)
        }
    }

    public var canSatisfyPublicURLShapeGate: Bool {
        isPublicDemoURLPacket
    }

    public var canSatisfyFinalLegalURLGate: Bool {
        isPublicDemoURLPacket && legalReviewCompleted
    }
}

public enum AppPrivacyDataUse: String, Codable, Equatable, CaseIterable, Sendable {
    case appFunctionality = "app-functionality"
    case aiAssistance = "ai-assistance"
    case optionalSync = "optional-encrypted-sync"
    case accountManagement = "account-management"
    case purchases = "purchases"
    case diagnostics = "diagnostics"
}

public struct AppPrivacyDataAnswer: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var appleDataCategory: String
    public var appleDataType: String
    public var collectedByAppOrBackend: Bool
    public var linkedToUser: Bool
    public var usedForTracking: Bool
    public var uses: [AppPrivacyDataUse]
    public var userConsentRequired: Bool
    public var deletionAndExportCovered: Bool
    public var rawMediaSentToAIProvider: Bool
    public var evidence: String

    public init(
        id: String,
        appleDataCategory: String,
        appleDataType: String,
        collectedByAppOrBackend: Bool,
        linkedToUser: Bool,
        usedForTracking: Bool = false,
        uses: [AppPrivacyDataUse],
        userConsentRequired: Bool,
        deletionAndExportCovered: Bool = true,
        rawMediaSentToAIProvider: Bool = false,
        evidence: String
    ) {
        self.id = id
        self.appleDataCategory = appleDataCategory
        self.appleDataType = appleDataType
        self.collectedByAppOrBackend = collectedByAppOrBackend
        self.linkedToUser = linkedToUser
        self.usedForTracking = usedForTracking
        self.uses = uses
        self.userConsentRequired = userConsentRequired
        self.deletionAndExportCovered = deletionAndExportCovered
        self.rawMediaSentToAIProvider = rawMediaSentToAIProvider
        self.evidence = evidence
    }
}

public struct AppPrivacyQuestionnairePacket: Codable, Equatable, Sendable {
    public var sourceReferences: [String]
    public var answers: [AppPrivacyDataAnswer]
    public var notCollectedAppleDataTypes: [String]
    public var noTracking: Bool
    public var noThirdPartyAdvertising: Bool
    public var noContactsAccess: Bool
    public var noGPSOrLocationInference: Bool
    public var noFaceRecognitionOrBiometricProfile: Bool
    public var rawMediaNeverSentToAIProvider: Bool
    public var aiUsesOnlyUserApprovedMinimalFields: Bool
    public var exportAndDeleteRightsPreserved: Bool
    public var privacyURLIncluded: Bool
    public var completedInAppStoreConnect: Bool
    public var legalReviewCompleted: Bool

    public init(
        sourceReferences: [String] = [
            "Apple Developer: App privacy details on the App Store",
            "App Store Connect Help: Manage app privacy",
            "App Store Connect Help: Data types"
        ],
        answers: [AppPrivacyDataAnswer] = AppPrivacyQuestionnairePacket.defaultAnswers,
        notCollectedAppleDataTypes: [String] = [
            "Contacts",
            "Precise Location",
            "Coarse Location",
            "Health",
            "Fitness",
            "Financial Info",
            "Browsing History",
            "Search History",
            "Sensitive Info"
        ],
        noTracking: Bool = true,
        noThirdPartyAdvertising: Bool = true,
        noContactsAccess: Bool = true,
        noGPSOrLocationInference: Bool = true,
        noFaceRecognitionOrBiometricProfile: Bool = true,
        rawMediaNeverSentToAIProvider: Bool = true,
        aiUsesOnlyUserApprovedMinimalFields: Bool = true,
        exportAndDeleteRightsPreserved: Bool = true,
        privacyURLIncluded: Bool = true,
        completedInAppStoreConnect: Bool = false,
        legalReviewCompleted: Bool = false
    ) {
        self.sourceReferences = sourceReferences
        self.answers = answers
        self.notCollectedAppleDataTypes = notCollectedAppleDataTypes
        self.noTracking = noTracking
        self.noThirdPartyAdvertising = noThirdPartyAdvertising
        self.noContactsAccess = noContactsAccess
        self.noGPSOrLocationInference = noGPSOrLocationInference
        self.noFaceRecognitionOrBiometricProfile = noFaceRecognitionOrBiometricProfile
        self.rawMediaNeverSentToAIProvider = rawMediaNeverSentToAIProvider
        self.aiUsesOnlyUserApprovedMinimalFields = aiUsesOnlyUserApprovedMinimalFields
        self.exportAndDeleteRightsPreserved = exportAndDeleteRightsPreserved
        self.privacyURLIncluded = privacyURLIncluded
        self.completedInAppStoreConnect = completedInAppStoreConnect
        self.legalReviewCompleted = legalReviewCompleted
    }

    public static let defaultAnswers: [AppPrivacyDataAnswer] = [
        .init(
            id: "memory-user-content",
            appleDataCategory: "User Content",
            appleDataType: "Other User Content",
            collectedByAppOrBackend: true,
            linkedToUser: true,
            uses: [.appFunctionality, .optionalSync],
            userConsentRequired: true,
            evidence: "Memory slices, titles, notes, tags, and weekly chapter source traces are user-created content."
        ),
        .init(
            id: "photo-video-anchors",
            appleDataCategory: "User Content",
            appleDataType: "Photos or Videos",
            collectedByAppOrBackend: true,
            linkedToUser: true,
            uses: [.appFunctionality, .optionalSync],
            userConsentRequired: true,
            evidence: "Photo/video anchors are user-selected through limited-library flows; no full-library scan, GPS inference, face recognition, or AI raw-media upload."
        ),
        .init(
            id: "account-identifier",
            appleDataCategory: "Identifiers",
            appleDataType: "User ID",
            collectedByAppOrBackend: true,
            linkedToUser: true,
            uses: [.accountManagement, .appFunctionality],
            userConsentRequired: true,
            evidence: "Account ID is needed only for optional account, sync, export, deletion, and review-safe backend operations."
        ),
        .init(
            id: "subscription-purchases",
            appleDataCategory: "Purchases",
            appleDataType: "Purchase History",
            collectedByAppOrBackend: true,
            linkedToUser: true,
            uses: [.purchases, .appFunctionality],
            userConsentRequired: true,
            evidence: "Subscription state unlocks enhanced sync/AI/storage only; export/delete rights remain available after subscription ends."
        ),
        .init(
            id: "diagnostics",
            appleDataCategory: "Diagnostics",
            appleDataType: "Crash Data and Performance Data",
            collectedByAppOrBackend: true,
            linkedToUser: false,
            uses: [.diagnostics],
            userConsentRequired: false,
            evidence: "Diagnostics should be limited to crash/performance quality monitoring and must not contain raw memories or media."
        ),
        .init(
            id: "minimal-ai-task-payload",
            appleDataCategory: "User Content",
            appleDataType: "Other User Content",
            collectedByAppOrBackend: true,
            linkedToUser: true,
            uses: [.aiAssistance],
            userConsentRequired: true,
            evidence: "DeepSeek weekly chapter tasks use only user-approved slice IDs, titles, tags, media kinds, and selected claims; no raw media or full archive."
        ),
        .init(
            id: "encrypted-sync-backup",
            appleDataCategory: "User Content",
            appleDataType: "Other User Content",
            collectedByAppOrBackend: true,
            linkedToUser: true,
            uses: [.optionalSync, .appFunctionality],
            userConsentRequired: true,
            evidence: "Optional encrypted backup/sync carries only consented memory data and remains exportable/deletable."
        )
    ]

    public var requiredAnswerIDs: [String] {
        [
            "memory-user-content",
            "photo-video-anchors",
            "account-identifier",
            "subscription-purchases",
            "diagnostics",
            "minimal-ai-task-payload",
            "encrypted-sync-backup"
        ]
    }

    public var coversRequiredTSDDataTypes: Bool {
        let ids = Set(answers.map(\.id))
        return Set(requiredAnswerIDs).isSubset(of: ids)
    }

    public var forbidsTrackingAndAds: Bool {
        noTracking &&
        noThirdPartyAdvertising &&
        answers.allSatisfy { !$0.usedForTracking }
    }

    public var preservesPrivacyBoundaries: Bool {
        noContactsAccess &&
        noGPSOrLocationInference &&
        noFaceRecognitionOrBiometricProfile &&
        rawMediaNeverSentToAIProvider &&
        aiUsesOnlyUserApprovedMinimalFields &&
        answers.allSatisfy { !$0.rawMediaSentToAIProvider }
    }

    public var preservesUserRights: Bool {
        exportAndDeleteRightsPreserved &&
        answers.filter(\.collectedByAppOrBackend).allSatisfy(\.deletionAndExportCovered)
    }

    public var canSatisfyQuestionnaireShapeGate: Bool {
        sourceReferences.count >= 3 &&
        privacyURLIncluded &&
        coversRequiredTSDDataTypes &&
        forbidsTrackingAndAds &&
        preservesPrivacyBoundaries &&
        preservesUserRights
    }

    public var canSatisfyFinalAppStoreQuestionnaireGate: Bool {
        canSatisfyQuestionnaireShapeGate &&
        completedInAppStoreConnect &&
        legalReviewCompleted
    }
}

public enum AgeRatingFrequency: String, Codable, Equatable, Sendable {
    case none
    case infrequent
    case frequent
}

public struct AppAgeRatingQuestionAnswer: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var appStoreConnectCategory: String
    public var frequency: AgeRatingFrequency
    public var included: Bool
    public var evidence: String

    public init(
        id: String,
        appStoreConnectCategory: String,
        frequency: AgeRatingFrequency,
        included: Bool,
        evidence: String
    ) {
        self.id = id
        self.appStoreConnectCategory = appStoreConnectCategory
        self.frequency = frequency
        self.included = included
        self.evidence = evidence
    }
}

public struct AppAgeRatingReviewPacket: Codable, Equatable, Sendable {
    public var sourceReferences: [String]
    public var targetMinimumAge: Int
    public var targetRatingLabel: String
    public var answers: [AppAgeRatingQuestionAnswer]
    public var notKidsCategory: Bool
    public var noPublicSocialFeed: Bool
    public var noRandomChatOrAnonymousMatching: Bool
    public var noGamblingLootBoxesOrContests: Bool
    public var noMedicalDiagnosisOrTreatment: Bool
    public var noPhysicalHarmInstructions: Bool
    public var externalLinksReviewed: Bool
    public var purchasesReviewed: Bool
    public var aiBoundedToFaithfulEditing: Bool
    public var userReportAndSupportPathRequiredForUGC: Bool
    public var ageSuitabilityURLIncluded: Bool
    public var completedInAppStoreConnect: Bool
    public var legalReviewCompleted: Bool

    public init(
        sourceReferences: [String] = [
            "App Store Connect Help: Set an app age rating",
            "App Store Connect Help: Age ratings values and definitions",
            "App Review Guidelines 1.2 User-Generated Content",
            "App Review Guidelines 1.3 Kids Category"
        ],
        targetMinimumAge: Int = 12,
        targetRatingLabel: String = "12+ direction, final rating to be calculated in App Store Connect",
        answers: [AppAgeRatingQuestionAnswer] = AppAgeRatingReviewPacket.defaultAnswers,
        notKidsCategory: Bool = true,
        noPublicSocialFeed: Bool = true,
        noRandomChatOrAnonymousMatching: Bool = true,
        noGamblingLootBoxesOrContests: Bool = true,
        noMedicalDiagnosisOrTreatment: Bool = true,
        noPhysicalHarmInstructions: Bool = true,
        externalLinksReviewed: Bool = true,
        purchasesReviewed: Bool = true,
        aiBoundedToFaithfulEditing: Bool = true,
        userReportAndSupportPathRequiredForUGC: Bool = true,
        ageSuitabilityURLIncluded: Bool = true,
        completedInAppStoreConnect: Bool = false,
        legalReviewCompleted: Bool = false
    ) {
        self.sourceReferences = sourceReferences
        self.targetMinimumAge = targetMinimumAge
        self.targetRatingLabel = targetRatingLabel
        self.answers = answers
        self.notKidsCategory = notKidsCategory
        self.noPublicSocialFeed = noPublicSocialFeed
        self.noRandomChatOrAnonymousMatching = noRandomChatOrAnonymousMatching
        self.noGamblingLootBoxesOrContests = noGamblingLootBoxesOrContests
        self.noMedicalDiagnosisOrTreatment = noMedicalDiagnosisOrTreatment
        self.noPhysicalHarmInstructions = noPhysicalHarmInstructions
        self.externalLinksReviewed = externalLinksReviewed
        self.purchasesReviewed = purchasesReviewed
        self.aiBoundedToFaithfulEditing = aiBoundedToFaithfulEditing
        self.userReportAndSupportPathRequiredForUGC = userReportAndSupportPathRequiredForUGC
        self.ageSuitabilityURLIncluded = ageSuitabilityURLIncluded
        self.completedInAppStoreConnect = completedInAppStoreConnect
        self.legalReviewCompleted = legalReviewCompleted
    }

    public static let defaultAnswers: [AppAgeRatingQuestionAnswer] = [
        .init(
            id: "private-user-memory-content",
            appStoreConnectCategory: "User-Generated Content",
            frequency: .infrequent,
            included: true,
            evidence: "TSD stores user-authored private memory slices, notes, tags, and user-selected family/media anchors; it is not a public posting network."
        ),
        .init(
            id: "photo-video-family-media",
            appStoreConnectCategory: "User-Generated Photos or Videos",
            frequency: .infrequent,
            included: true,
            evidence: "Photos/videos are user-selected memory anchors; family/child media has a caution path, no public feed, and export/delete rights."
        ),
        .init(
            id: "ai-edited-memory-drafts",
            appStoreConnectCategory: "Generative AI / creator tools",
            frequency: .infrequent,
            included: true,
            evidence: "AI is bounded to faithful weekly-chapter editing from user-selected slices and cannot generate open-ended social, sexual, violent, medical, or harmful content."
        ),
        .init(
            id: "external-links",
            appStoreConnectCategory: "Unrestricted Web Access / External Links",
            frequency: .infrequent,
            included: true,
            evidence: "The release packet includes support, privacy, export, deletion, subscription, and App Review route URLs; TSD is not claiming Kids Category."
        ),
        .init(
            id: "in-app-purchases",
            appStoreConnectCategory: "Purchases / Subscriptions",
            frequency: .infrequent,
            included: true,
            evidence: "Subscription copy is limited to sync, AI, and storage enhancements; memories, export, and deletion are never held hostage."
        ),
        .init(
            id: "medical-or-health-claims",
            appStoreConnectCategory: "Medical or Treatment Information",
            frequency: .none,
            included: false,
            evidence: "TSD is not a medical, mental-health, memory-loss, diagnosis, therapy, or cognitive assessment app."
        ),
        .init(
            id: "gambling-contests-loot-boxes",
            appStoreConnectCategory: "Gambling, Contests, Loot Boxes",
            frequency: .none,
            included: false,
            evidence: "TSD has no gambling, simulated gambling, loot boxes, contests, or chance-based rewards."
        ),
        .init(
            id: "random-chat-social-network",
            appStoreConnectCategory: "Random Chat / Social Networking",
            frequency: .none,
            included: false,
            evidence: "TSD has no random chat, anonymous matching, public follower graph, hot-or-not ranking, or public social feed."
        )
    ]

    public var requiredAnswerIDs: [String] {
        [
            "private-user-memory-content",
            "photo-video-family-media",
            "ai-edited-memory-drafts",
            "external-links",
            "in-app-purchases",
            "medical-or-health-claims",
            "gambling-contests-loot-boxes",
            "random-chat-social-network"
        ]
    }

    public var coversRequiredAgeRatingTopics: Bool {
        let ids = Set(answers.map(\.id))
        return Set(requiredAnswerIDs).isSubset(of: ids)
    }

    public var disallowsAdultOrRegulatedContentByDefault: Bool {
        noGamblingLootBoxesOrContests &&
        noMedicalDiagnosisOrTreatment &&
        noPhysicalHarmInstructions &&
        answers.first { $0.id == "medical-or-health-claims" }?.included == false &&
        answers.first { $0.id == "gambling-contests-loot-boxes" }?.included == false
    }

    public var preservesChildSafetyPositioning: Bool {
        targetMinimumAge >= 12 &&
        notKidsCategory &&
        externalLinksReviewed &&
        purchasesReviewed
    }

    public var preservesUGCAndAISafetyBoundaries: Bool {
        noPublicSocialFeed &&
        noRandomChatOrAnonymousMatching &&
        aiBoundedToFaithfulEditing &&
        userReportAndSupportPathRequiredForUGC &&
        answers.first { $0.id == "random-chat-social-network" }?.included == false
    }

    public var canSatisfyAgeRatingShapeGate: Bool {
        sourceReferences.count >= 4 &&
        ageSuitabilityURLIncluded &&
        coversRequiredAgeRatingTopics &&
        disallowsAdultOrRegulatedContentByDefault &&
        preservesChildSafetyPositioning &&
        preservesUGCAndAISafetyBoundaries
    }

    public var canSatisfyFinalAgeRatingGate: Bool {
        canSatisfyAgeRatingShapeGate &&
        completedInAppStoreConnect &&
        legalReviewCompleted
    }
}

public enum AppStoreSubmissionGateStatus: String, Codable, Equatable, Sendable {
    case passed
    case blocked
}

public struct AppStoreSubmissionGateRow: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var status: AppStoreSubmissionGateStatus
    public var requiredForTestFlight: Bool
    public var requiredForAppStore: Bool
    public var evidence: String
    public var unblockAction: String

    public init(
        id: String,
        title: String,
        status: AppStoreSubmissionGateStatus,
        requiredForTestFlight: Bool = true,
        requiredForAppStore: Bool = true,
        evidence: String,
        unblockAction: String
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.requiredForTestFlight = requiredForTestFlight
        self.requiredForAppStore = requiredForAppStore
        self.evidence = evidence
        self.unblockAction = unblockAction
    }

    public var blocksTestFlight: Bool {
        requiredForTestFlight && status == .blocked
    }

    public var blocksAppStore: Bool {
        requiredForAppStore && status == .blocked
    }
}

public struct AppStoreSubmissionGate: Codable, Equatable, Sendable {
    public var buildNumber: String
    public var rows: [AppStoreSubmissionGateRow]

    public init(buildNumber: String = "65", rows: [AppStoreSubmissionGateRow]) {
        self.buildNumber = buildNumber
        self.rows = rows
    }

    public var testFlightBlockers: [AppStoreSubmissionGateRow] {
        rows.filter(\.blocksTestFlight)
    }

    public var appStoreBlockers: [AppStoreSubmissionGateRow] {
        rows.filter(\.blocksAppStore)
    }

    public var canSubmitToTestFlight: Bool {
        testFlightBlockers.isEmpty
    }

    public var canSubmitToAppStore: Bool {
        appStoreBlockers.isEmpty
    }

    public var blockerIDs: [String] {
        appStoreBlockers.map(\.id)
    }

    public static func current(
        hasFullXcode: Bool,
        archiveCreated: Bool,
        testFlightUploadReceiptPresent: Bool,
        supportPrivacyURLsPublished: Bool,
        appPrivacyQuestionnaireCompleted: Bool,
        ageRatingReviewedFor12Plus: Bool,
        photosImportSignedDevicePassed: Bool,
        filesExportSignedDevicePassed: Bool,
        signingPlan: SigningReadinessPlan = SigningReadinessPlan(),
        buildNotes: TestFlightBuildNotes = TestFlightBuildNotes(),
        reviewRoute: AppReviewRoute = AppReviewRoute(),
        privacyBoundary: PrivacyBoundary = PrivacyBoundary(),
        publicURLPacket: AppStorePublicURLPacket = AppStorePublicURLPacket(),
        appPrivacyQuestionnairePacket: AppPrivacyQuestionnairePacket = AppPrivacyQuestionnairePacket(),
        ageRatingReviewPacket: AppAgeRatingReviewPacket = AppAgeRatingReviewPacket(),
        backendReleaseEvidence: TSDBackendReleaseEvidence = TSDBackendReleaseEvidence(),
        signedDeviceReceipt: SignedDeviceKeychainValidationReceipt? = nil,
        deepSeekReceipt: DeepSeekGatewayIntegrationReceipt? = nil,
        deletionReceipt: DeletionServiceLiveProbeReceipt? = nil,
        nativeRows: [ReadinessRow] = NativeHandoffLedger.rows,
        submissionRows: [ReadinessRow] = SubmissionPacket.rows,
        launchRows: [ReadinessRow] = AppStoreLaunchAssetChecklist.rows,
        productionRows: [ReadinessRow] = ProductionImplementationChecklist.rows
    ) -> AppStoreSubmissionGate {
        let teamIDPresent = signingPlan.teamID?.isEmpty == false
        let bundleIDMatches = signingPlan.bundleIdentifier == "com.raingodprc.timeslowdown"
        let supportContactPresent = !buildNotes.supportContact.localizedCaseInsensitiveContains("required")
        let publicURLShapeReady = publicURLPacket.canSatisfyPublicURLShapeGate
        let finalLegalURLsReady = publicURLPacket.canSatisfyFinalLegalURLGate
        let privacyQuestionnaireShapeReady = appPrivacyQuestionnairePacket.canSatisfyQuestionnaireShapeGate
        let ageRatingShapeReady = ageRatingReviewPacket.canSatisfyAgeRatingShapeGate
        let nativeContractCovered = nativeRows.map(\.id).contains("photos-picker") &&
        nativeRows.map(\.id).contains("keychain-e2ee") &&
        nativeRows.map(\.id).contains("deepseek-gateway")
        let submissionContractCovered = submissionRows.map(\.id).contains("privacy-questionnaire") &&
        submissionRows.map(\.id).contains("privacy-questionnaire-packet") &&
        submissionRows.map(\.id).contains("age-rating") &&
        submissionRows.map(\.id).contains("age-rating-review-packet") &&
        submissionRows.map(\.id).contains("support-privacy-urls")
        let launchContractsCovered = launchRows.count == 4 && launchRows.allSatisfy { $0.status == .poc }
        let productionContractsCovered = productionRows.count >= 7 && productionRows.allSatisfy { $0.status == .poc }
        let signedDevicePassed = signedDeviceReceipt?.isProductionPassReceipt == true
        let aiProviderPassed = deepSeekReceipt?.canBeUsedForAppStoreGate == true
        let deletionCompleted = deletionReceipt?.canSatisfyAppStoreDeletionGate == true
        let backendDeploymentPassed = backendReleaseEvidence.canSatisfyBackendDeploymentGate

        return AppStoreSubmissionGate(rows: [
            .init(
                id: "full-xcode",
                title: "Full Xcode toolchain",
                status: hasFullXcode ? .passed : .blocked,
                evidence: hasFullXcode ? "Full Xcode is available for archive/signing." : "Current SwiftPM host can build contracts but cannot archive/sign the iOS app.",
                unblockAction: "Install/select full Xcode and rerun archive checks."
            ),
            .init(
                id: "apple-developer-team",
                title: "Apple Developer Team ID",
                status: teamIDPresent ? .passed : .blocked,
                evidence: teamIDPresent ? "Signing plan includes a Team ID." : "Team ID is intentionally blank; fake signing is forbidden.",
                unblockAction: "Set the real Apple Developer Team ID in the Xcode project/signing plan."
            ),
            .init(
                id: "bundle-id",
                title: "Production bundle identifier",
                status: bundleIDMatches ? .passed : .blocked,
                evidence: signingPlan.bundleIdentifier,
                unblockAction: "Keep the project and App Store Connect bundle ID aligned."
            ),
            .init(
                id: "archive",
                title: "Release archive",
                status: hasFullXcode && archiveCreated ? .passed : .blocked,
                evidence: archiveCreated ? "Release archive receipt is present." : signingPlan.archiveCommandWhenXcodeAvailable,
                unblockAction: "Create a Release archive with full Xcode."
            ),
            .init(
                id: "testflight-upload",
                title: "TestFlight upload receipt",
                status: testFlightUploadReceiptPresent ? .passed : .blocked,
                evidence: testFlightUploadReceiptPresent ? "Upload receipt exists." : "No Transporter/App Store Connect upload receipt exists yet.",
                unblockAction: "Upload the signed archive to App Store Connect/TestFlight and capture the receipt."
            ),
            .init(
                id: "support-privacy-urls",
                title: "Support and privacy URLs",
                status: supportPrivacyURLsPublished && supportContactPresent && finalLegalURLsReady ? .passed : .blocked,
                evidence: publicURLShapeReady ? "Public demo URL packet exists, but final legal/company support URLs are not reviewed." : "Public support/privacy/export/delete URLs are not published.",
                unblockAction: "Publish and legal-review support, privacy, export, deletion, subscription, and App Review route URLs."
            ),
            .init(
                id: "public-url-packet",
                title: "Public URL packet shape",
                status: publicURLShapeReady ? .passed : .blocked,
                requiredForTestFlight: false,
                evidence: publicURLShapeReady ? publicURLPacket.privacyURL : "Public URL packet is incomplete or not HTTPS.",
                unblockAction: "Keep HTTPS public support/privacy/export/delete/subscription/review deep links reachable from the launch packet."
            ),
            .init(
                id: "app-privacy-questionnaire",
                title: "App Privacy questionnaire",
                status: appPrivacyQuestionnaireCompleted ? .passed : .blocked,
                requiredForTestFlight: false,
                evidence: appPrivacyQuestionnaireCompleted ? "App Store Connect privacy answers are reviewed." : "Privacy questionnaire remains blocked until App Store Connect entry and legal/release review are complete.",
                unblockAction: "Complete App Store Connect data-use answers for user content, media, account, purchases, diagnostics, AI, and sync."
            ),
            .init(
                id: "app-privacy-questionnaire-packet",
                title: "App Privacy questionnaire packet",
                status: privacyQuestionnaireShapeReady ? .passed : .blocked,
                requiredForTestFlight: false,
                evidence: privacyQuestionnaireShapeReady ? "v64 maps TSD user content, photos/videos, account identifiers, purchases, diagnostics, AI task payloads, and optional encrypted sync to privacy-answer evidence without tracking or raw-media AI upload." : "Privacy questionnaire packet is incomplete.",
                unblockAction: "Repair the machine-checkable privacy data mapping before release/legal handoff."
            ),
            .init(
                id: "age-rating-12-plus",
                title: "12+ age rating review",
                status: ageRatingReviewedFor12Plus ? .passed : .blocked,
                requiredForTestFlight: false,
                evidence: ageRatingReviewedFor12Plus ? "12+ age rating assumptions reviewed." : "12+ direction still requires legal/release review.",
                unblockAction: "Review UGC, family media, AI, links, and account flows against App Store age-rating rules."
            ),
            .init(
                id: "age-rating-review-packet",
                title: "Age Rating review packet",
                status: ageRatingShapeReady ? .passed : .blocked,
                requiredForTestFlight: false,
                evidence: ageRatingShapeReady ? "v65 maps private user memory/media content, no public social feed, no Kids Category claim, AI faithful-editing boundary, external links, purchases, and support/contact requirements into age-rating evidence." : "Age Rating review packet is incomplete.",
                unblockAction: "Repair the machine-checkable age-rating answer packet before legal/release review."
            ),
            .init(
                id: "guest-review-route",
                title: "Guest App Review route",
                status: reviewRoute.isGuestReviewFriendly ? .passed : .blocked,
                evidence: reviewRoute.reviewerNotes,
                unblockAction: "Keep a no-login App Review route through Memory Camera, media wall, weekly chapter, and Account Rights."
            ),
            .init(
                id: "privacy-safe-defaults",
                title: "Privacy-safe defaults",
                status: privacyBoundary.isAppStoreSafeDefault ? .passed : .blocked,
                evidence: "No raw-media upload, contacts, GPS inference, face recognition, or subscription-hostage export by default.",
                unblockAction: "Restore local-first privacy defaults."
            ),
            .init(
                id: "launch-contracts",
                title: "Launch contract coverage",
                status: nativeContractCovered && submissionContractCovered && launchContractsCovered && productionContractsCovered ? .passed : .blocked,
                evidence: "Native, submission, launch asset, and production trust ledgers are present.",
                unblockAction: "Repair missing ledger rows before release handoff."
            ),
            .init(
                id: "signed-device-keychain",
                title: "Signed-device Keychain/Secure Enclave pass",
                status: signedDevicePassed ? .passed : .blocked,
                evidence: signedDevicePassed ? "Production signed-device receipt passed." : "Only a pending SwiftPM-host scaffold exists; no physical-device pass receipt exists.",
                unblockAction: "Run the signed production app on a physical device and capture all Secure Enclave/Keychain step receipts."
            ),
            .init(
                id: "signed-device-photos-import",
                title: "Signed-device Photos import pass",
                status: photosImportSignedDevicePassed ? .passed : .blocked,
                evidence: photosImportSignedDevicePassed ? "Limited-library import passed on signed device." : "Photos import is contract-tested only; signed-device PhotosPicker validation is missing.",
                unblockAction: "Validate limited-library photo/video import on a signed physical device."
            ),
            .init(
                id: "signed-device-files-export",
                title: "Signed-device Files export pass",
                status: filesExportSignedDevicePassed ? .passed : .blocked,
                evidence: filesExportSignedDevicePassed ? "Files/share export passed on signed device." : "ZIP/fileExporter path is contract-tested only; signed-device Files export validation is missing.",
                unblockAction: "Validate Files/share-sheet export and re-open the ZIP package on a signed physical device."
            ),
            .init(
                id: "backend-release-manifest",
                title: "Backend release manifest",
                status: backendDeploymentPassed ? .passed : .blocked,
                evidence: backendDeploymentPassed ? "Backend deployment evidence includes HTTPS base URL, server-side DeepSeek secret boundary, live provider receipt, and completed deletion receipt." : backendReleaseEvidence.blockerReasons.joined(separator: "; "),
                unblockAction: "Deploy the real TSD backend, configure server-side DeepSeek credentials, run live provider/deletion probes, and complete backend release review."
            ),
            .init(
                id: "deepseek-provider-pass",
                title: "DeepSeek provider round trip",
                status: aiProviderPassed ? .passed : .blocked,
                evidence: aiProviderPassed ? "Provider pass receipt can unlock App Store AI gate." : "No real TSD backend/DeepSeek provider pass receipt is present.",
                unblockAction: "Run the live backend probe against a deployed TSD backend using server-side DeepSeek credentials."
            ),
            .init(
                id: "deletion-completion-pass",
                title: "Account deletion completion",
                status: deletionCompleted ? .passed : .blocked,
                evidence: deletionCompleted ? "Deletion live probe completed with job/audit/tombstone/per-system evidence." : "No completed deletion service receipt exists.",
                unblockAction: "Run the deletion live probe against a real test account until completion evidence is available."
            )
        ])
    }
}
