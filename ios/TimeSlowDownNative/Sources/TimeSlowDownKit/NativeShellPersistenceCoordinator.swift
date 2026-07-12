import Foundation

public actor NativeShellPersistenceCoordinator {
    public let url: URL
    public private(set) var latestRequestedRevision: UInt64 = 0
    public private(set) var latestCommittedRevision: UInt64 = 0

    public init(url: URL) {
        self.url = url
    }

    public func saveDebounced(
        _ store: NativeShellStore,
        delayNanoseconds: UInt64 = 250_000_000
    ) async throws {
        latestRequestedRevision &+= 1
        let revision = latestRequestedRevision
        try await Task.sleep(nanoseconds: delayNanoseconds)
        try Task.checkCancellation()
        guard revision == latestRequestedRevision else {
            throw CancellationError()
        }
        try NativeShellPersistence.save(store, to: url)
        latestCommittedRevision = revision
    }

    public func flush(_ store: NativeShellStore) throws {
        latestRequestedRevision &+= 1
        let revision = latestRequestedRevision
        try NativeShellPersistence.save(store, to: url)
        latestCommittedRevision = revision
    }
}
