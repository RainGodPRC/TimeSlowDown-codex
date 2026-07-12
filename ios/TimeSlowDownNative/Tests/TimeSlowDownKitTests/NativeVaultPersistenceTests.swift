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

    func testSchemaThreePersistsOnlyDomainPayloadAndResetsSessionState() throws {
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
        XCTAssertEqual(object["schemaVersion"] as? Int, 3)
        XCTAssertNil(object["store"])
        let payload = try XCTUnwrap(object["payload"] as? [String: Any])
        XCTAssertNotNil(payload["slices"])
        XCTAssertNotNil(payload["revisits"])
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

    func testLoadMigratesSchemaTwoEnvelopeToDomainOnlySchemaThree() throws {
        let url = temporaryVaultURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var schemaTwoStore = NativeShellStore()
        _ = schemaTwoStore.captureQuickMark(title: "v2 仓库中的真实记忆")
        schemaTwoStore.recordExportError("不应迁移的 session 错误")
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
        let schemaThreeEnvelope = try decoder.decode(NativeVaultEnvelope.self, from: Data(contentsOf: url))
        XCTAssertEqual(schemaThreeEnvelope.schemaVersion, 3)
        XCTAssertEqual(schemaThreeEnvelope.createdAt, createdAt)
        XCTAssertEqual(schemaThreeEnvelope.payload.slices.map(\.title), ["v2 仓库中的真实记忆"])
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
        XCTAssertGreaterThanOrEqual(artifact.entries.count, 6)
        XCTAssertTrue(artifact.isMemorySafeDefault)
        let handle = try FileHandle(forReadingFrom: artifact.fileURL)
        defer { try? handle.close() }
        XCTAssertEqual(try handle.read(upToCount: 4), Data([0x50, 0x4B, 0x03, 0x04]))
        try handle.seek(toOffset: UInt64(artifact.fileSizeBytes - 22))
        XCTAssertEqual(try handle.read(upToCount: 4), Data([0x50, 0x4B, 0x05, 0x06]))
        XCTAssertEqual(NativeExportSummary.from(artifact).fileSizeBytes, artifact.fileSizeBytes)
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
    var store: NativeShellStore
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
