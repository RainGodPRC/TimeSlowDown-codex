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
        buildNumber: String = "76",
        summary: String = "TimeSlowDown v76 adds a real local image-thumbnail pipeline and editable memory slices: PhotosPicker images are rendered through ImageIO into metadata-stripped bounded JPEG thumbnails, saved in an iOS-protected local cache, displayed in slice rows and detail, and surfaced as invalid when cache files disappear. Users can edit title/body/people/meaning, replace or remove media, delete a slice with its revisit layers, and undo deletion with thumbnail restoration. Video selection remains an honest poster-pending memory clue instead of loading an entire raw video. The build retains v75 atomic local persistence, first-launch empty vault, legacy migration, corrupt data backup recovery, the branded Memory Camera home, Yesterday Echo, native Weekly Story progress and Weekend Workbench, private Life Marks gallery, revisit export, Daily Difference Radar, 90-day tellable progress, Photos-library byte import adapter, E2EE media vault adapter, CryptoKit media vault envelope contract, Secure Enclave device-key contract, signed-device validation scaffold, signed-device media validation packet, archive/signing readiness packet, App Store metadata/legal review packet, screenshot/App Preview creative packet, Privacy Manifest required reason API audit packet, encryption export compliance review packet, Keychain record store adapter, Account Rights export UI state, SwiftUI fileExporter bridge, on-device export ZIP builder, raw media export policy, staged raw media export builder, deletion audit envelope, DeepSeek server gateway envelope, DeepSeek provider validation scaffold, DeepSeek integration test runner contract, DeepSeek backend endpoint/provider proxy contract, DeepSeek endpoint execution harness, optional live backend probe, deletion service boundary, deletion live probe, App Store submission gate, public URL packet, backend release manifest, App Privacy questionnaire packet, Age Rating review packet, and privacy/export/delete/AI trust boundaries.",
        testerRoute: [String] = [
            "Open Today and bring back Yesterday Echo; optionally add one user-authored reflection.",
            "Open Weekly Story Progress and complete one missing media, person, or meaning field in Weekend Workbench.",
            "Open Memory Camera and choose a photo or video as a memory anchor.",
            "Confirm the generated slice keeps media as the memory key, not a text attachment.",
            "Review the media wall and weekly chapter preview.",
            "Open account rights to verify export/delete remain available without subscription hostage.",
            "Open Life Marks to review earned and mystery achievements without completion pressure."
        ],
        knownLimitations: [String] = [
            "No production backend, account sync, or bundled DeepSeek provider key is included in this build; v55 separates pending backend, mock gateway, and future provider-passed validation receipts, v56 defines the redacted backend integration test request/result contract, v57 defines the backend endpoint contract plus provider proxy boundary, v58 adds a local endpoint execution harness that can pass only stub gates, v59 adds an optional live backend probe that requires TSD backend URL/token environment variables plus real provider evidence before any production AI/App Store AI gate can pass, and v60 adds an optional deletion live probe that requires TSD deletion backend URL/token plus real job/audit/tombstone/per-system evidence before deletion gates can pass.",
            "Secure Enclave generation request, reference receipt, and signed-device validation scaffold are now Swift-verifiable contracts, but no signed-device Secure Enclave/Keychain pass receipt, signed-device Photos import validation, or production E2EE media vault validation is claimed yet.",
            "v61 adds an App Store submission gate that remains blocked until full Xcode, Team ID, archive, TestFlight upload, App Store Connect metadata, support/privacy URLs, App Privacy questionnaire, age rating, DeepSeek provider pass, deletion completion, and signed-device privacy receipts exist.",
            "v62 adds a public URL packet with HTTPS support/privacy/export/delete/subscription/review deep links on the public GitHub Pages demo, while keeping formal legal review and final company support/privacy URLs as release blockers.",
            "v63 adds a backend release manifest gate that remains blocked until a real HTTPS TSD backend, server-side DeepSeek secret manager, weekly chapter endpoint, deletion jobs endpoint, audit/deletion worker, live provider receipt, completed deletion receipt, and deployment review exist.",
            "v64 adds an App Privacy questionnaire packet that maps user content, photo/video anchors, account identifiers, purchases, diagnostics, minimal AI task payloads, and optional encrypted sync to App Store privacy answers, but keeps final App Store Connect/legal completion blocked.",
            "v65 adds an Age Rating review packet that maps private user memory/media content, no public social feed, no Kids Category claim, AI editing boundaries, external links, purchases, and support contact requirements while keeping final legal/release age-rating review blocked.",
            "v66 adds a signed-device media validation packet for PhotosPicker import and Files/share export evidence, while keeping actual Photos and Files release gates blocked until a real physical-device pass receipt exists.",
            "v67 adds an archive/signing readiness packet for full Xcode, Apple Developer Team, Release archive, Transporter upload, and App Store Connect processing evidence, while keeping actual archive/TestFlight gates blocked until a real production receipt exists.",
            "v68 adds an App Store metadata/legal review packet for product page copy, screenshot/app preview plan, review notes, support/privacy/data-rights URLs, subscription wording, AI disclosure, and legal/release checklist while keeping final App Store Connect entry and legal review blocked.",
            "v69 adds a Privacy Manifest required reason API audit packet that keeps the current no-tracking/no-collected-data/no-accessed-API manifest shape honest for the local shipping path while keeping dependency manifest review, Xcode privacy report generation, and release review blocked.",
            "v70 adds an encryption export compliance review packet and a conservative Info.plist encryption declaration, while keeping final App Store Connect export-compliance answers, legal review, and release review blocked.",
            "v71 adds a screenshot/App Preview creative packet that maps six App Store scenes, Apple asset-count constraints, real-UI capture requirements, privacy masking, and anti-fear-marketing rules while keeping final rendered asset upload, poster frame, localization, legal review, and release review blocked.",
            "v72 adds the P0 Daily Difference Radar and 90-day tellable progress model so the home screen is anchored to real daily memory capture and the north-star outcome instead of another release-packet-only iteration.",
            "v73 adds Yesterday Echo, user-authored revisit layers, weekly story progress, a non-punitive weekend completion workbench, and revisit export so first-week retention produces real memory value rather than streak debt.",
            "v74 replaces the engineering-style native home and Launch tab with a branded Memory Camera experience, native return-loop sheets, and a private Life Marks gallery that keeps mystery without totals, rankings, or streak debt.",
            "v75 replaces seeded demo memories in the shipping app with an empty personal vault, atomically persists native state in Application Support, migrates legacy JSON, preserves corrupt backups, and gives empty Slices and Meadow destinations an intentional first-memory path.",
            "v76 generates protected metadata-stripped JPEG thumbnails for user-selected images, adds editable slice detail, media replacement/removal, delete plus undo, and missing-thumbnail recovery UI; video poster generation and signed-device Photos validation remain explicit follow-up work.",
            "Archive, signing, signed-device Photos/Files validation, TestFlight upload, App Store Connect metadata, full Xcode privacy report, dependency privacy manifest review, encryption export compliance, and legal review require full Xcode, Apple Developer access, and release/legal approval."
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

public enum ArchiveSigningValidationStatus: String, Codable, Equatable, Sendable {
    case pendingExternalXcode
    case readyToArchive
    case uploadedToTestFlight
    case failed
}

public struct ArchiveSigningValidationEnvironment: Codable, Equatable, Sendable {
    public var bundleIdentifier: String
    public var teamID: String?
    public var xcodeVersion: String?
    public var macOSVersion: String
    public var hasFullXcode: Bool
    public var hasAppleDeveloperTeam: Bool
    public var usesProductionBundleIdentifier: Bool
    public var signingStyle: String
    public var appStoreConnectAccessAvailable: Bool
    public var transporterAvailable: Bool
    public var networkRequiredForUpload: Bool

    public init(
        bundleIdentifier: String = "com.raingodprc.timeslowdown",
        teamID: String? = nil,
        xcodeVersion: String? = nil,
        macOSVersion: String = "host-swiftpm",
        hasFullXcode: Bool,
        hasAppleDeveloperTeam: Bool,
        usesProductionBundleIdentifier: Bool = true,
        signingStyle: String = "Automatic",
        appStoreConnectAccessAvailable: Bool,
        transporterAvailable: Bool,
        networkRequiredForUpload: Bool = true
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.teamID = teamID
        self.xcodeVersion = xcodeVersion
        self.macOSVersion = macOSVersion
        self.hasFullXcode = hasFullXcode
        self.hasAppleDeveloperTeam = hasAppleDeveloperTeam
        self.usesProductionBundleIdentifier = usesProductionBundleIdentifier
        self.signingStyle = signingStyle
        self.appStoreConnectAccessAvailable = appStoreConnectAccessAvailable
        self.transporterAvailable = transporterAvailable
        self.networkRequiredForUpload = networkRequiredForUpload
    }

    public static func unsignedSwiftPMHost() -> ArchiveSigningValidationEnvironment {
        ArchiveSigningValidationEnvironment(
            hasFullXcode: false,
            hasAppleDeveloperTeam: false,
            appStoreConnectAccessAvailable: false,
            transporterAvailable: false
        )
    }

    public var canRunArchiveUploadValidation: Bool {
        bundleIdentifier == "com.raingodprc.timeslowdown" &&
        teamID?.isEmpty == false &&
        xcodeVersion?.isEmpty == false &&
        hasFullXcode &&
        hasAppleDeveloperTeam &&
        usesProductionBundleIdentifier &&
        signingStyle == "Automatic" &&
        appStoreConnectAccessAvailable &&
        transporterAvailable &&
        networkRequiredForUpload
    }
}

public enum ArchiveSigningValidationStepKind: String, Codable, Equatable, Sendable {
    case fullXcodeSelected
    case appleDeveloperTeamResolved
    case bundleIdentifierMatched
    case releaseArchiveCreated
    case archiveValidated
    case appStoreExportOptionsCreated
    case transporterUploadCompleted
    case appStoreConnectProcessingVisible
}

public struct ArchiveSigningValidationStep: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: ArchiveSigningValidationStepKind
    public var title: String
    public var requiresFullXcode: Bool
    public var forbidsPrivateSigningMaterial: Bool
    public var forbidsAppleSessionToken: Bool
    public var expectedEvidence: String

    public init(
        id: String,
        kind: ArchiveSigningValidationStepKind,
        title: String,
        requiresFullXcode: Bool = true,
        forbidsPrivateSigningMaterial: Bool = true,
        forbidsAppleSessionToken: Bool = true,
        expectedEvidence: String
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.requiresFullXcode = requiresFullXcode
        self.forbidsPrivateSigningMaterial = forbidsPrivateSigningMaterial
        self.forbidsAppleSessionToken = forbidsAppleSessionToken
        self.expectedEvidence = expectedEvidence
    }

    public var preservesTSDArchiveSigningBoundary: Bool {
        id.hasPrefix("archive-signing-") &&
        requiresFullXcode &&
        forbidsPrivateSigningMaterial &&
        forbidsAppleSessionToken &&
        !expectedEvidence.isEmpty
    }
}

