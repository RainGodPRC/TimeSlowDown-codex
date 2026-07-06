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
        buildNumber: String = "46",
        summary: String = "TimeSlowDown v46 tests the native Memory Camera shell, media-first slice capture, weekly chapter preview, App Store launch assets, Keychain record store adapter, Account Rights export UI state, SwiftUI fileExporter bridge, on-device export ZIP builder, deletion audit envelope, DeepSeek server gateway envelope, and privacy/export/delete/AI trust boundaries.",
        testerRoute: [String] = [
            "Open Memory Camera and choose a photo or video as a memory anchor.",
            "Confirm the generated slice keeps media as the memory key, not a text attachment.",
            "Review the media wall and weekly chapter preview.",
            "Open account rights to verify export/delete remain available without subscription hostage.",
            "Open launch readiness to review App Store/TestFlight packet boundaries."
        ],
        knownLimitations: [String] = [
            "No production backend, account sync, or DeepSeek provider call is bundled in this build.",
            "No real Secure Enclave private-key generation, signed-device Keychain validation, or E2EE media vault is claimed yet.",
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
