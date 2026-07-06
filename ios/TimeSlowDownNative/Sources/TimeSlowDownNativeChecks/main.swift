import Foundation
import TimeSlowDownKit

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

let photo = MediaAnchor(kind: .image, label: "park.jpg", note: "孩子第一次自己爬上滑梯")
let slice = SliceFactory.quickMark(
    title: "他第一次自己爬上滑梯",
    tags: ["第一次", "家人"],
    media: photo
)
check(slice.hasMediaAnchor, "Quick Mark should keep media as a first-class memory anchor")
check(slice.media == photo, "Quick Mark should preserve the selected media anchor")
check(slice.tags.contains("照片"), "Image Quick Mark should add a photo tag")
check(slice.sources.contains("影像线索"), "Image Quick Mark should preserve media source provenance")
check(slice.body.contains("照片"), "Image-first slices should make text optional")

let original = SliceFactory.quickMark(title: "回家路上那段沉默", body: "被怼之后一路很烦。", tags: ["低落"])
let video = MediaAnchor(kind: .video, label: "walk-home.mov", note: "那天的路灯和风声")
let updated = SliceFactory.attach(video, to: original)
check(updated.hasMediaAnchor, "Existing slices should accept retroactive media anchors")
check(updated.media == video, "Retroactive attach should preserve the selected video anchor")
check(updated.tags.contains("视频"), "Video attach should add a video tag")
check(updated.sources.contains("切片补影像"), "Retroactive attach should preserve source provenance")

let moments = [
    SliceFactory.quickMark(title: "5 公里", tags: ["跑步"]),
    SliceFactory.quickMark(title: "和爸爸吃面", tags: ["家人"]),
    SliceFactory.quickMark(title: "会议后的回家路", tags: ["工作"]),
    SliceFactory.quickMark(title: "第四个候选", tags: ["普通"])
]
let chapter = SliceFactory.compileWeeklyChapter(title: "七月第一周", claimed: moments)
check(chapter.claimedSliceIDs.count == 3, "Weekly chapters should use at most three claimed moments")
check(chapter.narrative.contains("这一周没有消失"), "Weekly chapters should preserve the TSD story promise")
check(chapter.narrative.contains("5 公里"), "Weekly chapter should include claimed moments")
check(!chapter.narrative.contains("第四个候选"), "Weekly chapter should not include a fourth candidate")
check(chapter.sources.filter { $0.hasPrefix("slice:") }.count == 3, "Weekly chapter should keep slice provenance")

check(NativeHandoffLedger.rows.count == 8, "Native Handoff Ledger should keep the v32 eight-row contract")
check(SubmissionPacket.rows.count == 8, "Submission Packet should keep the v33 eight-row contract")
check(NativeHandoffLedger.rows.map(\.id).contains("photos-picker"), "Native Handoff should include PhotosPicker")
check(NativeHandoffLedger.rows.map(\.id).contains("keychain-e2ee"), "Native Handoff should include Keychain/E2EE")
check(SubmissionPacket.rows.map(\.id).contains("privacy-questionnaire"), "Submission Packet should include privacy questionnaire")
check(SubmissionPacket.rows.map(\.id).contains("subscription-copy"), "Submission Packet should include subscription wording")
check(NativeHandoffLedger.rows.first { $0.id == "swiftui-shell" }?.status == .poc, "SwiftUI shell should be promoted to PoC after v37 Xcode project skeleton")
check(NativeHandoffLedger.rows.first { $0.id == "keychain-e2ee" }?.status == .poc, "Keychain/E2EE should be promoted to PoC after v38 trust contracts")
check(NativeHandoffLedger.rows.first { $0.id == "media-package" }?.status == .poc, "Media package should be promoted to PoC after v38 export/delete contracts")
check(NativeHandoffLedger.rows.first { $0.id == "deepseek-gateway" }?.status == .poc, "DeepSeek gateway should be promoted to PoC after v38 AI task envelope")