public struct ArchiveSigningValidationPacket: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var environment: ArchiveSigningValidationEnvironment
    public var signingPlan: SigningReadinessPlan
    public var buildNotes: TestFlightBuildNotes
    public var steps: [ArchiveSigningValidationStep]
    public var status: ArchiveSigningValidationStatus
    public var productionValidationClaimed: Bool
    public var generatedAt: Date

    public init(
        id: String,
        environment: ArchiveSigningValidationEnvironment,
        signingPlan: SigningReadinessPlan,
        buildNotes: TestFlightBuildNotes,
        steps: [ArchiveSigningValidationStep],
        status: ArchiveSigningValidationStatus,
        productionValidationClaimed: Bool = false,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.environment = environment
        self.signingPlan = signingPlan
        self.buildNotes = buildNotes
        self.steps = steps
        self.status = status
        self.productionValidationClaimed = productionValidationClaimed
        self.generatedAt = generatedAt
    }

    public var isTSDArchiveSigningPacketSafe: Bool {
        id.hasPrefix("archive-signing-plan-") &&
        signingPlan.bundleIdentifier == "com.raingodprc.timeslowdown" &&
        signingPlan.requiresAppleDeveloperTeam &&
        signingPlan.fakeTeamIDForbidden &&
        buildNotes.buildNumber == "76" &&
        steps.count == ArchiveSigningValidationScaffold.defaultSteps.count &&
        Set(steps.map(\.kind)).count == steps.count &&
        steps.allSatisfy(\.preservesTSDArchiveSigningBoundary) &&
        !productionValidationClaimed &&
        (status == .pendingExternalXcode || status == .readyToArchive) &&
        (status == .readyToArchive) == environment.canRunArchiveUploadValidation
    }

    public var requiresExternalXcodeWork: Bool {
        status == .pendingExternalXcode &&
        !environment.canRunArchiveUploadValidation &&
        !productionValidationClaimed
    }
}

public struct ArchiveSigningValidationStepReceipt: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var stepID: String
    public var status: ArchiveSigningValidationStatus
    public var evidenceDigest: String?
    public var errorMessage: String?
    public var containsPrivateSigningMaterial: Bool
    public var containsAppleSessionToken: Bool

    public init(
        id: String,
        stepID: String,
        status: ArchiveSigningValidationStatus,
        evidenceDigest: String? = nil,
        errorMessage: String? = nil,
        containsPrivateSigningMaterial: Bool = false,
        containsAppleSessionToken: Bool = false
    ) {
        self.id = id
        self.stepID = stepID
        self.status = status
        self.evidenceDigest = evidenceDigest
        self.errorMessage = errorMessage
        self.containsPrivateSigningMaterial = containsPrivateSigningMaterial
        self.containsAppleSessionToken = containsAppleSessionToken
    }

    public var isHonestTSDArchiveSigningStepReceipt: Bool {
        id.hasPrefix("archive-signing-step-receipt-") &&
        !stepID.isEmpty &&
        !containsPrivateSigningMaterial &&
        !containsAppleSessionToken &&
        (status != .uploadedToTestFlight || evidenceDigest != nil) &&
        (status != .failed || errorMessage != nil)
    }
}

public struct ArchiveSigningValidationReceipt: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var planID: String
    public var status: ArchiveSigningValidationStatus
    public var stepReceipts: [ArchiveSigningValidationStepReceipt]
    public var productionValidationClaimed: Bool
    public var canSatisfyFullXcodeGate: Bool
    public var canSatisfyAppleDeveloperTeamGate: Bool
    public var canSatisfyArchiveGate: Bool
    public var canSatisfyTestFlightUploadGate: Bool
    public var containsPrivateSigningMaterial: Bool
    public var containsAppleSessionToken: Bool
    public var createdAt: Date

    public init(
        id: String,
        planID: String,
        status: ArchiveSigningValidationStatus,
        stepReceipts: [ArchiveSigningValidationStepReceipt],
        productionValidationClaimed: Bool,
        canSatisfyFullXcodeGate: Bool,
        canSatisfyAppleDeveloperTeamGate: Bool,
        canSatisfyArchiveGate: Bool,
        canSatisfyTestFlightUploadGate: Bool,
        containsPrivateSigningMaterial: Bool = false,
        containsAppleSessionToken: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.planID = planID
        self.status = status
        self.stepReceipts = stepReceipts
        self.productionValidationClaimed = productionValidationClaimed
        self.canSatisfyFullXcodeGate = canSatisfyFullXcodeGate
        self.canSatisfyAppleDeveloperTeamGate = canSatisfyAppleDeveloperTeamGate
        self.canSatisfyArchiveGate = canSatisfyArchiveGate
        self.canSatisfyTestFlightUploadGate = canSatisfyTestFlightUploadGate
        self.containsPrivateSigningMaterial = containsPrivateSigningMaterial
        self.containsAppleSessionToken = containsAppleSessionToken
        self.createdAt = createdAt
    }

    public var isHonestPendingReceipt: Bool {
        id.hasPrefix("archive-signing-receipt-") &&
        status == .pendingExternalXcode &&
        stepReceipts.allSatisfy { $0.status == .pendingExternalXcode && $0.isHonestTSDArchiveSigningStepReceipt } &&
        !productionValidationClaimed &&
        !canSatisfyFullXcodeGate &&
        !canSatisfyAppleDeveloperTeamGate &&
        !canSatisfyArchiveGate &&
        !canSatisfyTestFlightUploadGate &&
        !containsPrivateSigningMaterial &&
        !containsAppleSessionToken
    }

    public var isProductionArchiveUploadReceipt: Bool {
        id.hasPrefix("archive-signing-receipt-") &&
        status == .uploadedToTestFlight &&
        stepReceipts.count == ArchiveSigningValidationScaffold.defaultSteps.count &&
        stepReceipts.allSatisfy { $0.status == .uploadedToTestFlight && $0.isHonestTSDArchiveSigningStepReceipt } &&
        productionValidationClaimed &&
        canSatisfyFullXcodeGate &&
        canSatisfyAppleDeveloperTeamGate &&
        canSatisfyArchiveGate &&
        canSatisfyTestFlightUploadGate &&
        !containsPrivateSigningMaterial &&
        !containsAppleSessionToken
    }
}

public enum ArchiveSigningValidationScaffold {
    public static func packet(
        environment: ArchiveSigningValidationEnvironment,
        signingPlan: SigningReadinessPlan,
        buildNotes: TestFlightBuildNotes,
        generatedAt: Date = Date()
    ) -> ArchiveSigningValidationPacket {
        let digest = TrustDigest.checksum([
            environment.bundleIdentifier,
            environment.teamID ?? "no-team",
            signingPlan.bundleIdentifier,
            buildNotes.buildNumber
        ])
        return ArchiveSigningValidationPacket(
            id: "archive-signing-plan-\(digest.prefix(12))",
            environment: environment,
            signingPlan: signingPlan,
            buildNotes: buildNotes,
            steps: defaultSteps,
            status: environment.canRunArchiveUploadValidation ? .readyToArchive : .pendingExternalXcode,
            generatedAt: generatedAt
        )
    }

    public static func pendingReceipt(
        for packet: ArchiveSigningValidationPacket,
        createdAt: Date = Date()
    ) -> ArchiveSigningValidationReceipt {
        let stepReceipts = packet.steps.map { step in
            ArchiveSigningValidationStepReceipt(
                id: "archive-signing-step-receipt-\(TrustDigest.checksum([packet.id, step.id]).prefix(12))",
                stepID: step.id,
                status: .pendingExternalXcode
            )
        }
        let digest = TrustDigest.checksum([packet.id, "pending-archive-signing"])
        return ArchiveSigningValidationReceipt(
            id: "archive-signing-receipt-\(digest.prefix(12))",
            planID: packet.id,
            status: .pendingExternalXcode,
            stepReceipts: stepReceipts,
            productionValidationClaimed: false,
            canSatisfyFullXcodeGate: false,
            canSatisfyAppleDeveloperTeamGate: false,
            canSatisfyArchiveGate: false,
            canSatisfyTestFlightUploadGate: false,
            createdAt: createdAt
        )
    }

