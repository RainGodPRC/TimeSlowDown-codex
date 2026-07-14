import Foundation
import TimeSlowDownKit
#if canImport(AVFoundation)
import AVFoundation
import CoreVideo
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

func environmentValue(_ name: String) -> String? {
    guard let value = ProcessInfo.processInfo.environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty else {
        return nil
    }
    return value
}

#if canImport(AVFoundation)
func makeVideoPosterFixture(at url: URL) async throws {
    try? FileManager.default.removeItem(at: url)
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let width = 192
    let height = 108
    let input = AVAssetWriterInput(
        mediaType: .video,
        outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
    )
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
    )
    guard writer.canAdd(input) else { throw MediaThumbnailError.unsupportedVideo }
    writer.add(input)
    guard writer.startWriting() else {
        throw writer.error ?? MediaThumbnailError.renderFailed
    }
    writer.startSession(atSourceTime: .zero)

    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_32BGRA,
        nil,
        &pixelBuffer
    )
    guard status == kCVReturnSuccess, let pixelBuffer else {
        throw MediaThumbnailError.renderFailed
    }
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        for row in 0..<height {
            let bytes = baseAddress.advanced(by: row * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for column in 0..<width {
                let offset = column * 4
                bytes[offset] = UInt8(70 + (column % 80))
                bytes[offset + 1] = UInt8(120 + (row % 80))
                bytes[offset + 2] = 210
                bytes[offset + 3] = 255
            }
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

    for _ in 0..<200 where !input.isReadyForMoreMediaData {
        try await Task.sleep(nanoseconds: 5_000_000)
    }
    guard input.isReadyForMoreMediaData,
          adaptor.append(pixelBuffer, withPresentationTime: .zero),
          adaptor.append(pixelBuffer, withPresentationTime: CMTime(seconds: 1, preferredTimescale: 600)) else {
        writer.cancelWriting()
        throw writer.error ?? MediaThumbnailError.renderFailed
    }
    input.markAsFinished()
    await writer.finishWriting()
    guard writer.status == .completed else {
        throw writer.error ?? MediaThumbnailError.renderFailed
    }
}
#endif

final class HTTPResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?
    private var response: HTTPURLResponse?
    private var error: Error?

    func store(data: Data?, response: HTTPURLResponse?, error: Error?) {
        lock.lock()
        self.data = data
        self.response = response
        self.error = error
        lock.unlock()
    }

    func snapshot() -> (Data?, HTTPURLResponse?, Error?) {
        lock.lock()
        let snapshot = (data, response, error)
        lock.unlock()
        return snapshot
    }
}

final class ExportProgressBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Double] = []

    func append(_ value: Double) {
        lock.lock()
        storage.append(value)
        lock.unlock()
    }

    var values: [Double] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

func synchronousPOST(
    urlRequest: URLRequest,
    timeoutSeconds: TimeInterval
) throws -> (Data, HTTPURLResponse) {
    let semaphore = DispatchSemaphore(value: 0)
    let resultBox = HTTPResultBox()

    let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
        resultBox.store(data: data, response: response as? HTTPURLResponse, error: error)
        semaphore.signal()
    }
    task.resume()

    guard semaphore.wait(timeout: .now() + timeoutSeconds) == .success else {
        task.cancel()
        throw NSError(
            domain: "TimeSlowDownNativeChecks",
            code: 408,
            userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for DeepSeek backend probe response."]
        )
    }
    let (responseData, httpResponse, responseError) = resultBox.snapshot()
    if let responseError {
        throw responseError
    }
    guard let httpResponse else {
        throw NSError(
            domain: "TimeSlowDownNativeChecks",
            code: 502,
            userInfo: [NSLocalizedDescriptionKey: "DeepSeek backend probe did not return an HTTP response."]
        )
    }
    return (responseData ?? Data(), httpResponse)
}

func runOptionalLiveDeepSeekBackendProbe(
    plan: DeepSeekGatewayIntegrationPlan,
    request: DeepSeekGatewayIntegrationTestRequest,
    payload: DeepSeekBackendRoundTripProbePayload
) throws -> DeepSeekBackendRoundTripProbeReceipt {
    guard let configuredBaseURL = environmentValue("TSD_DEEPSEEK_BACKEND_BASE_URL"),
          let testToken = environmentValue("TSD_DEEPSEEK_TEST_TOKEN") else {
        return DeepSeekBackendRoundTripProbe.notConfiguredReceipt()
    }
    check(configuredBaseURL.hasPrefix("https://"), "Live DeepSeek backend probe should require https backend URL")
    check(!testToken.localizedCaseInsensitiveContains("sk-"), "Live probe token must be a TSD backend test token, not a DeepSeek provider key")
    check(payload.isSafeForBackendRoundTrip, "Live DeepSeek backend probe payload should be safe before network execution")
    check(request.isSafeToExecuteAgainstBackend, "Live DeepSeek backend probe request should be safe before network execution")

    let endpointURL = URL(string: configuredBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + request.endpointPath)!
    var urlRequest = URLRequest(url: endpointURL)
    urlRequest.httpMethod = request.method
    urlRequest.timeoutInterval = TimeInterval(request.timeoutSeconds)
    for (key, value) in request.headers {
        urlRequest.setValue(value, forHTTPHeaderField: key)
    }
    urlRequest.setValue("Bearer \(testToken)", forHTTPHeaderField: "Authorization")
    urlRequest.setValue("true", forHTTPHeaderField: "X-TSD-Provider-Round-Trip-Required")
    urlRequest.httpBody = try DeepSeekBackendRoundTripProbe.encodedPayload(payload)

    let (data, httpResponse) = try synchronousPOST(
        urlRequest: urlRequest,
        timeoutSeconds: TimeInterval(request.timeoutSeconds)
    )
    let response = try JSONDecoder().decode(DeepSeekBackendRoundTripProbeResponse.self, from: data)
    return DeepSeekBackendRoundTripProbe.receipt(
        plan: plan,
        request: request,
        payload: payload,
        statusCode: httpResponse.statusCode,
        response: response
    )
}

func runOptionalLiveDeletionServiceProbe(
    service: DeletionServiceIntegrationEnvelope,
    payload: DeletionServiceLiveProbePayload
) throws -> DeletionServiceLiveProbeReceipt {
    guard let configuredBaseURL = environmentValue("TSD_DELETION_BACKEND_BASE_URL"),
          let testToken = environmentValue("TSD_DELETION_TEST_TOKEN") else {
        return DeletionServiceLiveProbe.notConfiguredReceipt()
    }
    check(configuredBaseURL.hasPrefix("https://"), "Live deletion service probe should require https backend URL")
    check(!testToken.localizedCaseInsensitiveContains("sk-"), "Live deletion probe token must be a TSD backend test token, not a provider key")
    check(payload.isSafeForDeletionServiceProbe, "Live deletion service probe payload should be safe before network execution")
    check(service.isDeletionRightsSafe, "Live deletion service envelope should be safe before network execution")

    let endpointURL = URL(string: configuredBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + service.serviceEndpointPath)!
    var urlRequest = URLRequest(url: endpointURL)
    urlRequest.httpMethod = "POST"
    urlRequest.timeoutInterval = 30
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("Bearer \(testToken)", forHTTPHeaderField: "Authorization")
    urlRequest.setValue(payload.idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
    urlRequest.setValue(payload.deletionReceiptID, forHTTPHeaderField: "X-TSD-Deletion-Receipt")
    urlRequest.setValue("true", forHTTPHeaderField: "X-TSD-Deletion-Test-Account")
    urlRequest.httpBody = try DeletionServiceLiveProbe.encodedPayload(payload)

    let (data, httpResponse) = try synchronousPOST(
        urlRequest: urlRequest,
        timeoutSeconds: 30
    )
    let response = try JSONDecoder().decode(DeletionServiceLiveProbeResponse.self, from: data)
    return DeletionServiceLiveProbe.receipt(
        service: service,
        payload: payload,
        statusCode: httpResponse.statusCode,
        backendBaseURL: configuredBaseURL,
        response: response
    )
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

let radar = SliceFactory.dailyDifferenceRadar(from: [slice, updated] + moments)
check(radar.isTSDDailyLoopReady, "Daily Difference Radar should produce three sourced candidates")
check(radar.candidates.map(\.kind).contains(.mediaAnchor), "Daily Difference Radar should include a media-anchor candidate")
check(radar.candidates.map(\.kind).contains(.relationship), "Daily Difference Radar should include a relationship candidate")
check(radar.candidates.map(\.kind).contains(.turningPoint), "Daily Difference Radar should include a turning-point candidate")
let radarSlice = SliceFactory.quickMark(from: radar.candidates[0], media: photo)
check(radarSlice.sources.contains("今日差异雷达"), "Radar Quick Mark should preserve the Daily Difference Radar source")
check(radarSlice.hasMediaAnchor, "Radar Quick Mark should allow media to remain a memory anchor")

let ninetyDayProgress = SliceFactory.ninetyDayTellableProgress(
    from: [slice, updated] + moments,
    claimedSliceIDs: Array(moments.prefix(3)).map(\.id)
)
check(ninetyDayProgress.minimumTarget == 5, "90-day tellable progress should use five memories as the minimum north-star target")
check(ninetyDayProgress.aspirationalTarget == 10, "90-day tellable progress should keep ten memories as the aspirational target")
check(ninetyDayProgress.mediaAnchorCount >= 2, "90-day tellable progress should count media anchors")
check(ninetyDayProgress.weeklyClaimMissing == 0, "90-day tellable progress should recognize three weekly claimed moments")
check(ninetyDayProgress.isTSDNorthStarAligned, "90-day tellable progress should avoid shame/failure language")

check(NativeHandoffLedger.rows.count == 8, "Native Handoff Ledger should keep the v32 eight-row contract")
check(SubmissionPacket.rows.count == 13, "Submission Packet should keep the thirteen-row contract after v73 first-week return loop")
check(NativeHandoffLedger.rows.map(\.id).contains("photos-picker"), "Native Handoff should include PhotosPicker")
check(NativeHandoffLedger.rows.map(\.id).contains("keychain-e2ee"), "Native Handoff should include Keychain/E2EE")
check(SubmissionPacket.rows.map(\.id).contains("privacy-questionnaire"), "Submission Packet should include privacy questionnaire")
check(SubmissionPacket.rows.map(\.id).contains("subscription-copy"), "Submission Packet should include subscription wording")
check(SubmissionPacket.rows.map(\.id).contains("metadata-legal-review-packet"), "Submission Packet should include metadata/legal review packet")
check(SubmissionPacket.rows.map(\.id).contains("screenshot-app-preview-creative-packet"), "Submission Packet should include screenshot/App Preview creative packet")
check(SubmissionPacket.rows.map(\.id).contains("encryption-export-compliance-packet"), "Submission Packet should include encryption export compliance packet")
check(NativeHandoffLedger.rows.first { $0.id == "swiftui-shell" }?.status == .poc, "SwiftUI shell should be promoted to PoC after v37 Xcode project skeleton")
check(NativeHandoffLedger.rows.first { $0.id == "photos-picker" }?.status == .poc, "PhotosPicker should be promoted to PoC after v50 byte import adapter")
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

let fixedDate = Date(timeIntervalSince1970: 1_788_249_600)
var shell = NativeShellStore.seeded()
let firstSnapshot = shell.snapshot
check(firstSnapshot.routeCount == NativeShellRoute.allCases.count, "Native shell should expose all expected routes")
check(firstSnapshot.sliceCount == 3, "Seeded native shell should include three demo slices")
check(firstSnapshot.mediaAnchorCount == 1, "Seeded native shell should include one media anchor")
check(firstSnapshot.nativeTodoCount == NativeHandoffLedger.rows.filter { $0.status == .todo }.count, "Native shell should summarize native todo rows")
check(firstSnapshot.submissionTodoCount == SubmissionPacket.rows.filter { $0.status == .todo }.count, "Native shell should summarize submission todo rows")
check(firstSnapshot.privacySafe, "Native shell should start with a safe privacy boundary")
check(!firstSnapshot.hasExportPackage, "Native shell should not claim an export package before the user asks")
check(firstSnapshot.lastExportEntryCount == 0, "Native shell should start with no export entries")
check(firstSnapshot.dailyDifferenceCandidateCount == 3, "Native shell snapshot should expose three Daily Difference Radar candidates")
check(firstSnapshot.ninetyDayTellableCount >= 3, "Native shell snapshot should expose 90-day tellable progress")
check(firstSnapshot.ninetyDayMinimumTarget == 5, "Native shell snapshot should expose the 90-day minimum tellable target")
check(firstSnapshot.yesterdayEchoAvailable, "Native shell snapshot should expose a yesterday echo when an older slice exists")
check(firstSnapshot.activeRecallAvailable, "Native shell snapshot should expose a source-backed active recall when a slice is due")
check(firstSnapshot.weeklyStoryClaimedCount == 3, "Native shell snapshot should expose three claimed weekly story slots")
check(firstSnapshot.weeklyStoryReadyCount >= 1, "Native shell snapshot should expose at least one story-ready seeded slice")
check(firstSnapshot.revisitCount == 0, "Native shell should start without fabricated revisits")
check(firstSnapshot.recallInteractionCount == 0, "Native shell should start without fabricated recall interactions")
check(Set(shell.lifeMarks.map(\.kind)) == [.firstLeaf, .mediaAnchor, .threeMoments], "Seeded Life Marks should come only from real slice and media evidence")
check(shell.lifeMarks.allSatisfy { shell.lifeMarkEvidence(for: $0.id)?.isComplete == true }, "Every unlocked Life Mark should resolve to complete source evidence")

let seededIDs = Array(shell.slices.prefix(3)).map(\.id)
let weeklyProgress = SliceFactory.weeklyStoryProgress(from: shell.slices, claimedSliceIDs: seededIDs)
check(weeklyProgress.claimedCount == 3, "Weekly story progress should preserve three user-claimed slices")
check(weeklyProgress.candidates.count == 3, "Weekend workbench should expose three candidate slots")
check(weeklyProgress.isNonPunitive, "Weekend workbench copy should avoid debt, streak, and failure language")
check(weeklyProgress.percent > 0 && weeklyProgress.percent <= 100, "Weekly story progress should expose bounded field completeness")

var meadowCalendar = Calendar(identifier: .gregorian)
meadowCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
meadowCalendar.firstWeekday = 2
func meadowDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.date(from: DateComponents(
        timeZone: calendar.timeZone,
        year: year,
        month: month,
        day: day,
        hour: hour
    ))!
}
let meadowMedia = MediaAnchor(kind: .image, label: "summer.jpg")
let julyPhoto = SliceFactory.quickMark(
    title: "七月的海风",
    tags: ["家人"],
    media: meadowMedia,
    now: meadowDate(2026, 7, 2)
)
let julyOrdinary = SliceFactory.quickMark(
    title: "普通的晚饭",
    body: "没有大事，但桌边的灯很暖。",
    now: meadowDate(2026, 7, 2, 20)
)
let julyRain = SliceFactory.quickMark(
    title: "低落的一场雨",
    body: "这也是完整人生的一部分。",
    now: meadowDate(2026, 7, 15)
)
let juneMemory = SliceFactory.quickMark(title: "六月收尾", now: meadowDate(2026, 6, 30))
let olderMemory = SliceFactory.quickMark(title: "五年前学会骑车", now: meadowDate(2021, 4, 8))
let meadowSlices = [julyPhoto, julyOrdinary, julyRain, juneMemory, olderMemory]
let meadowRevisit = MemoryRevisit(
    sliceID: julyPhoto.id,
    revisitedAt: meadowDate(2026, 7, 20),
    reflection: "现在还记得风的声音。"
)
let memoryTimeline = MemoryTimelineFactory.snapshot(
    from: meadowSlices,
    revisits: [meadowRevisit],
    calendar: meadowCalendar
)
check(memoryTimeline.months.map(\.id) == ["2026-07", "2026-06", "2021-04"], "Timeline should group source slices into stable reverse-chronological months")
check(memoryTimeline.months.first?.days.map(\.id) == ["2026-07-15", "2026-07-02"], "Timeline should group source slices into stable reverse-chronological days")
let timelineJulySecond = memoryTimeline.months.first?.days.first { $0.id == "2026-07-02" }
check(timelineJulySecond?.slices.map(\.id) == [julyOrdinary.id, julyPhoto.id], "Same-day Timeline slices should retain deterministic newest-first source order")
check(timelineJulySecond?.prominentSliceID == julyPhoto.id, "Timeline should give the day's real media anchor visual prominence without changing source order")
check(memoryTimeline.sliceCount == 5 && memoryTimeline.mediaAnchorCount == 1 && memoryTimeline.revisitCount == 1, "Timeline summary should preserve slice, media, and revisit counts")
check(memoryTimeline.isSourceBacked, "Timeline should project every source slice exactly once without invented memories")
check(
    MemoryTimelineFactory.snapshot(
        from: [olderMemory, julyRain, julyOrdinary, juneMemory, julyPhoto],
        revisits: [meadowRevisit],
        calendar: meadowCalendar
    ) == memoryTimeline,
    "Timeline projection should remain deterministic when source input order changes"
)
let monthMeadow = LifeMeadowFactory.snapshot(
    from: meadowSlices,
    revisits: [meadowRevisit],
    scale: .month,
    anchorDate: meadowDate(2026, 7, 15),
    calendar: meadowCalendar
)
check(monthMeadow.periods.count == 31, "July meadow should expose one stable period per calendar day")
check(LifeMeadowFactory.leadingWeekdayPlaceholders(for: monthMeadow.intervalStart, calendar: meadowCalendar) == 2, "Month grid should align day one under Wednesday when Monday is the first weekday")
check(monthMeadow.memoryCount == 3, "Month meadow should include only source slices inside the selected month")
check(monthMeadow.mediaAnchorCount == 1, "Month meadow should preserve media density")
check(monthMeadow.revisitCount == 1, "Month meadow should layer later revisits onto their original memory period")
check(monthMeadow.isSourceBacked, "Meadow summary should exactly equal its source periods")
let julySecond = monthMeadow.periods.first { $0.title == "2" }
check(julySecond?.memoryCount == 2, "Same-day memories should share one deterministic meadow period")
check(julySecond?.growth == .grove, "Multiple slices, media, and revisits should form a denser source-backed landscape")
check(julySecond?.sliceIDs.contains(julyPhoto.id) == true, "A visible meadow period should retain drill-down source IDs")
check(
    LifeMeadowFactory.snapshot(
        from: meadowSlices,
        revisits: [meadowRevisit],
        scale: .month,
        anchorDate: meadowDate(2026, 7, 15),
        calendar: meadowCalendar
    ) == monthMeadow,
    "Meadow projection should be deterministic across recomputation"
)
let yearMeadow = LifeMeadowFactory.snapshot(
    from: meadowSlices,
    revisits: [meadowRevisit],
    scale: .year,
    anchorDate: meadowDate(2026, 7, 15),
    calendar: meadowCalendar
)
check(yearMeadow.periods.count == 12 && yearMeadow.memoryCount == 4, "Year meadow should aggregate stable month periods")
let decadeMeadow = LifeMeadowFactory.snapshot(
    from: meadowSlices,
    revisits: [meadowRevisit],
    scale: .decade,
    anchorDate: meadowDate(2026, 7, 15),
    calendar: meadowCalendar
)
check(decadeMeadow.periods.count == 10 && decadeMeadow.memoryCount == 5, "Decade meadow should preserve memories across calendar years")
check(decadeMeadow.periods.first { $0.title == "2021" }?.sliceIDs == [olderMemory.id], "Decade source IDs should remain attached to their original year")
let emptyMeadow = LifeMeadowFactory.snapshot(
    from: [],
    revisits: [],
    scale: .week,
    anchorDate: meadowDate(2026, 7, 15),
    calendar: meadowCalendar
)
check(emptyMeadow.periods.count == 7 && emptyMeadow.memoryCount == 0 && emptyMeadow.isSourceBacked, "Empty meadow should stay honest and structurally complete")
let nextMonthAnchor = LifeMeadowFactory.shiftedAnchor(
    from: meadowDate(2026, 7, 15),
    scale: .month,
    direction: 1,
    calendar: meadowCalendar
)
check(meadowCalendar.component(.month, from: nextMonthAnchor) == 8, "Meadow navigation should move by the selected semantic scale")

var productInteractionShell = NativeShellStore.seeded()
check(productInteractionShell.captureQuickMark(title: "   ") == nil, "Quick Mark should reject an empty title")
let nativeQuickMark = productInteractionShell.captureQuickMark(title: "雨停后的十分钟", body: "路面有一点亮。")
check(nativeQuickMark?.tags.contains("快速记录") == true, "Quick Mark should preserve its lightweight source identity")
check(productInteractionShell.selectedRoute == .now, "Quick Mark should keep the user in the Today loop")

var onboardingShell = NativeShellStore()
let firstMemory = onboardingShell.captureFirstMemory(
    title: "晚饭时爸爸讲起年轻时的故事",
    tags: ["人", "普通但值得"],
    sources: ["今日差异雷达"]
)
check(firstMemory?.sources.contains("首次体验") == true, "First-run capture should preserve onboarding provenance")
check(firstMemory?.sources.contains("今日差异雷达") == true, "First-run capture should preserve the selected radar source")
check(onboardingShell.selectedRoute == .slices, "First-run success should reveal the user's own slice")
let completedOnboarding = NativeOnboardingState(outcome: .capturedText)
check(
    NativeOnboardingDecision.shouldPresent(
        mode: .automatic,
        hasInjectedStore: false,
        vaultSource: .newVault,
        savedState: nil
    ),
    "A genuinely new vault should receive the first-memory experience"
)
check(
    !NativeOnboardingDecision.shouldPresent(
        mode: .automatic,
        hasInjectedStore: false,
        vaultSource: .restored,
        savedState: nil
    ),
    "Existing users should not be intercepted by first-run onboarding"
)
check(
    !NativeOnboardingDecision.shouldPresent(
        mode: .automatic,
        hasInjectedStore: false,
        vaultSource: .newVault,
        savedState: completedOnboarding
    ),
    "A saved completion or skip marker should prevent repeated onboarding"
)

let productClaimedIDs = Array(productInteractionShell.slices.dropFirst().prefix(3)).map(\.id)
let productProgress = SliceFactory.weeklyStoryProgress(from: productInteractionShell.slices, claimedSliceIDs: productClaimedIDs)
if let mediaCandidate = productProgress.candidates.first(where: { $0.missing.contains(.media) }) {
    let mediaCompleted = productInteractionShell.completeWeekendGap(
        sliceID: mediaCandidate.sliceID,
        kind: .media,
        media: MediaAnchor(kind: .image, label: "weekend-memory.jpg")
    )
    check(mediaCompleted, "Weekend Workbench should attach a selected media anchor")
    check(productInteractionShell.slices.first(where: { $0.id == mediaCandidate.sliceID })?.sources.contains("周末补全：影像") == true, "Weekend media completion should preserve source lineage")
} else {
    check(false, "Seeded product interaction should expose a media gap")
}

var peopleGapShell = NativeShellStore(slices: [SliceFactory.quickMark(title: "远处的雨", body: "路灯下有一小片水光。")])
let peopleSliceID = peopleGapShell.slices[0].id
check(peopleGapShell.completeWeekendGap(sliceID: peopleSliceID, kind: .people, value: "老朋友"), "Weekend Workbench should save a person clue")
check(peopleGapShell.slices[0].people == ["老朋友"], "Weekend person completion should update the memory slice")
check(peopleGapShell.completeWeekendGap(sliceID: peopleSliceID, kind: .meaning, value: "那天终于把误会说开了。"), "Weekend Workbench should save a meaning clue")
check(peopleGapShell.slices[0].meaning == "那天终于把误会说开了。", "Weekend meaning completion should update the memory slice")

let editableSlice = SliceFactory.quickMark(title: "旧标题", body: "旧正文")
let editableRevisit = MemoryRevisit(sliceID: editableSlice.id, reflection: "旧回访")
var editingShell = NativeShellStore(slices: [editableSlice], revisits: [editableRevisit])
check(editingShell.updateSlice(id: editableSlice.id, title: " 新标题 ", body: " 新正文 ", peopleText: "爸爸，朋友", meaning: " 值得留下 "), "Slice detail should save user edits")
check(editingShell.slices[0].title == "新标题", "Slice editing should trim its title")
check(editingShell.slices[0].people == ["爸爸", "朋友"], "Slice editing should parse people clues")
check(editingShell.slices[0].meaning == "值得留下", "Slice editing should save meaning")
check(editingShell.slices[0].sources.contains("用户编辑"), "Slice editing should preserve source lineage")
check(!editingShell.updateSlice(id: editableSlice.id, title: "  ", body: "", peopleText: "", meaning: ""), "Slice editing should reject an empty title")

let editableMedia = MediaAnchor(
    kind: .image,
    label: "detail-photo.jpg",
    thumbnailFileName: "detail-photo.jpg",
    thumbnailByteCount: 128
)
check(editingShell.attachMedia(editableMedia, to: editableSlice.id), "Slice detail should attach replacement media")
check(editingShell.slices[0].media == editableMedia, "Slice media replacement should update the source slice")
check(editingShell.detachMedia(from: editableSlice.id) == editableMedia, "Slice detail should detach media explicitly")
check(editingShell.slices[0].media == nil, "Detached slice media should no longer be referenced")
_ = editingShell.attachMedia(editableMedia, to: editableSlice.id)

let deletedEditableSlice = editingShell.deleteSlice(id: editableSlice.id)
check(deletedEditableSlice?.revisits == [editableRevisit], "Deleting a slice should retain related revisits for undo")
check(editingShell.slices.isEmpty && editingShell.revisits.isEmpty, "Deleting a slice should remove the slice and its revisit layers")
check(deletedEditableSlice.map { editingShell.restoreDeletedSlice($0) } == true, "Undo should restore a deleted slice")
check(editingShell.slices.first?.id == editableSlice.id && editingShell.revisits == [editableRevisit], "Undo should restore the slice and revisit lineage")

let yesterdayEcho = SliceFactory.yesterdayEcho(from: shell.slices)
check(yesterdayEcho?.isGentleReturnReady == true, "Yesterday echo should be a gentle, source-backed return prompt")
let nativeRevisit = shell.revisitYesterdayEcho(reflection: "现在再看，还是记得那碗面的热气。")
check(nativeRevisit?.source == "昨日回声", "Yesterday echo revisit should keep its source")
check(nativeRevisit?.reflection.contains("现在再看") == true, "Yesterday echo should preserve the user's current reflection")
check(shell.snapshot.revisitCount == 1, "Native shell snapshot should expose the new revisit layer")

var recallCalendar = Calendar(identifier: .gregorian)
recallCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
let recallSlice = MemorySlice(
    title: "四十天前的雨",
    body: "和家人一起走回家。",
    capturedAt: recallCalendar.date(byAdding: .day, value: -40, to: fixedDate)!,
    people: ["家人"],
    meaning: "后来仍想讲起",
    sources: ["真实切片"]
)
var activeRecallShell = NativeShellStore(slices: [recallSlice])
let dueRecall = activeRecallShell.activeRecallCandidate(now: fixedDate, calendar: recallCalendar)
check(dueRecall?.id == recallSlice.id, "Deterministic recall should surface a due real slice")
check(dueRecall?.reason == .longUnseen, "A long-unseen source should explain why it surfaced")
let completedRecall = activeRecallShell.completeActiveRecall(
    sliceID: recallSlice.id,
    mode: .neededCue,
    reflection: "",
    now: fixedDate
)
check(completedRecall?.reflection.isEmpty == true, "Active recall should allow a quiet review without forced writing")
check(completedRecall?.source == ActiveRecallMode.neededCue.sourceLabel, "Active recall should preserve whether a cue was needed")
check(activeRecallShell.recallInteractions.last?.revisitID == completedRecall?.id, "A completed recall should link its scheduling interaction to the real revisit")
check(activeRecallShell.activeRecallCandidate(now: recallCalendar.date(byAdding: .day, value: 2, to: fixedDate)!, calendar: recallCalendar) == nil, "Spaced recall should not immediately resurface a completed memory")
check(activeRecallShell.activeRecallCandidate(now: recallCalendar.date(byAdding: .day, value: 3, to: fixedDate)!, calendar: recallCalendar) != nil, "Spaced recall should become due at the next deterministic interval")
let skipDate = recallCalendar.date(byAdding: .day, value: 3, to: fixedDate)!
let quietSkip = activeRecallShell.skipActiveRecall(sliceID: recallSlice.id, now: skipDate, calendar: recallCalendar)
check(quietSkip?.outcome == .skipped, "Quiet skip should be persisted as an anti-nag interaction")
check(activeRecallShell.revisits.count == 1, "Quiet skip must not fabricate a completed revisit")
check(activeRecallShell.activeRecallCandidate(now: skipDate, calendar: recallCalendar) == nil, "Quiet skip should remove the memory from the current recall surface")

let encodedShell = try JSONEncoder().encode(NativeShellStore())
var legacyShellObject = try JSONSerialization.jsonObject(with: encodedShell) as! [String: Any]
legacyShellObject.removeValue(forKey: "revisits")
let legacyShellData = try JSONSerialization.data(withJSONObject: legacyShellObject)
let migratedShell = try JSONDecoder().decode(NativeShellStore.self, from: legacyShellData)
check(migratedShell.revisits.isEmpty, "Native shell migration should default legacy stores to an empty revisit list")

let persistenceDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("tsd-native-persistence-\(UUID().uuidString)", isDirectory: true)
let persistenceURL = persistenceDirectory.appendingPathComponent("native-shell-v1.json")
defer { try? FileManager.default.removeItem(at: persistenceDirectory) }

let freshVault = try NativeShellPersistence.loadRecovering(from: persistenceURL)
check(freshVault.source == .newVault, "A first launch should create an honest empty vault instead of demo memories")
check(freshVault.store.slices.isEmpty && freshVault.store.revisits.isEmpty, "A first launch vault should start empty")

var revisionBoundaryShell = NativeShellStore()
revisionBoundaryShell.selectedRoute = .meadow
revisionBoundaryShell.recordExportError("session-only")
check(revisionBoundaryShell.vaultRevision == 0, "Session-only route and export state should not advance the vault revision")
_ = revisionBoundaryShell.captureQuickMark(title: "domain mutation")
check(revisionBoundaryShell.vaultRevision == 1, "A real memory mutation should advance the vault revision exactly once")

var persistedShell = NativeShellStore.seeded(now: fixedDate)
if let persistedRecall = persistedShell.activeRecallCandidate(now: fixedDate) {
    _ = persistedShell.completeActiveRecall(
        sliceID: persistedRecall.id,
        mode: .remembered,
        reflection: "重启后也要保留这句话。",
        now: fixedDate
    )
}
try NativeShellPersistence.save(persistedShell, to: persistenceURL)
let persistedVaultObject = try JSONSerialization.jsonObject(with: Data(contentsOf: persistenceURL)) as! [String: Any]
let persistedVaultPayload = persistedVaultObject["payload"] as? [String: Any]
check(persistedVaultObject["schemaVersion"] as? Int == 5, "Native persistence should write the active-recall schema v5 envelope")
check(persistedVaultObject["store"] == nil, "Schema v5 should not retain the old full-store wrapper")
check(persistedVaultPayload?["slices"] != nil, "Schema v5 should persist memory slices in its domain payload")
check(persistedVaultPayload?["recallInteractions"] != nil, "Schema v5 should persist anti-nag recall interactions")
check(persistedVaultPayload?["lifeMarks"] != nil, "Schema v5 should persist the Life Marks provenance ledger")
check(persistedVaultPayload?["selectedRoute"] == nil, "Schema v5 should exclude the current tab from the vault payload")
check(persistedVaultPayload?["latestExportError"] == nil, "Schema v5 should exclude transient export errors from the vault payload")
let restoredVault = try NativeShellPersistence.loadRecovering(from: persistenceURL)
check(restoredVault.source == .restored, "A saved native vault should restore from Application Support")
check(restoredVault.store == persistedShell, "Persistence should round-trip slices, revisits, and privacy while session defaults remain equivalent")
check(restoredVault.store.vaultRevision == 0, "Restored stores should begin with a fresh in-memory revision token")

let coordinatedPersistenceURL = persistenceDirectory.appendingPathComponent("coordinated-native-shell-v1.json")
let persistenceCoordinator = NativeShellPersistenceCoordinator(url: coordinatedPersistenceURL)
var earlierSnapshot = NativeShellStore()
_ = earlierSnapshot.captureQuickMark(title: "较早的状态")
var latestSnapshot = earlierSnapshot
_ = latestSnapshot.captureQuickMark(title: "必须最后留下的状态")
let earlierSave = Task {
    try await persistenceCoordinator.saveDebounced(earlierSnapshot, delayNanoseconds: 80_000_000)
}
while await persistenceCoordinator.latestRequestedRevision < 1 {
    await Task.yield()
}
let latestSave = Task {
    try await persistenceCoordinator.saveDebounced(latestSnapshot, delayNanoseconds: 5_000_000)
}
do {
    _ = try await earlierSave.value
    check(false, "Persistence coordinator should cancel a stale delayed snapshot")
} catch is CancellationError {
    check(true, "Persistence coordinator cancelled a stale delayed snapshot")
}
_ = try await latestSave.value
let coordinatedVault = try NativeShellPersistence.loadRecovering(from: coordinatedPersistenceURL)
check(
    coordinatedVault.store.slices.map(\.title) == latestSnapshot.slices.map(\.title),
    "Persistence coordinator should reject a stale delayed snapshot"
)
let coordinatedRevision = await persistenceCoordinator.latestCommittedRevision
check(coordinatedRevision == 2, "Persistence coordinator should commit only the latest scheduled revision")

var backgroundSnapshot = latestSnapshot
_ = backgroundSnapshot.captureQuickMark(title: "进入后台前必须保存")
var supersededSnapshot = latestSnapshot
_ = supersededSnapshot.captureQuickMark(title: "不能覆盖后台快照")
let supersededSave = Task {
    try await persistenceCoordinator.saveDebounced(supersededSnapshot, delayNanoseconds: 80_000_000)
}
while await persistenceCoordinator.latestRequestedRevision < 3 {
    await Task.yield()
}
_ = try await persistenceCoordinator.flush(backgroundSnapshot)
do {
    _ = try await supersededSave.value
    check(false, "Background flush should invalidate an older pending debounce")
} catch is CancellationError {
    check(true, "Background flush invalidated an older pending debounce")
}
let flushedVault = try NativeShellPersistence.loadRecovering(from: coordinatedPersistenceURL)
check(
    flushedVault.store.slices.map(\.title) == backgroundSnapshot.slices.map(\.title),
    "Background flush should persist the latest snapshot immediately"
)
let flushedRevision = await persistenceCoordinator.latestCommittedRevision
check(flushedRevision == 4, "Background flush should advance past the superseded pending revision")

let gcDirectory = persistenceDirectory.appendingPathComponent("gc-vault", isDirectory: true)
let gcPersistenceURL = gcDirectory.appendingPathComponent("native-shell-v1.json")
let gcThumbnailDirectory = gcDirectory.appendingPathComponent("MediaThumbnails", isDirectory: true)
let referencedGCAnchor = try NativeMediaThumbnailStore.persist(
    MemoryCameraSelection(
        anchor: MediaAnchor(kind: .image, label: "referenced-gc.jpg"),
        thumbnailData: Data([0xFF, 0xD8, 0x10, 0xD9])
    ),
    directory: gcThumbnailDirectory
)
let orphanedGCAnchor = try NativeMediaThumbnailStore.persist(
    MemoryCameraSelection(
        anchor: MediaAnchor(kind: .image, label: "orphaned-gc.jpg"),
        thumbnailData: Data([0xFF, 0xD8, 0x11, 0xD9])
    ),
    directory: gcThumbnailDirectory
)
var gcStore = NativeShellStore()
_ = gcStore.captureFromMemoryCamera(referencedGCAnchor)
let gcCoordinator = NativeShellPersistenceCoordinator(
    url: gcPersistenceURL,
    thumbnailDirectory: gcThumbnailDirectory
)
let gcReceipt = try await gcCoordinator.flush(gcStore)
let referencedGCFileName = referencedGCAnchor.thumbnailFileName ?? ""
let orphanedGCFileName = orphanedGCAnchor.thumbnailFileName ?? ""
check(
    NativeMediaThumbnailStore.data(fileName: referencedGCFileName, directory: gcThumbnailDirectory) != nil,
    "Post-commit media GC should preserve thumbnails referenced by the committed snapshot"
)
check(
    NativeMediaThumbnailStore.data(fileName: orphanedGCFileName, directory: gcThumbnailDirectory) == nil,
    "Post-commit media GC should remove orphaned managed thumbnails"
)
check(
    gcReceipt.mediaGarbageCollection.removedFileNames == [orphanedGCFileName],
    "Persistence commit receipts should audit removed orphan thumbnails"
)

var legacyPersistenceObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(persistedShell)) as! [String: Any]
legacyPersistenceObject.removeValue(forKey: "revisits")
let legacyPersistenceData = try JSONSerialization.data(withJSONObject: legacyPersistenceObject)
try legacyPersistenceData.write(to: persistenceURL, options: .atomic)
let restoredLegacyVault = try NativeShellPersistence.loadRecovering(from: persistenceURL)
check(restoredLegacyVault.store.revisits.isEmpty, "Persistence should migrate a pre-revisit native vault without data loss")
check(restoredLegacyVault.store.slices.count == persistedShell.slices.count, "Legacy persistence migration should preserve memory slices")

