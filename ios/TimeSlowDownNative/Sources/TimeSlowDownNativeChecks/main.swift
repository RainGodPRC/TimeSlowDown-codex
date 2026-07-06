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
check(infoPlistText.contains("<string>37</string>"), "Info.plist should carry v37 build number")
check(infoPlistText.contains("UILaunchStoryboardName"), "Info.plist should point at LaunchScreen")

print("TimeSlowDownNativeChecks passed: slices, media anchors, weekly chapter, ledgers, privacy boundary, SwiftUI shell state, app target config, and Xcode project skeleton are aligned.")