    public static var defaultSteps: [ArchiveSigningValidationStep] {
        [
            .init(id: "archive-signing-full-xcode-selected", kind: .fullXcodeSelected, title: "Select full Xcode toolchain", expectedEvidence: "xcodebuild -version digest and selected developer directory"),
            .init(id: "archive-signing-apple-developer-team-resolved", kind: .appleDeveloperTeamResolved, title: "Resolve real Apple Developer Team ID", expectedEvidence: "Team ID digest and bundle capability check without exposing account session"),
            .init(id: "archive-signing-bundle-identifier-matched", kind: .bundleIdentifierMatched, title: "Match production bundle identifier", expectedEvidence: "com.raingodprc.timeslowdown bundle ID in project and App Store Connect"),
            .init(id: "archive-signing-release-archive-created", kind: .releaseArchiveCreated, title: "Create Release archive", expectedEvidence: "xcarchive path digest, build number, scheme, configuration, and archive timestamp"),
            .init(id: "archive-signing-archive-validated", kind: .archiveValidated, title: "Validate archive for App Store distribution", expectedEvidence: "Xcode archive validation result digest with no development signing"),
            .init(id: "archive-signing-app-store-export-options-created", kind: .appStoreExportOptionsCreated, title: "Create App Store export options", expectedEvidence: "method=app-store-connect/exportOptions digest without certificates or profiles"),
            .init(id: "archive-signing-transporter-upload-completed", kind: .transporterUploadCompleted, title: "Upload archive through Transporter/App Store Connect", expectedEvidence: "upload receipt digest, bundle ID, build number, and processing ID"),
            .init(id: "archive-signing-app-store-connect-processing-visible", kind: .appStoreConnectProcessingVisible, title: "Confirm build is visible in App Store Connect/TestFlight", expectedEvidence: "App Store Connect build processing receipt digest")
        ]
    }
}

public enum AppStoreLaunchAssetChecklist {
    public static let rows: [ReadinessRow] = [
        .init(id: "app-icon-pngs", title: "App Icon PNG assets", status: .poc, owner: "design/iOS", evidence: "All iPhone and iOS marketing icon slots have deterministic PNG files referenced by AppIcon Contents.json."),
        .init(id: "testflight-build-notes", title: "TestFlight build notes", status: .poc, owner: "release", evidence: "v76 build notes name protected image thumbnails, editable slice detail, media invalidation, delete/undo, honest video poster limits, local persistence, export/delete rights, AI boundary, and production limitations."),
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

public enum AppStoreMetadataLegalItemKind: String, Codable, Equatable, CaseIterable, Sendable {
    case productPagePositioning = "product-page-positioning"
    case screenshotsAndAppPreview = "screenshots-app-preview"
    case appReviewNotes = "app-review-notes"
    case supportAndPrivacyURLs = "support-privacy-urls"
    case exportAndDeletionRights = "export-deletion-rights"
    case subscriptionCopy = "subscription-copy"
    case aiAndDataProcessingDisclosure = "ai-data-processing-disclosure"
    case legalReleaseChecklist = "legal-release-checklist"
}

public struct AppStoreMetadataLegalReviewItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: AppStoreMetadataLegalItemKind
    public var title: String
    public var evidence: String
    public var requiresAppStoreConnectEntry: Bool
    public var requiresLegalReview: Bool
    public var preservesTSDPositioning: Bool
    public var avoidsFearDeathOrShameMarketing: Bool

    public init(
        id: String,
        kind: AppStoreMetadataLegalItemKind,
        title: String,
        evidence: String,
        requiresAppStoreConnectEntry: Bool = true,
        requiresLegalReview: Bool = true,
        preservesTSDPositioning: Bool = true,
        avoidsFearDeathOrShameMarketing: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.evidence = evidence
        self.requiresAppStoreConnectEntry = requiresAppStoreConnectEntry
        self.requiresLegalReview = requiresLegalReview
        self.preservesTSDPositioning = preservesTSDPositioning
        self.avoidsFearDeathOrShameMarketing = avoidsFearDeathOrShameMarketing
    }

    public var isHonestTSDMetadataItem: Bool {
        id.hasPrefix("metadata-legal-") &&
        !title.isEmpty &&
        !evidence.isEmpty &&
        preservesTSDPositioning &&
        avoidsFearDeathOrShameMarketing
    }
}

public struct AppStoreMetadataLegalReviewPacket: Codable, Equatable, Sendable {
    public var sourceReferences: [String]
    public var productName: String
    public var bundleIdentifier: String
    public var subtitle: String
    public var shortDescription: String
    public var keywords: [String]
    public var screenshotPlan: [String]
    public var appReviewNotes: String
    public var subscriptionCopy: String
    public var supportURL: String
    public var privacyURL: String
    public var exportRightsURL: String
    public var deletionRightsURL: String
    public var aiDisclosure: String
    public var items: [AppStoreMetadataLegalReviewItem]
    public var completedInAppStoreConnect: Bool
    public var legalReviewCompleted: Bool
    public var releaseReviewCompleted: Bool

    public init(
        sourceReferences: [String] = [
            "App Store Connect Help: Overview of app metadata",
            "App Store Connect Help: Add app information",
            "App Store Connect Help: App previews and screenshots",
            "App Review Guidelines 2.3 Accurate Metadata",
            "App Review Guidelines 5.1 Privacy"
        ],
        productName: String = "TimeSlowDown",
        bundleIdentifier: String = "com.raingodprc.timeslowdown",
        subtitle: String = "把今天留成以后能讲的瞬间",
        shortDescription: String = "TimeSlowDown helps you turn photo/video anchors, quick marks, and weekly claims into private memory slices and tellable chapters without becoming a public social feed, medical tool, or full photo-library scanner.",
        keywords: [String] = [
            "memory",
            "journal",
            "photo",
            "weekly story",
            "private archive",
            "time",
            "life meadow"
        ],
        screenshotPlan: [String] = [
            "Memory Camera photo/video-first capture",
            "Today slice with media anchor and source trace",
            "Weekly chapter: user claims three moments before AI edits",
            "Life Meadow semantic zoom across week/month/year/life",
            "Media wall with photo timeline and no full-library scan",
            "Account Rights: export, deletion, subscription, and AI boundaries"
        ],
        appReviewNotes: String = "Reviewer can use guest mode: Memory Camera → create media slice → Media Wall → Weekly Chapter → Account Rights / Privacy Center. No login is required for the review route.",
        subscriptionCopy: String = "Subscription enhances encrypted sync, AI quota, and storage. Existing memories, local recording, export, and deletion rights are never held hostage.",
        supportURL: String = "https://raingodprc.github.io/TimeSlowDown-codex/#support",
        privacyURL: String = "https://raingodprc.github.io/TimeSlowDown-codex/#privacy",
        exportRightsURL: String = "https://raingodprc.github.io/TimeSlowDown-codex/#export",
        deletionRightsURL: String = "https://raingodprc.github.io/TimeSlowDown-codex/#delete",
        aiDisclosure: String = "AI is a faithful editor for user-approved weekly chapter drafts. Raw photos/videos, full archives, contacts, GPS, face embeddings, provider keys, and subscription state must not be sent to the model provider.",
        items: [AppStoreMetadataLegalReviewItem] = AppStoreMetadataLegalReviewPacket.defaultItems,
        completedInAppStoreConnect: Bool = false,
        legalReviewCompleted: Bool = false,
        releaseReviewCompleted: Bool = false
    ) {
        self.sourceReferences = sourceReferences
        self.productName = productName
        self.bundleIdentifier = bundleIdentifier
        self.subtitle = subtitle
        self.shortDescription = shortDescription
        self.keywords = keywords
        self.screenshotPlan = screenshotPlan
        self.appReviewNotes = appReviewNotes
        self.subscriptionCopy = subscriptionCopy
        self.supportURL = supportURL
        self.privacyURL = privacyURL
        self.exportRightsURL = exportRightsURL
        self.deletionRightsURL = deletionRightsURL
        self.aiDisclosure = aiDisclosure
        self.items = items
        self.completedInAppStoreConnect = completedInAppStoreConnect
        self.legalReviewCompleted = legalReviewCompleted
        self.releaseReviewCompleted = releaseReviewCompleted
    }