try Data("not-a-native-vault".utf8).write(to: persistenceURL, options: .atomic)
let recoveredVault = try NativeShellPersistence.loadRecovering(from: persistenceURL)
if case .recoveredCorruptBackup(let backupName) = recoveredVault.source {
    check(FileManager.default.fileExists(atPath: persistenceDirectory.appendingPathComponent(backupName).path), "Corrupt persistence recovery should retain a backup file")
} else {
    check(false, "Corrupt persistence should be backed up before starting a new vault")
}
check(recoveredVault.store.slices.isEmpty, "Corrupt persistence recovery should not fabricate memories")

let captured = shell.captureFromMemoryCamera(
    MediaAnchor(kind: .image, label: "native-memory-camera.jpg", note: "SwiftUI Memory Camera")
)
check(shell.selectedRoute == .slices, "Memory Camera capture should route users to slices")
check(shell.slices.first == captured, "Memory Camera capture should insert the new slice first")
check(shell.snapshot.sliceCount == 4, "Memory Camera capture should increase slice count")
check(shell.snapshot.mediaAnchorCount == 2, "Memory Camera capture should increase media anchor count")
check(shell.weeklyPreviewTitle() == "本周没有消失", "Native shell should expose weekly chapter preview")

let shellExport = try shell.exportMemoryVault(now: fixedDate)
check(shell.selectedRoute == .account, "Exporting memory vault should keep users in Account Rights")
check(shellExport.hasZIPMagic, "Native shell export should generate a real ZIP package")
check(shellExport.isMemorySafeDefault, "Native shell export should preserve TSD memory rights")
check(shell.latestExportSummary?.fileName == shellExport.fileName, "Native shell should retain the latest export file name")
check(shell.latestExportSummary?.entryCount == 8, "Native shell export summary should expose eight default documents including recall interactions and Life Marks")
check(shell.latestExportSummary?.isTSDMemoryRightsSafe == true, "Native shell export summary should be memory-rights safe")
check(shell.snapshot.hasExportPackage, "Native shell snapshot should show that an export package exists after export")
check(shell.snapshot.lastExportEntryCount == 8, "Native shell snapshot should expose latest export entry count")
check(shell.latestExportError == nil, "Native shell should clear export errors after a successful export")
let fileExportDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("tsd-native-check-export-\(UUID().uuidString)", isDirectory: true)
let unrelatedExportFile = fileExportDirectory.appendingPathComponent("keep-me.txt")
try FileManager.default.createDirectory(at: fileExportDirectory, withIntermediateDirectories: true)
try Data("unrelated".utf8).write(to: unrelatedExportFile)
try Data("stale".utf8).write(to: fileExportDirectory.appendingPathComponent(".tsd-export-stale.partial"))
let removedExportArtifacts = try NativeMemoryExportFileBuilder.removeOwnedArtifacts(in: fileExportDirectory)
check(removedExportArtifacts == [".tsd-export-stale.partial"], "File export cleanup should remove only builder-owned artifacts")
check(FileManager.default.fileExists(atPath: unrelatedExportFile.path), "File export cleanup should preserve unrelated temporary files")
let exportProgress = ExportProgressBox()
let fileArtifact = try await NativeMemoryExportFileBuilder.export(
    shell.memoryExportRequest(now: fixedDate),
    to: fileExportDirectory,
    availableCapacityBytes: 10_000_000,
    progress: { exportProgress.append($0) }
)
check(FileManager.default.fileExists(atPath: fileArtifact.fileURL.path), "URL-backed export should create a completed ZIP file")
check(fileArtifact.fileSizeBytes > 22, "URL-backed export should contain ZIP headers and payload")
check(fileArtifact.entries.count == 8, "URL-backed export should contain the eight default documents")
check(fileArtifact.entries.map(\.path).contains("memories/recall-interactions.json"), "URL-backed export should carry the active-recall interaction ledger")
check(fileArtifact.entries.map(\.path).contains("memories/life-marks.json"), "URL-backed export should carry the Life Marks provenance ledger")
check(fileArtifact.isMemorySafeDefault, "URL-backed export should preserve the default memory-rights boundary")
let fileArtifactData = try Data(contentsOf: fileArtifact.fileURL)
check(fileArtifactData.starts(with: [0x50, 0x4B, 0x03, 0x04]), "URL-backed export should begin with ZIP local-file magic")
check(fileArtifactData.suffix(22).starts(with: [0x50, 0x4B, 0x05, 0x06]), "URL-backed export should end with a ZIP central-directory footer")
check(exportProgress.values.last == 1, "URL-backed export progress should finish at one")
check(zip(exportProgress.values, exportProgress.values.dropFirst()).allSatisfy { $0 <= $1 }, "URL-backed export progress should be monotonic")
check(NativeExportSummary.from(fileArtifact).fileSizeBytes == fileArtifact.fileSizeBytes, "URL-backed export should create a summary without retaining archive Data")
try FileManager.default.removeItem(at: fileExportDirectory)

let diagnosticsDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("tsd-native-check-diagnostics-\(UUID().uuidString)", isDirectory: true)
let diagnosticsStore = NativeRuntimeReceiptStore(
    url: diagnosticsDirectory.appendingPathComponent("store/runtime-receipts.json"),
    maximumReceiptCount: 3,
    maximumEncodedBytes: 32_768
)
let runtimeDiagnostics = NativeRuntimeDiagnostics(store: diagnosticsStore)
let privateCanary = "PRIVATE MEMORY ALICE /Users/alice/family.jpg"
await runtimeDiagnostics.record(
    NativeRuntimeReceiptFactory.failure(
        operation: .memoryExport,
        error: ExportZIPBuilderError.fileIO(privateCanary),
        duration: .milliseconds(18)
    )
)
for count in 1...4 {
    await runtimeDiagnostics.record(NativeRuntimeReceiptFactory.metricPayloads(count))
}
let boundedReceipts = await runtimeDiagnostics.receipts()
check(boundedReceipts.count == 3, "Runtime diagnostics should keep a bounded receipt ring")
check(boundedReceipts.compactMap(\.metricPayloadCount) == [2, 3, 4], "Runtime diagnostics should evict the oldest receipts first")
let diagnosticsArtifact = try await diagnosticsStore.exportSnapshot(
    to: diagnosticsDirectory.appendingPathComponent("exports", isDirectory: true)
)
let diagnosticsData = try Data(contentsOf: diagnosticsArtifact.fileURL)
let diagnosticsText = String(decoding: diagnosticsData, as: UTF8.self)
check(diagnosticsArtifact.receiptCount == 3, "Diagnostics export should expose only the bounded receipt snapshot")
check(!diagnosticsText.contains(privateCanary), "Diagnostics export must not preserve raw error descriptions")
check(!diagnosticsText.contains("/Users/alice"), "Diagnostics export must not contain absolute user paths")
check(diagnosticsText.contains(NativeRuntimeOperation.metricKitMetrics.rawValue), "Diagnostics export should contain typed operation codes")
check(NativeRuntimeReceiptFactory.metricDiagnostics(payloadCount: 1, crashCount: 2, hangCount: 3, diskWriteExceptionCount: 4, cpuExceptionCount: 5).isPrivacySafe, "MetricKit summaries should remain aggregate and privacy safe")
try FileManager.default.removeItem(at: diagnosticsDirectory)
#if canImport(SwiftUI)
let shellDocument = TSDExportZIPDocument(package: shellExport)
check(shellDocument.fileName == shellExport.fileName, "System exporter document should preserve export file name")
check(shellDocument.byteCount == shellExport.data.count, "System exporter document should preserve ZIP bytes")
check(shellDocument.entryCount == 8, "System exporter document should expose the eight default documents")
check(shellDocument.isMemoryRightsSafe, "System exporter document should preserve memory-rights boundary")
check(shellDocument.isReadyForSystemExporter, "System exporter document should be ready for SwiftUI fileExporter")
check(TSDExportZIPDocument.exportedFilenameExtension == "zip", "System exporter document should use zip extension")
#endif

let requiredRoutes = ["此刻", "切片", "旷野", "印记", "我的"]
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
    XcodeProjectContract.entitlementsPath,
    XcodeProjectContract.sharedSchemePath,
    XcodeProjectContract.uiTestSourcePath
]
for path in requiredXcodePaths {
    let url = packageRoot.appendingPathComponent(path)
    check(FileManager.default.fileExists(atPath: url.path), "Expected Xcode project asset to exist: \(path)")
}

let projectText = try String(contentsOf: packageRoot.appendingPathComponent(XcodeProjectContract.projectPath), encoding: .utf8)
for token in XcodeProjectContract.requiredProjectTokens {
    check(projectText.contains(token), "Xcode project should contain required token: \(token)")
}
check(projectText.contains("CURRENT_PROJECT_VERSION = 89;"), "Xcode project build settings should carry v89 build number")
check(projectText.contains("TimeSlowDownUITests"), "Xcode project should contain the formal UI testing target")
check(projectText.contains("com.apple.product-type.bundle.ui-testing"), "Xcode UI testing target should use the UI testing product type")
check(projectText.contains("PBXTargetDependency"), "Xcode UI testing target should depend on the app runner")

let appSourceText = try String(contentsOf: packageRoot.appendingPathComponent(XcodeProjectContract.appSourcePath), encoding: .utf8)
check(appSourceText.contains("@main"), "Xcode app source should declare @main")
check(appSourceText.contains("TSDNativeShellView"), "Xcode app source should mount TSDNativeShellView")
check(appSourceText.contains("NativeMetricKitSubscriber"), "Shipping app should subscribe to MetricKit")
check(appSourceText.contains("MXMetricManager.shared.add"), "Shipping app should register its MetricKit subscriber")
check(appSourceText.contains("NativeRuntimeDiagnostics.shared.record"), "MetricKit callbacks should enter the sanitized runtime diagnostics path")
check(appSourceText.contains("#if DEBUG"), "UI test fixtures should be compiled only in Debug")
check(appSourceText.contains("--ui-testing"), "Debug app bootstrap should recognize the UI testing launch contract")
check(appSourceText.contains("--ui-test-fixture"), "Debug app bootstrap should support deterministic fixture selection")
check(appSourceText.contains("persistenceURL: nil"), "UI testing must not persist fixtures into the production vault")
check(appSourceText.contains("TimeSlowDownUITests"), "UI testing diagnostics should use an isolated temporary directory")
check(appSourceText.contains("requiresOnboarding"), "Debug fixtures should support the real first-run route")
check(appSourceText.contains("onboardingMode:"), "The app target should explicitly isolate UI-test onboarding state")
check(appSourceText.contains("case \"timeline\":"), "Debug fixtures should expose the grouped Timeline without entering the production vault")

let sharedSchemeText = try String(contentsOf: packageRoot.appendingPathComponent(XcodeProjectContract.sharedSchemePath), encoding: .utf8)
check(sharedSchemeText.contains("TimeSlowDownUITests.xctest"), "Shared scheme should execute the formal UI testing target")
check(sharedSchemeText.contains("BlueprintName = \"TimeSlowDownUITests\""), "Shared scheme should reference the UI testing target by blueprint name")

let uiTestSourceText = try String(contentsOf: packageRoot.appendingPathComponent(XcodeProjectContract.uiTestSourcePath), encoding: .utf8)
check(uiTestSourceText.contains("testEmptyVaultCanCreateAQuickMark"), "UI suite should cover empty vault to Quick Mark to Slices")
check(uiTestSourceText.contains("testSeededSliceCanBeEditedDeletedAndUndone"), "UI suite should cover edit, delete, and undo")
check(uiTestSourceText.contains("testAccountExportsRemainReachableAtAccessibilityTextSize"), "UI suite should cover Account exports at accessibility text size")
check(uiTestSourceText.contains("testFirstRunCreatesASourceBackedMemoryBeforeEnteringTheApp"), "UI suite should cover first-run capture to a visible source-backed slice")
check(uiTestSourceText.contains("testFirstRunChoicesRemainReachableAtAccessibilityTextSize"), "UI suite should keep first-run choices reachable at accessibility text size")
check(uiTestSourceText.contains("testLifeMarkOpensItsPersistedSourceEvidence"), "UI suite should prove a Life Mark opens its persisted source evidence")
check(uiTestSourceText.contains("testLifeMarkSourceRemainsReadableAtAccessibilityTextSize"), "UI suite should keep Life Mark source evidence readable at Accessibility XXL")
check(uiTestSourceText.contains("testTimelineGroupsMonthsAndDaysAndOpensTheRealSlice"), "UI suite should cover grouped Timeline navigation into the real source slice")
check(uiTestSourceText.contains("testTimelineRemainsNavigableAtAccessibilityTextSize"), "UI suite should keep older Timeline months reachable at Accessibility XXL")
check(uiTestSourceText.contains("timeline.month.2026-07"), "UI suite should assert the native Timeline month identifier")
check(uiTestSourceText.contains("timeline.day.2026-07-02"), "UI suite should assert the native Timeline day identifier")
check(uiTestSourceText.contains("UICTContentSizeCategoryAccessibilityXXL"), "Account UI path should exercise an accessibility Dynamic Type category")

let infoPlistText = try String(contentsOf: packageRoot.appendingPathComponent(XcodeProjectContract.infoPlistPath), encoding: .utf8)
check(infoPlistText.contains("<string>89</string>"), "Info.plist should carry v89 build number")
check(infoPlistText.contains("UILaunchStoryboardName"), "Info.plist should point at LaunchScreen")
check(infoPlistText.contains("ITSAppUsesNonExemptEncryption"), "Info.plist should declare encryption export compliance posture")
check(infoPlistText.contains("<true/>"), "Info.plist should conservatively declare encryption use before final legal classification")

let privacyManifestText = try String(contentsOf: packageRoot.appendingPathComponent(XcodeProjectContract.privacyManifestPath), encoding: .utf8)
check(privacyManifestText.contains("<key>NSPrivacyTracking</key>"), "Privacy manifest should declare tracking status")
check(privacyManifestText.contains("<false/>"), "Privacy manifest should keep tracking disabled by default")
check(privacyManifestText.contains("<key>NSPrivacyTrackingDomains</key>"), "Privacy manifest should declare tracking domains")
check(privacyManifestText.contains("<key>NSPrivacyCollectedDataTypes</key>"), "Privacy manifest should declare collected data types")
check(privacyManifestText.contains("<key>NSPrivacyAccessedAPITypes</key>"), "Privacy manifest should declare accessed API types")
check(privacyManifestText.contains("NSPrivacyAccessedAPICategoryDiskSpace"), "Privacy manifest should declare the shipping disk-space API category")
check(privacyManifestText.contains("E174.1"), "Privacy manifest should declare the export preflight disk-space reason")
check(privacyManifestText.filter { $0 == "<" }.count >= 12, "Privacy manifest should remain a structured plist, not a loose note")

func pngMetadata(at url: URL) throws -> (width: Int, height: Int, colorType: UInt8) {
    let data = try Data(contentsOf: url)
    let pngSignature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]
    check(data.count >= 24, "PNG file should contain an IHDR chunk: \(url.lastPathComponent)")
    for (offset, byte) in pngSignature.enumerated() {
        check(data[offset] == byte, "PNG file should have a valid signature: \(url.lastPathComponent)")
    }
    func readBigEndianUInt32(_ offset: Int) -> Int {
        (Int(data[offset]) << 24) |
        (Int(data[offset + 1]) << 16) |
        (Int(data[offset + 2]) << 8) |
        Int(data[offset + 3])
    }
    return (readBigEndianUInt32(16), readBigEndianUInt32(20), data[25])
}

let appIconContentsText = try String(contentsOf: packageRoot.appendingPathComponent(XcodeProjectContract.appIconPath), encoding: .utf8)
check(AppIconAssetContract.slots.count == 9, "App Icon contract should track nine required iOS slots")
for slot in AppIconAssetContract.slots {
    check(appIconContentsText.contains(slot.filename), "AppIcon Contents.json should reference \(slot.filename)")
    let iconURL = packageRoot
        .appendingPathComponent(AppIconAssetContract.assetCatalogPath)
        .appendingPathComponent(slot.filename)
    check(FileManager.default.fileExists(atPath: iconURL.path), "App Icon PNG should exist: \(slot.filename)")
    let metadata = try pngMetadata(at: iconURL)
    check(metadata.width == slot.pixelSize, "App Icon width should match slot pixels for \(slot.filename)")
    check(metadata.height == slot.pixelSize, "App Icon height should match slot pixels for \(slot.filename)")
    check(metadata.colorType == 2, "App Icon should be RGB without alpha for \(slot.filename)")
}
check(AppIconAssetContract.requiredVisualMotifs.contains("no-copyrighted-asset"), "App Icon contract should forbid third-party assets")
check(AppIconAssetContract.requiredVisualMotifs.contains("no-alpha-channel"), "App Icon contract should require no alpha channel")

let thumbnailSourceSlot = AppIconAssetContract.slots.max(by: { $0.pixelSize < $1.pixelSize })!
let thumbnailSourceURL = packageRoot
    .appendingPathComponent(AppIconAssetContract.assetCatalogPath)
    .appendingPathComponent(thumbnailSourceSlot.filename)
let thumbnailSourceData = try Data(contentsOf: thumbnailSourceURL)
let renderedThumbnail = try MediaThumbnailRenderer.jpegThumbnail(from: thumbnailSourceData, maxPixelSize: 320)
check(renderedThumbnail.starts(with: [0xFF, 0xD8]), "Rendered local thumbnail should be JPEG data")
check(renderedThumbnail.count <= NativeMediaThumbnailStore.maximumThumbnailBytes, "Rendered local thumbnail should respect the protected-cache byte ceiling")
check(renderedThumbnail != thumbnailSourceData, "Thumbnail rendering should create a new metadata-stripped representation")

let thumbnailDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("tsd-thumbnail-store-\(UUID().uuidString)", isDirectory: true)
defer { try? FileManager.default.removeItem(at: thumbnailDirectory) }
let thumbnailAnchor = MediaAnchor(kind: .image, label: "selected-photo")
let thumbnailSelection = MemoryCameraSelection(anchor: thumbnailAnchor, thumbnailData: renderedThumbnail)
let persistedThumbnailAnchor = try NativeMediaThumbnailStore.persist(thumbnailSelection, directory: thumbnailDirectory)
check(persistedThumbnailAnchor.hasLocalThumbnailReference, "Persisted media anchor should reference a protected local thumbnail")
check(persistedThumbnailAnchor.thumbnailIssue == nil, "Successful thumbnail persistence should clear media issues")
check(persistedThumbnailAnchor.storage == "protected-local-thumbnail", "Persisted thumbnail should expose its local protected storage boundary")
check(persistedThumbnailAnchor.thumbnailFileName.flatMap { NativeMediaThumbnailStore.data(fileName: $0, directory: thumbnailDirectory) } == renderedThumbnail, "Protected thumbnail cache should round-trip rendered bytes")
var portableShell = NativeShellStore()
if let portableSlice = portableShell.captureQuickMark(title: "可迁移的照片记忆", now: fixedDate) {
    check(portableShell.attachMedia(persistedThumbnailAnchor, to: portableSlice.id), "Portable export fixture should attach its protected thumbnail")
    if let linkedSlice = portableShell.captureQuickMark(title: "同一张照片的另一段记忆", now: fixedDate) {
        check(portableShell.attachMedia(persistedThumbnailAnchor, to: linkedSlice.id), "Portable export fixture should support a shared media anchor")
    }
    let portableExport = try portableShell.exportMemoryVault(now: fixedDate, thumbnailDirectory: thumbnailDirectory)
    let portableThumbnailPath = "media/thumbnails/\(persistedThumbnailAnchor.id.uuidString.lowercased()).jpg"
    check(portableExport.entries.count == 9, "A shared available thumbnail should be exported once alongside the eight default documents")
    check(portableExport.entries.contains { $0.path == portableThumbnailPath }, "Default ZIP export should carry the protected thumbnail bytes")
    check(portableExport.entries.first { $0.path == portableThumbnailPath }?.containsRawMedia == false, "Exported thumbnails must remain derived media rather than raw originals")
    check(portableExport.data.range(of: Data(portableThumbnailPath.utf8)) != nil, "ZIP bytes should contain the portable thumbnail path")
    check(portableExport.data.range(of: Data("\"thumbnailPath\"".utf8)) != nil, "Media index should disclose the exported thumbnail path")
    check(portableExport.isMemorySafeDefault, "A thumbnail-inclusive default export should preserve the memory-rights boundary")
} else {
    check(false, "Portable export fixture should create a memory slice")
}
let restoredThumbnailAnchor = NativeMediaThumbnailStore.restoreAfterUndo(
    persistedThumbnailAnchor,
    thumbnailData: renderedThumbnail,
    directory: thumbnailDirectory
)
check(restoredThumbnailAnchor.hasLocalThumbnailReference, "Undo should restore protected thumbnail bytes")
let degradedUndoAnchor = NativeMediaThumbnailStore.restoreAfterUndo(
    persistedThumbnailAnchor,
    thumbnailData: nil,
    directory: thumbnailDirectory
)
check(!degradedUndoAnchor.hasLocalThumbnailReference, "Undo without thumbnail bytes must clear stale file references")
check(degradedUndoAnchor.thumbnailIssue != nil, "Undo without thumbnail bytes should disclose media recovery state")
if let thumbnailFileName = persistedThumbnailAnchor.thumbnailFileName {
    try NativeMediaThumbnailStore.remove(fileName: thumbnailFileName, directory: thumbnailDirectory)
    check(NativeMediaThumbnailStore.data(fileName: thumbnailFileName, directory: thumbnailDirectory) == nil, "Removing media should delete its local thumbnail cache")
}
do {
    try NativeMediaThumbnailStore.remove(fileName: "../outside.jpg", directory: thumbnailDirectory)
    check(false, "Thumbnail cache should reject unsafe relative paths")
} catch MediaThumbnailError.invalidFileName {
    check(true, "Thumbnail cache rejected unsafe relative paths")
}

