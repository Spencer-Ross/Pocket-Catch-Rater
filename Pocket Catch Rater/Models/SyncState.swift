import Foundation

enum SyncState: Equatable, Sendable {
    case idle
    case syncing(generation: Int, completed: Int, total: Int)
    case ready(source: DataSource)
    case failed(String)

    enum DataSource: String, Sendable {
        case api
        case seedFallback
    }

    var isSyncing: Bool {
        if case .syncing = self { return true }
        return false
    }
}

nonisolated struct SyncResult: Sendable {
    let generation: Int
    let speciesCount: Int
    let errors: [String]
}

nonisolated struct CacheStats: Sendable {
    let speciesCount: Int
    let databaseBytes: Int64
    let lastSyncByGeneration: [Int: String]

    func lastSync(for generation: Int) -> String? {
        lastSyncByGeneration[generation]
    }
}