    public static let defaultItems: [AppStoreMetadataLegalReviewItem] = [
        .init(id: "metadata-legal-product-page", kind: .productPagePositioning, title: "Product page positioning", evidence: "TSD is positioned as a private memory-slice and weekly-story app; it is not a generic diary, photo album, public social network, or medical/cognitive diagnostic tool."),
        .init(id: "metadata-legal-screenshots-app-preview", kind: .screenshotsAndAppPreview, title: "Screenshots and App Preview plan", evidence: "Screenshots cover Memory Camera, today slice, weekly chapter, life meadow, media wall, and Account Rights instead of vague lifestyle claims."),
        .init(id: "metadata-legal-review-notes", kind: .appReviewNotes, title: "App Review notes", evidence: "Guest route lets reviewers inspect media capture, slice, media wall, weekly chapter, export/delete/subscription boundaries, and privacy center without login."),
        .init(id: "metadata-legal-support-privacy-urls", kind: .supportAndPrivacyURLs, title: "Support and Privacy URLs", evidence: "Support/privacy/export/delete/subscription/review URLs exist as HTTPS public routes, while final company/legal approval remains a release blocker."),
        .init(id: "metadata-legal-export-deletion-rights", kind: .exportAndDeletionRights, title: "Export and deletion rights copy", evidence: "Metadata must say users can export and delete memories; sync/AI/subscription cannot hold memories hostage."),
        .init(id: "metadata-legal-subscription-copy", kind: .subscriptionCopy, title: "Subscription wording", evidence: "Subscription enhances sync, AI quota, and storage only; base recording, export, and deletion remain available."),
        .init(id: "metadata-legal-ai-data-processing", kind: .aiAndDataProcessingDisclosure, title: "AI and data processing disclosure", evidence: "AI is disclosed as faithful editing from minimal user-approved fields; raw media, full archive, contacts, GPS, face embeddings, provider key, and subscription state are forbidden."),
        .init(id: "metadata-legal-release-checklist", kind: .legalReleaseChecklist, title: "Legal and release checklist", evidence: "Formal App Store Connect entry, legal review, and release review are required before final gate can pass.")
    ]

    public var requiredItemKinds: [AppStoreMetadataLegalItemKind] {
        AppStoreMetadataLegalItemKind.allCases
    }

    public var coversRequiredMetadataItems: Bool {
        let kinds = Set(items.map(\.kind))
        return Set(requiredItemKinds).isSubset(of: kinds)
    }

    public var usesPublicHTTPSURLs: Bool {
        [supportURL, privacyURL, exportRightsURL, deletionRightsURL].allSatisfy { url in
            url.hasPrefix("https://") &&
            url.hasPrefix("https://raingodprc.github.io/TimeSlowDown-codex/") &&
            !url.contains("localhost") &&
            !url.localizedCaseInsensitiveContains("todo") &&
            !url.localizedCaseInsensitiveContains("required")
        }
    }

    public var preservesProductTruth: Bool {
        productName == "TimeSlowDown" &&
        bundleIdentifier == "com.raingodprc.timeslowdown" &&
        shortDescription.localizedCaseInsensitiveContains("memory") &&
        shortDescription.localizedCaseInsensitiveContains("photo") &&
        shortDescription.localizedCaseInsensitiveContains("private") &&
        shortDescription.localizedCaseInsensitiveContains("without becoming a public social feed") &&
        shortDescription.localizedCaseInsensitiveContains("medical tool") &&
        shortDescription.localizedCaseInsensitiveContains("full photo-library scanner")
    }

    public var avoidsFearDeathOrShameMarketing: Bool {
        let combined = ([subtitle, shortDescription, appReviewNotes, subscriptionCopy, aiDisclosure] + items.map(\.evidence)).joined(separator: " ").lowercased()
        let forbiddenPhrases = [
            "death",
            "die before",
            "running out of life",
            "shame",
            "guilt",
            "死亡",
            "时日无多",
            "羞耻",
            "内疚"
        ]
        return forbiddenPhrases.allSatisfy { !combined.contains($0) } &&
        items.allSatisfy(\.avoidsFearDeathOrShameMarketing)
    }

    public var preservesUserRightsAndSubscriptionEthics: Bool {
        subscriptionCopy.localizedCaseInsensitiveContains("never held hostage") &&
        subscriptionCopy.localizedCaseInsensitiveContains("export") &&
        subscriptionCopy.localizedCaseInsensitiveContains("deletion") &&
        items.contains { $0.kind == .exportAndDeletionRights && $0.evidence.localizedCaseInsensitiveContains("export") && $0.evidence.localizedCaseInsensitiveContains("delete") }
    }

    public var preservesAIBoundary: Bool {
        aiDisclosure.localizedCaseInsensitiveContains("faithful editor") &&
        aiDisclosure.localizedCaseInsensitiveContains("raw photos/videos") &&
        aiDisclosure.localizedCaseInsensitiveContains("must not be sent") &&
        aiDisclosure.localizedCaseInsensitiveContains("provider")
    }

    public var canSatisfyMetadataLegalShapeGate: Bool {
        sourceReferences.count >= 5 &&
        coversRequiredMetadataItems &&
        items.allSatisfy(\.isHonestTSDMetadataItem) &&
        preservesProductTruth &&
        avoidsFearDeathOrShameMarketing &&
        usesPublicHTTPSURLs &&
        screenshotPlan.count >= 6 &&
        keywords.count >= 6 &&
        appReviewNotes.localizedCaseInsensitiveContains("guest mode") &&
        preservesUserRightsAndSubscriptionEthics &&
        preservesAIBoundary
    }

    public var canSatisfyFinalMetadataLegalGate: Bool {
        canSatisfyMetadataLegalShapeGate &&
        completedInAppStoreConnect &&
        legalReviewCompleted &&
        releaseReviewCompleted
    }
}

public enum AppStoreScreenshotSceneKind: String, Codable, Equatable, CaseIterable, Sendable {
    case memoryCamera = "memory-camera"
    case todaySlice = "today-slice"
    case weeklyChapter = "weekly-chapter"
    case lifeMeadow = "life-meadow"
    case mediaWall = "media-wall"
    case accountRights = "account-rights"
}

public struct AppStoreScreenshotCreativeItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: AppStoreScreenshotSceneKind
    public var title: String
    public var captureRoute: String
    public var heroCopy: String
    public var functionalEvidence: String
    public var deviceFamilies: [String]
    public var privacyTreatment: String
    public var renderedFromRealAppUI: Bool
    public var usesOnlyConsentedOrSyntheticMedia: Bool
    public var avoidsFearDeathOrShameMarketing: Bool
    public var avoidsMedicalOrDiagnosticClaims: Bool
    public var avoidsUnsupportedFeatureClaims: Bool

    public init(
        id: String,
        kind: AppStoreScreenshotSceneKind,
        title: String,
        captureRoute: String,
        heroCopy: String,
        functionalEvidence: String,
        deviceFamilies: [String] = ["iPhone 6.7-inch", "iPhone 6.5-inch"],
        privacyTreatment: String = "Use synthetic or explicitly consented memory content; mask faces, names, addresses, provider responses, and raw private media unless the user supplied review-safe demo assets.",
        renderedFromRealAppUI: Bool = true,
        usesOnlyConsentedOrSyntheticMedia: Bool = true,
        avoidsFearDeathOrShameMarketing: Bool = true,
        avoidsMedicalOrDiagnosticClaims: Bool = true,
        avoidsUnsupportedFeatureClaims: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.captureRoute = captureRoute
        self.heroCopy = heroCopy
        self.functionalEvidence = functionalEvidence
        self.deviceFamilies = deviceFamilies
        self.privacyTreatment = privacyTreatment
        self.renderedFromRealAppUI = renderedFromRealAppUI
        self.usesOnlyConsentedOrSyntheticMedia = usesOnlyConsentedOrSyntheticMedia
        self.avoidsFearDeathOrShameMarketing = avoidsFearDeathOrShameMarketing
        self.avoidsMedicalOrDiagnosticClaims = avoidsMedicalOrDiagnosticClaims
        self.avoidsUnsupportedFeatureClaims = avoidsUnsupportedFeatureClaims
    }

    public var isHonestScreenshotCreativeItem: Bool {
        id.hasPrefix("screenshot-creative-") &&
        !title.isEmpty &&
        !captureRoute.isEmpty &&
        !heroCopy.isEmpty &&
        !functionalEvidence.isEmpty &&
        deviceFamilies.count >= 2 &&
        privacyTreatment.localizedCaseInsensitiveContains("synthetic") &&
        privacyTreatment.localizedCaseInsensitiveContains("mask") &&
        renderedFromRealAppUI &&
        usesOnlyConsentedOrSyntheticMedia &&
        avoidsFearDeathOrShameMarketing &&
        avoidsMedicalOrDiagnosticClaims &&
        avoidsUnsupportedFeatureClaims
    }
}

public struct AppStoreScreenshotAppPreviewCreativePacket: Codable, Equatable, Sendable {
    public var sourceReferences: [String]
    public var screenshotMinimumPerLocalization: Int
    public var screenshotMaximumPerDeviceLocalization: Int
    public var appPreviewMaximumPerDeviceLocalization: Int
    public var targetDeviceFamilies: [String]
    public var screenshotFormats: [String]
    public var appPreviewFormats: [String]
    public var items: [AppStoreScreenshotCreativeItem]
    public var usesHighestResolutionScreenshots: Bool
    public var includesPosterFramePlan: Bool
    public var renderedAssetsGenerated: Bool
    public var localizedAssetsReviewed: Bool
    public var uploadedInAppStoreConnect: Bool
    public var legalReviewCompleted: Bool
    public var releaseReviewCompleted: Bool

