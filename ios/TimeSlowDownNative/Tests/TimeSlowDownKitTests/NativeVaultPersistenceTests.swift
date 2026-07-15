import Foundation
import XCTest
#if canImport(CryptoKit)
import CryptoKit
#endif
@testable import TimeSlowDownKit

final class NativeVaultPersistenceTests: XCTestCase {
    private func temporaryVaultURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("tsd-vault-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("native-vault.json", isDirectory: false)
    }

    func testSaveWritesVersionedEnvelopeAndRestoresItsStore() throws {
        let url = temporaryVaultURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var store = NativeShellStore()
        _ = store.captureQuickMark(title: "版本化仓库中的第一刻")

        try NativeShellPersistence.save(store, to: url)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        XCTAssertEqual(object["schemaVersion"] as? Int, NativeVaultEnvelope.currentSchemaVersion)
        XCTAssertNotNil(object["createdAt"] as? String)
        XCTAssertNotNil(object["updatedAt"] as? String)
        XCTAssertNotNil(object["payloadChecksum"] as? String)
        XCTAssertNotNil(object["payload"] as? [String: Any])

        let restored = try NativeShellPersistence.loadRecovering(from: url)
        XCTAssertEqual(restored.source, .restored)
        XCTAssertEqual(restored.store.slices.map(\.title), ["版本化仓库中的第一刻"])
    }

    func testSchemaFivePersistsOnlyDomainPayloadAndResetsSessionState() throws {
        let url = temporaryVaultURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var store = NativeShellStore()
        _ = store.captureQuickMark(title: "只属于记忆领域的数据")
        store.selectedRoute = .account
        store.recordExportError("一次临时导出错误")

        try NativeShellPersistence.save(store, to: url)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        XCTAssertEqual(object["schemaVersion"] as? Int, 5)
        XCTAssertNil(object["store"])
        let payload = try XCTUnwrap(object["payload"] as? [String: Any])
        XCTAssertNotNil(payload["slices"])
        XCTAssertNotNil(payload["revisits"])
        XCTAssertNotNil(payload["recallInteractions"])
        XCTAssertNotNil(payload["lifeMarks"])
        XCTAssertNotNil(payload["privacyBoundary"])
        XCTAssertNil(payload["selectedRoute"])
        XCTAssertNil(payload["latestExportSummary"])
        XCTAssertNil(payload["latestExportError"])

        let restored = try NativeShellPersistence.loadRecovering(from: url)
        XCTAssertEqual(restored.store.slices.map(\.title), ["只属于记忆领域的数据"])
        XCTAssertEqual(restored.store.selectedRoute, .now)
        XCTAssertNil(restored.store.latestExportSummary)
        XCTAssertNil(restored.store.latestExportError)
    }

    func testDomainRevisionAdvancesOnlyForPersistedMemoryMutations() throws {
        var store = NativeShellStore()
        XCTAssertEqual(store.vaultRevision, 0)

        store.selectedRoute = .meadow
        store.recordExportError("只属于当前界面的错误")
        XCTAssertEqual(store.vaultRevision, 0)

        let slice = try XCTUnwrap(store.captureQuickMark(title: "真正改变仓库的记忆"))
        XCTAssertEqual(store.vaultRevision, 1)

        XCTAssertFalse(
            store.updateSlice(
                id: UUID(),
                title: "不存在的切片",
                body: "",
                peopleText: "",
                meaning: ""
            )
        )
        XCTAssertEqual(store.vaultRevision, 1)

        XCTAssertTrue(
            store.updateSlice(
                id: slice.id,
                title: "被认真命名的记忆",
                body: "今天真的发生过。",
                peopleText: "家人",
                meaning: "以后还想讲起"
            )
        )
        XCTAssertEqual(store.vaultRevision, 2)

        let deleted = try XCTUnwrap(store.deleteSlice(id: slice.id))
        XCTAssertEqual(store.vaultRevision, 3)
        XCTAssertTrue(store.restoreDeletedSlice(deleted))
        XCTAssertEqual(store.vaultRevision, 4)
    }

    func testFirstMemoryPreservesOnboardingAndRadarProvenance() throws {
        var store = NativeShellStore()

        let slice = try XCTUnwrap(
            store.captureFirstMemory(
                title: "晚饭时爸爸讲起年轻时的故事",
                body: "原来他也有过很莽撞的二十岁。",
                tags: ["人", "普通但值得"],
                sources: ["今日差异雷达"]
            )
        )

        XCTAssertEqual(store.slices.first?.id, slice.id)
        XCTAssertEqual(store.selectedRoute, .slices)
        XCTAssertEqual(store.vaultRevision, 1)
        XCTAssertTrue(slice.sources.contains("首次体验"))
        XCTAssertTrue(slice.sources.contains("今日差异雷达"))
    }

    func testFirstCapturedSliceCreatesASourceBackedLifeMark() throws {
        let capturedAt = Date(timeIntervalSince1970: 1_783_684_800)
        var store = NativeShellStore()

        let slice = try XCTUnwrap(
            store.captureFirstMemory(
                title: "晚饭时爸爸讲起年轻时的故事",
                sources: ["今日差异雷达"],
                now: capturedAt
            )
        )

        let mark = try XCTUnwrap(store.lifeMarks.first(where: { $0.kind == .firstLeaf }))
        XCTAssertEqual(mark.unlockedAt, capturedAt)
        XCTAssertEqual(mark.evidence.sliceIDs, [slice.id])
        XCTAssertTrue(mark.evidence.mediaAnchorIDs.isEmpty)
        XCTAssertTrue(mark.evidence.revisitIDs.isEmpty)

        let detail = try XCTUnwrap(store.lifeMarkEvidence(for: mark.id))
        XCTAssertEqual(detail.slices, [slice])
        XCTAssertTrue(detail.isComplete)
    }

