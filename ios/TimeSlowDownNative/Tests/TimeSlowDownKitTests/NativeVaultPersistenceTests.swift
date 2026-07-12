import Foundation
import XCTest
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
        XCTAssertEqual(object["schemaVersion"] as? Int, 2)
        XCTAssertNotNil(object["createdAt"] as? String)
        XCTAssertNotNil(object["updatedAt"] as? String)
        XCTAssertNotNil(object["payloadChecksum"] as? String)
        XCTAssertNotNil(object["store"] as? [String: Any])

        let restored = try NativeShellPersistence.loadRecovering(from: url)
        XCTAssertEqual(restored.source, .restored)
        XCTAssertEqual(restored.store.slices.map(\.title), ["版本化仓库中的第一刻"])
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
        XCTAssertEqual(object["schemaVersion"] as? Int, 2)
        XCTAssertNotNil(object["payloadChecksum"] as? String)
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