    public init(
        sourceReferences: [String] = [
            "App Store Connect Help: Upload app previews and screenshots",
            "App Store Connect Help: Screenshot specifications",
            "App Store Connect Help: App preview specifications",
            "App Review Guidelines 2.3 Accurate Metadata"
        ],
        screenshotMinimumPerLocalization: Int = 1,
        screenshotMaximumPerDeviceLocalization: Int = 10,
        appPreviewMaximumPerDeviceLocalization: Int = 3,
        targetDeviceFamilies: [String] = ["iPhone 6.7-inch", "iPhone 6.5-inch"],
        screenshotFormats: [String] = ["PNG", "JPEG"],
        appPreviewFormats: [String] = ["M4V", "MOV", "MP4"],
        items: [AppStoreScreenshotCreativeItem] = AppStoreScreenshotAppPreviewCreativePacket.defaultItems,
        usesHighestResolutionScreenshots: Bool = true,
        includesPosterFramePlan: Bool = true,
        renderedAssetsGenerated: Bool = false,
        localizedAssetsReviewed: Bool = false,
        uploadedInAppStoreConnect: Bool = false,
        legalReviewCompleted: Bool = false,
        releaseReviewCompleted: Bool = false
    ) {
        self.sourceReferences = sourceReferences
        self.screenshotMinimumPerLocalization = screenshotMinimumPerLocalization
        self.screenshotMaximumPerDeviceLocalization = screenshotMaximumPerDeviceLocalization
        self.appPreviewMaximumPerDeviceLocalization = appPreviewMaximumPerDeviceLocalization
        self.targetDeviceFamilies = targetDeviceFamilies
        self.screenshotFormats = screenshotFormats
        self.appPreviewFormats = appPreviewFormats
        self.items = items
        self.usesHighestResolutionScreenshots = usesHighestResolutionScreenshots
        self.includesPosterFramePlan = includesPosterFramePlan
        self.renderedAssetsGenerated = renderedAssetsGenerated
        self.localizedAssetsReviewed = localizedAssetsReviewed
        self.uploadedInAppStoreConnect = uploadedInAppStoreConnect
        self.legalReviewCompleted = legalReviewCompleted
        self.releaseReviewCompleted = releaseReviewCompleted
    }

    public static let defaultItems: [AppStoreScreenshotCreativeItem] = [
        .init(id: "screenshot-creative-memory-camera", kind: .memoryCamera, title: "Memory Camera", captureRoute: "Home → Memory Camera → choose photo/video", heroCopy: "先留住一个影像锚点，再补一句话", functionalEvidence: "Shows media-first capture as the primary mobile path, with text optional and no full-library scan."),
        .init(id: "screenshot-creative-today-slice", kind: .todaySlice, title: "Today Slice", captureRoute: "Slice → latest memory card", heroCopy: "把今天变成以后能讲的一刻", functionalEvidence: "Shows one natural sentence, difference evidence, media/source trace, and editable tags."),
        .init(id: "screenshot-creative-weekly-chapter", kind: .weeklyChapter, title: "Weekly Chapter", captureRoute: "Weekly Chapter → claim three moments", heroCopy: "每周认领三个瞬间，编成能讲的故事", functionalEvidence: "Shows user-claimed moments before AI faithful editing and source trace."),
        .init(id: "screenshot-creative-life-meadow", kind: .lifeMeadow, title: "Life Meadow", captureRoute: "Meadow → week/month/year/life zoom", heroCopy: "从今天，到十年后的人生旷野", functionalEvidence: "Shows semantic zoom where dense moments become flowers and quiet periods remain grass, without shaming empty weeks."),
        .init(id: "screenshot-creative-media-wall", kind: .mediaWall, title: "Media Wall", captureRoute: "Media Wall → photo/video/link filters", heroCopy: "照片和视频，是回忆的路标", functionalEvidence: "Shows image/video/link anchors organized into a recall timeline without contacts, GPS, or face recognition."),
        .init(id: "screenshot-creative-account-rights", kind: .accountRights, title: "Account Rights", captureRoute: "Account Rights → export/delete/subscription/AI boundaries", heroCopy: "记忆属于你，导出和删除不被订阅扣留", functionalEvidence: "Shows export, deletion, subscription, AI, and privacy boundaries for App Review and user trust.")
    ]

    public var requiredSceneKindsCovered: Bool {
        Set(AppStoreScreenshotSceneKind.allCases).isSubset(of: Set(items.map(\.kind)))
    }

    public var satisfiesAppleAssetCountBoundaries: Bool {
        screenshotMinimumPerLocalization >= 1 &&
        screenshotMaximumPerDeviceLocalization == 10 &&
        appPreviewMaximumPerDeviceLocalization == 3 &&
        items.count >= screenshotMinimumPerLocalization &&
        items.count <= screenshotMaximumPerDeviceLocalization
    }

    public var satisfiesFormatAndDeviceCoverage: Bool {
        targetDeviceFamilies.count >= 2 &&
        targetDeviceFamilies.allSatisfy { $0.localizedCaseInsensitiveContains("iphone") } &&
        screenshotFormats.contains("PNG") &&
        screenshotFormats.contains("JPEG") &&
        appPreviewFormats.contains("MP4") &&
        usesHighestResolutionScreenshots &&
        includesPosterFramePlan
    }

    public var preservesTSDProductSoul: Bool {
        let combined = items.map { "\($0.title) \($0.heroCopy) \($0.functionalEvidence)" }.joined(separator: " ")
        return combined.localizedCaseInsensitiveContains("media-first") &&
        combined.localizedCaseInsensitiveContains("weekly") &&
        combined.localizedCaseInsensitiveContains("Life Meadow") &&
        combined.localizedCaseInsensitiveContains("export") &&
        combined.localizedCaseInsensitiveContains("without") &&
        combined.localizedCaseInsensitiveContains("full-library scan")
    }

    public var avoidsFearDeathOrShameMarketing: Bool {
        let combined = items.map { "\($0.title) \($0.heroCopy) \($0.functionalEvidence)" }.joined(separator: " ").lowercased()
        let forbidden = ["death", "die before", "running out of life", "shame", "guilt", "死亡", "时日无多", "羞耻", "内疚"]
        return forbidden.allSatisfy { !combined.contains($0) } &&
        items.allSatisfy(\.avoidsFearDeathOrShameMarketing)
    }

    public var protectsPrivateMemoryContent: Bool {
        items.allSatisfy(\.usesOnlyConsentedOrSyntheticMedia) &&
        items.allSatisfy { $0.privacyTreatment.localizedCaseInsensitiveContains("mask") } &&
        items.allSatisfy { !$0.functionalEvidence.localizedCaseInsensitiveContains("contacts") || $0.functionalEvidence.localizedCaseInsensitiveContains("without contacts") }
    }

    public var canSatisfyCreativePacketShapeGate: Bool {
        sourceReferences.count >= 4 &&
        requiredSceneKindsCovered &&
        satisfiesAppleAssetCountBoundaries &&
        satisfiesFormatAndDeviceCoverage &&
        items.allSatisfy(\.isHonestScreenshotCreativeItem) &&
        preservesTSDProductSoul &&
        avoidsFearDeathOrShameMarketing &&
        protectsPrivateMemoryContent
    }

    public var canSatisfyFinalScreenshotAppPreviewGate: Bool {
        canSatisfyCreativePacketShapeGate &&
        renderedAssetsGenerated &&
        localizedAssetsReviewed &&
        uploadedInAppStoreConnect &&
        legalReviewCompleted &&
        releaseReviewCompleted
    }
}

public enum PrivacyManifestRequiredReasonAPIKind: String, Codable, Equatable, CaseIterable, Sendable {
    case fileTimestamp = "NSPrivacyAccessedAPICategoryFileTimestamp"
    case systemBootTime = "NSPrivacyAccessedAPICategorySystemBootTime"
    case diskSpace = "NSPrivacyAccessedAPICategoryDiskSpace"
    case activeKeyboard = "NSPrivacyAccessedAPICategoryActiveKeyboards"
    case userDefaults = "NSPrivacyAccessedAPICategoryUserDefaults"
}

public struct PrivacyManifestRequiredReasonAPIAuditItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: PrivacyManifestRequiredReasonAPIKind
    public var title: String
    public var usedByShippingTarget: Bool
    public var observedSymbols: [String]
    public var approvedReasonIDs: [String]
    public var evidence: String
    public var notes: String

    public init(
        id: String,
        kind: PrivacyManifestRequiredReasonAPIKind,
        title: String,
        usedByShippingTarget: Bool,
        observedSymbols: [String],
        approvedReasonIDs: [String] = [],
        evidence: String,
        notes: String
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.usedByShippingTarget = usedByShippingTarget
        self.observedSymbols = observedSymbols
        self.approvedReasonIDs = approvedReasonIDs
        self.evidence = evidence
        self.notes = notes
    }

    public var isKnownRequiredReasonCategory: Bool {
        PrivacyManifestRequiredReasonAPIKind.allCases.contains(kind)
    }

    public var hasApprovedReasonsWhenUsed: Bool {
        !usedByShippingTarget || !approvedReasonIDs.isEmpty
    }

    public var isHonestAuditItem: Bool {
        id.hasPrefix("privacy-manifest-required-reason-") &&
        !title.isEmpty &&
        !observedSymbols.isEmpty &&
        !evidence.isEmpty &&
        !notes.isEmpty &&
        isKnownRequiredReasonCategory &&
        hasApprovedReasonsWhenUsed
    }
}