let videoFixtureURL = thumbnailDirectory.appendingPathComponent("poster-fixture.mov")
try await makeVideoPosterFixture(at: videoFixtureURL)
let videoPoster = try await VideoPosterFrameRenderer.jpegPoster(from: videoFixtureURL, maxPixelSize: 320)
check(videoPoster.jpegData.starts(with: [0xFF, 0xD8]), "Video poster renderer should produce JPEG bytes")
check(videoPoster.jpegData.count <= NativeMediaThumbnailStore.maximumThumbnailBytes, "Video poster should respect the protected-cache byte ceiling")
check(videoPoster.actualTimeSeconds.isFinite, "Video poster should disclose the actual extracted frame time")
do {
    _ = try await VideoPosterFrameRenderer.jpegPoster(from: thumbnailSourceURL)
    check(false, "Video poster renderer must reject files without a video track")
} catch {
    check(true, "Video poster renderer rejected a non-video file")
}
let persistedVideoAnchor = try NativeMediaThumbnailStore.persist(
    MemoryCameraSelection(
        anchor: MediaAnchor(kind: .video, label: "selected-video"),
        thumbnailData: videoPoster.jpegData
    ),
    directory: thumbnailDirectory
)
check(persistedVideoAnchor.hasLocalThumbnailReference, "Video selection should persist a protected local poster")
check(persistedVideoAnchor.thumbnailIssue == nil, "Successful video poster generation should clear pending issues")
if let videoPosterFileName = persistedVideoAnchor.thumbnailFileName {
    try NativeMediaThumbnailStore.remove(fileName: videoPosterFileName, directory: thumbnailDirectory)
}
do {
    _ = try NativeMediaThumbnailStore.persist(
        MemoryCameraSelection(anchor: MediaAnchor(kind: .video, label: "missing-poster")),
        directory: thumbnailDirectory
    )
    check(false, "Video selections without poster data must not persist")
} catch MediaThumbnailError.renderFailed {
    check(true, "Video selections without poster data should fail explicitly")
} catch {
    check(false, "Missing video posters should fail with renderFailed")
}
do {
    _ = try NativeMediaThumbnailStore.persist(
        MemoryCameraSelection(anchor: MediaAnchor(kind: .image, label: "missing-thumbnail")),
        directory: thumbnailDirectory
    )
    check(false, "Image selections without rendered thumbnail data must not persist")
} catch MediaThumbnailError.renderFailed {
    check(true, "Image selections without rendered thumbnail data should fail explicitly")
} catch {
    check(false, "Missing image thumbnails should fail with renderFailed")
}

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

let keychainPlan = KeychainPersistencePlan.deviceKeyPlan(for: deviceKey)
check(keychainPlan.isSafeDefault, "Keychain plan should use safe this-device-only defaults")
check(keychainPlan.accessGroup == nil, "Keychain plan should not invent an access group without Team ID")
check(!keychainPlan.synchronizable, "Device key should not be synchronizable by default")
check(!keychainPlan.storesSecretMaterialOutsideKeychain, "Device key plan should not store secret material outside Keychain")

let keychainPayload = KeychainDeviceKeyPayload.metadataOnly(for: deviceKey)
check(keychainPayload.isMetadataOnly, "Keychain payload should keep private key material out of the metadata record")
check(keychainPayload.record.keyID == deviceKey.keyID, "Keychain payload should preserve the device key record")
check(!keychainPayload.containsPrivateKeyMaterial, "Keychain payload should not contain private key material")

let keychainStore = KeychainDeviceKeyStore(plan: keychainPlan)
let encodedPayload = try keychainStore.encodedPayload(keychainPayload)
let decodedPayload = try keychainStore.decodedPayload(from: encodedPayload)
check(decodedPayload == keychainPayload, "Keychain payload should round-trip through the store encoder")
let saveSnapshot = keychainStore.querySnapshot(operation: "save")
check(saveSnapshot.isSafeTSDDeviceKeyQuery, "Keychain store query should preserve safe TSD defaults")
check(saveSnapshot.operation == "save", "Keychain query snapshot should preserve operation")
check(keychainStore.canUseProductionKeychain, "Keychain store should compile with Security.framework on Apple platforms")

let secureEnclavePlan = SecureEnclaveDeviceKeyPlan()
check(secureEnclavePlan.preservesTSDKeyBoundary, "Secure Enclave plan should preserve non-extractable private key boundary")
check(secureEnclavePlan.keyType == "SecureEnclave.P256.KeyAgreement.PrivateKey", "Secure Enclave plan should use P256 key agreement for media vault encryption")
check(secureEnclavePlan.accessControlPolicy == "private-key-usage-biometry-current-set-or-device-passcode", "Secure Enclave plan should require a private-key usage access-control policy")
check(secureEnclavePlan.keychainAccessiblePolicy == .whenUnlockedThisDeviceOnly, "Secure Enclave plan should use when-unlocked-this-device-only Keychain accessibility")
check(secureEnclavePlan.keyUsage == "media-vault-key-agreement", "Secure Enclave plan should scope the key to media vault key agreement")
check(secureEnclavePlan.keySizeBits == 256, "Secure Enclave plan should use a 256-bit P256 key")
check(secureEnclavePlan.publicKeyExportAllowed, "Secure Enclave plan should allow public-key export for wrapping/verification")
check(!secureEnclavePlan.storesPrivateKeyBytesInAppData, "Secure Enclave plan should forbid app data private key bytes")
check(!secureEnclavePlan.storesPrivateKeyBytesInKeychainPayload, "Secure Enclave plan should forbid private key bytes in Keychain metadata payloads")
check(!secureEnclavePlan.allowsSoftwareFallback, "Secure Enclave plan should forbid software key fallback for production media vault keys")
check(secureEnclavePlan.requiresBiometryOrDevicePasscode, "Secure Enclave plan should require biometry or device passcode")
check(secureEnclavePlan.requiresRealDeviceForValidation, "Secure Enclave plan should require signed-device validation")
check(secureEnclavePlan.requiresSignedBuildForValidation, "Secure Enclave plan should require a signed build before validation is claimed")

let secureEnclaveKeyRequest = SecureEnclaveDeviceKeyFactory.generationRequest(
    accountID: deviceKey.accountID,
    deviceName: deviceKey.deviceName,
    createdAt: fixedDate
)
check(SecureEnclaveDeviceKeyFactory.canCompileSecureEnclaveContract, "Secure Enclave key factory contract should compile with Security/CryptoKit on supported Apple platforms")
check(secureEnclaveKeyRequest.isTSDProductionKeyGenerationSafe, "Secure Enclave key generation request should preserve TSD production boundaries")
check(secureEnclaveKeyRequest.keychainPlan.account.hasPrefix("tsd-device-"), "Secure Enclave key request should target a TSD device-key account")
check(secureEnclaveKeyRequest.keychainPlan.requiresUserPresence, "Secure Enclave key request should require user presence")
check(secureEnclaveKeyRequest.keychainPlan.accessible == .whenUnlockedThisDeviceOnly, "Secure Enclave key request should use when-unlocked-this-device-only Keychain accessibility")
check(!secureEnclaveKeyRequest.storesPrivateKeyBytesInRequest, "Secure Enclave key request should not carry private key bytes")
check(!secureEnclaveKeyRequest.storesPrivateKeyBytesInRepo, "Secure Enclave key request should not persist private key bytes in repo")
check(secureEnclaveKeyRequest.requiresLocalAuthenticationPrompt, "Secure Enclave key request should require local authentication prompt")
check(secureEnclaveKeyRequest.signedDeviceValidationStatus == "required-before-testflight", "Secure Enclave key request should keep signed-device validation pending")
let secureEnclaveKeyReceipt = try SecureEnclaveDeviceKeyFactory.referenceReceipt(
    for: secureEnclaveKeyRequest,
    publicKeyDigest: "public-key-digest-demo"
)
check(secureEnclaveKeyReceipt.isTSDProductionKeyReferenceSafe, "Secure Enclave key reference receipt should preserve TSD production key boundaries")
check(secureEnclaveKeyReceipt.record.trustLevel == .productionRequired, "Secure Enclave receipt should mark the key as production-required")
check(secureEnclaveKeyReceipt.record.storageClass == "secure-enclave-this-device-only", "Secure Enclave receipt should use secure-enclave-this-device-only storage class")
check(secureEnclaveKeyReceipt.keychainService == "com.raingodprc.timeslowdown.device-key", "Secure Enclave receipt should preserve the TSD Keychain service")
check(secureEnclaveKeyReceipt.keychainAccount == secureEnclaveKeyReceipt.record.keyID, "Secure Enclave receipt should bind Keychain account to key ID")
check(secureEnclaveKeyReceipt.publicKeyDigest == "public-key-digest-demo", "Secure Enclave receipt should preserve public-key digest evidence")
check(secureEnclaveKeyReceipt.generatedInsideSecureEnclave, "Secure Enclave receipt should require Secure Enclave generation")
check(!secureEnclaveKeyReceipt.privateKeyExtractable, "Secure Enclave receipt should forbid private-key extraction")
check(!secureEnclaveKeyReceipt.containsPrivateKeyBytes, "Secure Enclave receipt should not contain private key bytes")
check(!secureEnclaveKeyReceipt.keychainPayloadContainsPrivateKeyBytes, "Secure Enclave receipt should not put private key bytes in metadata payload")
check(secureEnclaveKeyReceipt.storesOnlyReferenceMetadata, "Secure Enclave receipt should store only key reference metadata")
check(!secureEnclaveKeyReceipt.allowsSoftwareFallback, "Secure Enclave receipt should forbid software fallback")
check(secureEnclaveKeyReceipt.requiresSignedDeviceValidation, "Secure Enclave receipt should still require signed-device validation")

let unsignedHostEnvironment = SignedDeviceKeychainValidationEnvironment.unsignedSwiftPMHost()
check(!unsignedHostEnvironment.canRunSignedDeviceKeychainValidation, "Unsigned SwiftPM host should not claim signed-device validation capability")
check(unsignedHostEnvironment.bundleIdentifier == "com.raingodprc.timeslowdown", "Signed-device environment should preserve production bundle identifier")
check(unsignedHostEnvironment.teamID == nil, "Unsigned host environment should not fake an Apple Developer Team ID")
check(!unsignedHostEnvironment.hasFullXcode, "Unsigned host environment should not pretend full Xcode exists")
check(!unsignedHostEnvironment.hasAppleDeveloperTeam, "Unsigned host environment should not pretend Apple Developer access exists")
check(!unsignedHostEnvironment.signedBundleInstalled, "Unsigned host environment should not claim a signed bundle is installed")
check(!unsignedHostEnvironment.runningOnPhysicalDevice, "Unsigned host environment should not claim physical device execution")
check(!unsignedHostEnvironment.passcodeOrBiometryAvailable, "Unsigned host environment should not claim passcode/biometry access")
check(!unsignedHostEnvironment.networkRequired, "Signed-device validation scaffold should not require network access")
let signedDeviceValidationPlan = SignedDeviceKeychainValidationScaffold.plan(
    environment: unsignedHostEnvironment,
    request: secureEnclaveKeyRequest,
    referenceReceipt: secureEnclaveKeyReceipt,
    generatedAt: fixedDate
)
check(signedDeviceValidationPlan.isTSDValidationPlanSafe, "Signed-device validation plan should preserve TSD boundaries")
check(signedDeviceValidationPlan.requiresExternalSignedDeviceWork, "Signed-device validation plan should honestly require external signed-device work here")
check(signedDeviceValidationPlan.status == .pendingSignedDevice, "Unsigned host plan should stay pending signed device")
check(!signedDeviceValidationPlan.productionValidationClaimed, "Unsigned host plan should not claim production validation")
check(signedDeviceValidationPlan.steps.count == 8, "Signed-device validation plan should define eight required steps")
check(signedDeviceValidationPlan.steps.map(\.kind).contains(.secureEnclaveKeyGeneration), "Signed-device validation should require Secure Enclave key generation")
check(signedDeviceValidationPlan.steps.map(\.kind).contains(.accessControlChallenge), "Signed-device validation should require access-control challenge")
check(signedDeviceValidationPlan.steps.map(\.kind).contains(.wrongDeviceRejection), "Signed-device validation should require wrong-device rejection")
check(signedDeviceValidationPlan.steps.allSatisfy(\.requiresPhysicalDevice), "Signed-device validation steps should require a physical device")
check(signedDeviceValidationPlan.steps.allSatisfy(\.forbidsPrivateKeyBytes), "Signed-device validation steps should forbid private key bytes")
let signedDevicePendingReceipt = SignedDeviceKeychainValidationScaffold.pendingReceipt(
    for: signedDeviceValidationPlan,
    createdAt: fixedDate
)
check(signedDevicePendingReceipt.isHonestPendingReceipt, "Signed-device pending receipt should be honest and non-production")
check(!signedDevicePendingReceipt.isProductionPassReceipt, "Pending signed-device receipt should not pass production gate")
check(signedDevicePendingReceipt.stepReceipts.count == signedDeviceValidationPlan.steps.count, "Signed-device pending receipt should mirror all plan steps")
check(signedDevicePendingReceipt.stepReceipts.allSatisfy { !$0.containsPrivateKeyBytes }, "Signed-device receipts should not contain private key bytes")
check(!signedDevicePendingReceipt.canBeUsedForTestFlightGate, "Pending signed-device receipt should not be usable for TestFlight gate")
check(!signedDevicePendingReceipt.canBeUsedForAppStoreGate, "Pending signed-device receipt should not be usable for App Store gate")

let signedDeviceMediaEnvironment = SignedDeviceMediaValidationEnvironment.unsignedSwiftPMHost()
check(!signedDeviceMediaEnvironment.canRunSignedDeviceMediaValidation, "Unsigned SwiftPM host should not claim signed-device media validation capability")
check(signedDeviceMediaEnvironment.bundleIdentifier == "com.raingodprc.timeslowdown", "Signed-device media environment should preserve production bundle identifier")
check(signedDeviceMediaEnvironment.teamID == nil, "Unsigned media environment should not fake an Apple Developer Team ID")
check(!signedDeviceMediaEnvironment.hasFullXcode, "Unsigned media environment should not pretend full Xcode exists")
check(!signedDeviceMediaEnvironment.hasAppleDeveloperTeam, "Unsigned media environment should not pretend Apple Developer access exists")
check(!signedDeviceMediaEnvironment.signedBundleInstalled, "Unsigned media environment should not claim a signed bundle is installed")
check(!signedDeviceMediaEnvironment.runningOnPhysicalDevice, "Unsigned media environment should not claim physical device execution")
check(signedDeviceMediaEnvironment.photosPermissionMode == .notDetermined, "Unsigned media environment should not claim limited-library Photos permission")
check(!signedDeviceMediaEnvironment.filesExporterAvailable, "Unsigned media environment should not claim Files exporter availability")
check(!signedDeviceMediaEnvironment.networkRequired, "Signed-device media validation scaffold should not require network access")

let mediaPhotoImportRequest = PhotosLibraryByteImportAdapter.request(
    for: photo,
    representation: .thumbnailOnly
)
let mediaVideoImportRequest = PhotosLibraryByteImportAdapter.request(
    for: video,
    representation: .selectedOriginal,
    consentReceiptID: "consent-media-original-demo"
)
check(mediaPhotoImportRequest.isTSDPhotosImportSafe, "Media validation photo import request should be Photos-safe")
check(mediaVideoImportRequest.isTSDPhotosImportSafe, "Media validation video import request should be Photos-safe")
check(mediaVideoImportRequest.allowsOriginalBytes, "Media validation original video request should require explicit consent")
let signedDeviceMediaExportProbe = SignedDeviceMediaExportProbe(
    fileName: shellExport.fileName,
    byteCount: shellExport.data.count,
    entryCount: shellExport.entries.count,
    memoryRightsSafe: shellExport.isMemorySafeDefault,
    canExportAfterSubscriptionEnds: shellExport.canBeGeneratedAfterSubscriptionEnds
)
check(signedDeviceMediaExportProbe.isTSDExportProbeSafe, "Signed-device media export probe should preserve ZIP/export rights boundaries")
let signedDeviceMediaPlan = SignedDeviceMediaValidationScaffold.plan(
    environment: signedDeviceMediaEnvironment,
    importRequests: [mediaPhotoImportRequest, mediaVideoImportRequest],
    exportProbe: signedDeviceMediaExportProbe,
    generatedAt: fixedDate
)
check(signedDeviceMediaPlan.isTSDMediaValidationPlanSafe, "Signed-device media validation plan should preserve TSD media boundaries")
check(signedDeviceMediaPlan.requiresExternalSignedDeviceWork, "Signed-device media plan should honestly require external signed-device work here")
check(signedDeviceMediaPlan.status == .pendingSignedDevice, "Unsigned host media plan should stay pending signed device")
check(!signedDeviceMediaPlan.productionValidationClaimed, "Unsigned host media plan should not claim production validation")
check(signedDeviceMediaPlan.steps.count == 10, "Signed-device media validation plan should define ten required steps")
check(signedDeviceMediaPlan.steps.map(\.kind).contains(.limitedLibraryPickerOpen), "Signed-device media validation should require limited-library picker evidence")
check(signedDeviceMediaPlan.steps.map(\.kind).contains(.userSelectedPhotoImport), "Signed-device media validation should require photo import evidence")
check(signedDeviceMediaPlan.steps.map(\.kind).contains(.userSelectedVideoImport), "Signed-device media validation should require video import evidence")
check(signedDeviceMediaPlan.steps.map(\.kind).contains(.fileExporterPresentation), "Signed-device media validation should require Files exporter evidence")
check(signedDeviceMediaPlan.steps.map(\.kind).contains(.exportedZIPReopen), "Signed-device media validation should require exported ZIP re-open evidence")
check(signedDeviceMediaPlan.steps.allSatisfy(\.requiresPhysicalDevice), "Signed-device media validation steps should require a physical device")
check(signedDeviceMediaPlan.steps.allSatisfy(\.forbidsRawMediaEvidence), "Signed-device media validation steps should forbid raw media evidence")
let signedDeviceMediaPendingReceipt = SignedDeviceMediaValidationScaffold.pendingReceipt(
    for: signedDeviceMediaPlan,
    createdAt: fixedDate
)
check(signedDeviceMediaPendingReceipt.isHonestPendingReceipt, "Signed-device media pending receipt should be honest and non-production")
check(!signedDeviceMediaPendingReceipt.isProductionPassReceipt, "Pending signed-device media receipt should not pass production gate")
check(!signedDeviceMediaPendingReceipt.isProductionPhotosImportPassReceipt, "Pending media receipt should not satisfy Photos import gate")
check(!signedDeviceMediaPendingReceipt.isProductionFilesExportPassReceipt, "Pending media receipt should not satisfy Files export gate")
check(signedDeviceMediaPendingReceipt.stepReceipts.count == signedDeviceMediaPlan.steps.count, "Signed-device media pending receipt should mirror all plan steps")
check(signedDeviceMediaPendingReceipt.stepReceipts.allSatisfy { !$0.containsRawMediaEvidence }, "Signed-device media receipts should not contain raw media evidence")

let signedDeviceMediaPassStepReceipts = signedDeviceMediaPlan.steps.map { step in
    SignedDeviceMediaValidationStepReceipt(
        id: "signed-device-media-step-receipt-\(TrustDigest.checksum([signedDeviceMediaPlan.id, step.id, "pass"]).prefix(12))",
        stepID: step.id,
        status: .passed,
        evidenceDigest: TrustDigest.checksum([step.id, "signed-device-media-pass"])
    )
}
let signedDeviceMediaPassReceipt = SignedDeviceMediaValidationReceipt(
    id: "signed-device-media-receipt-\(TrustDigest.checksum([signedDeviceMediaPlan.id, "pass"]).prefix(12))",
    planID: signedDeviceMediaPlan.id,
    status: .passed,
    stepReceipts: signedDeviceMediaPassStepReceipts,
    productionValidationClaimed: true,
    canSatisfyPhotosImportGate: true,
    canSatisfyFilesExportGate: true,
    createdAt: fixedDate
)
check(signedDeviceMediaPassReceipt.isProductionPassReceipt, "Complete signed-device media pass receipt should satisfy production media gate")
check(signedDeviceMediaPassReceipt.isProductionPhotosImportPassReceipt, "Complete signed-device media pass receipt should satisfy Photos import gate")
check(signedDeviceMediaPassReceipt.isProductionFilesExportPassReceipt, "Complete signed-device media pass receipt should satisfy Files export gate")

let rawEvidenceMediaReceipt = SignedDeviceMediaValidationReceipt(
    id: "signed-device-media-receipt-\(TrustDigest.checksum([signedDeviceMediaPlan.id, "raw-evidence"]).prefix(12))",
    planID: signedDeviceMediaPlan.id,
    status: .passed,
    stepReceipts: signedDeviceMediaPassStepReceipts,
    productionValidationClaimed: true,
    canSatisfyPhotosImportGate: true,
    canSatisfyFilesExportGate: true,
    containsRawMediaInEvidence: true,
    createdAt: fixedDate
)
check(!rawEvidenceMediaReceipt.isProductionPassReceipt, "Signed-device media receipt should fail if evidence stores raw media")
check(!rawEvidenceMediaReceipt.isProductionPhotosImportPassReceipt, "Raw-media evidence should not satisfy Photos import gate")
check(!rawEvidenceMediaReceipt.isProductionFilesExportPassReceipt, "Raw-media evidence should not satisfy Files export gate")

let missingFilesStepMediaReceipt = SignedDeviceMediaValidationReceipt(
    id: "signed-device-media-receipt-\(TrustDigest.checksum([signedDeviceMediaPlan.id, "missing-files"]).prefix(12))",
    planID: signedDeviceMediaPlan.id,
    status: .passed,
    stepReceipts: signedDeviceMediaPassStepReceipts.filter { $0.stepID != "signed-device-media-exported-zip-reopen" },
    productionValidationClaimed: true,
    canSatisfyPhotosImportGate: true,
    canSatisfyFilesExportGate: true,
    createdAt: fixedDate
)
check(!missingFilesStepMediaReceipt.isProductionPassReceipt, "Signed-device media receipt should fail when required ZIP re-open evidence is missing")
check(missingFilesStepMediaReceipt.isProductionPhotosImportPassReceipt, "Missing Files-only evidence should not erase a complete Photos pass")
check(!missingFilesStepMediaReceipt.isProductionFilesExportPassReceipt, "Missing ZIP re-open evidence should fail Files export gate")

let cryptoKitMediaVaultPlan = CryptoKitMediaVaultImplementationPlan.plan(for: secureEnclaveKeyReceipt.record)
check(cryptoKitMediaVaultPlan.isTSDProductionCryptoPlanSafe, "CryptoKit media vault plan should preserve TSD production crypto boundaries")
check(cryptoKitMediaVaultPlan.contentEncryptionAlgorithm == "CryptoKit.AES.GCM", "CryptoKit media vault should use AES.GCM content encryption")
check(cryptoKitMediaVaultPlan.keyAgreementAlgorithm == "SecureEnclave.P256.KeyAgreement.PrivateKey", "CryptoKit media vault should plan Secure Enclave P256 key agreement")
check(cryptoKitMediaVaultPlan.keyDerivationAlgorithm == "HKDF-SHA256-per-record", "CryptoKit media vault should derive per-record keys with HKDF-SHA256")
check(cryptoKitMediaVaultPlan.secureEnclavePrivateKeyPolicy == "non-extractable-this-device-only", "CryptoKit media vault should require non-extractable this-device-only private keys")
check(cryptoKitMediaVaultPlan.noncePolicy == "random-96-bit-nonce-required", "CryptoKit media vault should require random nonces")
check(!cryptoKitMediaVaultPlan.storesContentEncryptionKey, "CryptoKit media vault should not persist content encryption keys")
check(!cryptoKitMediaVaultPlan.storesPlaintextMedia, "CryptoKit media vault should not persist plaintext media")
check(!cryptoKitMediaVaultPlan.allowsCloudUpload, "CryptoKit media vault should not require cloud upload")
check(!cryptoKitMediaVaultPlan.allowsAIProviderAccess, "CryptoKit media vault should not allow AI/provider access")
check(cryptoKitMediaVaultPlan.requiresSignedDeviceValidation, "CryptoKit media vault should still require signed-device validation")

check(KeychainProductionChecklist.rows.count == 5, "Keychain production checklist should track five rows after v54")
check(KeychainProductionChecklist.rows.first { $0.id == "keychain-record-store" }?.status == .poc, "Keychain record store adapter should be PoC after v41")
check(KeychainProductionChecklist.rows.first { $0.id == "cryptokit-media-vault-plan" }?.status == .poc, "CryptoKit media vault plan should be PoC after v52")
check(KeychainProductionChecklist.rows.first { $0.id == "secure-enclave-key-plan" }?.status == .poc, "Secure Enclave key plan should be PoC after v53")
check(KeychainProductionChecklist.rows.first { $0.id == "signed-device-validation-scaffold" }?.status == .poc, "Signed-device validation scaffold should be PoC after v54")
check(KeychainProductionChecklist.rows.filter { $0.status == .todo }.count == 1, "Signed-device Keychain test should remain todo")

let gatewayRequest = DeepSeekGatewayClientPlan.request(for: aiEnvelope, accountID: deviceKey.accountID)
check(gatewayRequest.endpointPath == "/v1/ai/tasks/weekly-chapter", "Gateway request should target the TSD backend task endpoint")
check(gatewayRequest.requiresServerSideCredential, "Gateway request should require server-side provider credential")
check(!gatewayRequest.containsProviderAPIKey, "Client gateway request must not contain provider API key")
check(!gatewayRequest.sendsRawMedia, "Client gateway request must not send raw media")
check(!gatewayRequest.sendsFullArchive, "Client gateway request must not send full archive")
check(gatewayRequest.fallbackMode == "local-rules", "Gateway request should preserve local fallback")

let serverGateway = DeepSeekServerGatewayPlan.envelope(
    for: gatewayRequest,
    accountID: deviceKey.accountID,
    consentReceiptID: "consent-weekly-chapter-demo"
)
check(serverGateway.request == gatewayRequest, "Server gateway envelope should preserve the reviewed client gateway request")
check(serverGateway.headers["Content-Type"] == "application/json", "Server gateway envelope should use JSON content type")
check(serverGateway.headers["Idempotency-Key"] == gatewayRequest.idempotencyKey, "Server gateway envelope should surface the idempotency key")
check(serverGateway.headers["X-TSD-AI-Consent"] == "consent-weekly-chapter-demo", "Server gateway envelope should include an AI consent receipt")
check(serverGateway.headers["X-TSD-Task-Digest"] == aiEnvelope.minimalPayloadDigest, "Server gateway envelope should surface the minimal task digest")
check(!serverGateway.requestBodyDigest.isEmpty, "Server gateway envelope should include an auditable body digest")
check(serverGateway.auditEventName == "ai.weekly_chapter.requested", "Server gateway envelope should name the AI audit event")
check(serverGateway.serverCredentialLocation == "server-secret-manager", "Provider credentials should live in the server secret manager")
check(!serverGateway.providerCredentialVisibleToClient, "Provider credential should never be visible to the client")
check(serverGateway.requiresAuthenticatedAccount, "Server gateway should require an authenticated account")
check(serverGateway.requiresUserConsent, "Server gateway should require user consent")
check(serverGateway.budgetCeilingCents == aiEnvelope.maxBudgetCents, "Server gateway budget ceiling should match the reviewed AI envelope")
check(serverGateway.retentionHours <= 24, "Server gateway should keep transient task retention short")
check(serverGateway.dataResidencyPolicy == "user-region-pinned", "Server gateway should declare user-region-pinned data residency")
check(serverGateway.queueName == "ai-weekly-chapter", "Server gateway should route to the weekly chapter queue")
check(serverGateway.mockableWithoutProviderCall, "Server gateway should be mockable without a provider call")
check(serverGateway.responseContract.acceptedStatusCode == 202, "Server gateway response contract should use 202 for queued AI work")
check(serverGateway.responseContract.completedStatusCode == 200, "Server gateway response contract should use 200 for completed AI work")
check(serverGateway.responseContract.localFallbackStatusCode == 206, "Server gateway response contract should support partial local fallback")
check(serverGateway.responseContract.providerUnavailableStatusCode == 503, "Server gateway response contract should model provider outage")
check(serverGateway.responseContract.budgetExceededStatusCode == 402, "Server gateway response contract should model budget exceeded")
check(!serverGateway.responseContract.responseContainsProviderAPIKey, "Server gateway response should not expose provider API key")
check(!serverGateway.responseContract.responseContainsRawMedia, "Server gateway response should not echo raw media")
check(!serverGateway.responseContract.responseContainsFullMemoryArchive, "Server gateway response should not echo full memory archive")
check(serverGateway.responseContract.returnsGatewayJobID, "Server gateway response should return a gateway job ID")
check(serverGateway.responseContract.returnsAuditEventID, "Server gateway response should return an audit event ID")
check(serverGateway.responseContract.returnsModelName, "Server gateway response should name the model used")
check(serverGateway.responseContract.returnsCostEstimate, "Server gateway response should return a cost estimate")
check(serverGateway.responseContract.preservesUserEditableDraft, "Server gateway response should preserve user-editable draft semantics")
check(serverGateway.isProductionSafeBoundary, "Server gateway envelope should be production-safe at the client/backend boundary")

