import Foundation

public struct NativeShellPersistenceCommitReceipt: Equatable, Sendable {
    public var revision: UInt64
    public var mediaGarbageCollection: NativeMediaGarbageCollectionReport

    public init(revision: UInt64, mediaGarbageCollection: NativeMediaGarbageCollectionReport) {
        self.revision = revision
        self.mediaGarbageCollection = mediaGarbageCollection
    }
}

public actor NativeShellPersistenceCoordinator {
    public let url: URL
    public let thumbnailDirectory: URL
    public private(set) var latestRequestedRevision: UInt64 = 0
    public private(set) var latestCommittedRevision: UInt64 = 0

    public init(url: URL, thumbnailDirectory: URL? = nil) {
        self.url = url
        self.thumbnailDirectory = thumbnailDirectory ?? url
            .deletingLastPathComponent()
            .appendingPathComponent("MediaThumbnails", isDirectory: true)
    }

    public func saveDebounced(
        _ store: NativeShellStore,
        delayNanoseconds: UInt64 = 250_000_000
    ) async throws -> NativeShellPersistenceCommitReceipt {
        latestRequestedRevision &+= 1
        let revision = latestRequestedRevision
        try await Task.sleep(nanoseconds: delayNanoseconds)
        try Task.checkCancellation()
        guard revision == latestRequestedRevision else {
            throw CancellationError()
        }
        try NativeShellPersistence.save(store, to: url)
        latestCommittedRevision = revision
        return commitReceipt(for: store, revision: revision)
    }

    public func flush(_ store: NativeShellStore) throws -> NativeShellPersistenceCommitReceipt {
        latestRequestedRevision &+= 1
        let revision = latestRequestedRevision
        try NativeShellPersistence.save(store, to: url)
        latestCommittedRevision = revision
        return commitReceipt(for: store, revision: revision)
    }

    private func commitReceipt(
        for store: NativeShellStore,
        revision: UInt64
    ) -> NativeShellPersistenceCommitReceipt {
        let garbageCollection = NativeMediaThumbnailStore.garbageCollect(
            referencedFileNames: store.referencedThumbnailFileNames,
            directory: thumbnailDirectory
        )
        return NativeShellPersistenceCommitReceipt(
            revision: revision,
            mediaGarbageCollection: garbageCollection
        )
    }
}