    func testLifeMarkLedgerBindsMediaRevisitAndThreeMomentEvidence() throws {
        let firstDate = Date(timeIntervalSince1970: 1_783_684_800)
        let media = MediaAnchor(
            id: UUID(uuidString: "B3A42E2F-ADE4-41D4-BE3B-000000000087")!,
            kind: .image,
            label: "雨后的路.jpg"
        )
        let first = MemorySlice(
            id: UUID(uuidString: "A3A42E2F-ADE4-41D4-BE3B-000000000087")!,
            title: "雨后的路",
            body: "",
            capturedAt: firstDate,
            media: media
        )
        let second = MemorySlice(title: "和爸爸吃面", body: "", capturedAt: firstDate.addingTimeInterval(60))
        let third = MemorySlice(title: "晚风变凉", body: "", capturedAt: firstDate.addingTimeInterval(120))
        let revisit = MemoryRevisit(
            id: UUID(uuidString: "C3A42E2F-ADE4-41D4-BE3B-000000000087")!,
            sliceID: first.id,
            revisitedAt: firstDate.addingTimeInterval(180),
            reflection: "现在想起，最清楚的是路灯下的水光。"
        )

        let store = NativeShellStore(slices: [third, second, first], revisits: [revisit])

        XCTAssertEqual(Set(store.lifeMarks.map(\.kind)), Set(LifeMarkKind.allCases))
        let mediaMark = try XCTUnwrap(store.lifeMarks.first(where: { $0.kind == .mediaAnchor }))
        XCTAssertEqual(mediaMark.evidence.sliceIDs, [first.id])
        XCTAssertEqual(mediaMark.evidence.mediaAnchorIDs, [media.id])
        let revisitMark = try XCTUnwrap(store.lifeMarks.first(where: { $0.kind == .timeLayer }))
        XCTAssertEqual(revisitMark.evidence.sliceIDs, [first.id])
        XCTAssertEqual(revisitMark.evidence.revisitIDs, [revisit.id])
        let threeMomentMark = try XCTUnwrap(store.lifeMarks.first(where: { $0.kind == .threeMoments }))
        XCTAssertEqual(threeMomentMark.evidence.sliceIDs, [first.id, second.id, third.id])
        XCTAssertTrue(store.lifeMarks.allSatisfy { store.lifeMarkEvidence(for: $0.id)?.isComplete == true })
    }

    func testSchemaFivePersistsTheLifeMarkLedger() throws {
        let url = temporaryVaultURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let capturedAt = Date(timeIntervalSince1970: 1_783_684_800)
        var store = NativeShellStore()
        let slice = try XCTUnwrap(store.captureQuickMark(title: "被保存下来的第一刻", now: capturedAt))

        try NativeShellPersistence.save(store, to: url)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        XCTAssertEqual(object["schemaVersion"] as? Int, 5)
        let payload = try XCTUnwrap(object["payload"] as? [String: Any])
        let marks = try XCTUnwrap(payload["lifeMarks"] as? [[String: Any]])
        XCTAssertEqual(marks.count, 1)
        XCTAssertEqual(marks.first?["kind"] as? String, LifeMarkKind.firstLeaf.rawValue)

        let restored = try NativeShellPersistence.loadRecovering(from: url)
        let mark = try XCTUnwrap(restored.store.lifeMarks.first)
        XCTAssertEqual(mark.unlockedAt, capturedAt)
        XCTAssertEqual(mark.evidence.sliceIDs, [slice.id])
        XCTAssertEqual(restored.source, .restored)
    }

    func testSchemaFivePersistsRecallInteractionsWithoutCreatingStreakDebt() throws {
        let url = temporaryVaultURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let now = Date(timeIntervalSince1970: 1_783_958_400)
        let slice = MemorySlice(
            title: "这次先不回望",
            body: "跳过只代表今天想安静一点。",
            capturedAt: now.addingTimeInterval(-864_000)
        )
        var store = NativeShellStore(slices: [slice])
        let skip = try XCTUnwrap(store.skipActiveRecall(sliceID: slice.id, now: now))

        try NativeShellPersistence.save(store, to: url)
        let restored = try NativeShellPersistence.loadRecovering(from: url)

        XCTAssertEqual(restored.store.recallInteractions, [skip])
        XCTAssertTrue(restored.store.revisits.isEmpty)
        XCTAssertEqual(restored.store.lifeMarks.map(\.kind), [.firstLeaf])
    }

    func testSchemaThreeMigratesInPlaceAndBackfillsSourceBackedLifeMarks() throws {
        let url = temporaryVaultURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let slice = MemorySlice(
            id: UUID(uuidString: "A3A42E2F-ADE4-41D4-BE3B-000000000083")!,
            title: "v3 仓库中的第一片叶",
            body: "",
            capturedAt: createdAt
        )
        let payload = TestNativeVaultPayloadV3(
            slices: [slice],
            revisits: [],
            privacyBoundary: PrivacyBoundary()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let envelope = TestNativeVaultEnvelopeV3(
            schemaVersion: 3,
            createdAt: createdAt,
            updatedAt: createdAt,
            payloadChecksum: testChecksum(try encoder.encode(payload)),
            payload: payload
        )
        try encoder.encode(envelope).write(to: url, options: .atomic)

        let migrated = try NativeShellPersistence.loadRecovering(from: url)

        XCTAssertEqual(migrated.source, .migratedVersioned(3))
        XCTAssertEqual(migrated.store.slices, [slice])
        XCTAssertEqual(migrated.store.lifeMarks.first?.kind, .firstLeaf)
        XCTAssertEqual(migrated.store.lifeMarks.first?.evidence.sliceIDs, [slice.id])
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        XCTAssertEqual(object["schemaVersion"] as? Int, 5)
        XCTAssertNotNil((object["payload"] as? [String: Any])?["lifeMarks"])
    }

    func testSchemaFourMigratesInPlaceAndStartsWithNoRecallInteractionDebt() throws {
        let url = temporaryVaultURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let slice = MemorySlice(
            id: UUID(uuidString: "A3A42E2F-ADE4-41D4-BE3B-000000000084")!,
            title: "v4 仓库里的真实一刻",
            body: "它应该继续被完整保留。",
            capturedAt: createdAt
        )
        let mark = LifeMark(
            kind: .firstLeaf,
            unlockedAt: createdAt,
            evidence: LifeMarkEvidence(sliceIDs: [slice.id])
        )
        let payload = TestNativeVaultPayloadV4(
            slices: [slice],
            revisits: [],
            lifeMarks: [mark],
            privacyBoundary: PrivacyBoundary()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let envelope = TestNativeVaultEnvelopeV4(
            schemaVersion: 4,
            createdAt: createdAt,
            updatedAt: createdAt,
            payloadChecksum: testChecksum(try encoder.encode(payload)),
            payload: payload
        )
        try encoder.encode(envelope).write(to: url, options: .atomic)

        let migrated = try NativeShellPersistence.loadRecovering(from: url)

        XCTAssertEqual(migrated.source, .migratedVersioned(4))
        XCTAssertEqual(migrated.store.slices, [slice])
        XCTAssertEqual(migrated.store.lifeMarks, [mark])
        XCTAssertTrue(migrated.store.recallInteractions.isEmpty)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        XCTAssertEqual(object["schemaVersion"] as? Int, 5)
        XCTAssertNotNil((object["payload"] as? [String: Any])?["recallInteractions"])
    }

    func testActiveRecallSchedulerIsDeterministicAndHonorsQuietSkipCooldown() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_783_958_400)
        let oldest = MemorySlice(
            id: UUID(uuidString: "A3A42E2F-ADE4-41D4-BE3B-000000000188")!,
            title: "四十天前的雨",
            body: "和家人一起走回家。",
            capturedAt: calendar.date(byAdding: .day, value: -40, to: now)!,
            people: ["家人"],
            meaning: "后来仍想讲起",
            sources: ["真实切片"]
        )
        let recent = MemorySlice(
            id: UUID(uuidString: "B3A42E2F-ADE4-41D4-BE3B-000000000188")!,
            title: "五天前的一顿饭",
            body: "普通但值得。",
            capturedAt: calendar.date(byAdding: .day, value: -5, to: now)!
        )

        let first = try XCTUnwrap(
            ActiveRecallScheduler.next(
                from: [recent, oldest],
                revisits: [],
                interactions: [],
                now: now,
                calendar: calendar
            )
        )
        XCTAssertEqual(first.id, oldest.id)
        XCTAssertEqual(first.reason, .longUnseen)

        let skip = RecallInteraction(
            sliceID: oldest.id,
            occurredAt: now,
            outcome: .skipped
        )
        XCTAssertNil(
            ActiveRecallScheduler.next(
                from: [oldest, recent],
                revisits: [],
                interactions: [skip],
                now: now,
                calendar: calendar
            )
        )
        let afterSkip = try XCTUnwrap(
            ActiveRecallScheduler.next(
                from: [oldest, recent],
                revisits: [],
                interactions: [skip],
                now: calendar.date(byAdding: .day, value: 1, to: now)!,
                calendar: calendar
            )
        )
        XCTAssertEqual(afterSkip.id, recent.id)

        let afterCooldown = try XCTUnwrap(
            ActiveRecallScheduler.next(
                from: [recent, oldest],
                revisits: [],
                interactions: [skip],
                now: calendar.date(byAdding: .day, value: 7, to: now)!,
                calendar: calendar
            )
        )
        XCTAssertEqual(afterCooldown.id, oldest.id)

        let newlyDue = MemorySlice(
            title: "昨天的新记忆",
            body: "刚刚到第一次回望时间。",
            capturedAt: calendar.date(byAdding: .day, value: -1, to: now)!
        )
        let previouslyReviewed = MemorySlice(
            title: "需要第二次回望的旧记忆",
            body: "不能被每天新增的内容永久饿死。",
            capturedAt: calendar.date(byAdding: .day, value: -20, to: now)!
        )
        let earlierReview = MemoryRevisit(
            sliceID: previouslyReviewed.id,
            revisitedAt: calendar.date(byAdding: .day, value: -4, to: now)!
        )
        let spacedReturn = try XCTUnwrap(
            ActiveRecallScheduler.next(
                from: [newlyDue, previouslyReviewed],
                revisits: [earlierReview],
                interactions: [],
                now: now,
                calendar: calendar
            )
        )
        XCTAssertEqual(spacedReturn.id, previouslyReviewed.id)
        XCTAssertEqual(spacedReturn.reason, .spacedReturn)
    }

