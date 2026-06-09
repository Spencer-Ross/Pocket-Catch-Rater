import Foundation
import Observation

@Observable
@MainActor
final class PokemonDataStore {
    private(set) var syncState: SyncState = .idle
    private(set) var cacheStats: CacheStats?

    private let repository: PokemonRepository
    private var backgroundSyncTask: Task<Void, Never>?

    init(repository: PokemonRepository) {
        self.repository = repository
    }

    func bootstrap() async {
        do {
            let usedSeed = try repository.loadSeedFallbackIfNeeded()
            if usedSeed {
                syncState = .ready(source: .seedFallback)
            }
            refreshCacheStats()
        } catch {
            syncState = .failed(error.localizedDescription)
            return
        }

        await syncGameData(for: .gen1, replacingState: true)
        startBackgroundFullSyncIfNeeded()
    }

    func syncGeneration(_ generation: Int) async {
        let gameGeneration = PokemonGeneration(rawValue: generation) ?? .gen1
        await syncGameData(for: gameGeneration, replacingState: false)
    }

    func syncGameData(for gameGeneration: PokemonGeneration) async {
        await syncGameData(for: gameGeneration, replacingState: false)
    }

    func syncAllMissingData() async {
        guard !syncState.isSyncing else { return }

        syncState = .syncing(generation: 0, completed: 0, total: 0)

        do {
            _ = try await repository.syncAllMissingData { [weak self] completed, total, _ in
                Task { @MainActor [weak self] in
                    self?.syncState = .syncing(generation: 0, completed: completed, total: total)
                }
            }

            syncState = .ready(source: .api)
            refreshCacheStats()
        } catch {
            syncState = .failed(error.localizedDescription)
            refreshCacheStats()
        }
    }

    func ensureGameData(for gameGeneration: PokemonGeneration) async {
        guard (try? repository.needsGameSync(for: gameGeneration)) == true else { return }
        guard !syncState.isSyncing else { return }
        await syncGameData(for: gameGeneration, replacingState: false)
    }

    func species(in gameGeneration: PokemonGeneration) throws -> [PokemonSpecies] {
        try repository.species(in: gameGeneration)
    }

    func species(for generation: Int) throws -> [PokemonSpecies] {
        try repository.species(for: generation)
    }

    func search(name: String, in gameGeneration: PokemonGeneration) throws -> [PokemonSpecies] {
        try repository.search(name: name, in: gameGeneration)
    }

    func search(name: String, generation: Int) throws -> [PokemonSpecies] {
        try repository.search(name: name, generation: generation)
    }

    func isSpeciesAvailable(_ species: PokemonSpecies, in gameGeneration: PokemonGeneration) throws -> Bool {
        try repository.isSpeciesAvailable(species, in: gameGeneration)
    }

    func clearCacheAndResync() async {
        backgroundSyncTask?.cancel()
        backgroundSyncTask = nil

        do {
            try repository.clearCache()
            refreshCacheStats()
            _ = try? repository.loadSeedFallbackIfNeeded()
            syncState = .ready(source: .seedFallback)
        } catch {
            syncState = .failed(error.localizedDescription)
            return
        }

        await syncGameData(for: .gen1, replacingState: true)
        startBackgroundFullSyncIfNeeded()
    }

    func refreshCacheStats() {
        cacheStats = try? repository.cacheStats()
    }

    private func startBackgroundFullSyncIfNeeded() {
        guard backgroundSyncTask == nil else { return }
        guard (try? repository.needsAnySync()) == true else { return }

        backgroundSyncTask = Task {
            await syncAllMissingData()
            backgroundSyncTask = nil
        }
    }

    private func syncGameData(for gameGeneration: PokemonGeneration, replacingState: Bool) async {
        guard !syncState.isSyncing else { return }

        syncState = .syncing(generation: gameGeneration.rawValue, completed: 0, total: 0)

        do {
            let result = try await repository.syncGameData(for: gameGeneration) { [weak self] completed, total in
                Task { @MainActor [weak self] in
                    self?.syncState = .syncing(
                        generation: gameGeneration.rawValue,
                        completed: completed,
                        total: total
                    )
                }
            }

            syncState = .ready(source: .api)
            refreshCacheStats()

            if result.speciesCount == 0 {
                syncState = .failed("No species returned for \(gameGeneration.displayName).")
            } else {
                startBackgroundFullSyncIfNeeded()
            }
        } catch {
            if replacingState || (try? repository.speciesCount()) == 0 {
                _ = try? repository.loadSeedFallbackIfNeeded()
                if (try? repository.speciesCount()) ?? 0 > 0 {
                    syncState = .ready(source: .seedFallback)
                    refreshCacheStats()
                    startBackgroundFullSyncIfNeeded()
                    return
                }
            }
            syncState = .failed(error.localizedDescription)
            refreshCacheStats()
        }
    }
}