let backendEndpoint = DeepSeekBackendEndpointPlan.contract(for: serverGateway)
check(backendEndpoint.method == "POST", "Backend endpoint contract should use POST")
check(backendEndpoint.endpointPath == "/v1/ai/tasks/weekly-chapter", "Backend endpoint contract should target the weekly chapter task endpoint")
check(backendEndpoint.acceptsOnlyGatewayEnvelope, "Backend endpoint should accept only the reviewed gateway envelope shape")
check(backendEndpoint.requiresAuthenticatedAccount, "Backend endpoint should require an authenticated account")
check(backendEndpoint.requiresConsentReceipt, "Backend endpoint should require a consent receipt")
check(backendEndpoint.requiresIdempotencyKey, "Backend endpoint should require idempotency")
check(backendEndpoint.requiresTaskDigest, "Backend endpoint should require the minimal task digest")
check(backendEndpoint.requiresBudgetCeiling, "Backend endpoint should enforce the reviewed budget ceiling")
check(backendEndpoint.dataResidencyPolicy == "user-region-pinned", "Backend endpoint should preserve user-region-pinned policy")
check(backendEndpoint.queueName == "ai-weekly-chapter", "Backend endpoint should route to the weekly chapter queue")
check(backendEndpoint.retentionHours <= 24, "Backend endpoint should keep transient task retention short")
check(backendEndpoint.providerProxyRequest.provider == "deepseek", "Provider proxy should target DeepSeek")
check(backendEndpoint.providerProxyRequest.model == "deepseek-v4-flash", "Provider proxy should lock to deepseek-v4-flash")
check(backendEndpoint.providerProxyRequest.providerEndpoint.hasPrefix("https://"), "Provider proxy endpoint should require TLS")
check(backendEndpoint.providerProxyRequest.credentialLocation == "server-secret-manager", "Provider proxy should keep credentials in the server secret manager")
check(!backendEndpoint.providerProxyRequest.credentialVisibleToClient, "Provider proxy credential should never be visible to the client")
check(backendEndpoint.providerProxyRequest.mapsFromGatewayBodyDigest == serverGateway.requestBodyDigest, "Provider proxy should map from the reviewed gateway body digest")
check(backendEndpoint.providerProxyRequest.allowedProviderRequestKeys.contains("messages"), "Provider proxy should allow only minimal model messages")
check(backendEndpoint.providerProxyRequest.forbiddenProviderRequestKeys.contains("provider_api_key"), "Provider proxy should forbid provider API key in request body")
check(backendEndpoint.providerProxyRequest.forbiddenProviderRequestKeys.contains("raw_media_binary"), "Provider proxy should forbid raw media binary")
check(backendEndpoint.providerProxyRequest.forbiddenProviderRequestKeys.contains("full_memory_archive"), "Provider proxy should forbid full memory archive")
check(backendEndpoint.providerProxyRequest.forbiddenProviderRequestKeys.contains("contacts"), "Provider proxy should forbid contacts")
check(backendEndpoint.providerProxyRequest.forbiddenProviderRequestKeys.contains("gps_trace"), "Provider proxy should forbid GPS traces")
check(backendEndpoint.providerProxyRequest.forbiddenProviderRequestKeys.contains("face_embeddings"), "Provider proxy should forbid face embeddings")
check(backendEndpoint.providerProxyRequest.forbiddenProviderRequestKeys.contains("subscription_state"), "Provider proxy should forbid subscription state")
check(!backendEndpoint.providerProxyRequest.bodyContainsRawMedia, "Provider proxy request should not contain raw media")
check(!backendEndpoint.providerProxyRequest.bodyContainsFullMemoryArchive, "Provider proxy request should not contain full memory archive")
check(!backendEndpoint.providerProxyRequest.bodyContainsContacts, "Provider proxy request should not contain contacts")
check(!backendEndpoint.providerProxyRequest.bodyContainsGPS, "Provider proxy request should not contain GPS")
check(!backendEndpoint.providerProxyRequest.bodyContainsFaceEmbeddings, "Provider proxy request should not contain face embeddings")
check(!backendEndpoint.providerProxyRequest.bodyContainsSubscriptionState, "Provider proxy request should not contain subscription state")
check(backendEndpoint.providerProxyRequest.maxPromptRetentionHours <= 24, "Provider proxy prompt retention should be short")
check(backendEndpoint.providerProxyRequest.maxBudgetCents == serverGateway.budgetCeilingCents, "Provider proxy budget should match the server gateway budget")
check(backendEndpoint.providerProxyRequest.isSafeProviderProxyBoundary, "Provider proxy request should be safe at the backend/provider boundary")
check(backendEndpoint.providerProxyResponse.returnsEditableDraft, "Provider proxy response should return an editable draft")
check(backendEndpoint.providerProxyResponse.returnsSourceTrace, "Provider proxy response should return source trace")
check(backendEndpoint.providerProxyResponse.returnsResponseDigest, "Provider proxy response should return response digest")
check(backendEndpoint.providerProxyResponse.returnsGatewayJobID, "Provider proxy response should return gateway job ID")
check(backendEndpoint.providerProxyResponse.returnsAuditEventID, "Provider proxy response should return audit event ID")
check(backendEndpoint.providerProxyResponse.returnsCostEstimate, "Provider proxy response should return cost estimate")
check(!backendEndpoint.providerProxyResponse.storesRawProviderTranscript, "Provider proxy response should not store raw provider transcript")
check(!backendEndpoint.providerProxyResponse.responseContainsProviderCredential, "Provider proxy response should not contain provider credential")
check(!backendEndpoint.providerProxyResponse.responseContainsRawMedia, "Provider proxy response should not contain raw media")
check(!backendEndpoint.providerProxyResponse.responseContainsFullMemoryArchive, "Provider proxy response should not contain full memory archive")
check(!backendEndpoint.providerProxyResponse.responseContainsContacts, "Provider proxy response should not contain contacts")
check(!backendEndpoint.providerProxyResponse.responseContainsGPS, "Provider proxy response should not contain GPS")
check(!backendEndpoint.providerProxyResponse.responseContainsFaceEmbeddings, "Provider proxy response should not contain face embeddings")
check(backendEndpoint.providerProxyResponse.isSafeBackendResponseBoundary, "Provider proxy response should be safe at the backend/client boundary")
check(backendEndpoint.isProductionEndpointSafe, "Backend endpoint contract should be production-safe as a service boundary")

let endpointExecutionRequest = DeepSeekBackendEndpointExecutionRequest.reviewed(
    endpoint: backendEndpoint,
    gateway: serverGateway,
    mode: .localStub
)
check(endpointExecutionRequest.hasRequiredExecutionContext, "Endpoint execution request should carry auth, consent, idempotency, digest, and budget context")
check(endpointExecutionRequest.endpointID == backendEndpoint.id, "Endpoint execution request should bind to the reviewed endpoint contract")
check(endpointExecutionRequest.gatewayID == serverGateway.id, "Endpoint execution request should bind to the reviewed server gateway")
check(endpointExecutionRequest.consentReceiptID == serverGateway.consentReceiptID, "Endpoint execution request should carry the reviewed consent receipt")
check(endpointExecutionRequest.idempotencyKey == serverGateway.request.idempotencyKey, "Endpoint execution request should carry the reviewed idempotency key")
check(endpointExecutionRequest.taskDigest == aiEnvelope.minimalPayloadDigest, "Endpoint execution request should carry the minimal AI task digest")
check(endpointExecutionRequest.requestBodyDigest == serverGateway.requestBodyDigest, "Endpoint execution request should carry the reviewed body digest")
check(endpointExecutionRequest.budgetCeilingCents == serverGateway.budgetCeilingCents, "Endpoint execution request should carry the reviewed budget ceiling")

let endpointExecutionReceipt = DeepSeekBackendEndpointExecutionHarness.execute(
    endpoint: backendEndpoint,
    gateway: serverGateway,
    request: endpointExecutionRequest
)
check(endpointExecutionReceipt.status == .stubPassed, "Local endpoint execution harness should pass as a stub when all gates are safe")
check(endpointExecutionReceipt.isHonestLocalStubPass, "Local endpoint execution receipt should be honest about stub trust")
check(endpointExecutionReceipt.endpointContractSafe, "Endpoint execution harness should validate endpoint contract safety")
check(endpointExecutionReceipt.gatewayBoundarySafe, "Endpoint execution harness should validate gateway boundary safety")
check(endpointExecutionReceipt.providerProxyRequestSafe, "Endpoint execution harness should validate provider proxy request safety")
check(endpointExecutionReceipt.providerProxyResponseSafe, "Endpoint execution harness should validate provider proxy response safety")
check(endpointExecutionReceipt.requiredInputGatePassed, "Endpoint execution harness should validate required input gates")
check(endpointExecutionReceipt.forbiddenFieldGatePassed, "Endpoint execution harness should validate forbidden payload gates")
check(endpointExecutionReceipt.requestWasMocked, "Local endpoint execution receipt should disclose stub execution")
check(!endpointExecutionReceipt.providerCallPerformed, "Local endpoint execution harness must not claim a provider call")
check(!endpointExecutionReceipt.canBeUsedForProductionAIGate, "Local endpoint execution harness must not unlock production AI")
check(!endpointExecutionReceipt.canBeUsedForAppStoreGate, "Local endpoint execution harness must not unlock App Store AI gate")

let providerModeExecutionRequest = DeepSeekBackendEndpointExecutionRequest.reviewed(
    endpoint: backendEndpoint,
    gateway: serverGateway,
    mode: .providerGateway
)
let providerModeExecutionReceipt = DeepSeekBackendEndpointExecutionHarness.execute(
    endpoint: backendEndpoint,
    gateway: serverGateway,
    request: providerModeExecutionRequest
)
check(providerModeExecutionReceipt.status == .providerRequired, "Provider mode endpoint execution should require real backend/provider evidence")
check(!providerModeExecutionReceipt.requestWasMocked, "Provider mode endpoint execution should not be marked mocked")
check(!providerModeExecutionReceipt.providerCallPerformed, "Provider mode endpoint execution harness should not perform the provider call locally")
check(!providerModeExecutionReceipt.canBeUsedForProductionAIGate, "Provider-required receipt should not unlock production AI")
check(!providerModeExecutionReceipt.canBeUsedForAppStoreGate, "Provider-required receipt should not unlock App Store AI gate")

var missingAuthExecutionRequest = endpointExecutionRequest
missingAuthExecutionRequest.accountAuthenticated = false
let missingAuthExecutionReceipt = DeepSeekBackendEndpointExecutionHarness.execute(
    endpoint: backendEndpoint,
    gateway: serverGateway,
    request: missingAuthExecutionRequest
)
check(missingAuthExecutionReceipt.status == .failed, "Endpoint execution harness should fail when account auth is missing")
check(!missingAuthExecutionReceipt.requiredInputGatePassed, "Missing auth should fail the required input gate")
check(!missingAuthExecutionReceipt.canBeUsedForProductionAIGate, "Missing auth failure should not unlock production AI")

var missingConsentExecutionRequest = endpointExecutionRequest
missingConsentExecutionRequest.consentReceiptID = ""
let missingConsentExecutionReceipt = DeepSeekBackendEndpointExecutionHarness.execute(
    endpoint: backendEndpoint,
    gateway: serverGateway,
    request: missingConsentExecutionRequest
)
check(missingConsentExecutionReceipt.status == .failed, "Endpoint execution harness should fail when consent receipt is missing")
check(!missingConsentExecutionReceipt.requiredInputGatePassed, "Missing consent should fail the required input gate")

var unsafeProviderEndpoint = backendEndpoint
unsafeProviderEndpoint.providerProxyRequest.bodyContainsRawMedia = true
let unsafeProviderExecutionReceipt = DeepSeekBackendEndpointExecutionHarness.execute(
    endpoint: unsafeProviderEndpoint,
    gateway: serverGateway,
    request: endpointExecutionRequest
)
check(unsafeProviderExecutionReceipt.status == .failed, "Endpoint execution harness should fail unsafe provider proxy fields")
check(!unsafeProviderExecutionReceipt.providerProxyRequestSafe, "Raw media in provider proxy should fail provider request safety")
check(!unsafeProviderExecutionReceipt.forbiddenFieldGatePassed, "Raw media in provider proxy should fail forbidden field gate")

let gatewayValidationEnvironment = DeepSeekGatewayValidationEnvironment.swiftPMHostWithoutBackend()
check(gatewayValidationEnvironment.model == "deepseek-v4-flash", "Gateway validation environment should target the selected DeepSeek PoC model")
check(!gatewayValidationEnvironment.usesClientProviderKey, "Gateway validation environment should forbid client-side provider keys")
check(gatewayValidationEnvironment.providerCredentialLocation == "server-secret-manager", "Gateway validation environment should point provider credentials to the server secret manager")
check(!gatewayValidationEnvironment.canRunProviderValidation, "SwiftPM host without backend should not claim provider validation capability")

let gatewayValidationPlan = DeepSeekGatewayIntegrationScaffold.plan(
    environment: gatewayValidationEnvironment,
    gateway: serverGateway
)
check(gatewayValidationPlan.gateway == serverGateway, "Gateway validation plan should preserve the reviewed server gateway envelope")
check(gatewayValidationPlan.productionModel == "deepseek-v4-flash", "Gateway validation plan should lock to deepseek-v4-flash")
check(gatewayValidationPlan.requiresExternalBackendWork, "Gateway validation plan should honestly require external backend work here")
check(!gatewayValidationPlan.isReadyForProviderValidation, "Gateway validation plan should not be provider-ready on this host")
check(gatewayValidationPlan.steps.count == 10, "Gateway validation plan should track ten backend/provider validation steps")
check(gatewayValidationPlan.steps.contains { $0.kind == .serverSecretManagerCheck && $0.requiresProviderCredential }, "Gateway validation should require server secret manager credential check")
check(gatewayValidationPlan.steps.contains { $0.kind == .clientKeyAbsenceCheck && $0.canRunOnSwiftPMHost }, "Gateway validation should include host-runnable client key absence check")
check(gatewayValidationPlan.steps.contains { $0.kind == .mockGatewayRoundTrip && !$0.requiredForAppStoreGate }, "Mock gateway round trip should not be an App Store gate by itself")
check(gatewayValidationPlan.steps.contains { $0.kind == .providerGatewayRoundTrip && $0.requiredForAppStoreGate }, "Provider gateway round trip should remain required for App Store AI gate")

let pendingGatewayReceipt = DeepSeekGatewayIntegrationScaffold.pendingBackendReceipt(for: gatewayValidationPlan)
check(pendingGatewayReceipt.status == .pendingBackend, "Gateway receipt should be pending until real backend/provider validation exists")
check(!pendingGatewayReceipt.providerCallPerformed, "Pending gateway receipt should not claim a provider call")
check(!pendingGatewayReceipt.requestWasMocked, "Pending gateway receipt should not claim even a mock run")
check(!pendingGatewayReceipt.canBeUsedForProductionAIGate, "Pending gateway receipt should not unlock production AI")
check(!pendingGatewayReceipt.canBeUsedForAppStoreGate, "Pending gateway receipt should not unlock App Store gate")
check(!pendingGatewayReceipt.isProviderPassReceipt, "Pending gateway receipt should not be a provider pass receipt")
check(pendingGatewayReceipt.stepReceipts.count == gatewayValidationPlan.steps.count, "Pending gateway receipt should mirror all validation steps")
check(pendingGatewayReceipt.stepReceipts.allSatisfy { $0.status == .pendingBackend }, "Pending gateway receipt steps should remain pending, not mock-passed")
check(pendingGatewayReceipt.stepReceipts.allSatisfy { !$0.containsProviderCredential }, "Gateway validation receipts should never contain provider credentials")
check(pendingGatewayReceipt.stepReceipts.allSatisfy { !$0.containsRawMedia }, "Gateway validation receipts should never contain raw media")
check(pendingGatewayReceipt.stepReceipts.allSatisfy { !$0.containsFullMemoryArchive }, "Gateway validation receipts should never contain full memory archives")

let mockGatewayReceipt = DeepSeekGatewayIntegrationScaffold.mockPassedReceipt(for: gatewayValidationPlan)
check(mockGatewayReceipt.status == .mockPassed, "Mock gateway receipt should be explicitly marked mockPassed")
check(mockGatewayReceipt.requestWasMocked, "Mock gateway receipt should disclose that it was mocked")
check(!mockGatewayReceipt.providerCallPerformed, "Mock gateway receipt should not claim a provider call")
check(!mockGatewayReceipt.canBeUsedForProductionAIGate, "Mock gateway receipt should not unlock production AI")
check(!mockGatewayReceipt.canBeUsedForAppStoreGate, "Mock gateway receipt should not unlock App Store gate")
check(!mockGatewayReceipt.isProviderPassReceipt, "Mock gateway receipt should remain distinct from provider pass receipt")
check(mockGatewayReceipt.gatewayJobID != nil, "Mock gateway receipt may return a mock job ID for UI/backend contract testing")
check(mockGatewayReceipt.auditEventID != nil, "Mock gateway receipt may return a mock audit event ID for UI/backend contract testing")
check(!mockGatewayReceipt.responseContainsProviderCredential, "Mock gateway response should not contain provider credential")
check(!mockGatewayReceipt.responseContainsRawMedia, "Mock gateway response should not contain raw media")
check(!mockGatewayReceipt.responseContainsFullMemoryArchive, "Mock gateway response should not contain full memory archive")

let deployedGatewayEnvironment = DeepSeekGatewayValidationEnvironment(
    backendBaseURL: "https://api.timeslowdown.example",
    hasServerRuntime: true,
    hasServerSecretManager: true,
    hasProviderCredentialOnServer: true,
    canReachProvider: true
)
check(deployedGatewayEnvironment.canRunProviderValidation, "Deployed gateway environment should be provider-validation capable when server prerequisites exist")

let deployedGatewayValidationPlan = DeepSeekGatewayIntegrationScaffold.plan(
    environment: deployedGatewayEnvironment,
    gateway: serverGateway
)
check(deployedGatewayValidationPlan.isReadyForProviderValidation, "Deployed gateway validation plan should be ready for provider round trip")
check(!deployedGatewayValidationPlan.requiresExternalBackendWork, "Deployed gateway validation plan should not require missing external backend work")

let providerTestRequest = DeepSeekGatewayIntegrationTestRunner.request(
    for: deployedGatewayValidationPlan,
    mode: .providerGateway
)
check(providerTestRequest.mode == .providerGateway, "Provider test request should be in provider gateway mode")
check(providerTestRequest.backendBaseURL == "https://api.timeslowdown.example", "Provider test request should use deployed backend base URL")
check(providerTestRequest.endpointPath == "/v1/ai/tasks/weekly-chapter", "Provider test request should target weekly chapter backend endpoint")
check(providerTestRequest.headers["X-TSD-Gateway-Test-Mode"] == "providerGateway", "Provider test request should carry test mode header")
check(providerTestRequest.headers["Authorization"] == nil, "Provider test request must not carry Authorization provider credentials")
check(providerTestRequest.headers["X-DeepSeek-API-Key"] == nil, "Provider test request must not carry DeepSeek API key")
check(!providerTestRequest.containsProviderCredential, "Provider test request should not contain provider credential")
check(!providerTestRequest.containsRawMedia, "Provider test request should not contain raw media")
check(!providerTestRequest.containsFullMemoryArchive, "Provider test request should not contain full archive")
check(providerTestRequest.allowedResponseKeys.contains("editable_draft"), "Provider test request should expect editable draft response key")
check(providerTestRequest.forbiddenResponseKeys.contains("provider_api_key"), "Provider test request should forbid provider key echo")
check(providerTestRequest.forbiddenResponseKeys.contains("raw_media_binary"), "Provider test request should forbid raw media echo")
check(providerTestRequest.redactedCurlCommand.contains("<minimal-weekly-chapter-task-body-redacted>"), "Provider test request should expose only a redacted command")
check(providerTestRequest.requiresTLS, "Provider test request should require TLS")
check(providerTestRequest.backendBaseURL.hasPrefix("https://"), "Provider test request should use https backend URL")
check(providerTestRequest.routesThroughTSDBackend, "Provider test request should route through TSD backend")
check(providerTestRequest.usesServerCredentialProxy, "Provider test request should use server credential proxy")
check(!providerTestRequest.redactedCurlCommand.localizedCaseInsensitiveContains("Authorization: Bearer"), "Provider test request should not include bearer authorization in redacted command")
check(!providerTestRequest.redactedCommandContainsProviderSecretToken, "Provider test request should not include provider-secret-shaped tokens in redacted command")
check(providerTestRequest.isSafeToExecuteAgainstBackend, "Provider test request should be safe to execute against TSD backend")

let providerTestResultDigest = TrustDigest.checksum([
    providerTestRequest.id,
    providerTestRequest.bodyDigest,
    "provider-result"
])
let providerTestResult = DeepSeekGatewayIntegrationTestResult(
    id: "deepseek-provider-result-\(providerTestResultDigest.prefix(12))",
    request: providerTestRequest,
    statusCode: providerTestRequest.expectedStatusCode,
    gatewayJobID: "job-\(providerTestResultDigest.prefix(8))",
    auditEventID: "audit-\(providerTestResultDigest.prefix(8))",
    costEstimateCents: 2,
    retentionHours: 1,
    responseDigest: providerTestResultDigest,
    requestWasMocked: false,
    providerCallPerformed: true
)
check(providerTestResult.isSafeProviderRoundTripEvidence, "Provider test result should qualify as safe provider round-trip evidence")

let providerPassReceipt = DeepSeekGatewayIntegrationTestRunner.providerPassedReceipt(
    for: deployedGatewayValidationPlan,
    result: providerTestResult
)
check(providerPassReceipt.status == .providerPassed, "Provider result should promote to providerPassed receipt")
check(providerPassReceipt.isProviderPassReceipt, "Provider pass receipt should satisfy production provider pass requirements")
check(providerPassReceipt.canBeUsedForProductionAIGate, "Provider pass receipt should unlock production AI gate")
check(providerPassReceipt.canBeUsedForAppStoreGate, "Provider pass receipt should unlock App Store AI gate")
check(providerPassReceipt.stepReceipts.allSatisfy { $0.status == .providerPassed }, "Provider pass receipt steps should all be providerPassed")
check(providerPassReceipt.costEstimateCents == 2, "Provider pass receipt should preserve cost estimate")

let liveProbePayload = DeepSeekBackendRoundTripProbe.payload(
    for: deployedGatewayValidationPlan,
    claimed: moments
)
check(liveProbePayload.isSafeForBackendRoundTrip, "Live DeepSeek backend probe payload should contain only minimal safe fields")
check(liveProbePayload.userSelectedClaims.count == 3, "Live DeepSeek backend probe payload should carry at most three user-selected claims")
check(liveProbePayload.mediaKindsOnly.allSatisfy { ["image", "video", "link", "none"].contains($0) }, "Live DeepSeek backend probe payload should carry media kinds only")
check(!liveProbePayload.containsRawMedia, "Live DeepSeek backend probe payload should not contain raw media")
check(!liveProbePayload.containsFullMemoryArchive, "Live DeepSeek backend probe payload should not contain a full archive")
check(!liveProbePayload.clientProviderCredentialPresent, "Live DeepSeek backend probe payload should not contain provider credentials")
let liveProbePayloadData = try DeepSeekBackendRoundTripProbe.encodedPayload(liveProbePayload)
let liveProbePayloadText = String(data: liveProbePayloadData, encoding: .utf8) ?? ""
check(liveProbePayloadText.contains("userSelectedClaims") || liveProbePayloadText.contains("user_selected_claims"), "Live DeepSeek backend probe payload should encode selected claims")
check(!liveProbePayloadText.localizedCaseInsensitiveContains("RAW_ORIGINAL"), "Live DeepSeek backend probe payload should not encode raw media bytes")
check(!liveProbePayloadText.localizedCaseInsensitiveContains("provider_api_key"), "Live DeepSeek backend probe payload should not encode provider key fields")

let liveProbeResponse = DeepSeekBackendRoundTripProbeResponse(
    gatewayJobID: "job-\(providerTestResultDigest.prefix(8))",
    auditEventID: "audit-\(providerTestResultDigest.prefix(8))",
    costEstimateCents: 2,
    retentionHours: 1,
    responseDigest: providerTestResultDigest,
    requestWasMocked: false,
    providerCallPerformed: true
)
let liveProbeReceipt = DeepSeekBackendRoundTripProbe.receipt(
    plan: deployedGatewayValidationPlan,
    request: providerTestRequest,
    payload: liveProbePayload,
    statusCode: providerTestRequest.expectedStatusCode,
    response: liveProbeResponse
)
check(liveProbeReceipt.status == .providerPassed, "Live DeepSeek backend probe response should promote to providerPassed when evidence is safe")
check(liveProbeReceipt.canUnlockProductionAI, "Live DeepSeek backend probe should unlock production AI only with provider pass receipt")
check(liveProbeReceipt.canUnlockAppStoreAIGate, "Live DeepSeek backend probe should unlock App Store AI gate only with provider pass receipt")
check(liveProbeReceipt.providerReceipt?.isProviderPassReceipt == true, "Live DeepSeek backend probe should reuse the provider pass receipt gate")

let unsafeLiveProbeResponse = DeepSeekBackendRoundTripProbeResponse(
    gatewayJobID: "job-unsafe",
    auditEventID: "audit-unsafe",
    costEstimateCents: 2,
    retentionHours: 1,
    responseDigest: TrustDigest.checksum(["unsafe-live-probe"]),
    requestWasMocked: false,
    providerCallPerformed: true,
    responseContainsRawMedia: true
)
let unsafeLiveProbeReceipt = DeepSeekBackendRoundTripProbe.receipt(
    plan: deployedGatewayValidationPlan,
    request: providerTestRequest,
    payload: liveProbePayload,
    statusCode: providerTestRequest.expectedStatusCode,
    response: unsafeLiveProbeResponse
)
check(unsafeLiveProbeReceipt.status == .failed, "Live DeepSeek backend probe should fail unsafe response evidence")
check(!unsafeLiveProbeReceipt.canUnlockProductionAI, "Unsafe live probe response should not unlock production AI")
check(!unsafeLiveProbeReceipt.canUnlockAppStoreAIGate, "Unsafe live probe response should not unlock App Store AI gate")

let notConfiguredLiveProbeReceipt = DeepSeekBackendRoundTripProbe.notConfiguredReceipt()
check(notConfiguredLiveProbeReceipt.status == .notConfigured, "Live DeepSeek backend probe should be explicitly notConfigured without env vars")
check(!notConfiguredLiveProbeReceipt.canUnlockProductionAI, "Not-configured live probe should not unlock production AI")
check(!notConfiguredLiveProbeReceipt.canUnlockAppStoreAIGate, "Not-configured live probe should not unlock App Store AI gate")

let optionalLiveProbeReceipt = try runOptionalLiveDeepSeekBackendProbe(
    plan: deployedGatewayValidationPlan,
    request: providerTestRequest,
    payload: liveProbePayload
)
if optionalLiveProbeReceipt.status == .notConfigured {
    print("DeepSeek live backend probe skipped: set TSD_DEEPSEEK_BACKEND_BASE_URL and TSD_DEEPSEEK_TEST_TOKEN to require a real provider round trip.")
} else {
    check(optionalLiveProbeReceipt.status == .providerPassed, "Configured live DeepSeek backend probe should pass provider evidence")
    check(optionalLiveProbeReceipt.canUnlockProductionAI, "Configured live DeepSeek backend probe should unlock production AI only after provider pass")
    check(optionalLiveProbeReceipt.canUnlockAppStoreAIGate, "Configured live DeepSeek backend probe should unlock App Store AI gate only after provider pass")
}