    func testMemoryTimelineGroupsMonthsAndDaysWithoutLosingSourceOrder() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
            calendar.date(from: DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour
            ))!
        }

        let june = MemorySlice(
            id: UUID(uuidString: "A3A42E2F-ADE4-41D4-BE3B-000000000189")!,
            title: "六月最后一次长谈",
            body: "回家以后仍然记得。",
            capturedAt: date(2026, 6, 28, 21)
        )
        let julyMorning = MemorySlice(
            id: UUID(uuidString: "B3A42E2F-ADE4-41D4-BE3B-000000000189")!,
            title: "清晨的第一张照片",
            body: "光落在窗边。",
            capturedAt: date(2026, 7, 2, 8),
            media: MediaAnchor(kind: .image, label: "morning.jpg")
        )
        let julyEvening = MemorySlice(
            id: UUID(uuidString: "C3A42E2F-ADE4-41D4-BE3B-000000000189")!,
            title: "同一天的晚风",
            body: "一天里可以有不止一个瞬间。",
            capturedAt: date(2026, 7, 2, 19)
        )
        let revisit = MemoryRevisit(
            sliceID: june.id,
            revisitedAt: date(2026, 7, 10, 12),
            reflection: "后来又讲起那晚。"
        )

        let snapshot = MemoryTimelineFactory.snapshot(
            from: [june, julyMorning, julyEvening],
            revisits: [revisit],
            calendar: calendar
        )

        XCTAssertEqual(snapshot.months.map(\.id), ["2026-07", "2026-06"])
        XCTAssertEqual(snapshot.months.first?.days.map(\.id), ["2026-07-02"])
        XCTAssertEqual(snapshot.months.first?.days.first?.slices.map(\.id), [julyEvening.id, julyMorning.id])
        XCTAssertEqual(snapshot.months.first?.days.first?.prominentSliceID, julyMorning.id)
        XCTAssertEqual(snapshot.sourceSliceIDs, [julyEvening.id, julyMorning.id, june.id])
        XCTAssertEqual(snapshot.sliceCount, 3)
        XCTAssertEqual(snapshot.mediaAnchorCount, 1)
        XCTAssertEqual(snapshot.revisitCount, 1)
        XCTAssertTrue(snapshot.isSourceBacked)
        let julyDay = try XCTUnwrap(snapshot.months.first?.days.first)
        XCTAssertEqual(julyDay.revisitCount(for: julyMorning.id), 0)
        XCTAssertEqual(julyDay.revisitCount(for: julyEvening.id), 0)
        let juneDay = try XCTUnwrap(snapshot.months.last?.days.first)
        XCTAssertEqual(juneDay.revisitCount(for: june.id), 1)

        var corruptedSnapshot = snapshot
        corruptedSnapshot.months[1].days[0].revisitCountsBySliceID[june.id] = 0
        XCTAssertFalse(corruptedSnapshot.isSourceBacked)
        XCTAssertEqual(
            snapshot,
            MemoryTimelineFactory.snapshot(
                from: [julyEvening, june, julyMorning],
                revisits: [revisit],
                calendar: calendar
            )
        )
    }

    func testMemoryTimelineTenYearBaseline() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2030,
            month: 1,
            day: 1,
            hour: 12
        )))
        let slices = (0..<3_650).map { offset in
            MemorySlice(
                id: UUID(uuidString: String(
                    format: "00000000-0000-0000-0000-%012llX",
                    UInt64(offset + 1)
                ))!,
                title: "第 \(offset + 1) 天",
                body: "十年时间轴性能基线。",
                capturedAt: calendar.date(byAdding: .day, value: -offset, to: anchor)!,
                media: offset.isMultiple(of: 7)
                    ? MediaAnchor(kind: .image, label: "day-\(offset + 1).jpg")
                    : nil
            )
        }
        let revisits = slices.flatMap { slice in
            [
                MemoryRevisit(sliceID: slice.id, revisitedAt: anchor),
                MemoryRevisit(sliceID: slice.id, revisitedAt: anchor.addingTimeInterval(60))
            ]
        }

        let factoryStart = CFAbsoluteTimeGetCurrent()
        let snapshot = MemoryTimelineFactory.snapshot(
            from: slices.reversed(),
            revisits: revisits.reversed(),
            calendar: calendar
        )
        let factoryMilliseconds = (CFAbsoluteTimeGetCurrent() - factoryStart) * 1_000

        let lookupStart = CFAbsoluteTimeGetCurrent()
        let projectedLookupChecksum = snapshot.months
            .flatMap(\.days)
            .reduce(0) { count, day in
                count + day.slices.reduce(0) { sliceCount, slice in
                    sliceCount + day.revisitCount(for: slice.id)
                }
            }
        let projectedLookupMilliseconds = (CFAbsoluteTimeGetCurrent() - lookupStart) * 1_000

        print(String(
            format: "TSD_TIMELINE_V90 factory_ms=%.3f projected_lookup_ms=%.3f checksum=%d",
            factoryMilliseconds,
            projectedLookupMilliseconds,
            projectedLookupChecksum
        ))
        XCTAssertEqual(snapshot.months.flatMap(\.days).count, 3_650)
        XCTAssertEqual(snapshot.sliceCount, 3_650)
        XCTAssertEqual(snapshot.revisitCount, 7_300)
        XCTAssertEqual(projectedLookupChecksum, 7_300)
        XCTAssertTrue(snapshot.isSourceBacked)
        XCTAssertLessThan(factoryMilliseconds, 5_000)
        XCTAssertLessThan(projectedLookupMilliseconds, 1_000)
    }

    func testActiveRecallCadenceCompletionAndSkipRemainNonPunitive() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_783_958_400)
        let slice = MemorySlice(
            title: "那天的晚风",
            body: "回家路上风突然变凉。",
            capturedAt: calendar.date(byAdding: .day, value: -20, to: now)!
        )
        let notDue = MemorySlice(
            title: "今天刚发生的事",
            body: "它还没到需要回望的时候。",
            capturedAt: now
        )
        var notDueStore = NativeShellStore(slices: [notDue])
        XCTAssertNil(
            notDueStore.completeActiveRecall(
                sliceID: notDue.id,
                mode: .remembered,
                now: now,
                calendar: calendar
            )
        )
        XCTAssertNil(notDueStore.skipActiveRecall(sliceID: notDue.id, now: now, calendar: calendar))

        var store = NativeShellStore(slices: [slice])

        let firstCandidate = try XCTUnwrap(store.activeRecallCandidate(now: now, calendar: calendar))
        XCTAssertEqual(firstCandidate.id, slice.id)
        let revisit = try XCTUnwrap(
            store.completeActiveRecall(
                sliceID: slice.id,
                mode: .neededCue,
                reflection: "",
                now: now,
                calendar: calendar
            )
        )
        XCTAssertTrue(revisit.reflection.isEmpty)
        XCTAssertEqual(revisit.source, ActiveRecallMode.neededCue.sourceLabel)
        XCTAssertEqual(store.recallInteractions.last?.revisitID, revisit.id)
        XCTAssertEqual(store.recallInteractions.last?.outcome, .revisited)
        XCTAssertNil(
            store.completeActiveRecall(
                sliceID: slice.id,
                mode: .remembered,
                now: now,
                calendar: calendar
            )
        )
        XCTAssertNil(
            store.activeRecallCandidate(
                now: calendar.date(byAdding: .day, value: 2, to: now)!,
                calendar: calendar
            )
        )
        XCTAssertNotNil(
            store.activeRecallCandidate(
                now: calendar.date(byAdding: .day, value: 3, to: now)!,
                calendar: calendar
            )
        )

        let secondNow = calendar.date(byAdding: .day, value: 3, to: now)!
        let skip = try XCTUnwrap(store.skipActiveRecall(sliceID: slice.id, now: secondNow, calendar: calendar))
        XCTAssertEqual(skip.outcome, .skipped)
        XCTAssertEqual(store.revisits.count, 1)
        XCTAssertNil(store.skipActiveRecall(sliceID: slice.id, now: secondNow, calendar: calendar))
        XCTAssertNil(store.activeRecallCandidate(now: secondNow, calendar: calendar))
    }

    func testDeletingAndUndoingASourceNeverLeavesOrphanedLifeMarkEvidence() throws {
        let firstDate = Date(timeIntervalSince1970: 1_783_684_800)
        let media = MediaAnchor(kind: .image, label: "park.jpg")
        let first = MemorySlice(title: "第一刻", body: "", capturedAt: firstDate, media: media)
        let second = MemorySlice(title: "第二刻", body: "", capturedAt: firstDate.addingTimeInterval(60))
        let third = MemorySlice(title: "第三刻", body: "", capturedAt: firstDate.addingTimeInterval(120))
        let revisit = MemoryRevisit(
            sliceID: first.id,
            revisitedAt: firstDate.addingTimeInterval(180),
            reflection: "现在再看"
        )
        let interaction = RecallInteraction(
            sliceID: first.id,
            occurredAt: revisit.revisitedAt,
            outcome: .revisited,
            mode: .remembered,
            revisitID: revisit.id
        )
        var store = NativeShellStore(
            slices: [third, second, first],
            revisits: [revisit],
            recallInteractions: [interaction]
        )
        let originalMarks = store.lifeMarks

        let deleted = try XCTUnwrap(store.deleteSlice(id: first.id))

        XCTAssertFalse(store.lifeMarks.flatMap(\.evidence.sliceIDs).contains(first.id))
        XCTAssertFalse(store.lifeMarks.flatMap(\.evidence.mediaAnchorIDs).contains(media.id))
        XCTAssertFalse(store.lifeMarks.flatMap(\.evidence.revisitIDs).contains(revisit.id))
        XCTAssertTrue(store.recallInteractions.isEmpty)
        XCTAssertTrue(store.lifeMarks.allSatisfy { store.lifeMarkEvidence(for: $0.id)?.isComplete == true })

        XCTAssertTrue(store.restoreDeletedSlice(deleted))
        XCTAssertEqual(store.lifeMarks, originalMarks)
        XCTAssertEqual(store.recallInteractions, [interaction])
        XCTAssertTrue(store.lifeMarks.allSatisfy { store.lifeMarkEvidence(for: $0.id)?.isComplete == true })
    }

    func testOnboardingCompletionPersistsOutsideTheMemoryVault() throws {
        let vaultURL = temporaryVaultURL()
        let onboardingURL = vaultURL.deletingLastPathComponent().appendingPathComponent("onboarding.json")
        defer { try? FileManager.default.removeItem(at: vaultURL.deletingLastPathComponent()) }
        let completedAt = Date(timeIntervalSince1970: 1_783_684_800)
        let state = NativeOnboardingState(
            completedAt: completedAt,
            outcome: .capturedText
        )

        try NativeOnboardingPersistence.save(state, to: onboardingURL)

        XCTAssertFalse(FileManager.default.fileExists(atPath: vaultURL.path))
        XCTAssertEqual(try XCTUnwrap(NativeOnboardingPersistence.load(from: onboardingURL)), state)
        XCTAssertTrue(
            NativeOnboardingDecision.shouldPresent(
                mode: .automatic,
                hasInjectedStore: false,
                vaultSource: .newVault,
                savedState: nil
            )
        )
        XCTAssertFalse(
            NativeOnboardingDecision.shouldPresent(
                mode: .automatic,
                hasInjectedStore: false,
                vaultSource: .restored,
                savedState: nil
            )
        )
        XCTAssertFalse(
            NativeOnboardingDecision.shouldPresent(
                mode: .automatic,
                hasInjectedStore: false,
                vaultSource: .newVault,
                savedState: state
            )
        )
    }

    func testFutureOnboardingSchemaIsNotOverwritten() throws {
        let url = temporaryVaultURL()
            .deletingLastPathComponent()
            .appendingPathComponent("onboarding.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let futureData = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": NativeOnboardingState.currentSchemaVersion + 1,
            "completedAt": "2026-07-14T15:00:00Z",
            "outcome": NativeOnboardingOutcome.skipped.rawValue
        ], options: [.sortedKeys])
        try futureData.write(to: url, options: .atomic)

        XCTAssertThrowsError(try NativeOnboardingPersistence.load(from: url))
        XCTAssertThrowsError(
            try NativeOnboardingPersistence.save(
                NativeOnboardingState(outcome: .capturedText),
                to: url
            )
        )
        XCTAssertEqual(try Data(contentsOf: url), futureData)
    }

    func testLoadMigratesLegacyBareStoreInPlace() throws {
        let url = temporaryVaultURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var legacyStore = NativeShellStore()
        _ = legacyStore.captureQuickMark(title: "旧仓库里的记忆")
        let legacyEncoder = JSONEncoder()
        legacyEncoder.dateEncodingStrategy = .iso8601
        try legacyEncoder.encode(legacyStore).write(to: url, options: .atomic)

        let migrated = try NativeShellPersistence.loadRecovering(from: url)

        XCTAssertEqual(migrated.source, .migratedLegacy)
        XCTAssertEqual(migrated.store.slices.map(\.title), ["旧仓库里的记忆"])
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        XCTAssertEqual(object["schemaVersion"] as? Int, NativeVaultEnvelope.currentSchemaVersion)
        XCTAssertNotNil(object["payloadChecksum"] as? String)
    }

    func testLoadMigratesSchemaTwoEnvelopeToDomainOnlySchemaFive() throws {
        let url = temporaryVaultURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let schemaTwoStore = TestNativeShellStoreV2(
            selectedRoute: .account,
            slices: [MemorySlice(title: "v2 仓库中的真实记忆", body: "")],
            revisits: [],
            privacyBoundary: PrivacyBoundary(),
            latestExportSummary: nil,
            latestExportError: "不应迁移的 session 错误"
        )
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let storeData = try encoder.encode(schemaTwoStore)
        let envelope = TestNativeVaultEnvelopeV2(
            schemaVersion: 2,
            createdAt: createdAt,
            updatedAt: createdAt,
            payloadChecksum: testChecksum(storeData),
            store: schemaTwoStore
        )
        try encoder.encode(envelope).write(to: url, options: .atomic)

        let migrated = try NativeShellPersistence.loadRecovering(from: url)

        XCTAssertEqual(migrated.source, .migratedVersioned(2))
        XCTAssertEqual(migrated.store.slices.map(\.title), ["v2 仓库中的真实记忆"])
        XCTAssertEqual(migrated.store.selectedRoute, .now)
        XCTAssertNil(migrated.store.latestExportError)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let schemaFiveEnvelope = try decoder.decode(NativeVaultEnvelope.self, from: Data(contentsOf: url))
        XCTAssertEqual(schemaFiveEnvelope.schemaVersion, 5)
        XCTAssertEqual(schemaFiveEnvelope.createdAt, createdAt)
        XCTAssertEqual(schemaFiveEnvelope.payload.slices.map(\.title), ["v2 仓库中的真实记忆"])
        XCTAssertEqual(schemaFiveEnvelope.payload.lifeMarks.map(\.kind), [.firstLeaf])
        XCTAssertTrue(schemaFiveEnvelope.payload.recallInteractions.isEmpty)
    }

    func testCorruptPrimaryRestoresThePreviousLastKnownGoodVault() throws {
        let url = temporaryVaultURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var firstStore = NativeShellStore()
        _ = firstStore.captureQuickMark(title: "仍然可以找回的记忆")
        try NativeShellPersistence.save(firstStore, to: url)

        var secondStore = firstStore
        _ = secondStore.captureQuickMark(title: "最新一次修改")
        try NativeShellPersistence.save(secondStore, to: url)
        try Data("broken-primary".utf8).write(to: url, options: .atomic)

        let recovered = try NativeShellPersistence.loadRecovering(from: url)

        guard case .restoredLastKnownGood(let corruptBackupName) = recovered.source else {
            return XCTFail("A corrupt primary should restore the previous last-known-good vault")
        }
        XCTAssertEqual(recovered.store.slices.map(\.title), ["仍然可以找回的记忆"])
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: url.deletingLastPathComponent().appendingPathComponent(corruptBackupName).path
            )
        )
        let restoredAgain = try NativeShellPersistence.loadRecovering(from: url)
        XCTAssertEqual(restoredAgain.source, .restored)
        XCTAssertEqual(restoredAgain.store.slices.map(\.title), ["仍然可以找回的记忆"])
    }

    func testFutureSchemaIsRefusedWithoutMovingOrOverwritingThePrimary() throws {
        let url = temporaryVaultURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var store = NativeShellStore()
        _ = store.captureQuickMark(title: "来自未来版本的记忆")
        try NativeShellPersistence.save(store, to: url)

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        object["schemaVersion"] = NativeVaultEnvelope.currentSchemaVersion + 1
        let futureData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        try futureData.write(to: url, options: .atomic)

        XCTAssertThrowsError(try NativeShellPersistence.loadRecovering(from: url)) { error in
            XCTAssertEqual(
                error as? NativeVaultPersistenceError,
                .unsupportedSchema(NativeVaultEnvelope.currentSchemaVersion + 1)
            )
        }
        XCTAssertEqual(try Data(contentsOf: url), futureData)

        var replacementStore = NativeShellStore()
        _ = replacementStore.captureQuickMark(title: "旧版本试图写入的新记忆")
        XCTAssertThrowsError(try NativeShellPersistence.save(replacementStore, to: url)) { error in
            XCTAssertEqual(
                error as? NativeVaultPersistenceError,
                .unsupportedSchema(NativeVaultEnvelope.currentSchemaVersion + 1)
            )
        }
        XCTAssertEqual(try Data(contentsOf: url), futureData)

        let siblings = try FileManager.default.contentsOfDirectory(
            at: url.deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        )
        XCTAssertFalse(siblings.contains { $0.lastPathComponent.contains("corrupt-") })
    }

    func testSecondSavePreservesCreatedAtAndAdvancesUpdatedAt() throws {
        let url = temporaryVaultURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var firstStore = NativeShellStore()
        _ = firstStore.captureQuickMark(title: "仓库诞生时的记忆")
        try NativeShellPersistence.save(firstStore, to: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var firstEnvelope = try decoder.decode(NativeVaultEnvelope.self, from: Data(contentsOf: url))
        let originalCreatedAt = Date(timeIntervalSince1970: 978_307_200)
        let originalUpdatedAt = Date(timeIntervalSince1970: 978_393_600)
        firstEnvelope.createdAt = originalCreatedAt
        firstEnvelope.updatedAt = originalUpdatedAt
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(firstEnvelope).write(to: url, options: .atomic)

        var secondStore = firstStore
        _ = secondStore.captureQuickMark(title: "多年后的新记忆")
        try NativeShellPersistence.save(secondStore, to: url)

        let secondEnvelope = try decoder.decode(NativeVaultEnvelope.self, from: Data(contentsOf: url))
        XCTAssertEqual(secondEnvelope.createdAt, originalCreatedAt)
        XCTAssertGreaterThan(secondEnvelope.updatedAt, originalUpdatedAt)
        XCTAssertEqual(secondEnvelope.store.slices.count, 2)
    }

    func testCommittedSnapshotGarbageCollectsOnlyUnreferencedManagedThumbnails() async throws {
        let url = temporaryVaultURL()
        let thumbnailDirectory = url.deletingLastPathComponent().appendingPathComponent("MediaThumbnails")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let referencedAnchor = try NativeMediaThumbnailStore.persist(
            MemoryCameraSelection(
                anchor: MediaAnchor(kind: .image, label: "仍被切片引用.jpg"),
                thumbnailData: Data([0xFF, 0xD8, 0xFF, 0xD9])
            ),
            directory: thumbnailDirectory
        )
        let orphanedAnchor = try NativeMediaThumbnailStore.persist(
            MemoryCameraSelection(
                anchor: MediaAnchor(kind: .image, label: "已经被替换.jpg"),
                thumbnailData: Data([0xFF, 0xD8, 0x00, 0xD9])
            ),
            directory: thumbnailDirectory
        )
        let managedLookingDirectory = thumbnailDirectory.appendingPathComponent(
            "\(UUID().uuidString.lowercased()).jpg",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: managedLookingDirectory,
            withIntermediateDirectories: true
        )
        var store = NativeShellStore()
        _ = store.captureFromMemoryCamera(referencedAnchor)

        let coordinator = NativeShellPersistenceCoordinator(
            url: url,
            thumbnailDirectory: thumbnailDirectory
        )
        let receipt = try await coordinator.flush(store)

        let referencedFileName = try XCTUnwrap(referencedAnchor.thumbnailFileName)
        let orphanedFileName = try XCTUnwrap(orphanedAnchor.thumbnailFileName)
        XCTAssertNotNil(NativeMediaThumbnailStore.data(fileName: referencedFileName, directory: thumbnailDirectory))
        XCTAssertNil(NativeMediaThumbnailStore.data(fileName: orphanedFileName, directory: thumbnailDirectory))
        var isDirectory: ObjCBool = false
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: managedLookingDirectory.path, isDirectory: &isDirectory)
        )
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertEqual(receipt.mediaGarbageCollection.removedFileNames, [orphanedFileName])
        XCTAssertTrue(receipt.mediaGarbageCollection.failedFileNames.isEmpty)

        let restored = try NativeShellPersistence.loadRecovering(from: url)
        XCTAssertEqual(restored.store.slices.first?.media?.thumbnailFileName, referencedFileName)
    }

    func testFailedVaultCommitDoesNotGarbageCollectMedia() async throws {
        let url = temporaryVaultURL()
        let thumbnailDirectory = url.deletingLastPathComponent().appendingPathComponent("MediaThumbnails")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let orphanedAnchor = try NativeMediaThumbnailStore.persist(
            MemoryCameraSelection(
                anchor: MediaAnchor(kind: .image, label: "提交失败时必须保留.jpg"),
                thumbnailData: Data([0xFF, 0xD8, 0x01, 0xD9])
            ),
            directory: thumbnailDirectory
        )
        try NativeShellPersistence.save(NativeShellStore(), to: url)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        object["schemaVersion"] = NativeVaultEnvelope.currentSchemaVersion + 1
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            .write(to: url, options: .atomic)

        let coordinator = NativeShellPersistenceCoordinator(
            url: url,
            thumbnailDirectory: thumbnailDirectory
        )
        await XCTAssertThrowsErrorAsync(try await coordinator.flush(NativeShellStore())) { error in
            XCTAssertEqual(
                error as? NativeVaultPersistenceError,
                .unsupportedSchema(NativeVaultEnvelope.currentSchemaVersion + 1)
            )
        }

        let fileName = try XCTUnwrap(orphanedAnchor.thumbnailFileName)
        XCTAssertNotNil(NativeMediaThumbnailStore.data(fileName: fileName, directory: thumbnailDirectory))
    }

    func testSharedThumbnailIsCollectedOnlyAfterItsFinalCommittedReferenceIsRemoved() async throws {
        let url = temporaryVaultURL()
        let thumbnailDirectory = url.deletingLastPathComponent().appendingPathComponent("MediaThumbnails")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let sharedAnchor = try NativeMediaThumbnailStore.persist(
            MemoryCameraSelection(
                anchor: MediaAnchor(kind: .image, label: "两张切片共同引用.jpg"),
                thumbnailData: Data([0xFF, 0xD8, 0x02, 0xD9])
            ),
            directory: thumbnailDirectory
        )
        var store = NativeShellStore()
        let first = store.captureFromMemoryCamera(sharedAnchor, title: "第一张切片")
        let second = store.captureFromMemoryCamera(sharedAnchor, title: "第二张切片")
        let coordinator = NativeShellPersistenceCoordinator(
            url: url,
            thumbnailDirectory: thumbnailDirectory
        )
        let fileName = try XCTUnwrap(sharedAnchor.thumbnailFileName)

        _ = try await coordinator.flush(store)
        _ = store.deleteSlice(id: first.id)
        _ = try await coordinator.flush(store)
        XCTAssertNotNil(NativeMediaThumbnailStore.data(fileName: fileName, directory: thumbnailDirectory))

        _ = store.deleteSlice(id: second.id)
        let finalReceipt = try await coordinator.flush(store)
        XCTAssertNil(NativeMediaThumbnailStore.data(fileName: fileName, directory: thumbnailDirectory))
        XCTAssertEqual(finalReceipt.mediaGarbageCollection.removedFileNames, [fileName])
    }

    func testFileExportWritesAValidZIPArtifactWithoutReturningArchiveData() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tsd-file-export-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var store = NativeShellStore()
        _ = store.captureQuickMark(title: "写入文件而不是堆在内存里的记忆")
        let request = store.memoryExportRequest(now: Date(timeIntervalSince1970: 1_700_000_000))

        let artifact = try await NativeMemoryExportFileBuilder.export(
            request,
            to: directory,
            availableCapacityBytes: 10_000_000
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: artifact.fileURL.path))
        XCTAssertEqual(artifact.fileName, request.plan.fileName)
        XCTAssertGreaterThan(artifact.fileSizeBytes, 22)
        XCTAssertGreaterThanOrEqual(artifact.entries.count, 8)
        XCTAssertTrue(artifact.isMemorySafeDefault)
        let handle = try FileHandle(forReadingFrom: artifact.fileURL)
        defer { try? handle.close() }
        XCTAssertEqual(try handle.read(upToCount: 4), Data([0x50, 0x4B, 0x03, 0x04]))
        try handle.seek(toOffset: UInt64(artifact.fileSizeBytes - 22))
        XCTAssertEqual(try handle.read(upToCount: 4), Data([0x50, 0x4B, 0x05, 0x06]))
        XCTAssertEqual(NativeExportSummary.from(artifact).fileSizeBytes, artifact.fileSizeBytes)
    }

    func testMemoryExportCarriesTheSourceBackedLifeMarkLedger() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tsd-life-mark-export-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var store = NativeShellStore()
        _ = store.captureQuickMark(title: "这枚印记也属于我")

        let request = store.memoryExportRequest()
        let artifact = try await NativeMemoryExportFileBuilder.export(
            request,
            to: directory,
            availableCapacityBytes: 10_000_000
        )

        XCTAssertEqual(request.lifeMarks, store.lifeMarks)
        XCTAssertTrue(artifact.entries.map(\.path).contains("memories/life-marks.json"))
        XCTAssertTrue(artifact.isMemorySafeDefault)
    }

    func testMemoryExportCarriesActiveRecallInteractions() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tsd-recall-export-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date(timeIntervalSince1970: 1_783_958_400)
        let slice = MemorySlice(
            title: "导出里也保留回望选择",
            body: "用户的跳过与完成都属于可携带数据。",
            capturedAt: now.addingTimeInterval(-864_000)
        )
        var store = NativeShellStore(slices: [slice])
        _ = store.skipActiveRecall(sliceID: slice.id, now: now)

        let request = store.memoryExportRequest(now: now)
        let artifact = try await NativeMemoryExportFileBuilder.export(
            request,
            to: directory,
            availableCapacityBytes: 10_000_000
        )

        XCTAssertEqual(request.recallInteractions, store.recallInteractions)
        XCTAssertTrue(artifact.entries.map(\.path).contains("memories/recall-interactions.json"))
        XCTAssertTrue(artifact.isMemorySafeDefault)
    }

    func testFileExportRejectsInsufficientSpaceWithoutLeavingPartialFiles() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tsd-file-export-space-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var store = NativeShellStore()
        _ = store.captureQuickMark(title: "空间不足时不能留下半个导出包")

        await XCTAssertThrowsErrorAsync(
            try await NativeMemoryExportFileBuilder.export(
                store.memoryExportRequest(),
                to: directory,
                availableCapacityBytes: 1
            )
        ) { error in
            guard case .insufficientDiskSpace(let required, let available) = error as? ExportZIPBuilderError else {
                return XCTFail("Expected an insufficient-disk-space error")
            }
            XCTAssertGreaterThan(required, available)
            XCTAssertEqual(available, 1)
        }

        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        XCTAssertTrue(leftovers.isEmpty)
    }

    func testCancelledFileExportLeavesNoPartialFiles() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tsd-file-export-cancel-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var store = NativeShellStore()
        _ = store.captureQuickMark(title: "取消导出也不能留下垃圾")

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await NativeMemoryExportFileBuilder.export(
                store.memoryExportRequest(),
                to: directory,
                availableCapacityBytes: 10_000_000
            )
        }
        do {
            _ = try await task.value
            XCTFail("A pre-cancelled export should throw CancellationError")
        } catch is CancellationError {
            // Expected.
        }

        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        XCTAssertTrue(leftovers.isEmpty)
    }

    func testFileExportReportsMonotonicProgressEndingAtOne() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tsd-file-export-progress-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var store = NativeShellStore()
        _ = store.captureQuickMark(title: "看得见进度的导出")
        let recorder = ThreadSafeProgressRecorder()

        _ = try await NativeMemoryExportFileBuilder.export(
            store.memoryExportRequest(),
            to: directory,
            availableCapacityBytes: 10_000_000,
            progress: { recorder.append($0) }
        )

        let values = recorder.values
        XCTAssertFalse(values.isEmpty)
        XCTAssertEqual(values.last, 1)
        XCTAssertTrue(zip(values, values.dropFirst()).allSatisfy { $0 <= $1 })
    }

    func testOwnedExportArtifactCleanupPreservesUnrelatedFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tsd-file-export-cleanup-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let ownedNames = [
            ".tsd-export-abcd.partial",
            "tsd-export-efgh.zip"
        ]
        let unrelatedNames = [
            "family-memories.zip",
            ".tsd-export-not-partial.tmp",
            "tsd-export-not-zip.json"
        ]
        for name in ownedNames + unrelatedNames {
            try Data(name.utf8).write(to: directory.appendingPathComponent(name))
        }

        let removed = try NativeMemoryExportFileBuilder.removeOwnedArtifacts(in: directory)

        XCTAssertEqual(removed, ownedNames.sorted())
        let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        XCTAssertEqual(remaining, unrelatedNames.sorted())
    }

    func testRuntimeErrorCodesAreTypedAndNeverPreserveErrorDescriptions() throws {
        XCTAssertEqual(
            NativeRuntimeErrorCode.from(NativeVaultPersistenceError.unsupportedSchema(99)),
            .unsupportedSchema
        )
        XCTAssertEqual(
            NativeRuntimeErrorCode.from(MediaThumbnailError.thumbnailTooLarge(9_999_999)),
            .thumbnailTooLarge
        )
        XCTAssertEqual(
            NativeRuntimeErrorCode.from(ExportZIPBuilderError.insufficientDiskSpace(required: 2, available: 1)),
            .insufficientDiskSpace
        )
        XCTAssertEqual(NativeRuntimeErrorCode.from(CancellationError()), .userCancelled)

        let canary = "PRIVATE-MEMORY-CANARY-ALICE-AT-HOME.jpg"
        let unknownError = NSError(
            domain: canary,
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: canary]
        )
        let receipt = NativeRuntimeReceiptFactory.failure(
            operation: .vaultCommit,
            error: unknownError,
            duration: .milliseconds(25)
        )
        let data = try JSONEncoder().encode(receipt)

        XCTAssertEqual(receipt.errorCode, .ioUnknown)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains(canary))
        XCTAssertTrue(receipt.isPrivacySafe)
    }

    func testRuntimeReceiptFactoriesKeepOnlyCountsBucketsAndTypedOutcomes() {
        var store = NativeShellStore()
        _ = store.captureQuickMark(title: "A title that must never enter diagnostics")
        let loadReceipt = NativeRuntimeReceiptFactory.vaultLoad(
            source: .restoredLastKnownGood("private-backup-name.json"),
            store: store,
            duration: .milliseconds(11)
        )
        XCTAssertEqual(loadReceipt.outcome, .recovered)
        XCTAssertEqual(loadReceipt.vaultLoadSource, .restoredLastKnownGood)
        XCTAssertEqual(loadReceipt.sourceSchemaVersion, NativeVaultEnvelope.currentSchemaVersion)
        XCTAssertEqual(loadReceipt.sliceCount, 1)
        XCTAssertNil(loadReceipt.errorCode)

        let gcReport = NativeMediaGarbageCollectionReport(
            removedFileNames: ["private-removed.jpg"],
            failedFileNames: ["private-failed.jpg"]
        )
        let commitReceipt = NativeRuntimeReceiptFactory.vaultCommit(
            NativeShellPersistenceCommitReceipt(revision: 7, mediaGarbageCollection: gcReport),
            store: store,
            duration: .milliseconds(13)
        )
        XCTAssertEqual(commitReceipt.outcome, .failed)
        XCTAssertEqual(commitReceipt.garbageCollectedCount, 1)
        XCTAssertEqual(commitReceipt.garbageCollectionFailureCount, 1)
        XCTAssertEqual(commitReceipt.revision, 7)

        let metricReceipt = NativeRuntimeReceiptFactory.metricDiagnostics(
            payloadCount: 2,
            crashCount: 1,
            hangCount: 3,
            diskWriteExceptionCount: 4,
            cpuExceptionCount: 5
        )
        XCTAssertEqual(metricReceipt.diagnosticPayloadCount, 2)
        XCTAssertEqual(metricReceipt.crashCount, 1)
        XCTAssertEqual(metricReceipt.hangCount, 3)
        XCTAssertEqual(metricReceipt.diskWriteExceptionCount, 4)
        XCTAssertEqual(metricReceipt.cpuExceptionCount, 5)
    }

    func testRuntimeReceiptStoreIsBoundedAcrossRestarts() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tsd-runtime-receipts-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("runtime-receipts.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NativeRuntimeReceiptStore(
            url: url,
            maximumReceiptCount: 3,
            maximumEncodedBytes: 32_768
        )

        for count in 0..<5 {
            try await store.append(NativeRuntimeReceiptFactory.metricPayloads(count))
        }

        let receipts = try await store.readAll()
        XCTAssertEqual(receipts.count, 3)
        XCTAssertEqual(receipts.compactMap(\.metricPayloadCount), [2, 3, 4])
        let restoredStore = NativeRuntimeReceiptStore(
            url: url,
            maximumReceiptCount: 3,
            maximumEncodedBytes: 32_768
        )
        let restoredReceipts = try await restoredStore.readAll()
        XCTAssertEqual(restoredReceipts, receipts)
        XCTAssertLessThanOrEqual(try Data(contentsOf: url).count, 32_768)

        try Data("corrupt diagnostics".utf8).write(to: url, options: .atomic)
        try await restoredStore.append(NativeRuntimeReceiptFactory.metricPayloads(9))
        let recoveredReceipts = try await restoredStore.readAll()
        XCTAssertEqual(recoveredReceipts.compactMap(\.metricPayloadCount), [9])
    }

    func testRuntimeDiagnosticsExportsOnlyItsBoundedSanitizedSnapshot() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tsd-runtime-diagnostics-export-\(UUID().uuidString)", isDirectory: true)
        let receiptURL = directory.appendingPathComponent("store/runtime-receipts.json")
        let exportDirectory = directory.appendingPathComponent("exports", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NativeRuntimeReceiptStore(url: receiptURL, maximumReceiptCount: 10)
        let diagnostics = NativeRuntimeDiagnostics(store: store)
        await diagnostics.record(
            NativeRuntimeReceiptFactory.failure(
                operation: .memoryExport,
                error: ExportZIPBuilderError.fileIO("PRIVATE ABSOLUTE PATH /Users/alice/memory.jpg")
            )
        )
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        let unrelatedURL = exportDirectory.appendingPathComponent("family-notes.json")
        try Data("keep".utf8).write(to: unrelatedURL)

        let first = try await store.exportSnapshot(to: exportDirectory)
        let second = try await store.exportSnapshot(to: exportDirectory)
        let data = try Data(contentsOf: second.fileURL)
        let text = String(decoding: data, as: UTF8.self)

        XCTAssertEqual(first.receiptCount, 1)
        XCTAssertEqual(second.receiptCount, 1)
        let transferable = TSDDiagnosticsFile(artifact: second)
        XCTAssertFalse(transferable.fileName.isEmpty)
        XCTAssertEqual(transferable.fileName, second.fileURL.lastPathComponent)
        XCTAssertEqual(transferable.fileURL, second.fileURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelatedURL.path))
        XCTAssertTrue(text.contains(NativeRuntimeErrorCode.exportFileIO.rawValue))
        XCTAssertFalse(text.contains("PRIVATE ABSOLUTE PATH"))
        XCTAssertFalse(text.contains("/Users/alice"))
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in },
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}