let boundary = PrivacyBoundary()
check(boundary.isAppStoreSafeDefault, "Default privacy boundary should be App Store safe")
check(!boundary.allowsRawMediaUpload, "Default boundary should not upload raw media")
check(!boundary.allowsContactsAccess, "Default boundary should not read contacts")
check(!boundary.allowsGPSInference, "Default boundary should not infer GPS")
check(!boundary.allowsFaceRecognition, "Default boundary should not do face recognition")
check(!boundary.subscriptionCanBlockExport, "Subscription should not block memory export")

var shell = NativeShellStore.seeded()
let firstSnapshot = shell.snapshot
check(firstSnapshot.routeCount == NativeShellRoute.allCases.count, "Native shell should expose all expected routes")
check(firstSnapshot.sliceCount == 3, "Seeded native shell should include three demo slices")
check(firstSnapshot.mediaAnchorCount == 1, "Seeded native shell should include one media anchor")
check(firstSnapshot.nativeTodoCount == NativeHandoffLedger.rows.filter { $0.status == .todo }.count, "Native shell should summarize native todo rows")
check(firstSnapshot.submissionTodoCount == SubmissionPacket.rows.filter { $0.status == .todo }.count, "Native shell should summarize submission todo rows")
check(firstSnapshot.privacySafe, "Native shell should start with a safe privacy boundary")

let captured = shell.captureFromMemoryCamera(
    MediaAnchor(kind: .image, label: "native-memory-camera.jpg", note: "SwiftUI Memory Camera")
)
check(shell.selectedRoute == .slices, "Memory Camera capture should route users to slices")
check(shell.slices.first == captured, "Memory Camera capture should insert the new slice first")
check(shell.snapshot.sliceCount == 4, "Memory Camera capture should increase slice count")
check(shell.snapshot.mediaAnchorCount == 2, "Memory Camera capture should increase media anchor count")
check(shell.weeklyPreviewTitle() == "本周没有消失", "Native shell should expose weekly chapter preview")

let requiredRoutes = ["此刻", "切片", "旷野", "上架", "我的"]
check(NativeShellRoute.allCases.map(\.title) == requiredRoutes, "Native shell route titles should match the App Store shell")

let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let requiredXcodePaths = [
    XcodeProjectContract.projectPath,
    XcodeProjectContract.appSourcePath,
    XcodeProjectContract.launchScreenPath,
    XcodeProjectContract.assetCatalogPath,
    XcodeProjectContract.appIconPath,
    XcodeProjectContract.accentColorPath,
    XcodeProjectContract.infoPlistPath,
    XcodeProjectContract.privacyManifestPath,
    XcodeProjectContract.entitlementsPath
]
for path in requiredXcodePaths {
    let url = packageRoot.appendingPathComponent(path)
    check(FileManager.default.fileExists(atPath: url.path), "Expected Xcode project asset to exist: \(path)")
}

let projectText = try String(contentsOf: packageRoot.appendingPathComponent(XcodeProjectContract.projectPath), encoding: .utf8)
for token in XcodeProjectContract.requiredProjectTokens {
    check(projectText.contains(token), "Xcode project should contain required token: \(token)")
}

let appSourceText = try String(contentsOf: packageRoot.appendingPathComponent(XcodeProjectContract.appSourcePath), encoding: .utf8)
check(appSourceText.contains("@main"), "Xcode app source should declare @main")
check(appSourceText.contains("TSDNativeShellView"), "Xcode app source should mount TSDNativeShellView")

let infoPlistText = try String(contentsOf: packageRoot.appendingPathComponent(XcodeProjectContract.infoPlistPath), encoding: .utf8)
check(infoPlistText.contains("<string>38</string>"), "Info.plist should carry v38 build number")
check(infoPlistText.contains("UILaunchStoryboardName"), "Info.plist should point at LaunchScreen")