let mockIntegrationRequest = DeepSeekGatewayIntegrationTestRunner.request(
    for: deployedGatewayValidationPlan,
    mode: .mockGateway
)
let mockIntegrationResult = DeepSeekGatewayIntegrationTestRunner.mockResult(for: mockIntegrationRequest)
check(!mockIntegrationResult.isSafeProviderRoundTripEvidence, "Mock integration result should not qualify as provider evidence")
let failedProviderReceipt = DeepSeekGatewayIntegrationTestRunner.providerPassedReceipt(
    for: deployedGatewayValidationPlan,
    result: mockIntegrationResult
)
check(failedProviderReceipt.status == .failed, "Mock result should fail provider receipt promotion")
check(!failedProviderReceipt.canBeUsedForProductionAIGate, "Failed provider receipt should not unlock production AI")
check(!failedProviderReceipt.canBeUsedForAppStoreGate, "Failed provider receipt should not unlock App Store gate")

let archivePlan = ExportArchivePlan.zipPlan(for: exportManifest)
check(archivePlan.fileName.hasSuffix(".zip"), "Export archive should use a zip file name")
check(archivePlan.generatedOnDevice, "Export archive should be generated on device by default")
check(archivePlan.canBeGeneratedAfterSubscriptionEnds, "Export archive should remain available after subscription ends")
check(archivePlan.entries.map(\.kind).contains(.manifest), "Export archive should include manifest")
check(archivePlan.entries.map(\.kind).contains(.revisits), "Export archive should include revisit layers")
check(archivePlan.entries.map(\.kind).contains(.recallInteractions), "Export archive should include active-recall interactions")
check(archivePlan.entries.map(\.kind).contains(.lifeMarks), "Export archive should include the Life Marks provenance ledger")
check(archivePlan.entries.map(\.kind).contains(.mediaIndex), "Export archive should include media index")
check(archivePlan.entries.map(\.kind).contains(.deletionRights), "Export archive should include deletion rights")
check(archivePlan.entries.allSatisfy { !$0.containsRawMedia }, "Export archive plan should not include raw media by default")

let zipPackage = try OnDeviceExportZIPBuilder.package(
    for: archivePlan,
    slices: [slice, updated],
    chapters: [chapter],
    deletionReceipt: deletion
)
check(zipPackage.fileName == archivePlan.fileName, "Export ZIP package should preserve archive file name")
check(zipPackage.hasZIPMagic, "Export ZIP package should start with local file header magic")
check(zipPackage.hasEndOfCentralDirectory, "Export ZIP package should include end-of-central-directory record")
check(zipPackage.centralDirectoryRecordCount == archivePlan.entries.count, "Export ZIP package should include one central-directory record per export entry")
check(zipPackage.entries.map(\.path).contains("manifest.json"), "Export ZIP package should include manifest.json")
check(zipPackage.entries.map(\.path).contains("memories/revisits.json"), "Export ZIP package should include revisit layers")
check(zipPackage.entries.map(\.path).contains("memories/recall-interactions.json"), "Export ZIP package should include active-recall interactions")
check(zipPackage.entries.map(\.path).contains("memories/life-marks.json"), "Export ZIP package should include Life Marks")
check(zipPackage.entries.map(\.path).contains("media/index.json"), "Export ZIP package should include media index")
check(zipPackage.entries.map(\.path).contains("rights/deletion-receipt-template.json"), "Export ZIP package should include deletion rights")
check(zipPackage.entries.allSatisfy { $0.uncompressedSize > 0 }, "Export ZIP entries should contain encoded JSON documents")
check(zipPackage.entries.allSatisfy { !$0.containsRawMedia && !$0.containsAITranscript }, "Export ZIP should exclude raw media and AI transcripts by default")
check(zipPackage.isMemorySafeDefault, "Export ZIP should preserve local generation and non-hostage export rights")

let thumbnailsOnlyMediaExport = RawMediaExportPolicyPlan.thumbnailsOnlyEnvelope(
    for: archivePlan,
    slices: [slice, updated]
)
check(thumbnailsOnlyMediaExport.baseArchivePlan == archivePlan, "Raw media export policy should preserve the reviewed base archive plan")
check(thumbnailsOnlyMediaExport.selection.mode == .thumbnailsOnly, "Raw media export should default to thumbnails-only mode")
check(!thumbnailsOnlyMediaExport.selection.userExplicitlyOptedIn, "Thumbnails-only export should not pretend the user opted into raw originals")
check(thumbnailsOnlyMediaExport.selection.selectedAnchorIDs.isEmpty, "Thumbnails-only export should not select raw original anchors")
check(!thumbnailsOnlyMediaExport.defaultIncludesRawOriginals, "Raw media export should never include originals by default")
check(!thumbnailsOnlyMediaExport.includesRawOriginals, "Thumbnails-only export should not include raw originals")
check(!thumbnailsOnlyMediaExport.includesAITranscripts, "Raw media export should exclude AI transcripts")
check(thumbnailsOnlyMediaExport.generatedOnDevice, "Raw media export should be generated on device")
check(!thumbnailsOnlyMediaExport.cloudUploadRequired, "Raw media export should not require cloud upload")
check(!thumbnailsOnlyMediaExport.syncRequired, "Raw media export should not require sync")
check(!thumbnailsOnlyMediaExport.providerUploadRequired, "Raw media export should not require provider upload")
check(thumbnailsOnlyMediaExport.canBeGeneratedAfterSubscriptionEnds, "Raw media export should remain available after subscription ends")
check(thumbnailsOnlyMediaExport.postSubscriptionAccessAllowed, "Raw media export should preserve post-subscription access")
check(thumbnailsOnlyMediaExport.encryptionPolicy == "device-key-encrypted-staging", "Raw media export should stage with device-key encryption policy")
check(thumbnailsOnlyMediaExport.stagingPolicy == "staged-files-export-with-user-confirmation", "Raw media export should require user-confirmed staged Files export")
check(thumbnailsOnlyMediaExport.maxStageSizeMB <= 2048, "Raw media export should define a bounded stage size")
check(thumbnailsOnlyMediaExport.filesAppExportReady, "Raw media export should be ready for Files/export UX handoff")
check(thumbnailsOnlyMediaExport.manifestPath == "media/raw-media-manifest.json", "Raw media export should define a media manifest path")
check(thumbnailsOnlyMediaExport.manifestItems.count == 2, "Raw media export manifest should include the two media anchors")
check(thumbnailsOnlyMediaExport.manifestItems.allSatisfy { !$0.includesRawOriginal && $0.originalPath == nil }, "Thumbnails-only manifest should not include original file paths")
check(thumbnailsOnlyMediaExport.childOrFamilyMediaCaution, "Raw media export should flag child/family media review when applicable")
check(thumbnailsOnlyMediaExport.responseContract.stagedStatusCode == 202, "Raw media export response should support staged work")
check(thumbnailsOnlyMediaExport.responseContract.completedStatusCode == 200, "Raw media export response should support completion")
check(thumbnailsOnlyMediaExport.responseContract.storageLimitStatusCode == 413, "Raw media export response should model large media limits")
check(thumbnailsOnlyMediaExport.responseContract.returnsMediaManifest, "Raw media export response should return a manifest")
check(thumbnailsOnlyMediaExport.responseContract.returnsExportReceiptID, "Raw media export response should return an export receipt")
check(thumbnailsOnlyMediaExport.responseContract.returnsStagedFileToken, "Raw media export response should return staged file token")
check(!thumbnailsOnlyMediaExport.responseContract.responseContainsProviderCredential, "Raw media export response should not expose provider credentials")
check(!thumbnailsOnlyMediaExport.responseContract.responseContainsAITranscript, "Raw media export response should not include AI transcripts")
check(!thumbnailsOnlyMediaExport.responseContract.uploadsToCloudByDefault, "Raw media export response should not upload to cloud by default")
check(thumbnailsOnlyMediaExport.responseContract.userCanCancelStaging, "Raw media export should let users cancel staging")
check(thumbnailsOnlyMediaExport.responseContract.supportsResume, "Raw media export should support resume for large staged exports")
check(thumbnailsOnlyMediaExport.isMemoryRightsSafe, "Thumbnails-only raw media export envelope should be memory-rights safe")

let selectedOriginalsExport = RawMediaExportPolicyPlan.selectedOriginalsEnvelope(
    for: archivePlan,
    slices: [slice, updated],
    selectedAnchorIDs: [photo.id.uuidString],
    consentReceiptID: "consent-raw-media-export-demo"
)
check(selectedOriginalsExport.selection.mode == .selectedOriginals, "Selected originals export should use selected-originals mode")
check(selectedOriginalsExport.selection.userExplicitlyOptedIn, "Selected originals export should require explicit user opt-in")
check(selectedOriginalsExport.selection.consentReceiptID == "consent-raw-media-export-demo", "Selected originals export should preserve consent receipt")
check(selectedOriginalsExport.selection.selectedAnchorIDs == [photo.id.uuidString], "Selected originals export should preserve the selected media anchor")
check(selectedOriginalsExport.selection.allowsRawOriginals, "Selected originals export should only allow raw media after explicit consent")
check(selectedOriginalsExport.includesRawOriginals, "Selected originals export should include at least one raw original")
check(selectedOriginalsExport.manifestItems.filter { $0.includesRawOriginal }.count == 1, "Selected originals export should include only the user-selected original")
check(selectedOriginalsExport.manifestItems.first { $0.anchorID == photo.id.uuidString }?.originalPath?.contains("media/originals/") == true, "Selected original should receive an original export path")
check(selectedOriginalsExport.manifestItems.first { $0.anchorID == video.id.uuidString }?.originalPath == nil, "Unselected media anchor should remain thumbnail-only")
check(!selectedOriginalsExport.includesAITranscripts, "Selected originals export should still exclude AI transcripts")
check(!selectedOriginalsExport.cloudUploadRequired, "Selected originals export should not require cloud upload")
check(!selectedOriginalsExport.providerUploadRequired, "Selected originals export should not require AI/provider upload")
check(selectedOriginalsExport.isMemoryRightsSafe, "Selected originals raw media export envelope should be memory-rights safe after consent")

let unsafeLabelPhoto = MediaAnchor(kind: .image, label: "2026/park raw.heic", note: "路径字符也要安全")
let unsafeLabelSlice = SliceFactory.quickMark(title: "文件名安全", tags: ["照片"], media: unsafeLabelPhoto)
let unsafeLabelExport = RawMediaExportPolicyPlan.selectedOriginalsEnvelope(
    for: archivePlan,
    slices: [unsafeLabelSlice],
    selectedAnchorIDs: [unsafeLabelPhoto.id.uuidString],
    consentReceiptID: "consent-raw-media-export-safe-filename"
)
let unsafeOriginalPath = unsafeLabelExport.manifestItems.first?.originalPath ?? ""
check(!unsafeOriginalPath.contains("/park raw"), "Raw media original path should not embed unsafe user label path separators")
check(unsafeOriginalPath.contains("2026-park-raw.heic"), "Raw media original path should sanitize user labels into safe filenames")

let photoThumbnailBytes = Data("thumb-photo-demo".utf8)
let photoOriginalBytes = Data("RAW_ORIGINAL_PHOTO_BYTES_DO_NOT_INCLUDE_BY_DEFAULT".utf8)
let videoThumbnailBytes = Data("thumb-video-demo".utf8)
let videoOriginalBytes = Data("RAW_ORIGINAL_VIDEO_BYTES_UNSELECTED".utf8)

let thumbnailImportRequest = PhotosLibraryByteImportAdapter.request(
    for: photo,
    representation: .thumbnailOnly
)
check(thumbnailImportRequest.isTSDPhotosImportSafe, "Photos byte import request should be safe for limited-library thumbnail import")
check(!thumbnailImportRequest.allowsOriginalBytes, "Thumbnail import request should not allow original bytes")
let thumbnailImport = try PhotosLibraryByteImportAdapter.importPayload(
    request: thumbnailImportRequest,
    thumbnailData: photoThumbnailBytes
)
check(thumbnailImport.payload.anchorID == photo.id.uuidString, "Photos byte import should preserve anchor ID")
check(thumbnailImport.thumbnailByteCount == photoThumbnailBytes.count, "Photos byte import should preserve thumbnail byte count")
check(thumbnailImport.originalByteCount == 0, "Thumbnail import should not include original bytes")
check(thumbnailImport.request.usesLimitedLibraryPicker, "Photos byte import should use limited library picker")
check(!thumbnailImport.request.readsEntireLibrary, "Photos byte import should not scan the full library")
check(!thumbnailImport.request.infersLocation, "Photos byte import should not infer location")
check(!thumbnailImport.request.performsFaceRecognition, "Photos byte import should not perform face recognition")
check(!thumbnailImport.request.uploadsToCloud, "Photos byte import should not upload to cloud")
check(thumbnailImport.stripsLocationMetadataByPolicy, "Photos byte import should strip location metadata by policy")
check(thumbnailImport.isTSDPhotosByteImportSafe, "Photos thumbnail byte import should be TSD-safe")

do {
    _ = try PhotosLibraryByteImportAdapter.importPayload(
        request: thumbnailImportRequest,
        thumbnailData: photoThumbnailBytes,
        originalData: photoOriginalBytes
    )
    check(false, "Thumbnail import should reject unconsented original bytes")
} catch PhotosLibraryByteImporterError.originalBytesNotAllowed(let anchorID) {
    check(anchorID == photo.id.uuidString, "Original-not-allowed error should name the anchor")
}

let selectedOriginalImportRequest = PhotosLibraryByteImportAdapter.request(
    for: photo,
    representation: .selectedOriginal,
    consentReceiptID: "consent-raw-media-export-demo"
)
check(selectedOriginalImportRequest.allowsOriginalBytes, "Selected-original Photos import should allow original bytes after consent")
let selectedOriginalImport = try PhotosLibraryByteImportAdapter.importPayload(
    request: selectedOriginalImportRequest,
    thumbnailData: photoThumbnailBytes,
    originalData: photoOriginalBytes
)
check(selectedOriginalImport.originalByteCount == photoOriginalBytes.count, "Selected-original Photos import should preserve original byte count")
check(selectedOriginalImport.payload.originalData == photoOriginalBytes, "Selected-original Photos import should preserve original bytes")
check(selectedOriginalImport.isTSDPhotosByteImportSafe, "Selected-original Photos import should be TSD-safe after consent")

let thumbnailVaultRequest = E2EEMediaVaultAdapter.sealRequest(
    payload: thumbnailImport.payload,
    deviceKey: deviceKey,
    sourceRequestID: thumbnailImport.request.id
)
check(thumbnailVaultRequest.isTSDMediaVaultSealSafe, "Thumbnail media vault seal request should be safe")
check(!thumbnailVaultRequest.storesPlaintextThumbnail, "Media vault should not persist plaintext thumbnails")
check(!thumbnailVaultRequest.storesPlaintextOriginal, "Media vault should not persist plaintext originals")
check(!thumbnailVaultRequest.uploadsToCloud, "Media vault seal should not upload to cloud")
check(!thumbnailVaultRequest.allowsAIProviderAccess, "Media vault seal should not allow AI/provider media access")
check(thumbnailVaultRequest.canExportAfterSubscriptionEnds, "Media vault should preserve post-subscription export")
check(thumbnailVaultRequest.canDeleteAfterSubscriptionEnds, "Media vault should preserve post-subscription deletion")
let thumbnailVaultRecord = try E2EEMediaVaultAdapter.seal(thumbnailVaultRequest)
check(thumbnailVaultRecord.isTSDMediaVaultSafe, "Thumbnail media vault record should be TSD-safe")
check(thumbnailVaultRecord.anchorID == photo.id.uuidString, "Media vault should preserve anchor ID")
check(thumbnailVaultRecord.keyID == deviceKey.keyID, "Media vault should bind to the device key")
check(thumbnailVaultRecord.additionalAuthenticatedData.contains("anchor:\(photo.id.uuidString)"), "Media vault AAD should bind the anchor")
check(thumbnailVaultRecord.thumbnailCiphertext != photoThumbnailBytes, "Media vault should not store thumbnail plaintext as ciphertext")
check(!thumbnailVaultRecord.containsOriginalCiphertext, "Thumbnail-only vault record should not contain original ciphertext")
check(!thumbnailVaultRecord.rawPlaintextPersistedInRecord, "Media vault record should not persist raw plaintext")
let unsealedThumbnailPayload = try E2EEMediaVaultAdapter.unseal(thumbnailVaultRecord, with: deviceKey)
check(unsealedThumbnailPayload == thumbnailImport.payload, "Media vault should unseal thumbnail payload for export")

let selectedOriginalVaultRequest = E2EEMediaVaultAdapter.sealRequest(
    payload: selectedOriginalImport.payload,
    deviceKey: deviceKey,
    sourceRequestID: selectedOriginalImport.request.id,
    consentReceiptID: selectedOriginalImport.request.consentReceiptID
)
check(selectedOriginalVaultRequest.isTSDMediaVaultSealSafe, "Selected-original media vault seal request should be safe")
let selectedOriginalVaultRecord = try E2EEMediaVaultAdapter.seal(selectedOriginalVaultRequest)
check(selectedOriginalVaultRecord.isTSDMediaVaultSafe, "Selected-original media vault record should be TSD-safe")
check(selectedOriginalVaultRecord.containsOriginalCiphertext, "Selected-original vault record should contain original ciphertext")
check(selectedOriginalVaultRecord.originalCiphertext != photoOriginalBytes, "Media vault should not store original plaintext as ciphertext")
check(selectedOriginalVaultRecord.consentReceiptID == "consent-raw-media-export-demo", "Media vault record should preserve raw media consent receipt")
check(CryptoKitMediaVaultEnvelopeFactory.canUseCryptoKit, "CryptoKit media vault envelope factory should compile with CryptoKit on supported Apple platforms")
let cryptoKitMediaVaultEnvelope = try CryptoKitMediaVaultEnvelopeFactory.envelope(
    for: selectedOriginalVaultRecord,
    plan: cryptoKitMediaVaultPlan
)
check(cryptoKitMediaVaultEnvelope.isTSDCryptoKitEnvelopeSafe, "CryptoKit media vault envelope should preserve TSD production crypto boundaries")
check(cryptoKitMediaVaultEnvelope.sourceRecordID == selectedOriginalVaultRecord.id, "CryptoKit media vault envelope should preserve source vault record ID")
check(cryptoKitMediaVaultEnvelope.anchorID == photo.id.uuidString, "CryptoKit media vault envelope should preserve anchor ID")
check(cryptoKitMediaVaultEnvelope.keyID == deviceKey.keyID, "CryptoKit media vault envelope should bind to device key ID")
check(cryptoKitMediaVaultEnvelope.contentEncryptionAlgorithm == "CryptoKit.AES.GCM", "CryptoKit media vault envelope should use AES.GCM")
check(cryptoKitMediaVaultEnvelope.keyAgreementAlgorithm == "SecureEnclave.P256.KeyAgreement.PrivateKey", "CryptoKit media vault envelope should keep Secure Enclave key agreement plan")
check(cryptoKitMediaVaultEnvelope.keyDerivationAlgorithm == "HKDF-SHA256-per-record", "CryptoKit media vault envelope should keep HKDF plan")
check(cryptoKitMediaVaultEnvelope.noncePolicy == "random-96-bit-nonce-required", "CryptoKit media vault envelope should require random nonces")
check(cryptoKitMediaVaultEnvelope.additionalAuthenticatedData.contains("anchor:\(photo.id.uuidString)"), "CryptoKit media vault envelope should bind AAD to anchor")
check(cryptoKitMediaVaultEnvelope.sealedBoxByteCount > 0, "CryptoKit media vault envelope should produce a sealed box")
check(cryptoKitMediaVaultEnvelope.authenticationTagByteCount == 16, "CryptoKit media vault envelope should include a 128-bit authentication tag")
check(!cryptoKitMediaVaultEnvelope.storesPlaintextMedia, "CryptoKit media vault envelope should not store plaintext media")
check(!cryptoKitMediaVaultEnvelope.storesContentEncryptionKey, "CryptoKit media vault envelope should not store content encryption key")
check(!cryptoKitMediaVaultEnvelope.allowsCloudUpload, "CryptoKit media vault envelope should not upload to cloud")
check(!cryptoKitMediaVaultEnvelope.allowsAIProviderAccess, "CryptoKit media vault envelope should not allow AI/provider access")
check(cryptoKitMediaVaultEnvelope.requiresSignedDeviceValidation, "CryptoKit media vault envelope should still require signed-device validation")
let unsealedSelectedOriginalPayload = try E2EEMediaVaultAdapter.unseal(selectedOriginalVaultRecord, with: deviceKey)
check(unsealedSelectedOriginalPayload == selectedOriginalImport.payload, "Media vault should unseal selected-original payload for staged export")
let wrongDeviceKey = KeychainVaultStub.bootstrapDeviceKey(
    accountID: "acct-other",
    deviceName: "Other iPhone",
    createdAt: fixedDate
)
do {
    _ = try E2EEMediaVaultAdapter.unseal(selectedOriginalVaultRecord, with: wrongDeviceKey)
    check(false, "Media vault should reject unseal with the wrong device key")
} catch E2EEMediaVaultAdapterError.wrongDeviceKey(let recordID) {
    check(recordID == selectedOriginalVaultRecord.id, "Wrong-key media vault error should name the record")
}
let mediaVaultDeletion = E2EEMediaVaultAdapter.deletionReceipt(
    for: selectedOriginalVaultRecord,
    deletedAt: fixedDate
)
check(mediaVaultDeletion.recordID == selectedOriginalVaultRecord.id, "Media vault deletion receipt should preserve record ID")
check(mediaVaultDeletion.deletedLocalCiphertext, "Media vault deletion should delete local ciphertext")
check(mediaVaultDeletion.deletedThumbnailCiphertext, "Media vault deletion should delete thumbnail ciphertext")
check(mediaVaultDeletion.deletedOriginalCiphertext, "Media vault deletion should delete original ciphertext")
check(mediaVaultDeletion.canBeRequestedAfterSubscriptionEnds, "Media vault deletion should remain available after subscription ends")
check(!mediaVaultDeletion.containsRawMediaPayload, "Media vault deletion receipt should not carry raw media payload")
check(mediaVaultDeletion.isTSDMediaDeletionSafe, "Media vault deletion receipt should be TSD-safe")

let rawMediaAssets = [
    unsealedSelectedOriginalPayload,
    RawMediaAssetPayload(anchorID: video.id.uuidString, thumbnailData: videoThumbnailBytes, originalData: videoOriginalBytes)
]

let thumbnailStagePackage = try RawMediaStagedExportBuilder.package(
    for: thumbnailsOnlyMediaExport,
    assets: rawMediaAssets
)
check(thumbnailStagePackage.fileName.hasSuffix(".zip"), "Raw media staged export should use a ZIP filename")
check(thumbnailStagePackage.hasZIPMagic, "Raw media staged export should start with ZIP magic")
check(thumbnailStagePackage.hasEndOfCentralDirectory, "Raw media staged export should include end-of-central-directory")
check(thumbnailStagePackage.entries.map(\.path).contains("media/raw-media-manifest.json"), "Raw media staged export should include the media manifest")
check(thumbnailStagePackage.entries.map(\.path).contains("rights/raw-media-export-receipt.json"), "Raw media staged export should include an export receipt")
check(thumbnailStagePackage.entries.filter { $0.path.hasPrefix("media/thumbnails/") }.count == 2, "Thumbnail-only staged export should write two thumbnail files")
check(thumbnailStagePackage.entries.filter(\.containsRawMedia).isEmpty, "Thumbnail-only staged export should not mark raw media entries")
check(!thumbnailStagePackage.containsRawOriginals, "Thumbnail-only staged export should not contain raw originals")
check(!thumbnailStagePackage.containsAITranscripts, "Raw media staged export should not contain AI transcripts")
check(thumbnailStagePackage.data.range(of: photoOriginalBytes) == nil, "Thumbnail-only staged export must not contain provided photo original bytes")
check(thumbnailStagePackage.data.range(of: videoOriginalBytes) == nil, "Thumbnail-only staged export must not contain provided video original bytes")
check(thumbnailStagePackage.data.range(of: photoThumbnailBytes) != nil, "Thumbnail-only staged export should contain provided photo thumbnail bytes")
check(thumbnailStagePackage.centralDirectoryRecordCount == thumbnailStagePackage.entries.count, "Thumbnail-only staged export should list every staged file in central directory")
check(thumbnailStagePackage.receipt.rawOriginalCount == 0, "Thumbnail-only staged export receipt should record zero raw originals")
check(thumbnailStagePackage.receipt.encryptedStagingPolicy == "device-key-encrypted-staging", "Raw media staged export receipt should preserve encrypted staging policy")
check(thumbnailStagePackage.data.range(of: Data(thumbnailStagePackage.receipt.id.utf8)) != nil, "Raw media staged export ZIP should contain the returned receipt ID")
check(thumbnailStagePackage.isTSDRawMediaRightsSafe, "Thumbnail-only staged export should preserve TSD raw media rights")

let selectedOriginalsStagePackage = try RawMediaStagedExportBuilder.package(
    for: selectedOriginalsExport,
    assets: rawMediaAssets
)
check(selectedOriginalsStagePackage.containsRawOriginals, "Selected-originals staged export should contain a selected raw original")
check(selectedOriginalsStagePackage.entries.filter(\.containsRawMedia).count == 1, "Selected-originals staged export should write exactly one raw original")
check(selectedOriginalsStagePackage.entries.contains { $0.path.contains("media/originals/") && $0.containsRawMedia }, "Selected-originals staged export should include an original media path")
check(selectedOriginalsStagePackage.data.range(of: photoOriginalBytes) != nil, "Selected-originals staged export should contain the opted-in photo original bytes")
check(selectedOriginalsStagePackage.data.range(of: videoOriginalBytes) == nil, "Selected-originals staged export must not contain unselected video original bytes")
check(selectedOriginalsStagePackage.receipt.consentReceiptID == "consent-raw-media-export-demo", "Selected-originals staged export receipt should preserve consent")
check(selectedOriginalsStagePackage.receipt.rawOriginalCount == 1, "Selected-originals staged export receipt should count one raw original")
check(selectedOriginalsStagePackage.centralDirectoryRecordCount == selectedOriginalsStagePackage.entries.count, "Selected-originals staged export should list every staged file in central directory")
check(selectedOriginalsStagePackage.isTSDRawMediaRightsSafe, "Selected-originals staged export should preserve TSD raw media rights after consent")

do {
    _ = try RawMediaStagedExportBuilder.package(
        for: selectedOriginalsExport,
        assets: [
            RawMediaAssetPayload(anchorID: photo.id.uuidString, thumbnailData: photoThumbnailBytes),
            RawMediaAssetPayload(anchorID: video.id.uuidString, thumbnailData: videoThumbnailBytes)
        ]
    )
    check(false, "Selected-originals staged export should reject missing original bytes")
} catch RawMediaStagedExportBuilderError.missingOriginal(let anchorID) {
    check(anchorID == photo.id.uuidString, "Missing original error should name the selected anchor")
}

let deletionRequest = DeletionAPIRequest.request(for: deletion, accountID: deviceKey.accountID)
check(deletionRequest.endpointPath == "/v1/account/deletion-receipts", "Deletion API request should target receipt endpoint")
check(deletionRequest.requiresAuthenticatedUser, "Deletion API request should require authenticated user")
check(deletionRequest.canBeCreatedAfterSubscriptionEnds, "Deletion API request should remain available after subscription ends")
check(!deletionRequest.containsRawMemoryPayload, "Deletion API request should not carry raw memory payload")
check(deletionRequest.retryPolicy == "idempotent-retry-24h", "Deletion API request should have idempotent retry policy")

let deletionEnvelope = DeletionAPIClientPlan.envelope(for: deletionRequest, exportPackage: zipPackage)
check(deletionEnvelope.request == deletionRequest, "Deletion API envelope should preserve the reviewed request")
check(deletionEnvelope.headers["Content-Type"] == "application/json", "Deletion API envelope should use JSON content type")
check(deletionEnvelope.headers["Idempotency-Key"] == deletionRequest.idempotencyKey, "Deletion API envelope should surface the idempotency key")
check(deletionEnvelope.headers["X-TSD-Deletion-Receipt"] == deletion.id, "Deletion API envelope should surface the deletion receipt ID")
check(deletionEnvelope.exportFileName == zipPackage.fileName, "Deletion API envelope should remember the export offered before deletion")
check(!deletionEnvelope.bodyDigest.isEmpty, "Deletion API envelope should include an auditable body digest")
check(deletionEnvelope.auditEventName == "account.deletion.requested", "Deletion API envelope should name the audit event")
check(deletionEnvelope.requiresExportOpportunityBeforeSubmission, "Deletion API envelope should require an export opportunity before submission")
check(deletionEnvelope.userCanRetainExportAfterSubscriptionEnds, "Deletion API envelope should preserve post-subscription export rights")
check(!deletionEnvelope.transportContainsRawMemoryPayload, "Deletion API envelope transport should not carry raw memory payload")
check(deletionEnvelope.responseContract.acceptedStatusCode == 202, "Deletion API response contract should use 202 for queued deletion")
check(deletionEnvelope.responseContract.alreadyQueuedStatusCode == 200, "Deletion API response contract should allow idempotent already-queued responses")
check(deletionEnvelope.responseContract.reauthenticationStatusCode == 401, "Deletion API response contract should require reauthentication when needed")
check(!deletionEnvelope.responseContract.responseContainsRawMemoryPayload, "Deletion API response should not echo raw memory payload")
check(deletionEnvelope.responseContract.returnsDeletionReceiptID, "Deletion API response should return a deletion receipt ID")
check(deletionEnvelope.responseContract.returnsAuditEventID, "Deletion API response should return an audit event ID")
check(deletionEnvelope.responseContract.userCanExportBeforeDeletion, "Deletion API response contract should preserve export-before-delete rights")
check(deletionEnvelope.isPrivacyReviewSafe, "Deletion API envelope should be privacy-review safe")

