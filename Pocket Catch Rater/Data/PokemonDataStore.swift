import Foundation
import Observation

@Observable
@MainActor
final class PokemonDataStore {
    private(set) var syncState: SyncState = .idle
    private(set) var cacheStats: CacheStats?

    private let repository: PokemonRepository
    private var syncWorkerTask: Task<Void, Never>?
    private var pendingSyncGenerations: [PokemonGeneration] = []

    init(repository: PokemonRepository) {
        self.repository = repository
    }

    func bootstrap() async {
        do {
            let usedSeed = try repository.loadSeedFallbackIfNeeded()
            refreshCacheStats()

            if usedSeed {
                syncState = .ready(source: .seedFallback)
            } else if (try? repository.hasPlayableData(for: .gen1)) == true {
                syncState = .ready(source: .api)
            } else if (try? repository.rebuildGameDataLocally(for: .gen1)) == true {
                syncState = .ready(source: .api)
                refreshCacheStats()
            } else {
                syncState = .idle
            }
        } catch {
            syncState = .failed(error.localizedDescription)
            return
        }

        enqueueSync(for: .gen1)
        startSyncWorkerIfNeeded()
    }

    func syncGeneration(_ generation: Int) async {
        let gameGeneration = PokemonGeneration(rawValue: generation) ?? .gen1
        await syncGameData(for: gameGeneration, replacingState: false)
    }

    func syncGameData(for gameGeneration: PokemonGeneration) async {
        await syncGameData(for: gameGeneration, replacingState: false)
    }

    /// Downloads every uncached PokeAPI source. Only triggered from Settings.
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

    /// Ensures data is usable for a generation without blocking on network when cache can satisfy it.
    func ensureGameData(for gameGeneration: PokemonGeneration) async {
        if (try? repository.hasPlayableData(for: gameGeneration)) == true {
            return
        }

        if (try? repository.rebuildGameDataLocally(for: gameGeneration)) == true {
            refreshCacheStats()
            if case .idle = syncState {
                syncState = .ready(source: .api)
            }
            return
        }

        guard (try? repository.needsNetworkSync(for: gameGeneration)) == true else {
            return
        }

        enqueueSync(for: gameGeneration)
        startSyncWorkerIfNeeded()
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
        syncWorkerTask?.cancel()
        syncWorkerTask = nil
        pendingSyncGenerations.removeAll()

        do {
            try repository.clearCache()
            refreshCacheStats()
            _ = try? repository.loadSeedFallbackIfNeeded()
            syncState = .ready(source: .seedFallback)
        } catch {
            syncState = .failed(error.localizedDescription)
            return
        }

        enqueueSync(for: .gen1)
        startSyncWorkerIfNeeded()
    }

    func refreshCacheStats() {
        cacheStats = try? repository.cacheStats()
    }

    private func enqueueSync(for gameGeneration: PokemonGeneration) {
        guard (try? repository.needsGameSync(for: gameGeneration)) == true
            || (try? repository.needsNetworkSync(for: gameGeneration)) == true else {
            return
        }

        guard !pendingSyncGenerations.contains(gameGeneration) else { return }
        pendingSyncGenerations.append(gameGeneration)
    }

    private func startSyncWorkerIfNeeded() {
        guard syncWorkerTask == nil else { return }
        guard !pendingSyncGenerations.isEmpty else { return }

        syncWorkerTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let nextGeneration = await MainActor.run { () -> PokemonGeneration? in
                    guard !self.pendingSyncGenerations.isEmpty else { return nil }
                    return self.pendingSyncGenerations.removeFirst()
                }

                guard let nextGeneration else { break }

                await self.syncGameData(for: nextGeneration, replacingState: false)
            }

            await MainActor.run {
                self.syncWorkerTask = nil
                if !self.pendingSyncGenerations.isEmpty {
                    self.startSyncWorkerIfNeeded()
                }
            }
        }
    }

    private func syncGameData(for gameGeneration: PokemonGeneration, replacingState: Bool) async {
        if (try? repository.rebuildGameDataLocally(for: gameGeneration)) == true,
           (try? repository.hasPlayableData(for: gameGeneration)) == true,
           (try? repository.needsNetworkSync(for: gameGeneration)) == false {
            refreshCacheStats()
            if case .idle = syncState {
                syncState = .ready(source: .api)
            }
            return
        }

        guard !syncState.isSyncing else {
            enqueueSync(for: gameGeneration)
            return
        }

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
            }
        } catch {
            if replacingState || (try? repository.speciesCount()) == 0 {
                _ = try? repository.loadSeedFallbackIfNeeded()
                if (try? repository.speciesCount()) ?? 0 > 0 {
                    syncState = .ready(source: .seedFallback)
                    refreshCacheStats()
                    startSyncWorkerIfNeeded()
                    return
                }
            }
            syncState = .failed(error.localizedDescription)
            refreshCacheStats()
        }
    }
}