private struct TestNativeVaultEnvelopeV2: Codable {
    var schemaVersion: Int
    var createdAt: Date
    var updatedAt: Date
    var payloadChecksum: String
    var store: TestNativeShellStoreV2
}

private struct TestNativeShellStoreV2: Codable {
    var selectedRoute: NativeShellRoute
    var slices: [MemorySlice]
    var revisits: [MemoryRevisit]
    var privacyBoundary: PrivacyBoundary
    var latestExportSummary: NativeExportSummary?
    var latestExportError: String?
}

private struct TestNativeVaultPayloadV3: Codable {
    var slices: [MemorySlice]
    var revisits: [MemoryRevisit]
    var privacyBoundary: PrivacyBoundary
}

private struct TestNativeVaultEnvelopeV3: Codable {
    var schemaVersion: Int
    var createdAt: Date
    var updatedAt: Date
    var payloadChecksum: String
    var payload: TestNativeVaultPayloadV3
}

private struct TestNativeVaultPayloadV4: Codable {
    var slices: [MemorySlice]
    var revisits: [MemoryRevisit]
    var lifeMarks: [LifeMark]
    var privacyBoundary: PrivacyBoundary
}

private struct TestNativeVaultEnvelopeV4: Codable {
    var schemaVersion: Int
    var createdAt: Date
    var updatedAt: Date
    var payloadChecksum: String
    var payload: TestNativeVaultPayloadV4
}

private func testChecksum(_ data: Data) -> String {
#if canImport(CryptoKit)
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
#else
    data.base64EncodedString()
#endif
}

private final class ThreadSafeProgressRecorder: @unchecked Sendable {
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