let deletionService = DeletionServiceIntegrationPlan.envelope(for: deletionEnvelope)
check(deletionService.clientEnvelope == deletionEnvelope, "Deletion service envelope should preserve the client deletion envelope")
check(deletionService.serviceEndpointPath == "/v1/account/deletion-jobs", "Deletion service should target the deletion jobs endpoint")
check(deletionService.queueName == "account-deletion", "Deletion service should use the account-deletion queue")
check(deletionService.jobID.hasPrefix("delete-job-"), "Deletion service should create a deletion job ID")
check(deletionService.deletionReceiptID == deletion.id, "Deletion service should preserve the deletion receipt ID")
check(deletionService.exportFileName == zipPackage.fileName, "Deletion service should preserve the export offered before deletion")
check(deletionService.systemsToErase.contains("encrypted-backup"), "Deletion service should erase encrypted backups")
check(deletionService.systemsToErase.contains("ai-draft-cache"), "Deletion service should erase AI draft cache")
check(deletionService.systemsToErase.contains("thumbnail-cache"), "Deletion service should erase thumbnail cache")
check(deletionService.systemsRequiringTombstone.contains("account-ledger"), "Deletion service should tombstone account ledger")
check(deletionService.systemsRequiringTombstone.contains("billing-entitlement-ledger"), "Deletion service should tombstone billing entitlement ledger")
check(deletionService.freezesNewWritesBeforeErase, "Deletion service should freeze new writes before erase")
check(deletionService.requiresReauthentication, "Deletion service should require reauthentication")
check(deletionService.requiresExportOpportunity, "Deletion service should require export opportunity")
check(deletionService.availableAfterSubscriptionEnds, "Deletion service should remain available after subscription ends")
check(!deletionService.containsRawMemoryPayload, "Deletion service should not carry raw memory payload")
check(!deletionService.containsRawMedia, "Deletion service should not carry raw media")
check(deletionService.maxCompletionHours <= 24, "Deletion service should target completion within 24 hours")
check(deletionService.auditRetentionDays >= 30, "Deletion service should retain minimal audit record long enough for user support")
check(deletionService.backupErasePolicy == "delete-encrypted-backup-and-next-snapshot", "Deletion service should define encrypted backup erasure policy")
check(deletionService.aiDraftErasePolicy == "purge-ai-draft-cache", "Deletion service should define AI draft erasure policy")
check(deletionService.responseContract.acceptedStatusCode == 202, "Deletion service response should use 202 for queued jobs")
check(deletionService.responseContract.completedStatusCode == 200, "Deletion service response should use 200 for completed jobs")
check(deletionService.responseContract.alreadyCompletedStatusCode == 208, "Deletion service response should be idempotent for already completed jobs")
check(deletionService.responseContract.cancellationWindowStatusCode == 409, "Deletion service response should model cancellation-window conflicts")
check(deletionService.responseContract.returnsDeletionReceiptID, "Deletion service response should return deletion receipt ID")
check(deletionService.responseContract.returnsAuditEventID, "Deletion service response should return audit event ID")
check(deletionService.responseContract.returnsTombstoneID, "Deletion service response should return tombstone ID")
check(deletionService.responseContract.returnsPerSystemResults, "Deletion service response should return per-system results")
check(!deletionService.responseContract.responseContainsRawMemoryPayload, "Deletion service response should not echo raw memory payload")
check(!deletionService.responseContract.responseContainsRawMedia, "Deletion service response should not echo raw media")
check(deletionService.responseContract.userCanDownloadReceiptAfterCompletion, "Deletion service response should preserve downloadable completion receipt")
check(deletionService.isDeletionRightsSafe, "Deletion service envelope should be deletion-rights safe")

let deletionLiveProbePayload = DeletionServiceLiveProbe.payload(for: deletionService)
check(deletionLiveProbePayload.isSafeForDeletionServiceProbe, "Deletion live probe payload should be safe for backend execution")
check(deletionLiveProbePayload.deletionReceiptID == deletion.id, "Deletion live probe payload should preserve deletion receipt ID")
check(deletionLiveProbePayload.idempotencyKey == deletionRequest.idempotencyKey, "Deletion live probe payload should preserve idempotency key")
check(deletionLiveProbePayload.systemsToErase.contains("encrypted-backup"), "Deletion live probe payload should include encrypted backup erasure")
check(deletionLiveProbePayload.systemsToErase.contains("ai-draft-cache"), "Deletion live probe payload should include AI draft erasure")
check(deletionLiveProbePayload.systemsToErase.contains("thumbnail-cache"), "Deletion live probe payload should include thumbnail erasure")
check(deletionLiveProbePayload.systemsRequiringTombstone.contains("account-ledger"), "Deletion live probe payload should include account ledger tombstone")
check(deletionLiveProbePayload.requiresReauthentication, "Deletion live probe payload should require reauthentication")
check(deletionLiveProbePayload.requiresExportOpportunity, "Deletion live probe payload should preserve export opportunity")
check(deletionLiveProbePayload.availableAfterSubscriptionEnds, "Deletion live probe payload should remain available after subscription ends")
check(!deletionLiveProbePayload.containsRawMemoryPayload, "Deletion live probe payload should not contain raw memory")
check(!deletionLiveProbePayload.containsRawMedia, "Deletion live probe payload should not contain raw media")
check(deletionLiveProbePayload.testAccountOnly, "Deletion live probe payload should be restricted to test account boundary")
let deletionLiveProbePayloadData = try DeletionServiceLiveProbe.encodedPayload(deletionLiveProbePayload)
let deletionLiveProbePayloadText = String(data: deletionLiveProbePayloadData, encoding: .utf8) ?? ""
check(deletionLiveProbePayloadText.contains("deletion_receipt_id"), "Deletion live probe payload should encode snake_case receipt field")
check(deletionLiveProbePayloadText.contains("test_account_only"), "Deletion live probe payload should encode test account boundary")
check(!deletionLiveProbePayloadText.localizedCaseInsensitiveContains("RAW_ORIGINAL"), "Deletion live probe payload should not encode raw media bytes")

let deletionLiveProbeCompletionDigest = TrustDigest.checksum([
    deletionService.id,
    deletionLiveProbePayload.bodyDigest,
    "completed"
])
let deletionLiveProbeResponse = DeletionServiceLiveProbeResponse(
    deletionReceiptID: deletion.id,
    deletionJobID: deletionService.jobID,
    auditEventID: "audit-\(deletionLiveProbeCompletionDigest.prefix(8))",
    tombstoneID: "tombstone-\(deletionLiveProbeCompletionDigest.prefix(8))",
    perSystemResults: [
        "encrypted-backup": "erased",
        "ai-draft-cache": "erased",
        "thumbnail-cache": "erased"
    ],
    completionReceiptDigest: deletionLiveProbeCompletionDigest,
    status: .completed
)
let deletionLiveProbeReceipt = DeletionServiceLiveProbe.receipt(
    service: deletionService,
    payload: deletionLiveProbePayload,
    statusCode: deletionService.responseContract.completedStatusCode,
    backendBaseURL: "https://api.timeslowdown.example",
    response: deletionLiveProbeResponse
)
check(deletionLiveProbeReceipt.status == .completed, "Deletion live probe should promote completed backend evidence")
check(deletionLiveProbeReceipt.canSatisfyProductionDeletionGate, "Deletion live probe should satisfy production deletion gate when backend evidence is complete")
check(deletionLiveProbeReceipt.canSatisfyAppStoreDeletionGate, "Deletion live probe should satisfy App Store deletion gate only with completed evidence")
check(deletionLiveProbeReceipt.deletionJobID == deletionService.jobID, "Deletion live probe receipt should preserve backend job ID")
check(deletionLiveProbeReceipt.tombstoneID != nil, "Deletion live probe receipt should preserve tombstone ID")

let deletionAcceptedProbeResponse = DeletionServiceLiveProbeResponse(
    deletionReceiptID: deletion.id,
    deletionJobID: deletionService.jobID,
    auditEventID: "audit-\(deletionLiveProbeCompletionDigest.suffix(8))",
    tombstoneID: "tombstone-\(deletionLiveProbeCompletionDigest.suffix(8))",
    perSystemResults: [
        "encrypted-backup": "queued",
        "ai-draft-cache": "queued",
        "thumbnail-cache": "queued"
    ],
    completionReceiptDigest: TrustDigest.checksum(["accepted", deletionService.id]),
    status: .accepted
)
let deletionAcceptedProbeReceipt = DeletionServiceLiveProbe.receipt(
    service: deletionService,
    payload: deletionLiveProbePayload,
    statusCode: deletionService.responseContract.acceptedStatusCode,
    backendBaseURL: "https://api.timeslowdown.example",
    response: deletionAcceptedProbeResponse
)
check(deletionAcceptedProbeReceipt.status == .accepted, "Deletion live probe should accept queued backend evidence")
check(deletionAcceptedProbeReceipt.canSatisfyProductionDeletionGate, "Accepted deletion live probe should satisfy production deletion request gate")
check(!deletionAcceptedProbeReceipt.canSatisfyAppStoreDeletionGate, "Accepted-only deletion probe should not satisfy App Store completion gate")

let unsafeDeletionLiveProbeResponse = DeletionServiceLiveProbeResponse(
    deletionReceiptID: deletion.id,
    deletionJobID: deletionService.jobID,
    auditEventID: "audit-unsafe",
    tombstoneID: "tombstone-unsafe",
    perSystemResults: [
        "encrypted-backup": "erased",
        "ai-draft-cache": "erased",
        "thumbnail-cache": "erased"
    ],
    completionReceiptDigest: TrustDigest.checksum(["unsafe-deletion-live-probe"]),
    status: .completed,
    responseContainsRawMemoryPayload: true
)
let unsafeDeletionLiveProbeReceipt = DeletionServiceLiveProbe.receipt(
    service: deletionService,
    payload: deletionLiveProbePayload,
    statusCode: deletionService.responseContract.completedStatusCode,
    backendBaseURL: "https://api.timeslowdown.example",
    response: unsafeDeletionLiveProbeResponse
)
check(unsafeDeletionLiveProbeReceipt.status == .failed, "Deletion live probe should fail unsafe response evidence")
check(!unsafeDeletionLiveProbeReceipt.canSatisfyProductionDeletionGate, "Unsafe deletion live probe should not satisfy production deletion gate")
check(!unsafeDeletionLiveProbeReceipt.canSatisfyAppStoreDeletionGate, "Unsafe deletion live probe should not satisfy App Store deletion gate")

let notConfiguredDeletionProbeReceipt = DeletionServiceLiveProbe.notConfiguredReceipt()
check(notConfiguredDeletionProbeReceipt.status == .notConfigured, "Deletion live probe should be explicitly notConfigured without env vars")
check(!notConfiguredDeletionProbeReceipt.canSatisfyProductionDeletionGate, "Not-configured deletion probe should not satisfy production deletion gate")
check(!notConfiguredDeletionProbeReceipt.canSatisfyAppStoreDeletionGate, "Not-configured deletion probe should not satisfy App Store deletion gate")

let optionalDeletionProbeReceipt = try runOptionalLiveDeletionServiceProbe(
    service: deletionService,
    payload: deletionLiveProbePayload
)
if optionalDeletionProbeReceipt.status == .notConfigured {
    print("Deletion live service probe skipped: set TSD_DELETION_BACKEND_BASE_URL and TSD_DELETION_TEST_TOKEN to require a real deletion service round trip.")
} else {
    check(optionalDeletionProbeReceipt.canSatisfyProductionDeletionGate, "Configured deletion live probe should satisfy production deletion gate only after safe backend evidence")
    if optionalDeletionProbeReceipt.status == .completed {
        check(optionalDeletionProbeReceipt.canSatisfyAppStoreDeletionGate, "Completed deletion live probe should satisfy App Store deletion gate")
    }
}

let defaultBackendManifest = TSDBackendReleaseManifest()
check(!defaultBackendManifest.usesProductionHTTPSBaseURL, "Default backend manifest should not fake a production HTTPS base URL")
check(defaultBackendManifest.endpointShapeMatchesNativeProbes, "Default backend manifest should preserve native probe endpoint paths")
check(!defaultBackendManifest.hasServerSideCredentialBoundary, "Default backend manifest should not fake server-side provider credentials")
check(!defaultBackendManifest.hasDeletionServiceBoundary, "Default backend manifest should not fake deletion service readiness")
check(defaultBackendManifest.forbidsUnsafeAIPayloads, "Default backend manifest should forbid unsafe AI payloads")
check(!defaultBackendManifest.hasDeployableShape, "Default backend manifest should not claim deployable shape")

let productionBackendManifest = TSDBackendReleaseManifest(
    baseURL: "https://api.timeslowdown.app",
    serverRuntime: "swift-vapor-container",
    serverSecretManager: "server-secret-manager/deepseek-v4-flash",
    deepSeekProviderCredentialStoredServerSide: true,
    deletionWorkerConfigured: true,
    auditLogConfigured: true,
    testAccountBoundaryEnabled: true,
    deletionCompletionReceiptDownloadable: true
)
check(productionBackendManifest.usesProductionHTTPSBaseURL, "Production backend manifest should require HTTPS non-localhost base URL")
check(productionBackendManifest.endpointShapeMatchesNativeProbes, "Production backend manifest should match native live probe endpoint paths")
check(productionBackendManifest.hasServerSideCredentialBoundary, "Production backend manifest should keep DeepSeek credentials server-side")
check(productionBackendManifest.hasDeletionServiceBoundary, "Production backend manifest should configure deletion worker, audit, test-account, and receipt boundaries")
check(productionBackendManifest.hasDeployableShape, "Production backend manifest should have deployable shape only when all backend boundaries are present")

let unreviewedBackendEvidence = TSDBackendReleaseEvidence(manifest: productionBackendManifest)
check(!unreviewedBackendEvidence.canSatisfyBackendDeploymentGate, "Backend evidence should not pass without live receipts and deployment review")
check(unreviewedBackendEvidence.blockerReasons.contains("real DeepSeek provider round trip receipt missing"), "Backend evidence should name missing provider receipt")
check(unreviewedBackendEvidence.blockerReasons.contains("completed deletion service receipt missing"), "Backend evidence should name missing deletion completion receipt")

let reviewedBackendEvidence = TSDBackendReleaseEvidence(
    manifest: productionBackendManifest,
    deepSeekReceipt: liveProbeReceipt,
    deletionReceipt: deletionLiveProbeReceipt,
    deploymentReviewCompleted: true
)
check(reviewedBackendEvidence.canSatisfyBackendDeploymentGate, "Backend evidence should pass only with deployable manifest, live provider receipt, completed deletion receipt, and deployment review")
check(reviewedBackendEvidence.blockerReasons.isEmpty, "Reviewed backend evidence should have no blocker reasons")

let localhostBackendManifest = TSDBackendReleaseManifest(
    baseURL: "https://localhost:8787",
    serverRuntime: "swift-vapor-container",
    serverSecretManager: "server-secret-manager/deepseek-v4-flash",
    deepSeekProviderCredentialStoredServerSide: true,
    deletionWorkerConfigured: true,
    auditLogConfigured: true,
    testAccountBoundaryEnabled: true,
    deletionCompletionReceiptDownloadable: true
)
check(!localhostBackendManifest.usesProductionHTTPSBaseURL, "Backend release manifest should reject localhost even over HTTPS")
check(!TSDBackendReleaseEvidence(manifest: localhostBackendManifest, deepSeekReceipt: liveProbeReceipt, deletionReceipt: deletionLiveProbeReceipt, deploymentReviewCompleted: true).canSatisfyBackendDeploymentGate, "Localhost backend evidence should not satisfy release gate")

check(ProductionImplementationChecklist.rows.count == 7, "Production Implementation Checklist should track seven implementation adapters after v63 backend release manifest")
check(ProductionImplementationChecklist.rows.allSatisfy { $0.status == .poc }, "Implementation adapter rows should remain PoC, not falsely ready")

let buildNotes = TestFlightBuildNotes()
check(buildNotes.buildNumber == "89", "TestFlight build notes should match v89")
check(buildNotes.summary.localizedCaseInsensitiveContains("month and day grouped native Timeline"), "TestFlight build notes should describe the v89 grouped native Timeline")
check(buildNotes.summary.localizedCaseInsensitiveContains("eleven user-observable paths"), "TestFlight build notes should disclose all eleven simulator paths")
check(buildNotes.summary.localizedCaseInsensitiveContains("deterministic active recall"), "TestFlight build notes should retain the v88 active-recall scheduler")
check(buildNotes.summary.localizedCaseInsensitiveContains("Schema v5"), "TestFlight build notes should mention the recall-interaction schema v5 payload")
check(buildNotes.summary.localizedCaseInsensitiveContains("recall-interactions.json"), "TestFlight build notes should disclose the portable recall-interaction ledger")
check(buildNotes.summary.localizedCaseInsensitiveContains("seven-day local anti-nag cooldown"), "TestFlight build notes should preserve quiet-skip anti-nag semantics")
check(buildNotes.summary.localizedCaseInsensitiveContains("durable, source-backed provenance ledger"), "TestFlight build notes should describe the v87 Life Marks ledger")
check(buildNotes.summary.localizedCaseInsensitiveContains("Schema v4"), "TestFlight build notes should mention the Life Marks schema v4 payload")
check(buildNotes.summary.localizedCaseInsensitiveContains("life-marks.json"), "TestFlight build notes should disclose the portable Life Marks ledger")
check(buildNotes.summary.localizedCaseInsensitiveContains("progressive native first-run"), "TestFlight build notes should describe the v86 first-memory experience")
check(buildNotes.summary.localizedCaseInsensitiveContains("one source-backed memory"), "TestFlight build notes should name the first-session outcome")
check(buildNotes.summary.localizedCaseInsensitiveContains("separate versioned local marker"), "TestFlight build notes should disclose onboarding/vault separation")
check(buildNotes.summary.localizedCaseInsensitiveContains("not prerequisites"), "TestFlight build notes should preserve the no-account/no-paywall first-run boundary")
check(buildNotes.summary.localizedCaseInsensitiveContains("formal XCUITest target"), "TestFlight build notes should describe the formal v85 UI testing target")
check(buildNotes.summary.localizedCaseInsensitiveContains("Debug-only deterministic fixtures"), "TestFlight build notes should describe deterministic Debug-only fixtures")
check(buildNotes.summary.localizedCaseInsensitiveContains("production vault"), "TestFlight build notes should disclose production-vault isolation")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("real PhotosPicker"), "TestFlight limitations should not claim real PhotosPicker automation")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("signed-device"), "TestFlight limitations should preserve signed-device evidence boundaries")
check(buildNotes.summary.localizedCaseInsensitiveContains("operational diagnostics"), "TestFlight build notes should describe the v84 diagnostics loop")
check(buildNotes.summary.localizedCaseInsensitiveContains("200 entries and 256KB"), "TestFlight build notes should disclose the bounded local receipt ring")
check(buildNotes.summary.localizedCaseInsensitiveContains("never uploaded"), "TestFlight build notes should disclose the local-only diagnostics boundary")
check(buildNotes.summary.localizedCaseInsensitiveContains("without call stacks"), "TestFlight build notes should disclose the sanitized MetricKit boundary")
check(buildNotes.summary.localizedCaseInsensitiveContains("URL-backed temporary file"), "TestFlight build notes should describe the URL-backed export path")
check(buildNotes.summary.localizedCaseInsensitiveContains("bounded chunks"), "TestFlight build notes should describe bounded thumbnail streaming")
check(buildNotes.summary.localizedCaseInsensitiveContains("E174.1"), "TestFlight build notes should disclose the approved disk-space reason")
check(buildNotes.summary.localizedCaseInsensitiveContains("Schema v3"), "TestFlight build notes should mention the domain-only schema v3 payload")
check(buildNotes.summary.localizedCaseInsensitiveContains("monotonic vault revision"), "TestFlight build notes should mention revision-keyed persistence")
check(buildNotes.summary.localizedCaseInsensitiveContains("current tab"), "TestFlight build notes should disclose that session navigation is excluded from the vault")
check(buildNotes.summary.localizedCaseInsensitiveContains("garbage-collects"), "TestFlight build notes should mention post-commit media garbage collection")
check(buildNotes.summary.localizedCaseInsensitiveContains("Failed vault commits never delete media"), "TestFlight build notes should preserve the failed-commit media invariant")
check(buildNotes.summary.localizedCaseInsensitiveContains("versioned native vault"), "TestFlight build notes should mention the versioned native vault")
check(buildNotes.summary.localizedCaseInsensitiveContains("last-known-good"), "TestFlight build notes should mention last-known-good recovery")
check(buildNotes.summary.localizedCaseInsensitiveContains("future schema"), "TestFlight build notes should mention future-schema refusal")
check(buildNotes.summary.localizedCaseInsensitiveContains("semantic zoom"), "TestFlight build notes should mention native Meadow semantic zoom")
check(buildNotes.summary.localizedCaseInsensitiveContains("source-backed"), "TestFlight build notes should keep the Meadow traceable to real sources")
check(buildNotes.summary.localizedCaseInsensitiveContains("chronological river"), "TestFlight build notes should mention the plain linear Meadow route")
check(buildNotes.summary.localizedCaseInsensitiveContains("video poster extraction"), "TestFlight build notes should mention the real video poster pipeline")
check(buildNotes.summary.localizedCaseInsensitiveContains("file representation"), "TestFlight build notes should mention file-based video transfer")
check(buildNotes.summary.localizedCaseInsensitiveContains("editable memory slices"), "TestFlight build notes should mention editable slice detail")
check(buildNotes.summary.localizedCaseInsensitiveContains("undo deletion"), "TestFlight build notes should mention deletion undo")
check(buildNotes.summary.localizedCaseInsensitiveContains("does not load the entire video into Data"), "TestFlight build notes should keep raw-video memory limits honest")
check(buildNotes.summary.localizedCaseInsensitiveContains("local persistence"), "TestFlight build notes should mention local persistence")
check(buildNotes.summary.localizedCaseInsensitiveContains("empty vault"), "TestFlight build notes should mention the honest first-launch vault")
check(buildNotes.summary.localizedCaseInsensitiveContains("corrupt data"), "TestFlight build notes should mention corrupt backup recovery")
check(buildNotes.summary.localizedCaseInsensitiveContains("Memory Camera home"), "TestFlight build notes should mention the native product home")
check(buildNotes.summary.localizedCaseInsensitiveContains("Life Marks"), "TestFlight build notes should mention the private achievement gallery")
check(buildNotes.summary.localizedCaseInsensitiveContains("Yesterday Echo"), "TestFlight build notes should mention Yesterday Echo")
check(buildNotes.summary.localizedCaseInsensitiveContains("Weekend Workbench"), "TestFlight build notes should mention the weekend workbench")
check(buildNotes.summary.localizedCaseInsensitiveContains("revisit export"), "TestFlight build notes should mention revisit export")
check(buildNotes.summary.localizedCaseInsensitiveContains("media"), "TestFlight build notes should mention media capture")
check(buildNotes.summary.localizedCaseInsensitiveContains("Photos-library"), "TestFlight build notes should mention Photos-library byte import")
check(buildNotes.summary.localizedCaseInsensitiveContains("E2EE media vault"), "TestFlight build notes should mention E2EE media vault adapter")
check(buildNotes.summary.localizedCaseInsensitiveContains("CryptoKit"), "TestFlight build notes should mention CryptoKit media vault envelope")
check(buildNotes.summary.localizedCaseInsensitiveContains("Secure Enclave device-key"), "TestFlight build notes should mention Secure Enclave device-key contract")
check(buildNotes.summary.localizedCaseInsensitiveContains("signed-device validation scaffold"), "TestFlight build notes should mention signed-device validation scaffold")
check(buildNotes.summary.localizedCaseInsensitiveContains("signed-device media validation packet"), "TestFlight build notes should mention signed-device media validation packet")
check(buildNotes.summary.localizedCaseInsensitiveContains("archive/signing readiness packet"), "TestFlight build notes should mention archive/signing readiness packet")
check(buildNotes.summary.localizedCaseInsensitiveContains("metadata/legal review packet"), "TestFlight build notes should mention metadata/legal review packet")
check(buildNotes.summary.localizedCaseInsensitiveContains("screenshot/App Preview creative packet"), "TestFlight build notes should mention screenshot/App Preview creative packet")
check(buildNotes.summary.localizedCaseInsensitiveContains("Privacy Manifest required reason API audit packet"), "TestFlight build notes should mention Privacy Manifest required reason API audit packet")
check(buildNotes.summary.localizedCaseInsensitiveContains("encryption export compliance review packet"), "TestFlight build notes should mention encryption export compliance review packet")
check(buildNotes.summary.localizedCaseInsensitiveContains("Keychain"), "TestFlight build notes should mention Keychain adapter")
check(buildNotes.summary.localizedCaseInsensitiveContains("export ZIP"), "TestFlight build notes should mention export ZIP builder")
check(buildNotes.summary.localizedCaseInsensitiveContains("raw media export"), "TestFlight build notes should mention raw media export policy")
check(buildNotes.summary.localizedCaseInsensitiveContains("staged"), "TestFlight build notes should mention staged raw media export")
check(buildNotes.summary.localizedCaseInsensitiveContains("Account Rights"), "TestFlight build notes should mention Account Rights export UI")
check(buildNotes.summary.localizedCaseInsensitiveContains("fileExporter"), "TestFlight build notes should mention SwiftUI fileExporter bridge")
check(buildNotes.summary.localizedCaseInsensitiveContains("deletion audit"), "TestFlight build notes should mention deletion audit envelope")
check(buildNotes.summary.localizedCaseInsensitiveContains("server gateway"), "TestFlight build notes should mention server gateway envelope")
check(buildNotes.summary.localizedCaseInsensitiveContains("provider validation scaffold"), "TestFlight build notes should mention DeepSeek provider validation scaffold")
check(buildNotes.summary.localizedCaseInsensitiveContains("integration test runner contract"), "TestFlight build notes should mention DeepSeek integration test runner contract")
check(buildNotes.summary.localizedCaseInsensitiveContains("backend endpoint"), "TestFlight build notes should mention DeepSeek backend endpoint contract")
check(buildNotes.summary.localizedCaseInsensitiveContains("provider proxy"), "TestFlight build notes should mention DeepSeek provider proxy contract")
check(buildNotes.summary.localizedCaseInsensitiveContains("endpoint execution harness"), "TestFlight build notes should mention DeepSeek endpoint execution harness")
check(buildNotes.summary.localizedCaseInsensitiveContains("live backend probe"), "TestFlight build notes should mention DeepSeek live backend probe")
check(buildNotes.summary.localizedCaseInsensitiveContains("deletion service"), "TestFlight build notes should mention deletion service boundary")
check(buildNotes.summary.localizedCaseInsensitiveContains("deletion live probe"), "TestFlight build notes should mention deletion live probe")
check(buildNotes.summary.localizedCaseInsensitiveContains("App Store submission gate"), "TestFlight build notes should mention App Store submission gate")
check(buildNotes.summary.localizedCaseInsensitiveContains("public URL packet"), "TestFlight build notes should mention public URL packet")
check(buildNotes.summary.localizedCaseInsensitiveContains("backend release manifest"), "TestFlight build notes should mention backend release manifest")
check(buildNotes.summary.localizedCaseInsensitiveContains("App Privacy questionnaire packet"), "TestFlight build notes should mention App Privacy questionnaire packet")
check(buildNotes.summary.localizedCaseInsensitiveContains("Age Rating review packet"), "TestFlight build notes should mention Age Rating review packet")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("mock gateway"), "TestFlight build notes should disclose mock/provider validation split")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("redacted backend integration test"), "TestFlight build notes should disclose redacted backend integration test boundary")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("backend endpoint contract"), "TestFlight build notes should disclose backend endpoint contract boundary")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("local endpoint execution harness"), "TestFlight build notes should disclose local endpoint execution harness boundary")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("optional live backend probe"), "TestFlight build notes should disclose optional live backend probe boundary")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("optional deletion live probe"), "TestFlight build notes should disclose optional deletion live probe boundary")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("App Store submission gate"), "TestFlight build notes should disclose submission gate boundary")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("public URL packet"), "TestFlight build notes should disclose public URL packet boundary")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("backend release manifest"), "TestFlight build notes should disclose backend release manifest boundary")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("App Privacy questionnaire packet"), "TestFlight build notes should disclose App Privacy questionnaire packet boundary")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("Age Rating review packet"), "TestFlight build notes should disclose Age Rating review packet boundary")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("signed-device media validation packet"), "TestFlight build notes should disclose signed-device media validation packet boundary")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("archive/signing readiness packet"), "TestFlight build notes should disclose archive/signing readiness packet boundary")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("metadata/legal review packet"), "TestFlight build notes should disclose metadata/legal review packet boundary")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("screenshot/App Preview creative packet"), "TestFlight build notes should disclose screenshot/App Preview creative packet boundary")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("Privacy Manifest required reason API audit packet"), "TestFlight build notes should disclose Privacy Manifest required reason API audit packet boundary")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("Xcode privacy report"), "TestFlight build notes should disclose Xcode privacy report boundary")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("encryption export compliance review packet"), "TestFlight build notes should disclose encryption export compliance review packet boundary")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("App Store Connect export-compliance"), "TestFlight build notes should disclose App Store Connect export-compliance boundary")
check(buildNotes.knownLimitations.joined(separator: " ").localizedCaseInsensitiveContains("archive"), "TestFlight build notes should disclose archive/upload limitation")
check(buildNotes.namesAIPrivacyBoundary, "TestFlight build notes should name AI and DeepSeek boundary")
check(buildNotes.supportContact.localizedCaseInsensitiveContains("required"), "TestFlight build notes should not fake a support contact")