let fixedDate = Date(timeIntervalSince1970: 1_788_249_600)
let deviceKey = KeychainVaultStub.bootstrapDeviceKey(
    accountID: "guest-pass",
    deviceName: "Geralt iPhone",
    createdAt: fixedDate
)
check(deviceKey.storageClass == "keychain-this-device-only", "Device key should target a Keychain-only storage class")
check(!deviceKey.privateKeyExtractable, "Device key contract should forbid private-key extraction")
check(!deviceKey.secretMaterialPersistedInRepo, "Device key stub should never persist secret material in repo")

let envelope = E2EEEnvelope.sealMetadataOnly(slice, with: deviceKey)
check(envelope.keyID == deviceKey.keyID, "E2EE envelope should bind to the device key")
check(!envelope.containsRawMemoryBody, "E2EE envelope contract should not expose raw memory body")
check(!envelope.containsRawMedia, "E2EE envelope contract should not contain raw media")
check(envelope.trustLevel == .developmentStub, "E2EE envelope should explicitly identify stub trust level")

let exportManifest = ExportManifestSigner.sign(
    slices: [slice, updated],
    chapters: [chapter],
    with: deviceKey,
    generatedAt: fixedDate
)
check(exportManifest.sliceCount == 2, "Export manifest should count exported slices")
check(exportManifest.mediaAnchorCount == 2, "Export manifest should count media anchors")
check(!exportManifest.includesRawMedia, "Export manifest should default to no raw media in stub")
check(!exportManifest.includesAITranscripts, "Export manifest should not include AI transcripts by default")
check(exportManifest.userCanExportWithoutSubscription, "Export must remain available without subscription")
check(exportManifest.signature.hasPrefix("stub-signature-v1:"), "Export manifest should carry a deterministic signature stub")

let deletion = DeletionReceipt.issue(
    scopes: [.encryptedCloudBackup, .aiDrafts, .mediaThumbnails],
    requestedAt: fixedDate
)
check(deletion.status == .accepted, "Deletion receipt should be accepted")
check(deletion.userCanExportBeforeDeletion, "Deletion receipt should preserve pre-deletion export rights")
check(deletion.scopes.contains(.aiDrafts), "Deletion receipt should cover AI drafts")
check(deletion.affectedRemoteSystems.contains("encrypted-backup"), "Deletion receipt should list affected remote systems")

let aiEnvelope = DeepSeekTaskEnvelope.weeklyChapterDraft(claimed: moments)
check(aiEnvelope.provider == "deepseek", "AI envelope should use DeepSeek provider for PoC")
check(aiEnvelope.model == "deepseek-v4-flash", "AI envelope should use the selected DeepSeek model")
check(aiEnvelope.userConsentRequired, "AI envelope should require user consent")
check(aiEnvelope.maxBudgetCents <= 4, "AI envelope should keep PoC budget bounded")
check(aiEnvelope.fallbackMode == "local-rules", "AI envelope should declare local fallback")
check(!aiEnvelope.containsRawMedia, "AI envelope should forbid raw media")
check(!aiEnvelope.containsFullMemoryArchive, "AI envelope should forbid full memory archive")
check(aiEnvelope.allowedPayloadKeys.contains("user_selected_claims"), "AI envelope should only send user-claimed context")
check(aiEnvelope.forbiddenPayloadKeys.contains("raw_media_binary"), "AI envelope should explicitly forbid raw media binary")
check(aiEnvelope.forbiddenPayloadKeys.contains("full_memory_archive"), "AI envelope should explicitly forbid full archive upload")

check(ProductionTrustChecklist.rows.count == 5, "Production Trust Checklist should track five v38 trust contracts")
check(ProductionTrustChecklist.rows.allSatisfy { $0.status == .poc }, "Production Trust Checklist rows should remain PoC, not falsely ready")

print("TimeSlowDownNativeChecks passed: slices, media anchors, weekly chapter, ledgers, privacy boundary, SwiftUI shell state, app target config, Xcode project skeleton, and v38 production trust contracts are aligned.")