public struct PrivacyManifestRequiredReasonAPIAuditPacket: Codable, Equatable, Sendable {
    public var sourceReferences: [String]
    public var privacyManifestPath: String
    public var manifestTrackingDisabled: Bool
    public var manifestHasNoTrackingDomains: Bool
    public var manifestHasNoCollectedDataTypes: Bool
    public var manifestHasNoAccessedAPITypes: Bool
    public var requiredReasonItems: [PrivacyManifestRequiredReasonAPIAuditItem]
    public var dependencyManifestReviewRequired: Bool
    public var dependencyManifestReviewCompleted: Bool
    public var xcodePrivacyReportRequired: Bool
    public var xcodePrivacyReportGenerated: Bool
    public var completedInFullXcodeArchive: Bool
    public var releaseReviewCompleted: Bool

    public init(
        sourceReferences: [String] = [
            "Apple Developer Documentation: Privacy manifest files",
            "Apple Developer Documentation: Describing use of required reason API",
            "Apple Technote TN3183: Adding required reason API entries to your privacy manifest",
            "WWDC23: Get started with privacy manifests",
            "TSD local scan: shipping app/library sources versus checks-only target"
        ],
        privacyManifestPath: String = XcodeProjectContract.privacyManifestPath,
        manifestTrackingDisabled: Bool = true,
        manifestHasNoTrackingDomains: Bool = true,
        manifestHasNoCollectedDataTypes: Bool = true,
        manifestHasNoAccessedAPITypes: Bool = true,
        requiredReasonItems: [PrivacyManifestRequiredReasonAPIAuditItem] = PrivacyManifestRequiredReasonAPIAuditPacket.defaultItems,
        dependencyManifestReviewRequired: Bool = true,
        dependencyManifestReviewCompleted: Bool = false,
        xcodePrivacyReportRequired: Bool = true,
        xcodePrivacyReportGenerated: Bool = false,
        completedInFullXcodeArchive: Bool = false,
        releaseReviewCompleted: Bool = false
    ) {
        self.sourceReferences = sourceReferences
        self.privacyManifestPath = privacyManifestPath
        self.manifestTrackingDisabled = manifestTrackingDisabled
        self.manifestHasNoTrackingDomains = manifestHasNoTrackingDomains
        self.manifestHasNoCollectedDataTypes = manifestHasNoCollectedDataTypes
        self.manifestHasNoAccessedAPITypes = manifestHasNoAccessedAPITypes
        self.requiredReasonItems = requiredReasonItems
        self.dependencyManifestReviewRequired = dependencyManifestReviewRequired
        self.dependencyManifestReviewCompleted = dependencyManifestReviewCompleted
        self.xcodePrivacyReportRequired = xcodePrivacyReportRequired
        self.xcodePrivacyReportGenerated = xcodePrivacyReportGenerated
        self.completedInFullXcodeArchive = completedInFullXcodeArchive
        self.releaseReviewCompleted = releaseReviewCompleted
    }

    public static let defaultItems: [PrivacyManifestRequiredReasonAPIAuditItem] = [
        .init(
            id: "privacy-manifest-required-reason-file-timestamp",
            kind: .fileTimestamp,
            title: "File timestamp APIs",
            usedByShippingTarget: false,
            observedSymbols: ["No production use of file creation/modification timestamp APIs found in Sources/TimeSlowDownKit or TimeSlowDownApp."],
            evidence: "Checks target reads local project files for verification only; the shipping app path writes user-requested export bytes without inspecting file timestamps.",
            notes: "If production code later reads file timestamps, add the Apple-approved reason IDs to PrivacyInfo.xcprivacy and this packet."
        ),
        .init(
            id: "privacy-manifest-required-reason-system-boot-time",
            kind: .systemBootTime,
            title: "System boot time APIs",
            usedByShippingTarget: false,
            observedSymbols: ["No production use of ProcessInfo.systemUptime, mach_absolute_time, or boot-time APIs found."],
            evidence: "ProcessInfo.environment appears only in TimeSlowDownNativeChecks for optional backend probes and is not part of the app target.",
            notes: "If runtime performance or anti-abuse code later reads uptime, it must be justified with Apple-approved reason IDs."
        ),
        .init(
            id: "privacy-manifest-required-reason-disk-space",
            kind: .diskSpace,
            title: "Disk space APIs",
            usedByShippingTarget: false,
            observedSymbols: ["No production use of volumeAvailableCapacity, volumeTotalCapacity, statfs, or disk-capacity APIs found."],
            evidence: "Current export code builds an in-memory ZIP package and does not read device capacity for fingerprinting-prone signals.",
            notes: "If media vault storage management later reads disk capacity, use only app-storage reasons and update the manifest."
        ),
        .init(
            id: "privacy-manifest-required-reason-active-keyboards",
            kind: .activeKeyboard,
            title: "Active keyboard APIs",
            usedByShippingTarget: false,
            observedSymbols: ["No production use of activeInputModes or keyboard inventory APIs found."],
            evidence: "TSD text capture uses ordinary SwiftUI input and does not inspect installed or active keyboards.",
            notes: "Keyboard inventory is not needed for memory capture; keep this absent unless a reviewed accessibility feature requires it."
        ),
        .init(
            id: "privacy-manifest-required-reason-user-defaults",
            kind: .userDefaults,
            title: "UserDefaults APIs",
            usedByShippingTarget: false,
            observedSymbols: ["No production use of UserDefaults found in Sources/TimeSlowDownKit or TimeSlowDownApp."],
            evidence: "Current PoC state is in-memory/native-shell contract state; persisted user settings have not been added to the shipping target.",
            notes: "If onboarding/preferences later use UserDefaults, add the app-specific storage reason ID and keep it scoped to TSD data."
        )
    ]

    public var requiredKindsCovered: Bool {
        let covered = Set(requiredReasonItems.map(\.kind))
        return Set(PrivacyManifestRequiredReasonAPIKind.allCases).isSubset(of: covered)
    }

    public var shippingTargetUsesRequiredReasonAPIs: Bool {
        requiredReasonItems.contains(where: \.usedByShippingTarget)
    }

    public var requiredAPIUsagesHaveApprovedReasons: Bool {
        requiredReasonItems.allSatisfy(\.hasApprovedReasonsWhenUsed)
    }

    public var canKeepAccessedAPITypesEmpty: Bool {
        !shippingTargetUsesRequiredReasonAPIs &&
        manifestTrackingDisabled &&
        manifestHasNoTrackingDomains &&
        manifestHasNoCollectedDataTypes &&
        manifestHasNoAccessedAPITypes
    }

    public var canSatisfyRequiredReasonShapeGate: Bool {
        sourceReferences.count >= 5 &&
        privacyManifestPath == XcodeProjectContract.privacyManifestPath &&
        manifestTrackingDisabled &&
        manifestHasNoTrackingDomains &&
        manifestHasNoCollectedDataTypes &&
        requiredKindsCovered &&
        requiredReasonItems.allSatisfy(\.isHonestAuditItem) &&
        requiredAPIUsagesHaveApprovedReasons &&
        (canKeepAccessedAPITypesEmpty || !manifestHasNoAccessedAPITypes) &&
        dependencyManifestReviewRequired &&
        xcodePrivacyReportRequired
    }

    public var canSatisfyFinalPrivacyManifestGate: Bool {
        canSatisfyRequiredReasonShapeGate &&
        completedInFullXcodeArchive &&
        xcodePrivacyReportGenerated &&
        (!dependencyManifestReviewRequired || dependencyManifestReviewCompleted) &&
        releaseReviewCompleted
    }
}

public enum EncryptionExportComplianceUseKind: String, Codable, Equatable, CaseIterable, Sendable {
    case cryptoKitAESGCM = "cryptokit-aes-gcm"
    case secureEnclaveKeyAgreement = "secure-enclave-key-agreement"
    case keychainProtectedMetadata = "keychain-protected-metadata"
    case deviceKeyEncryptedMediaVault = "device-key-encrypted-media-vault"
    case tlsBackendTransport = "tls-backend-transport"
}

public struct EncryptionExportComplianceReviewItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: EncryptionExportComplianceUseKind
    public var title: String
    public var usesEncryption: Bool
    public var evidence: String
    public var appStoreConnectAnswerRequired: Bool
    public var legalReviewRequired: Bool
    public var finalClassificationCompleted: Bool
    public var notes: String

    public init(
        id: String,
        kind: EncryptionExportComplianceUseKind,
        title: String,
        usesEncryption: Bool = true,
        evidence: String,
        appStoreConnectAnswerRequired: Bool = true,
        legalReviewRequired: Bool = true,
        finalClassificationCompleted: Bool = false,
        notes: String
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.usesEncryption = usesEncryption
        self.evidence = evidence
        self.appStoreConnectAnswerRequired = appStoreConnectAnswerRequired
        self.legalReviewRequired = legalReviewRequired
        self.finalClassificationCompleted = finalClassificationCompleted
        self.notes = notes
    }

    public var isHonestEncryptionItem: Bool {
        id.hasPrefix("encryption-export-compliance-") &&
        !title.isEmpty &&
        !evidence.isEmpty &&
        !notes.isEmpty &&
        usesEncryption &&
        appStoreConnectAnswerRequired &&
        legalReviewRequired
    }
}

public struct EncryptionExportComplianceReviewPacket: Codable, Equatable, Sendable {
    public var sourceReferences: [String]
    public var infoPlistKey: String
    public var infoPlistDeclaresNonExemptEncryption: Bool
    public var productUsesEncryption: Bool
    public var usesAppleStandardCrypto: Bool
    public var usesCustomCryptography: Bool
    public var usesEndToEndEncryptedUserContent: Bool
    public var items: [EncryptionExportComplianceReviewItem]
    public var appStoreConnectExportComplianceAnswered: Bool
    public var legalReviewCompleted: Bool
    public var exportDocumentationAttachedIfRequired: Bool
    public var releaseReviewCompleted: Bool