let reviewRoute = AppReviewRoute()
check(reviewRoute.isGuestReviewFriendly, "App Review route should not require login")
check(reviewRoute.steps.count == 6, "App Review route should keep six focused steps")
check(reviewRoute.steps.joined(separator: " ").localizedCaseInsensitiveContains("Memory Camera"), "App Review route should include Memory Camera")
check(reviewRoute.steps.joined(separator: " ").localizedCaseInsensitiveContains("export"), "App Review route should include export/delete rights")

let signingPlan = SigningReadinessPlan()
check(signingPlan.bundleIdentifier == "com.raingodprc.timeslowdown", "Signing plan should preserve bundle identifier")
check(signingPlan.doesNotFakeSigning, "Signing plan should not fake a Team ID")
check(signingPlan.archiveCommandWhenXcodeAvailable.contains("xcodebuild"), "Signing plan should name the future Xcode archive command")

let archiveSigningEnvironment = ArchiveSigningValidationEnvironment.unsignedSwiftPMHost()
check(!archiveSigningEnvironment.canRunArchiveUploadValidation, "Unsigned SwiftPM host should not claim archive/upload validation capability")
check(archiveSigningEnvironment.bundleIdentifier == "com.raingodprc.timeslowdown", "Archive/signing environment should preserve production bundle identifier")
check(archiveSigningEnvironment.teamID == nil, "Archive/signing environment should not fake an Apple Developer Team ID")
check(!archiveSigningEnvironment.hasFullXcode, "Archive/signing environment should not pretend full Xcode exists")
check(!archiveSigningEnvironment.hasAppleDeveloperTeam, "Archive/signing environment should not pretend Apple Developer access exists")
check(!archiveSigningEnvironment.appStoreConnectAccessAvailable, "Archive/signing environment should not pretend App Store Connect access exists")
check(!archiveSigningEnvironment.transporterAvailable, "Archive/signing environment should not pretend Transporter is available")
let archiveSigningPacket = ArchiveSigningValidationScaffold.packet(
    environment: archiveSigningEnvironment,
    signingPlan: signingPlan,
    buildNotes: buildNotes,
    generatedAt: fixedDate
)
check(archiveSigningPacket.isTSDArchiveSigningPacketSafe, "Archive/signing packet should preserve TSD release boundaries")
check(archiveSigningPacket.requiresExternalXcodeWork, "Archive/signing packet should honestly require external Xcode work here")
check(archiveSigningPacket.status == .pendingExternalXcode, "Unsigned host archive/signing packet should stay pending external Xcode")
check(!archiveSigningPacket.productionValidationClaimed, "Unsigned host archive/signing packet should not claim production validation")
check(archiveSigningPacket.steps.count == 8, "Archive/signing packet should define eight required steps")
check(archiveSigningPacket.steps.map(\.kind).contains(.fullXcodeSelected), "Archive/signing packet should require full Xcode evidence")
check(archiveSigningPacket.steps.map(\.kind).contains(.appleDeveloperTeamResolved), "Archive/signing packet should require Apple Developer Team evidence")
check(archiveSigningPacket.steps.map(\.kind).contains(.releaseArchiveCreated), "Archive/signing packet should require Release archive evidence")
check(archiveSigningPacket.steps.map(\.kind).contains(.transporterUploadCompleted), "Archive/signing packet should require Transporter upload evidence")
check(archiveSigningPacket.steps.map(\.kind).contains(.appStoreConnectProcessingVisible), "Archive/signing packet should require App Store Connect processing evidence")
check(archiveSigningPacket.steps.allSatisfy(\.requiresFullXcode), "Archive/signing steps should require full Xcode")
check(archiveSigningPacket.steps.allSatisfy(\.forbidsPrivateSigningMaterial), "Archive/signing steps should forbid private signing material")
check(archiveSigningPacket.steps.allSatisfy(\.forbidsAppleSessionToken), "Archive/signing steps should forbid Apple session tokens")
let archiveSigningPendingReceipt = ArchiveSigningValidationScaffold.pendingReceipt(
    for: archiveSigningPacket,
    createdAt: fixedDate
)
check(archiveSigningPendingReceipt.isHonestPendingReceipt, "Archive/signing pending receipt should be honest and non-production")
check(!archiveSigningPendingReceipt.isProductionArchiveUploadReceipt, "Pending archive/signing receipt should not pass production gate")
check(!archiveSigningPendingReceipt.canSatisfyFullXcodeGate, "Pending archive/signing receipt should not satisfy full Xcode gate")
check(!archiveSigningPendingReceipt.canSatisfyAppleDeveloperTeamGate, "Pending archive/signing receipt should not satisfy Apple Developer Team gate")
check(!archiveSigningPendingReceipt.canSatisfyArchiveGate, "Pending archive/signing receipt should not satisfy archive gate")
check(!archiveSigningPendingReceipt.canSatisfyTestFlightUploadGate, "Pending archive/signing receipt should not satisfy TestFlight upload gate")

let archiveSigningPassStepReceipts = archiveSigningPacket.steps.map { step in
    ArchiveSigningValidationStepReceipt(
        id: "archive-signing-step-receipt-\(TrustDigest.checksum([archiveSigningPacket.id, step.id, "pass"]).prefix(12))",
        stepID: step.id,
        status: .uploadedToTestFlight,
        evidenceDigest: TrustDigest.checksum([step.id, "archive-signing-pass"])
    )
}
let archiveSigningPassReceipt = ArchiveSigningValidationReceipt(
    id: "archive-signing-receipt-\(TrustDigest.checksum([archiveSigningPacket.id, "pass"]).prefix(12))",
    planID: archiveSigningPacket.id,
    status: .uploadedToTestFlight,
    stepReceipts: archiveSigningPassStepReceipts,
    productionValidationClaimed: true,
    canSatisfyFullXcodeGate: true,
    canSatisfyAppleDeveloperTeamGate: true,
    canSatisfyArchiveGate: true,
    canSatisfyTestFlightUploadGate: true,
    createdAt: fixedDate
)
check(archiveSigningPassReceipt.isProductionArchiveUploadReceipt, "Complete archive/signing receipt should satisfy production archive/upload gate")

let secretBearingArchiveReceipt = ArchiveSigningValidationReceipt(
    id: "archive-signing-receipt-\(TrustDigest.checksum([archiveSigningPacket.id, "secret-bearing"]).prefix(12))",
    planID: archiveSigningPacket.id,
    status: .uploadedToTestFlight,
    stepReceipts: archiveSigningPassStepReceipts,
    productionValidationClaimed: true,
    canSatisfyFullXcodeGate: true,
    canSatisfyAppleDeveloperTeamGate: true,
    canSatisfyArchiveGate: true,
    canSatisfyTestFlightUploadGate: true,
    containsPrivateSigningMaterial: true,
    createdAt: fixedDate
)
check(!secretBearingArchiveReceipt.isProductionArchiveUploadReceipt, "Archive/signing receipt should fail if evidence contains private signing material")

let missingUploadArchiveReceipt = ArchiveSigningValidationReceipt(
    id: "archive-signing-receipt-\(TrustDigest.checksum([archiveSigningPacket.id, "missing-upload"]).prefix(12))",
    planID: archiveSigningPacket.id,
    status: .uploadedToTestFlight,
    stepReceipts: archiveSigningPassStepReceipts.filter { $0.stepID != "archive-signing-transporter-upload-completed" },
    productionValidationClaimed: true,
    canSatisfyFullXcodeGate: true,
    canSatisfyAppleDeveloperTeamGate: true,
    canSatisfyArchiveGate: true,
    canSatisfyTestFlightUploadGate: true,
    createdAt: fixedDate
)
check(!missingUploadArchiveReceipt.isProductionArchiveUploadReceipt, "Archive/signing receipt should fail if Transporter upload evidence is missing")

let publicURLPacket = AppStorePublicURLPacket()
check(publicURLPacket.urls.count == 6, "Public URL packet should expose six release URLs")
check(publicURLPacket.urls.allSatisfy { $0.hasPrefix("https://") }, "Public URL packet should use HTTPS URLs")
check(publicURLPacket.urls.allSatisfy { $0.hasPrefix(publicURLPacket.baseURL) }, "Public URL packet should stay on the public demo origin")
check(publicURLPacket.urls.contains(publicURLPacket.supportURL), "Public URL packet should include support URL")
check(publicURLPacket.urls.contains(publicURLPacket.privacyURL), "Public URL packet should include privacy URL")
check(publicURLPacket.urls.contains(publicURLPacket.exportRightsURL), "Public URL packet should include export rights URL")
check(publicURLPacket.urls.contains(publicURLPacket.deletionRightsURL), "Public URL packet should include deletion rights URL")
check(publicURLPacket.urls.contains(publicURLPacket.subscriptionRightsURL), "Public URL packet should include subscription rights URL")
check(publicURLPacket.urls.contains(publicURLPacket.appReviewRouteURL), "Public URL packet should include App Review route URL")
check(publicURLPacket.canSatisfyPublicURLShapeGate, "Public URL packet should satisfy the public URL shape gate")
check(!publicURLPacket.canSatisfyFinalLegalURLGate, "Public URL packet should not satisfy final legal URL gate before legal review")

let appPrivacyPacket = AppPrivacyQuestionnairePacket()
check(appPrivacyPacket.sourceReferences.count == 3, "App Privacy questionnaire packet should name Apple source references")
check(appPrivacyPacket.answers.count == 7, "App Privacy questionnaire packet should cover seven TSD data answers")
check(appPrivacyPacket.requiredAnswerIDs.allSatisfy { requiredID in appPrivacyPacket.answers.map(\.id).contains(requiredID) }, "App Privacy questionnaire packet should include all required TSD answer IDs")
check(appPrivacyPacket.answers.map(\.id).contains("photo-video-anchors"), "App Privacy questionnaire packet should cover photo/video anchors")
check(appPrivacyPacket.answers.map(\.id).contains("minimal-ai-task-payload"), "App Privacy questionnaire packet should cover minimal AI task payloads")
check(appPrivacyPacket.notCollectedAppleDataTypes.contains("Contacts"), "App Privacy questionnaire packet should explicitly exclude contacts")
check(appPrivacyPacket.notCollectedAppleDataTypes.contains("Precise Location"), "App Privacy questionnaire packet should explicitly exclude precise location")
check(appPrivacyPacket.coversRequiredTSDDataTypes, "App Privacy questionnaire packet should cover TSD data types")
check(appPrivacyPacket.forbidsTrackingAndAds, "App Privacy questionnaire packet should forbid tracking and advertising")
check(appPrivacyPacket.preservesPrivacyBoundaries, "App Privacy questionnaire packet should preserve privacy boundaries")
check(appPrivacyPacket.preservesUserRights, "App Privacy questionnaire packet should preserve export/delete rights")
check(appPrivacyPacket.canSatisfyQuestionnaireShapeGate, "App Privacy questionnaire packet should satisfy the local questionnaire shape gate")
check(!appPrivacyPacket.canSatisfyFinalAppStoreQuestionnaireGate, "App Privacy questionnaire packet should not satisfy final App Store questionnaire gate before App Store Connect/legal completion")

let completedAppPrivacyPacket = AppPrivacyQuestionnairePacket(
    completedInAppStoreConnect: true,
    legalReviewCompleted: true
)
check(completedAppPrivacyPacket.canSatisfyFinalAppStoreQuestionnaireGate, "Reviewed and entered App Privacy questionnaire packet should be able to satisfy the final questionnaire evidence contract")

var trackingAnswer = AppPrivacyQuestionnairePacket.defaultAnswers[0]
trackingAnswer.usedForTracking = true
let trackingAppPrivacyPacket = AppPrivacyQuestionnairePacket(answers: [trackingAnswer] + Array(AppPrivacyQuestionnairePacket.defaultAnswers.dropFirst()))
check(!trackingAppPrivacyPacket.forbidsTrackingAndAds, "App Privacy questionnaire packet should fail if any answer is used for tracking")
check(!trackingAppPrivacyPacket.canSatisfyQuestionnaireShapeGate, "App Privacy questionnaire packet should not pass the shape gate with tracking")

var unsafeAIAnswer = AppPrivacyQuestionnairePacket.defaultAnswers[5]
unsafeAIAnswer.rawMediaSentToAIProvider = true
let unsafeAIPrivacyPacket = AppPrivacyQuestionnairePacket(answers: Array(AppPrivacyQuestionnairePacket.defaultAnswers.prefix(5)) + [unsafeAIAnswer] + Array(AppPrivacyQuestionnairePacket.defaultAnswers.dropFirst(6)))
check(!unsafeAIPrivacyPacket.preservesPrivacyBoundaries, "App Privacy questionnaire packet should fail if raw media can be sent to the AI provider")
check(!unsafeAIPrivacyPacket.canSatisfyQuestionnaireShapeGate, "App Privacy questionnaire packet should not pass the shape gate with unsafe AI media upload")

let ageRatingPacket = AppAgeRatingReviewPacket()
check(ageRatingPacket.sourceReferences.count == 4, "Age Rating review packet should name Apple source references")
check(ageRatingPacket.targetMinimumAge == 12, "Age Rating review packet should keep the 12+ direction")
check(ageRatingPacket.answers.count == 8, "Age Rating review packet should cover eight age-rating answers")
check(ageRatingPacket.requiredAnswerIDs.allSatisfy { requiredID in ageRatingPacket.answers.map(\.id).contains(requiredID) }, "Age Rating review packet should include all required answer IDs")
check(ageRatingPacket.answers.map(\.id).contains("private-user-memory-content"), "Age Rating review packet should cover private user memory content")
check(ageRatingPacket.answers.map(\.id).contains("photo-video-family-media"), "Age Rating review packet should cover photo/video family media")
check(ageRatingPacket.answers.map(\.id).contains("ai-edited-memory-drafts"), "Age Rating review packet should cover bounded AI editing")
check(ageRatingPacket.answers.first { $0.id == "gambling-contests-loot-boxes" }?.included == false, "Age Rating review packet should exclude gambling/loot boxes")
check(ageRatingPacket.answers.first { $0.id == "medical-or-health-claims" }?.included == false, "Age Rating review packet should exclude medical claims")
check(ageRatingPacket.coversRequiredAgeRatingTopics, "Age Rating review packet should cover required topics")
check(ageRatingPacket.disallowsAdultOrRegulatedContentByDefault, "Age Rating review packet should disallow adult or regulated content by default")
check(ageRatingPacket.preservesChildSafetyPositioning, "Age Rating review packet should preserve child-safety positioning")
check(ageRatingPacket.preservesUGCAndAISafetyBoundaries, "Age Rating review packet should preserve UGC and AI safety boundaries")
check(ageRatingPacket.canSatisfyAgeRatingShapeGate, "Age Rating review packet should satisfy the local age-rating shape gate")
check(!ageRatingPacket.canSatisfyFinalAgeRatingGate, "Age Rating review packet should not satisfy final Age Rating gate before App Store Connect/legal completion")

let completedAgeRatingPacket = AppAgeRatingReviewPacket(
    completedInAppStoreConnect: true,
    legalReviewCompleted: true
)
check(completedAgeRatingPacket.canSatisfyFinalAgeRatingGate, "Reviewed and entered Age Rating packet should be able to satisfy final age-rating evidence contract")

let kidsCategoryAgeRatingPacket = AppAgeRatingReviewPacket(notKidsCategory: false)
check(!kidsCategoryAgeRatingPacket.preservesChildSafetyPositioning, "Age Rating review packet should fail if it falsely claims Kids Category positioning")
check(!kidsCategoryAgeRatingPacket.canSatisfyAgeRatingShapeGate, "Age Rating review packet should not pass shape gate with Kids Category mismatch")

let publicSocialAgeRatingPacket = AppAgeRatingReviewPacket(noPublicSocialFeed: false)
check(!publicSocialAgeRatingPacket.preservesUGCAndAISafetyBoundaries, "Age Rating review packet should fail if a public social feed is allowed")
check(!publicSocialAgeRatingPacket.canSatisfyAgeRatingShapeGate, "Age Rating review packet should not pass shape gate with public social feed")

var gamblingAnswer = AppAgeRatingReviewPacket.defaultAnswers[6]
gamblingAnswer.included = true
gamblingAnswer.frequency = .frequent
let gamblingAgeRatingPacket = AppAgeRatingReviewPacket(answers: Array(AppAgeRatingReviewPacket.defaultAnswers.prefix(6)) + [gamblingAnswer] + Array(AppAgeRatingReviewPacket.defaultAnswers.dropFirst(7)))
check(!gamblingAgeRatingPacket.disallowsAdultOrRegulatedContentByDefault, "Age Rating review packet should fail if gambling/loot boxes are included")
check(!gamblingAgeRatingPacket.canSatisfyAgeRatingShapeGate, "Age Rating review packet should not pass shape gate with gambling/loot boxes")

let metadataLegalPacket = AppStoreMetadataLegalReviewPacket()
check(metadataLegalPacket.sourceReferences.count == 5, "Metadata/legal review packet should name five source references")
check(metadataLegalPacket.productName == "TimeSlowDown", "Metadata/legal review packet should preserve product name")
check(metadataLegalPacket.bundleIdentifier == "com.raingodprc.timeslowdown", "Metadata/legal review packet should preserve bundle identifier")
check(metadataLegalPacket.items.count == 8, "Metadata/legal review packet should cover eight metadata/legal items")
check(metadataLegalPacket.requiredItemKinds.allSatisfy { requiredKind in metadataLegalPacket.items.map(\.kind).contains(requiredKind) }, "Metadata/legal review packet should include every required metadata/legal item")
check(metadataLegalPacket.items.map(\.kind).contains(.productPagePositioning), "Metadata/legal review packet should include product page positioning")
check(metadataLegalPacket.items.map(\.kind).contains(.screenshotsAndAppPreview), "Metadata/legal review packet should include screenshot/app preview plan")
check(metadataLegalPacket.items.map(\.kind).contains(.appReviewNotes), "Metadata/legal review packet should include App Review notes")
check(metadataLegalPacket.items.map(\.kind).contains(.supportAndPrivacyURLs), "Metadata/legal review packet should include support/privacy URLs")
check(metadataLegalPacket.items.map(\.kind).contains(.subscriptionCopy), "Metadata/legal review packet should include subscription copy")
check(metadataLegalPacket.items.map(\.kind).contains(.aiAndDataProcessingDisclosure), "Metadata/legal review packet should include AI/data disclosure")
check(metadataLegalPacket.screenshotPlan.count >= 6, "Metadata/legal review packet should define at least six screenshot/app preview moments")
check(metadataLegalPacket.usesPublicHTTPSURLs, "Metadata/legal review packet should use HTTPS public URLs")
check(metadataLegalPacket.preservesProductTruth, "Metadata/legal review packet should preserve TSD product truth")
check(metadataLegalPacket.avoidsFearDeathOrShameMarketing, "Metadata/legal review packet should avoid fear/death/shame marketing")
check(metadataLegalPacket.preservesUserRightsAndSubscriptionEthics, "Metadata/legal review packet should preserve user rights and subscription ethics")
check(metadataLegalPacket.preservesAIBoundary, "Metadata/legal review packet should preserve AI provider boundary")
check(metadataLegalPacket.canSatisfyMetadataLegalShapeGate, "Metadata/legal review packet should satisfy local shape gate")
check(!metadataLegalPacket.canSatisfyFinalMetadataLegalGate, "Metadata/legal review packet should not satisfy final metadata/legal gate before App Store Connect/legal/release completion")

let completedMetadataLegalPacket = AppStoreMetadataLegalReviewPacket(
    completedInAppStoreConnect: true,
    legalReviewCompleted: true,
    releaseReviewCompleted: true
)
check(completedMetadataLegalPacket.canSatisfyFinalMetadataLegalGate, "Completed metadata/legal packet should satisfy final metadata/legal evidence contract")

let fearMarketingMetadataPacket = AppStoreMetadataLegalReviewPacket(
    shortDescription: "Your life is running out of life, so record before death."
)
check(!fearMarketingMetadataPacket.avoidsFearDeathOrShameMarketing, "Metadata/legal review packet should reject death/fear marketing")
check(!fearMarketingMetadataPacket.canSatisfyMetadataLegalShapeGate, "Metadata/legal review packet should fail shape gate with death/fear marketing")

let localhostMetadataPacket = AppStoreMetadataLegalReviewPacket(
    supportURL: "http://localhost:54194/#support"
)
check(!localhostMetadataPacket.usesPublicHTTPSURLs, "Metadata/legal review packet should reject localhost/non-HTTPS support URLs")
check(!localhostMetadataPacket.canSatisfyMetadataLegalShapeGate, "Metadata/legal review packet should fail shape gate with localhost URLs")

let hostageSubscriptionMetadataPacket = AppStoreMetadataLegalReviewPacket(
    subscriptionCopy: "Subscription is required to export or delete memories."
)
check(!hostageSubscriptionMetadataPacket.preservesUserRightsAndSubscriptionEthics, "Metadata/legal review packet should reject subscription-hostage wording")
check(!hostageSubscriptionMetadataPacket.canSatisfyMetadataLegalShapeGate, "Metadata/legal review packet should fail shape gate with subscription-hostage wording")

let screenshotCreativePacket = AppStoreScreenshotAppPreviewCreativePacket()
check(screenshotCreativePacket.sourceReferences.count == 4, "Screenshot/App Preview packet should name four source references")
check(screenshotCreativePacket.screenshotMinimumPerLocalization == 1, "Screenshot/App Preview packet should respect Apple's one-screenshot minimum")
check(screenshotCreativePacket.screenshotMaximumPerDeviceLocalization == 10, "Screenshot/App Preview packet should respect Apple's ten-screenshot maximum")
check(screenshotCreativePacket.appPreviewMaximumPerDeviceLocalization == 3, "Screenshot/App Preview packet should respect Apple's three-preview maximum")
check(screenshotCreativePacket.items.count == 6, "Screenshot/App Preview packet should define six launch scenes")
check(screenshotCreativePacket.requiredSceneKindsCovered, "Screenshot/App Preview packet should cover every required TSD scene")
check(screenshotCreativePacket.items.map(\.kind).contains(.memoryCamera), "Screenshot/App Preview packet should cover Memory Camera")
check(screenshotCreativePacket.items.map(\.kind).contains(.todaySlice), "Screenshot/App Preview packet should cover today slice")
check(screenshotCreativePacket.items.map(\.kind).contains(.weeklyChapter), "Screenshot/App Preview packet should cover weekly chapter")
check(screenshotCreativePacket.items.map(\.kind).contains(.lifeMeadow), "Screenshot/App Preview packet should cover Life Meadow")
check(screenshotCreativePacket.items.map(\.kind).contains(.mediaWall), "Screenshot/App Preview packet should cover media wall")
check(screenshotCreativePacket.items.map(\.kind).contains(.accountRights), "Screenshot/App Preview packet should cover Account Rights")
check(screenshotCreativePacket.satisfiesAppleAssetCountBoundaries, "Screenshot/App Preview packet should satisfy Apple asset count boundaries")
check(screenshotCreativePacket.satisfiesFormatAndDeviceCoverage, "Screenshot/App Preview packet should satisfy format and iPhone device coverage")
check(screenshotCreativePacket.preservesTSDProductSoul, "Screenshot/App Preview packet should preserve TSD product soul")
check(screenshotCreativePacket.avoidsFearDeathOrShameMarketing, "Screenshot/App Preview packet should avoid fear/death/shame marketing")
check(screenshotCreativePacket.protectsPrivateMemoryContent, "Screenshot/App Preview packet should protect private memory content")
check(screenshotCreativePacket.canSatisfyCreativePacketShapeGate, "Screenshot/App Preview packet should satisfy the local creative shape gate")
check(!screenshotCreativePacket.canSatisfyFinalScreenshotAppPreviewGate, "Screenshot/App Preview packet should not satisfy final gate before rendered/uploaded/reviewed assets exist")

let completedScreenshotCreativePacket = AppStoreScreenshotAppPreviewCreativePacket(
    renderedAssetsGenerated: true,
    localizedAssetsReviewed: true,
    uploadedInAppStoreConnect: true,
    legalReviewCompleted: true,
    releaseReviewCompleted: true
)
check(completedScreenshotCreativePacket.canSatisfyFinalScreenshotAppPreviewGate, "Completed screenshot/App Preview packet should satisfy final asset evidence contract")

var fearScreenshotItem = AppStoreScreenshotAppPreviewCreativePacket.defaultItems[0]
fearScreenshotItem.heroCopy = "Record before death catches you."
fearScreenshotItem.avoidsFearDeathOrShameMarketing = false
let fearScreenshotPacket = AppStoreScreenshotAppPreviewCreativePacket(
    items: [fearScreenshotItem] + Array(AppStoreScreenshotAppPreviewCreativePacket.defaultItems.dropFirst())
)
check(!fearScreenshotPacket.avoidsFearDeathOrShameMarketing, "Screenshot/App Preview packet should reject death/fear creative copy")
check(!fearScreenshotPacket.canSatisfyCreativePacketShapeGate, "Screenshot/App Preview packet should fail shape gate with death/fear creative copy")

var fakeScreenshotItem = AppStoreScreenshotAppPreviewCreativePacket.defaultItems[1]
fakeScreenshotItem.renderedFromRealAppUI = false
let fakeScreenshotPacket = AppStoreScreenshotAppPreviewCreativePacket(
    items: [AppStoreScreenshotAppPreviewCreativePacket.defaultItems[0], fakeScreenshotItem] + Array(AppStoreScreenshotAppPreviewCreativePacket.defaultItems.dropFirst(2))
)
check(!fakeScreenshotPacket.items.allSatisfy(\.isHonestScreenshotCreativeItem), "Screenshot/App Preview packet should reject non-real-UI mockups")
check(!fakeScreenshotPacket.canSatisfyCreativePacketShapeGate, "Screenshot/App Preview packet should fail shape gate with non-real-UI mockups")

var unsafeMediaScreenshotItem = AppStoreScreenshotAppPreviewCreativePacket.defaultItems[4]
unsafeMediaScreenshotItem.usesOnlyConsentedOrSyntheticMedia = false
let unsafeMediaScreenshotPacket = AppStoreScreenshotAppPreviewCreativePacket(
    items: Array(AppStoreScreenshotAppPreviewCreativePacket.defaultItems.prefix(4)) + [unsafeMediaScreenshotItem] + Array(AppStoreScreenshotAppPreviewCreativePacket.defaultItems.dropFirst(5))
)
check(!unsafeMediaScreenshotPacket.protectsPrivateMemoryContent, "Screenshot/App Preview packet should reject unconsented private media")
check(!unsafeMediaScreenshotPacket.canSatisfyCreativePacketShapeGate, "Screenshot/App Preview packet should fail shape gate with unconsented private media")

let privacyManifestAuditPacket = PrivacyManifestRequiredReasonAPIAuditPacket()
check(privacyManifestAuditPacket.sourceReferences.count == 5, "Privacy Manifest required reason audit packet should name five source references")
check(privacyManifestAuditPacket.privacyManifestPath == XcodeProjectContract.privacyManifestPath, "Privacy Manifest required reason audit packet should point at the bundled privacy manifest")
check(privacyManifestAuditPacket.requiredReasonItems.count == PrivacyManifestRequiredReasonAPIKind.allCases.count, "Privacy Manifest audit packet should cover every required reason API category")
check(privacyManifestAuditPacket.requiredKindsCovered, "Privacy Manifest audit packet should cover all known required reason API kinds")
check(privacyManifestAuditPacket.shippingTargetUsesRequiredReasonAPIs, "Current shipping target audit should disclose disk-space API use")
check(privacyManifestAuditPacket.requiredAPIUsagesHaveApprovedReasons, "Privacy Manifest audit packet should require approved reasons whenever a category is used")
check(!privacyManifestAuditPacket.canKeepAccessedAPITypesEmpty, "Current shipping target audit should forbid an empty NSPrivacyAccessedAPITypes array")
let diskSpaceAuditItem = privacyManifestAuditPacket.requiredReasonItems.first { $0.kind == .diskSpace }
check(diskSpaceAuditItem?.usedByShippingTarget == true, "Disk-space audit item should match the shipping export preflight")
check(diskSpaceAuditItem?.approvedReasonIDs == ["E174.1"], "Disk-space audit item should use only the write-preflight reason E174.1")
check(diskSpaceAuditItem?.observedSymbols.contains { $0.contains("volumeAvailableCapacityForImportantUsageKey") } == true, "Disk-space audit item should name the observed production symbol")
check(privacyManifestAuditPacket.canSatisfyRequiredReasonShapeGate, "Privacy Manifest required reason audit packet should satisfy the local shape gate")
check(!privacyManifestAuditPacket.canSatisfyFinalPrivacyManifestGate, "Privacy Manifest audit packet should not satisfy final gate before Xcode privacy report, dependency review, and release review")