    public init(
        sourceReferences: [String] = [
            "Apple Developer: Complying with Encryption Export Regulations",
            "App Store Connect Help: Overview of export compliance",
            "Info.plist: ITSAppUsesNonExemptEncryption",
            "TSD native trust layer: CryptoKit AES.GCM media vault envelope",
            "TSD native trust layer: Secure Enclave device-key contract"
        ],
        infoPlistKey: String = "ITSAppUsesNonExemptEncryption",
        infoPlistDeclaresNonExemptEncryption: Bool = true,
        productUsesEncryption: Bool = true,
        usesAppleStandardCrypto: Bool = true,
        usesCustomCryptography: Bool = false,
        usesEndToEndEncryptedUserContent: Bool = true,
        items: [EncryptionExportComplianceReviewItem] = EncryptionExportComplianceReviewPacket.defaultItems,
        appStoreConnectExportComplianceAnswered: Bool = false,
        legalReviewCompleted: Bool = false,
        exportDocumentationAttachedIfRequired: Bool = false,
        releaseReviewCompleted: Bool = false
    ) {
        self.sourceReferences = sourceReferences
        self.infoPlistKey = infoPlistKey
        self.infoPlistDeclaresNonExemptEncryption = infoPlistDeclaresNonExemptEncryption
        self.productUsesEncryption = productUsesEncryption
        self.usesAppleStandardCrypto = usesAppleStandardCrypto
        self.usesCustomCryptography = usesCustomCryptography
        self.usesEndToEndEncryptedUserContent = usesEndToEndEncryptedUserContent
        self.items = items
        self.appStoreConnectExportComplianceAnswered = appStoreConnectExportComplianceAnswered
        self.legalReviewCompleted = legalReviewCompleted
        self.exportDocumentationAttachedIfRequired = exportDocumentationAttachedIfRequired
        self.releaseReviewCompleted = releaseReviewCompleted
    }

    public static let defaultItems: [EncryptionExportComplianceReviewItem] = [
        .init(
            id: "encryption-export-compliance-cryptokit-aes-gcm",
            kind: .cryptoKitAESGCM,
            title: "CryptoKit AES.GCM media vault envelope",
            evidence: "v52 defines CryptoKit.AES.GCM content encryption, HKDF-SHA256 per-record derivation, random nonce, AAD, and no plaintext/CEK persistence.",
            notes: "Do not hide this as no-encryption; App Store Connect export compliance answers must account for the media vault path."
        ),
        .init(
            id: "encryption-export-compliance-secure-enclave-key-agreement",
            kind: .secureEnclaveKeyAgreement,
            title: "Secure Enclave P256 key agreement",
            evidence: "v53 defines non-extractable SecureEnclave.P256.KeyAgreement.PrivateKey references for device-local media vault keys.",
            notes: "Final classification must be reviewed with the signed-device implementation, not inferred from the SwiftPM host."
        ),
        .init(
            id: "encryption-export-compliance-keychain-metadata",
            kind: .keychainProtectedMetadata,
            title: "Keychain-protected key metadata",
            evidence: "v41/v53 keep device-key metadata in Keychain-shaped records with this-device-only and user-presence boundaries.",
            notes: "Keychain storage is part of the encryption/security posture and should remain visible to release review."
        ),
        .init(
            id: "encryption-export-compliance-media-vault",
            kind: .deviceKeyEncryptedMediaVault,
            title: "Device-key encrypted media vault",
            evidence: "v51/v52 seal user-selected photo/video payloads into encrypted media vault records before consented export/delete.",
            notes: "This protects private memory media; it is a product trust feature and an export-compliance disclosure topic."
        ),
        .init(
            id: "encryption-export-compliance-tls-backend-transport",
            kind: .tlsBackendTransport,
            title: "HTTPS/TLS backend transport",
            evidence: "v57/v59/v63 require HTTPS TSD backend endpoints and server-side DeepSeek/deletion service boundaries.",
            notes: "Even transport-only encryption must be represented in App Store Connect export compliance answers if applicable."
        )
    ]

    public var requiredUseKindsCovered: Bool {
        let covered = Set(items.map(\.kind))
        return Set(EncryptionExportComplianceUseKind.allCases).isSubset(of: covered)
    }

    public var doesNotFalselyDenyEncryption: Bool {
        productUsesEncryption &&
        infoPlistDeclaresNonExemptEncryption &&
        items.contains(where: { $0.kind == .cryptoKitAESGCM && $0.usesEncryption }) &&
        items.contains(where: { $0.kind == .secureEnclaveKeyAgreement && $0.usesEncryption }) &&
        usesEndToEndEncryptedUserContent
    }

    public var canSatisfyEncryptionExportShapeGate: Bool {
        sourceReferences.count >= 5 &&
        infoPlistKey == "ITSAppUsesNonExemptEncryption" &&
        doesNotFalselyDenyEncryption &&
        usesAppleStandardCrypto &&
        !usesCustomCryptography &&
        requiredUseKindsCovered &&
        items.allSatisfy(\.isHonestEncryptionItem)
    }

    public var canSatisfyFinalEncryptionExportComplianceGate: Bool {
        canSatisfyEncryptionExportShapeGate &&
        appStoreConnectExportComplianceAnswered &&
        legalReviewCompleted &&
        exportDocumentationAttachedIfRequired &&
        releaseReviewCompleted &&
        items.allSatisfy(\.finalClassificationCompleted)
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

    public init(buildNumber: String = "76", rows: [AppStoreSubmissionGateRow]) {
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
        metadataLegalReviewPacket: AppStoreMetadataLegalReviewPacket = AppStoreMetadataLegalReviewPacket(),
        screenshotAppPreviewCreativePacket: AppStoreScreenshotAppPreviewCreativePacket = AppStoreScreenshotAppPreviewCreativePacket(),
        privacyManifestRequiredReasonAuditPacket: PrivacyManifestRequiredReasonAPIAuditPacket = PrivacyManifestRequiredReasonAPIAuditPacket(),
        encryptionExportComplianceReviewPacket: EncryptionExportComplianceReviewPacket = EncryptionExportComplianceReviewPacket(),
        archiveSigningReceipt: ArchiveSigningValidationReceipt? = nil,
        backendReleaseEvidence: TSDBackendReleaseEvidence = TSDBackendReleaseEvidence(),
        signedDeviceReceipt: SignedDeviceKeychainValidationReceipt? = nil,
        signedDeviceMediaReceipt: SignedDeviceMediaValidationReceipt? = nil,
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
        let metadataLegalShapeReady = metadataLegalReviewPacket.canSatisfyMetadataLegalShapeGate
        let screenshotAppPreviewCreativeShapeReady = screenshotAppPreviewCreativePacket.canSatisfyCreativePacketShapeGate
        let screenshotAppPreviewFinalReady = screenshotAppPreviewCreativePacket.canSatisfyFinalScreenshotAppPreviewGate
        let privacyManifestRequiredReasonShapeReady = privacyManifestRequiredReasonAuditPacket.canSatisfyRequiredReasonShapeGate
        let privacyManifestRequiredReasonFinalReady = privacyManifestRequiredReasonAuditPacket.canSatisfyFinalPrivacyManifestGate
        let encryptionExportShapeReady = encryptionExportComplianceReviewPacket.canSatisfyEncryptionExportShapeGate
        let encryptionExportFinalReady = encryptionExportComplianceReviewPacket.canSatisfyFinalEncryptionExportComplianceGate
        let archiveSigningPacketShapeReady = archiveSigningReceipt?.isHonestPendingReceipt == true || archiveSigningReceipt?.isProductionArchiveUploadReceipt == true
        let mediaValidationPacketShapeReady = signedDeviceMediaReceipt?.isHonestPendingReceipt == true || signedDeviceMediaReceipt?.isProductionPassReceipt == true
        let nativeContractCovered = nativeRows.map(\.id).contains("photos-picker") &&
        nativeRows.map(\.id).contains("keychain-e2ee") &&
        nativeRows.map(\.id).contains("deepseek-gateway")
        let submissionContractCovered = submissionRows.map(\.id).contains("privacy-questionnaire") &&
        submissionRows.map(\.id).contains("privacy-questionnaire-packet") &&
        submissionRows.map(\.id).contains("age-rating") &&
        submissionRows.map(\.id).contains("age-rating-review-packet") &&
        submissionRows.map(\.id).contains("support-privacy-urls") &&
        submissionRows.map(\.id).contains("metadata-legal-review-packet") &&
        submissionRows.map(\.id).contains("screenshot-app-preview-creative-packet") &&
        submissionRows.map(\.id).contains("encryption-export-compliance-packet")
        let launchContractsCovered = launchRows.count == 4 && launchRows.allSatisfy { $0.status == .poc }
        let productionContractsCovered = productionRows.count >= 7 && productionRows.allSatisfy { $0.status == .poc }
        let signedDevicePassed = signedDeviceReceipt?.isProductionPassReceipt == true
        let photosImportPassed = photosImportSignedDevicePassed || signedDeviceMediaReceipt?.isProductionPhotosImportPassReceipt == true
        let filesExportPassed = filesExportSignedDevicePassed || signedDeviceMediaReceipt?.isProductionFilesExportPassReceipt == true
        let aiProviderPassed = deepSeekReceipt?.canBeUsedForAppStoreGate == true
        let deletionCompleted = deletionReceipt?.canSatisfyAppStoreDeletionGate == true
        let backendDeploymentPassed = backendReleaseEvidence.canSatisfyBackendDeploymentGate
        let fullXcodePassed = hasFullXcode || archiveSigningReceipt?.canSatisfyFullXcodeGate == true
        let appleDeveloperTeamPassed = teamIDPresent || archiveSigningReceipt?.canSatisfyAppleDeveloperTeamGate == true
        let archivePassed = (hasFullXcode && archiveCreated) || archiveSigningReceipt?.canSatisfyArchiveGate == true
        let testFlightUploadPassed = testFlightUploadReceiptPresent || archiveSigningReceipt?.canSatisfyTestFlightUploadGate == true

        return AppStoreSubmissionGate(rows: [
            .init(
                id: "full-xcode",
                title: "Full Xcode toolchain",
                status: fullXcodePassed ? .passed : .blocked,
                evidence: fullXcodePassed ? "Full Xcode availability is proven for archive/signing." : "Current SwiftPM host can build contracts but cannot archive/sign the iOS app.",
                unblockAction: "Install/select full Xcode and rerun archive checks."
            ),
            .init(
                id: "apple-developer-team",
                title: "Apple Developer Team ID",
                status: appleDeveloperTeamPassed ? .passed : .blocked,
                evidence: appleDeveloperTeamPassed ? "Real Apple Developer Team evidence is present." : "Team ID is intentionally blank; fake signing is forbidden.",
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
                status: archivePassed ? .passed : .blocked,
                evidence: archivePassed ? "Release archive receipt is present." : signingPlan.archiveCommandWhenXcodeAvailable,
                unblockAction: "Create a Release archive with full Xcode."
            ),
            .init(
                id: "testflight-upload",
                title: "TestFlight upload receipt",
                status: testFlightUploadPassed ? .passed : .blocked,
                evidence: testFlightUploadPassed ? "Transporter/App Store Connect upload receipt exists." : "No Transporter/App Store Connect upload receipt exists yet.",
                unblockAction: "Upload the signed archive to App Store Connect/TestFlight and capture the receipt."
            ),
            .init(
                id: "archive-signing-readiness-packet",
                title: "Archive/signing readiness packet",
                status: archiveSigningPacketShapeReady ? .passed : .blocked,
                requiredForTestFlight: false,
                evidence: archiveSigningPacketShapeReady ? "v67 defines honest pending/pass receipt shape for full Xcode, Team ID, Release archive, Transporter upload, and App Store Connect processing without exposing signing material or Apple session tokens." : "Archive/signing readiness packet is missing or malformed.",
                unblockAction: "Create an honest pending packet here, then replace it only with a real production archive/upload receipt from full Xcode and App Store Connect."
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
                id: "app-store-connect-metadata",
                title: "App Store Connect metadata and legal review",
                status: metadataLegalReviewPacket.canSatisfyFinalMetadataLegalGate ? .passed : .blocked,
                requiredForTestFlight: false,
                evidence: metadataLegalReviewPacket.canSatisfyFinalMetadataLegalGate ? "Product page, screenshots/app preview, review notes, subscription copy, support/privacy/data-rights URLs, AI disclosure, App Store Connect entry, legal review, and release review are complete." : "Metadata/legal packet exists only as a draft until App Store Connect entry plus legal/release review are complete.",
                unblockAction: "Enter final metadata in App Store Connect, attach reviewed screenshots/app preview, approve support/privacy/data-rights URLs, review subscription and AI disclosures, then capture legal/release approval."
            ),
            .init(
                id: "metadata-legal-review-packet",
                title: "Metadata/legal review packet",
                status: metadataLegalShapeReady ? .passed : .blocked,
                requiredForTestFlight: false,
                evidence: metadataLegalShapeReady ? "v68 maps product page positioning, screenshots/app preview, review notes, support/privacy/data-rights URLs, subscription wording, AI disclosure, and legal/release checklist without death/fear/shame marketing or subscription-hostage claims." : "Metadata/legal review packet is missing or malformed.",
                unblockAction: "Repair the machine-checkable metadata/legal review packet before App Store Connect and legal handoff."
            ),
            .init(
                id: "screenshots-app-preview-assets",
                title: "Rendered screenshots and App Preview assets",
                status: screenshotAppPreviewFinalReady ? .passed : .blocked,
                requiredForTestFlight: false,
                evidence: screenshotAppPreviewFinalReady ? "Rendered screenshot/App Preview assets, poster frame, localization review, App Store Connect upload, legal review, and release review are complete." : "Screenshot/App Preview creative packet exists only as a release plan until final rendered assets are generated, reviewed, localized, uploaded, and approved.",
                unblockAction: "Render final screenshots/App Preview from real app UI, mask private memory content, review localizations, upload in App Store Connect, and capture legal/release approval."
            ),
            .init(
                id: "screenshot-app-preview-creative-packet",
                title: "Screenshot/App Preview creative packet",
                status: screenshotAppPreviewCreativeShapeReady ? .passed : .blocked,
                requiredForTestFlight: false,
                evidence: screenshotAppPreviewCreativeShapeReady ? "v71 maps Memory Camera, today slice, weekly chapter, life meadow, media wall, and Account Rights to Apple screenshot/App Preview constraints with real-UI, synthetic/consented media, privacy masking, and no death/fear/shame marketing." : "Screenshot/App Preview creative packet is missing, misleading, under-specified, or privacy-unsafe.",
                unblockAction: "Repair the screenshot/App Preview packet before rendering final App Store assets."
            ),
            .init(
                id: "encryption-export-compliance",
                title: "Encryption export compliance final review",
                status: encryptionExportFinalReady ? .passed : .blocked,
                requiredForTestFlight: false,
                evidence: encryptionExportFinalReady ? "App Store Connect export-compliance answers, legal classification, required documentation, and release review are complete." : "Encryption export compliance remains blocked until App Store Connect answers, legal classification, required documentation, and release review are complete.",
                unblockAction: "Answer App Store Connect export-compliance questions for CryptoKit, Secure Enclave, Keychain, media vault, and HTTPS transport; attach required documentation if legal review requires it."
            ),
            .init(
                id: "encryption-export-compliance-packet",
                title: "Encryption export compliance review packet",
                status: encryptionExportShapeReady ? .passed : .blocked,
                requiredForTestFlight: false,
                evidence: encryptionExportShapeReady ? "v70 conservatively declares encryption use, maps CryptoKit AES.GCM, Secure Enclave, Keychain metadata, encrypted media vault, and HTTPS transport without falsely claiming no encryption or final legal classification." : "Encryption export compliance review packet is missing or malformed.",
                unblockAction: "Repair the machine-checkable encryption export-compliance packet before App Store Connect and legal handoff."
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
                id: "privacy-manifest-required-reason-api",
                title: "Privacy Manifest required reason API final review",
                status: privacyManifestRequiredReasonFinalReady ? .passed : .blocked,
                requiredForTestFlight: false,
                evidence: privacyManifestRequiredReasonFinalReady ? "Full Xcode archive privacy report, dependency manifests, required reason API audit, and release review are complete." : "Privacy manifest required reason API audit exists only as a local packet until full-Xcode privacy report, dependency manifest review, and release review are complete.",
                unblockAction: "Generate the Xcode privacy report from the archive, review all app and dependency manifests, update PrivacyInfo.xcprivacy for any required reason API use, and capture release approval."
            ),
            .init(
                id: "privacy-manifest-required-reason-audit-packet",
                title: "Privacy Manifest required reason API audit packet",
                status: privacyManifestRequiredReasonShapeReady ? .passed : .blocked,
                requiredForTestFlight: false,
                evidence: privacyManifestRequiredReasonShapeReady ? "v69 audits Apple required reason API categories, keeps the current no-tracking/no-collected-data/no-accessed-API manifest honest for the local shipping path, and names the remaining Xcode privacy report/dependency review gates." : "Privacy Manifest required reason API audit packet is missing or malformed.",
                unblockAction: "Repair the required reason API audit before Xcode archive and App Store Connect privacy handoff."
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
                id: "signed-device-media-validation-packet",
                title: "Signed-device media validation packet",
                status: mediaValidationPacketShapeReady ? .passed : .blocked,
                requiredForTestFlight: false,
                evidence: mediaValidationPacketShapeReady ? "v66 defines honest pending/pass receipt shape for limited-library Photos import and system Files/share export without storing raw media evidence." : "Signed-device media validation packet is missing or malformed.",
                unblockAction: "Create an honest pending packet here, then replace it only with a real physical-device pass receipt after signed PhotosPicker and Files export validation."
            ),
            .init(
                id: "signed-device-photos-import",
                title: "Signed-device Photos import pass",
                status: photosImportPassed ? .passed : .blocked,
                evidence: photosImportPassed ? "Limited-library photo/video import passed on signed device." : "Photos import is contract-tested only; signed-device PhotosPicker validation is missing.",
                unblockAction: "Validate limited-library photo/video import on a signed physical device."
            ),
            .init(
                id: "signed-device-files-export",
                title: "Signed-device Files export pass",
                status: filesExportPassed ? .passed : .blocked,
                evidence: filesExportPassed ? "Files/share export and ZIP re-open passed on signed device." : "ZIP/fileExporter path is contract-tested only; signed-device Files export validation is missing.",
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