let completedPrivacyManifestAuditPacket = PrivacyManifestRequiredReasonAPIAuditPacket(
    dependencyManifestReviewCompleted: true,
    xcodePrivacyReportGenerated: true,
    completedInFullXcodeArchive: true,
    releaseReviewCompleted: true
)
check(completedPrivacyManifestAuditPacket.canSatisfyFinalPrivacyManifestGate, "Completed Privacy Manifest audit packet should satisfy final privacy-manifest evidence contract")

var userDefaultsRequiredReasonItem = PrivacyManifestRequiredReasonAPIAuditPacket.defaultItems[4]
userDefaultsRequiredReasonItem.usedByShippingTarget = true
userDefaultsRequiredReasonItem.approvedReasonIDs = []
let malformedPrivacyManifestAuditPacket = PrivacyManifestRequiredReasonAPIAuditPacket(
    requiredReasonItems: Array(PrivacyManifestRequiredReasonAPIAuditPacket.defaultItems.prefix(4)) + [userDefaultsRequiredReasonItem]
)
check(!malformedPrivacyManifestAuditPacket.requiredAPIUsagesHaveApprovedReasons, "Privacy Manifest audit packet should fail if used required reason APIs have no approved reason IDs")
check(!malformedPrivacyManifestAuditPacket.canSatisfyRequiredReasonShapeGate, "Privacy Manifest audit packet should fail shape gate when a used required reason API lacks approved reason IDs")

let encryptionExportPacket = EncryptionExportComplianceReviewPacket()
check(encryptionExportPacket.sourceReferences.count == 5, "Encryption export compliance packet should name five source references")
check(encryptionExportPacket.infoPlistKey == "ITSAppUsesNonExemptEncryption", "Encryption export compliance packet should bind to the Info.plist encryption key")
check(encryptionExportPacket.infoPlistDeclaresNonExemptEncryption, "Encryption export compliance packet should conservatively declare encryption use")
check(encryptionExportPacket.productUsesEncryption, "Encryption export compliance packet should not deny encryption use")
check(encryptionExportPacket.usesAppleStandardCrypto, "Encryption export compliance packet should identify Apple standard crypto use")
check(!encryptionExportPacket.usesCustomCryptography, "Encryption export compliance packet should not claim custom cryptography")
check(encryptionExportPacket.usesEndToEndEncryptedUserContent, "Encryption export compliance packet should disclose encrypted user media/content")
check(encryptionExportPacket.items.count == EncryptionExportComplianceUseKind.allCases.count, "Encryption export compliance packet should cover all encryption use kinds")
check(encryptionExportPacket.requiredUseKindsCovered, "Encryption export compliance packet should cover every required encryption use kind")
check(encryptionExportPacket.doesNotFalselyDenyEncryption, "Encryption export compliance packet should not falsely deny TSD encryption")
check(encryptionExportPacket.canSatisfyEncryptionExportShapeGate, "Encryption export compliance packet should satisfy the local shape gate")
check(!encryptionExportPacket.canSatisfyFinalEncryptionExportComplianceGate, "Encryption export compliance packet should not satisfy final gate before App Store Connect/legal/release completion")

let completedEncryptionItems = EncryptionExportComplianceReviewPacket.defaultItems.map { item in
    var completedItem = item
    completedItem.finalClassificationCompleted = true
    return completedItem
}
let completedEncryptionExportPacket = EncryptionExportComplianceReviewPacket(
    items: completedEncryptionItems,
    appStoreConnectExportComplianceAnswered: true,
    legalReviewCompleted: true,
    exportDocumentationAttachedIfRequired: true,
    releaseReviewCompleted: true
)
check(completedEncryptionExportPacket.canSatisfyFinalEncryptionExportComplianceGate, "Completed encryption export compliance packet should satisfy final evidence contract")

let falseNoEncryptionPacket = EncryptionExportComplianceReviewPacket(
    infoPlistDeclaresNonExemptEncryption: false,
    productUsesEncryption: false
)
check(!falseNoEncryptionPacket.doesNotFalselyDenyEncryption, "Encryption export compliance packet should reject false no-encryption claims")
check(!falseNoEncryptionPacket.canSatisfyEncryptionExportShapeGate, "Encryption export compliance packet should fail shape gate when encryption is falsely denied")

let customCryptoPacket = EncryptionExportComplianceReviewPacket(usesCustomCryptography: true)
check(!customCryptoPacket.canSatisfyEncryptionExportShapeGate, "Encryption export compliance packet should fail shape gate if custom crypto appears before legal review")

let appStoreSubmissionGate = AppStoreSubmissionGate.current(
    hasFullXcode: unsignedHostEnvironment.hasFullXcode,
    archiveCreated: false,
    testFlightUploadReceiptPresent: false,
    supportPrivacyURLsPublished: false,
    appPrivacyQuestionnaireCompleted: false,
    ageRatingReviewedFor12Plus: false,
    photosImportSignedDevicePassed: false,
    filesExportSignedDevicePassed: false,
    signingPlan: signingPlan,
    buildNotes: buildNotes,
    reviewRoute: reviewRoute,
    privacyBoundary: boundary,
    publicURLPacket: publicURLPacket,
    appPrivacyQuestionnairePacket: appPrivacyPacket,
    ageRatingReviewPacket: ageRatingPacket,
    metadataLegalReviewPacket: metadataLegalPacket,
    screenshotAppPreviewCreativePacket: screenshotCreativePacket,
    archiveSigningReceipt: archiveSigningPendingReceipt,
    backendReleaseEvidence: TSDBackendReleaseEvidence(),
    signedDeviceReceipt: signedDevicePendingReceipt,
    signedDeviceMediaReceipt: signedDeviceMediaPendingReceipt,
    deepSeekReceipt: providerPassReceipt,
    deletionReceipt: deletionLiveProbeReceipt
)
check(appStoreSubmissionGate.buildNumber == "89", "App Store submission gate should track v89")
check(appStoreSubmissionGate.rows.count == 30, "App Store submission gate should keep thirty release gates after v89 grouped native Timeline")
check(!appStoreSubmissionGate.canSubmitToTestFlight, "Current host should not be allowed to submit to TestFlight")
check(!appStoreSubmissionGate.canSubmitToAppStore, "Current host should not be allowed to submit to App Store")
check(appStoreSubmissionGate.blockerIDs.contains("full-xcode"), "Submission gate should block without full Xcode")
check(appStoreSubmissionGate.blockerIDs.contains("apple-developer-team"), "Submission gate should block without Apple Developer Team ID")
check(appStoreSubmissionGate.blockerIDs.contains("archive"), "Submission gate should block without a release archive")
check(appStoreSubmissionGate.blockerIDs.contains("testflight-upload"), "Submission gate should block without TestFlight upload receipt")
check(!appStoreSubmissionGate.blockerIDs.contains("archive-signing-readiness-packet"), "Archive/signing readiness packet shape should not block once honestly mapped")
check(appStoreSubmissionGate.blockerIDs.contains("support-privacy-urls"), "Submission gate should block without support/privacy URLs")
check(!appStoreSubmissionGate.blockerIDs.contains("public-url-packet"), "Public URL packet shape should not block once HTTPS deep links exist")
check(appStoreSubmissionGate.blockerIDs.contains("app-store-connect-metadata"), "Submission gate should block without final App Store Connect metadata/legal review")
check(!appStoreSubmissionGate.blockerIDs.contains("metadata-legal-review-packet"), "Metadata/legal review packet shape should not block once mapped")
check(appStoreSubmissionGate.blockerIDs.contains("screenshots-app-preview-assets"), "Submission gate should block without final rendered/uploaded screenshot and App Preview assets")
check(!appStoreSubmissionGate.blockerIDs.contains("screenshot-app-preview-creative-packet"), "Screenshot/App Preview creative packet shape should not block once mapped")
check(appStoreSubmissionGate.blockerIDs.contains("encryption-export-compliance"), "Submission gate should block without final encryption export compliance review")
check(!appStoreSubmissionGate.blockerIDs.contains("encryption-export-compliance-packet"), "Encryption export compliance packet shape should not block once mapped")
check(appStoreSubmissionGate.blockerIDs.contains("app-privacy-questionnaire"), "Submission gate should block without App Privacy questionnaire")
check(!appStoreSubmissionGate.blockerIDs.contains("app-privacy-questionnaire-packet"), "App Privacy questionnaire packet shape should not block once mapped")
check(appStoreSubmissionGate.blockerIDs.contains("privacy-manifest-required-reason-api"), "Submission gate should block without final Privacy Manifest required reason API review")
check(!appStoreSubmissionGate.blockerIDs.contains("privacy-manifest-required-reason-audit-packet"), "Privacy Manifest required reason API audit packet shape should not block once mapped")
check(appStoreSubmissionGate.blockerIDs.contains("age-rating-12-plus"), "Submission gate should block without age-rating review")
check(!appStoreSubmissionGate.blockerIDs.contains("age-rating-review-packet"), "Age Rating review packet shape should not block once mapped")
check(appStoreSubmissionGate.blockerIDs.contains("signed-device-keychain"), "Submission gate should block without signed-device Keychain/Secure Enclave pass")
check(!appStoreSubmissionGate.blockerIDs.contains("signed-device-media-validation-packet"), "Signed-device media validation packet shape should not block once honestly mapped")
check(appStoreSubmissionGate.blockerIDs.contains("signed-device-photos-import"), "Submission gate should block without signed-device Photos import pass")
check(appStoreSubmissionGate.blockerIDs.contains("signed-device-files-export"), "Submission gate should block without signed-device Files export pass")
check(appStoreSubmissionGate.blockerIDs.contains("backend-release-manifest"), "Submission gate should block without reviewed backend deployment evidence")
check(!appStoreSubmissionGate.blockerIDs.contains("deepseek-provider-pass"), "Provider pass receipt should satisfy the AI release gate")
check(!appStoreSubmissionGate.blockerIDs.contains("deletion-completion-pass"), "Completed deletion receipt should satisfy the deletion release gate")
check(appStoreSubmissionGate.rows.first { $0.id == "bundle-id" }?.status == .passed, "Submission gate should pass the production bundle ID gate")
check(appStoreSubmissionGate.rows.first { $0.id == "guest-review-route" }?.status == .passed, "Submission gate should pass the guest App Review route gate")
check(appStoreSubmissionGate.rows.first { $0.id == "privacy-safe-defaults" }?.status == .passed, "Submission gate should pass privacy-safe defaults")
check(appStoreSubmissionGate.rows.first { $0.id == "launch-contracts" }?.status == .passed, "Submission gate should pass local launch-contract coverage")

let archivePassedSubmissionGate = AppStoreSubmissionGate.current(
    hasFullXcode: false,
    archiveCreated: false,
    testFlightUploadReceiptPresent: false,
    supportPrivacyURLsPublished: false,
    appPrivacyQuestionnaireCompleted: false,
    ageRatingReviewedFor12Plus: false,
    photosImportSignedDevicePassed: false,
    filesExportSignedDevicePassed: false,
    signingPlan: signingPlan,
    buildNotes: buildNotes,
    reviewRoute: reviewRoute,
    privacyBoundary: boundary,
    publicURLPacket: publicURLPacket,
    appPrivacyQuestionnairePacket: appPrivacyPacket,
    ageRatingReviewPacket: ageRatingPacket,
    archiveSigningReceipt: archiveSigningPassReceipt,
    backendReleaseEvidence: TSDBackendReleaseEvidence(),
    signedDeviceReceipt: signedDevicePendingReceipt,
    signedDeviceMediaReceipt: signedDeviceMediaPendingReceipt,
    deepSeekReceipt: providerPassReceipt,
    deletionReceipt: deletionLiveProbeReceipt
)
check(!archivePassedSubmissionGate.blockerIDs.contains("archive-signing-readiness-packet"), "Production archive/signing receipt should satisfy archive/signing packet shape gate")
check(!archivePassedSubmissionGate.blockerIDs.contains("full-xcode"), "Production archive/signing receipt should satisfy full Xcode gate")
check(!archivePassedSubmissionGate.blockerIDs.contains("apple-developer-team"), "Production archive/signing receipt should satisfy Apple Developer Team gate")
check(!archivePassedSubmissionGate.blockerIDs.contains("archive"), "Production archive/signing receipt should satisfy archive gate")
check(!archivePassedSubmissionGate.blockerIDs.contains("testflight-upload"), "Production archive/signing receipt should satisfy TestFlight upload gate")
check(archivePassedSubmissionGate.blockerIDs.contains("support-privacy-urls"), "Production archive/signing receipt should not mask unrelated legal URL blockers")

let mediaPassedSubmissionGate = AppStoreSubmissionGate.current(
    hasFullXcode: false,
    archiveCreated: false,
    testFlightUploadReceiptPresent: false,
    supportPrivacyURLsPublished: false,
    appPrivacyQuestionnaireCompleted: false,
    ageRatingReviewedFor12Plus: false,
    photosImportSignedDevicePassed: false,
    filesExportSignedDevicePassed: false,
    signingPlan: signingPlan,
    buildNotes: buildNotes,
    reviewRoute: reviewRoute,
    privacyBoundary: boundary,
    publicURLPacket: publicURLPacket,
    appPrivacyQuestionnairePacket: appPrivacyPacket,
    ageRatingReviewPacket: ageRatingPacket,
    archiveSigningReceipt: archiveSigningPendingReceipt,
    backendReleaseEvidence: TSDBackendReleaseEvidence(),
    signedDeviceReceipt: signedDevicePendingReceipt,
    signedDeviceMediaReceipt: signedDeviceMediaPassReceipt,
    deepSeekReceipt: providerPassReceipt,
    deletionReceipt: deletionLiveProbeReceipt
)
check(!mediaPassedSubmissionGate.blockerIDs.contains("signed-device-media-validation-packet"), "Production media pass receipt should satisfy media packet shape gate")
check(!mediaPassedSubmissionGate.blockerIDs.contains("signed-device-photos-import"), "Production media pass receipt should satisfy Photos import gate")
check(!mediaPassedSubmissionGate.blockerIDs.contains("signed-device-files-export"), "Production media pass receipt should satisfy Files export gate")
check(mediaPassedSubmissionGate.blockerIDs.contains("full-xcode"), "Production media receipt should not mask unrelated Xcode blockers")

let backendProvenSubmissionGate = AppStoreSubmissionGate.current(
    hasFullXcode: false,
    archiveCreated: false,
    testFlightUploadReceiptPresent: false,
    supportPrivacyURLsPublished: false,
    appPrivacyQuestionnaireCompleted: false,
    ageRatingReviewedFor12Plus: false,
    photosImportSignedDevicePassed: false,
    filesExportSignedDevicePassed: false,
    signingPlan: signingPlan,
    buildNotes: buildNotes,
    reviewRoute: reviewRoute,
    privacyBoundary: boundary,
    publicURLPacket: publicURLPacket,
    appPrivacyQuestionnairePacket: appPrivacyPacket,
    ageRatingReviewPacket: ageRatingPacket,
    archiveSigningReceipt: archiveSigningPendingReceipt,
    backendReleaseEvidence: reviewedBackendEvidence,
    signedDeviceReceipt: signedDevicePendingReceipt,
    signedDeviceMediaReceipt: signedDeviceMediaPendingReceipt,
    deepSeekReceipt: providerPassReceipt,
    deletionReceipt: deletionLiveProbeReceipt
)
check(!backendProvenSubmissionGate.blockerIDs.contains("backend-release-manifest"), "Reviewed backend deployment evidence should satisfy the backend release manifest gate")
check(backendProvenSubmissionGate.blockerIDs.contains("full-xcode"), "Backend evidence should not mask unrelated Xcode blockers")

let metadataLegalCompletedSubmissionGate = AppStoreSubmissionGate.current(
    hasFullXcode: false,
    archiveCreated: false,
    testFlightUploadReceiptPresent: false,
    supportPrivacyURLsPublished: false,
    appPrivacyQuestionnaireCompleted: false,
    ageRatingReviewedFor12Plus: false,
    photosImportSignedDevicePassed: false,
    filesExportSignedDevicePassed: false,
    signingPlan: signingPlan,
    buildNotes: buildNotes,
    reviewRoute: reviewRoute,
    privacyBoundary: boundary,
    publicURLPacket: publicURLPacket,
    appPrivacyQuestionnairePacket: appPrivacyPacket,
    ageRatingReviewPacket: ageRatingPacket,
    metadataLegalReviewPacket: completedMetadataLegalPacket,
    archiveSigningReceipt: archiveSigningPendingReceipt,
    backendReleaseEvidence: TSDBackendReleaseEvidence(),
    signedDeviceReceipt: signedDevicePendingReceipt,
    signedDeviceMediaReceipt: signedDeviceMediaPendingReceipt,
    deepSeekReceipt: providerPassReceipt,
    deletionReceipt: deletionLiveProbeReceipt
)
check(!metadataLegalCompletedSubmissionGate.blockerIDs.contains("metadata-legal-review-packet"), "Completed metadata/legal packet should keep shape gate satisfied")
check(!metadataLegalCompletedSubmissionGate.blockerIDs.contains("app-store-connect-metadata"), "Completed metadata/legal packet should satisfy final metadata/legal gate")
check(metadataLegalCompletedSubmissionGate.blockerIDs.contains("full-xcode"), "Metadata/legal completion should not mask unrelated Xcode blockers")

let screenshotCompletedSubmissionGate = AppStoreSubmissionGate.current(
    hasFullXcode: false,
    archiveCreated: false,
    testFlightUploadReceiptPresent: false,
    supportPrivacyURLsPublished: false,
    appPrivacyQuestionnaireCompleted: false,
    ageRatingReviewedFor12Plus: false,
    photosImportSignedDevicePassed: false,
    filesExportSignedDevicePassed: false,
    signingPlan: signingPlan,
    buildNotes: buildNotes,
    reviewRoute: reviewRoute,
    privacyBoundary: boundary,
    publicURLPacket: publicURLPacket,
    appPrivacyQuestionnairePacket: appPrivacyPacket,
    ageRatingReviewPacket: ageRatingPacket,
    metadataLegalReviewPacket: metadataLegalPacket,
    screenshotAppPreviewCreativePacket: completedScreenshotCreativePacket,
    archiveSigningReceipt: archiveSigningPendingReceipt,
    backendReleaseEvidence: TSDBackendReleaseEvidence(),
    signedDeviceReceipt: signedDevicePendingReceipt,
    signedDeviceMediaReceipt: signedDeviceMediaPendingReceipt,
    deepSeekReceipt: providerPassReceipt,
    deletionReceipt: deletionLiveProbeReceipt
)
check(!screenshotCompletedSubmissionGate.blockerIDs.contains("screenshot-app-preview-creative-packet"), "Completed screenshot/App Preview packet should keep shape gate satisfied")
check(!screenshotCompletedSubmissionGate.blockerIDs.contains("screenshots-app-preview-assets"), "Completed screenshot/App Preview packet should satisfy final asset gate")
check(screenshotCompletedSubmissionGate.blockerIDs.contains("full-xcode"), "Screenshot/App Preview completion should not mask unrelated Xcode blockers")

let encryptionExportCompletedSubmissionGate = AppStoreSubmissionGate.current(
    hasFullXcode: false,
    archiveCreated: false,
    testFlightUploadReceiptPresent: false,
    supportPrivacyURLsPublished: false,
    appPrivacyQuestionnaireCompleted: false,
    ageRatingReviewedFor12Plus: false,
    photosImportSignedDevicePassed: false,
    filesExportSignedDevicePassed: false,
    signingPlan: signingPlan,
    buildNotes: buildNotes,
    reviewRoute: reviewRoute,
    privacyBoundary: boundary,
    publicURLPacket: publicURLPacket,
    appPrivacyQuestionnairePacket: appPrivacyPacket,
    ageRatingReviewPacket: ageRatingPacket,
    metadataLegalReviewPacket: metadataLegalPacket,
    encryptionExportComplianceReviewPacket: completedEncryptionExportPacket,
    archiveSigningReceipt: archiveSigningPendingReceipt,
    backendReleaseEvidence: TSDBackendReleaseEvidence(),
    signedDeviceReceipt: signedDevicePendingReceipt,
    signedDeviceMediaReceipt: signedDeviceMediaPendingReceipt,
    deepSeekReceipt: providerPassReceipt,
    deletionReceipt: deletionLiveProbeReceipt
)
check(!encryptionExportCompletedSubmissionGate.blockerIDs.contains("encryption-export-compliance-packet"), "Completed encryption export packet should keep shape gate satisfied")
check(!encryptionExportCompletedSubmissionGate.blockerIDs.contains("encryption-export-compliance"), "Completed encryption export packet should satisfy final export compliance gate")
check(encryptionExportCompletedSubmissionGate.blockerIDs.contains("full-xcode"), "Encryption export completion should not mask unrelated Xcode blockers")

let privacyManifestCompletedSubmissionGate = AppStoreSubmissionGate.current(
    hasFullXcode: false,
    archiveCreated: false,
    testFlightUploadReceiptPresent: false,
    supportPrivacyURLsPublished: false,
    appPrivacyQuestionnaireCompleted: false,
    ageRatingReviewedFor12Plus: false,
    photosImportSignedDevicePassed: false,
    filesExportSignedDevicePassed: false,
    signingPlan: signingPlan,
    buildNotes: buildNotes,
    reviewRoute: reviewRoute,
    privacyBoundary: boundary,
    publicURLPacket: publicURLPacket,
    appPrivacyQuestionnairePacket: appPrivacyPacket,
    ageRatingReviewPacket: ageRatingPacket,
    metadataLegalReviewPacket: metadataLegalPacket,
    privacyManifestRequiredReasonAuditPacket: completedPrivacyManifestAuditPacket,
    archiveSigningReceipt: archiveSigningPendingReceipt,
    backendReleaseEvidence: TSDBackendReleaseEvidence(),
    signedDeviceReceipt: signedDevicePendingReceipt,
    signedDeviceMediaReceipt: signedDeviceMediaPendingReceipt,
    deepSeekReceipt: providerPassReceipt,
    deletionReceipt: deletionLiveProbeReceipt
)
check(!privacyManifestCompletedSubmissionGate.blockerIDs.contains("privacy-manifest-required-reason-audit-packet"), "Completed Privacy Manifest packet should keep shape gate satisfied")
check(!privacyManifestCompletedSubmissionGate.blockerIDs.contains("privacy-manifest-required-reason-api"), "Completed Privacy Manifest packet should satisfy final required reason API gate")
check(privacyManifestCompletedSubmissionGate.blockerIDs.contains("full-xcode"), "Privacy Manifest completion should not mask unrelated Xcode blockers")

let unprovenBackendSubmissionGate = AppStoreSubmissionGate.current(
    hasFullXcode: false,
    archiveCreated: false,
    testFlightUploadReceiptPresent: false,
    supportPrivacyURLsPublished: false,
    appPrivacyQuestionnaireCompleted: false,
    ageRatingReviewedFor12Plus: false,
    photosImportSignedDevicePassed: false,
    filesExportSignedDevicePassed: false,
    signingPlan: signingPlan,
    buildNotes: buildNotes,
    reviewRoute: reviewRoute,
    privacyBoundary: boundary,
    publicURLPacket: publicURLPacket,
    appPrivacyQuestionnairePacket: AppPrivacyQuestionnairePacket(noTracking: false),
    ageRatingReviewPacket: AppAgeRatingReviewPacket(noPublicSocialFeed: false),
    metadataLegalReviewPacket: fearMarketingMetadataPacket,
    screenshotAppPreviewCreativePacket: fakeScreenshotPacket,
    privacyManifestRequiredReasonAuditPacket: malformedPrivacyManifestAuditPacket,
    encryptionExportComplianceReviewPacket: falseNoEncryptionPacket,
    archiveSigningReceipt: secretBearingArchiveReceipt,
    backendReleaseEvidence: TSDBackendReleaseEvidence(),
    signedDeviceReceipt: signedDevicePendingReceipt,
    signedDeviceMediaReceipt: rawEvidenceMediaReceipt,
    deepSeekReceipt: nil,
    deletionReceipt: nil
)
check(unprovenBackendSubmissionGate.blockerIDs.contains("backend-release-manifest"), "Submission gate should block backend release manifest without deployment evidence")
check(unprovenBackendSubmissionGate.blockerIDs.contains("deepseek-provider-pass"), "Submission gate should block AI without a provider pass receipt")
check(unprovenBackendSubmissionGate.blockerIDs.contains("deletion-completion-pass"), "Submission gate should block deletion without completion evidence")
check(unprovenBackendSubmissionGate.blockerIDs.contains("app-privacy-questionnaire-packet"), "Submission gate should block malformed privacy questionnaire packet evidence")
check(unprovenBackendSubmissionGate.blockerIDs.contains("age-rating-review-packet"), "Submission gate should block malformed Age Rating review packet evidence")
check(unprovenBackendSubmissionGate.blockerIDs.contains("metadata-legal-review-packet"), "Submission gate should block malformed metadata/legal review packet evidence")
check(unprovenBackendSubmissionGate.blockerIDs.contains("screenshot-app-preview-creative-packet"), "Submission gate should block malformed screenshot/App Preview creative evidence")
check(unprovenBackendSubmissionGate.blockerIDs.contains("encryption-export-compliance-packet"), "Submission gate should block malformed encryption export compliance evidence")
check(unprovenBackendSubmissionGate.blockerIDs.contains("privacy-manifest-required-reason-audit-packet"), "Submission gate should block malformed Privacy Manifest required reason audit evidence")
check(unprovenBackendSubmissionGate.blockerIDs.contains("archive-signing-readiness-packet"), "Submission gate should block malformed archive/signing packet evidence")
check(unprovenBackendSubmissionGate.blockerIDs.contains("signed-device-media-validation-packet"), "Submission gate should block malformed signed-device media packet evidence")

check(AppStoreLaunchAssetChecklist.rows.count == 4, "App Store launch checklist should track four v40 asset contracts")
check(AppStoreLaunchAssetChecklist.rows.allSatisfy { $0.status == .poc }, "App Store launch checklist rows should remain PoC, not falsely ready")
check(NativeHandoffLedger.rows.first { $0.id == "testflight-packet" }?.status == .poc, "TestFlight packet should be PoC after v40 contracts, not ready")

print("TimeSlowDownNativeChecks passed: slices, media anchors, weekly chapter, Daily Difference Radar, 90-day tellable progress, deterministic active recall, source concealment, cue-vs-remembered provenance, quiet-skip anti-nag cooldown, revisit layers, weekly story progress, non-punitive weekend completion, source-backed Life Meadow semantic zoom, month/day grouped native Timeline, chronological river, recall/revisit export, branded native Memory Camera home, persistent source-backed Life Marks provenance ledger, coordinated atomic persistence, background flush, legacy migration, corrupt backup recovery, honest first-launch empty vault, metadata-stripped protected image thumbnails, protected video poster extraction, portable thumbnail export, media invalidation, editable slice detail, media replacement/removal, delete and undo with revisit restoration, ledgers, privacy boundary, SwiftUI shell state, app target config, Xcode project skeleton, v38 production trust contracts, v39 implementation adapters, v40 App Store launch assets, v41 Keychain adapter, v42 export ZIP builder, v43 native export UI state, v44 system file exporter bridge, v45 deletion API audit envelope, v46 DeepSeek server gateway envelope, v47 deletion service integration boundary, v48 raw media export policy envelope, v49 raw media staged export builder, v50 Photos-library byte import adapter, v51 E2EE media vault adapter, v52 CryptoKit media vault envelope contract, v53 Secure Enclave device-key contract, v54 signed-device Keychain validation scaffold, v55 DeepSeek provider validation scaffold, v56 DeepSeek integration test runner contract, v57 DeepSeek backend endpoint/provider proxy contract, v58 DeepSeek endpoint execution harness, v59 DeepSeek live backend probe, v60 deletion service live probe, v61 App Store submission gate, v62 public URL packet, v63 backend release manifest, v64 App Privacy questionnaire packet, v65 Age Rating review packet, v66 signed-device media validation packet, v67 archive/signing readiness packet, v68 App Store metadata/legal review packet, v69 Privacy Manifest required reason API audit packet, v70 encryption export compliance review packet, v71 screenshot/App Preview creative packet, v72 P0 daily loop, v73 first-week return loop, v74 native product home, v75 native persistence, v76 media editing, v77 protected video posters, v78 persistence/media portability hardening, v79 native Life Meadow, v80 versioned last-known-good vault recovery, v81 post-commit media garbage collection, v82 domain/session state separation, v83 URL-backed streaming export, v84 privacy-safe runtime diagnostics, v85 deterministic native XCUITest infrastructure, v86 progressive source-backed onboarding, v87 persistent Life Marks provenance, v88 deterministic active recall, and v89 grouped native Timeline are aligned.")
