import Foundation

nonisolated final class PokemonRepository {
    private let database: PokemonDatabase
    private let apiClient: any PokemonAPIClient

    init(database: PokemonDatabase, apiClient: any PokemonAPIClient = PokeAPIClient()) {
        self.database = database
        self.apiClient = apiClient
    }

    func speciesCount() throws -> Int {
        try database.speciesCount()
    }

    func speciesCount(inGameGeneration gameGeneration: Int) throws -> Int {
        try database.species(inGameGeneration: gameGeneration).count
    }

    func speciesCount(for generation: Int) throws -> Int {
        try speciesCount(inGameGeneration: generation)
    }

    func cacheStats() throws -> CacheStats {
        var lastSync: [Int: String] = [:]
        for generation in PokemonGeneration.allCases {
            if let value = try database.metadataValue(for: Self.syncMetadataKey(for: generation)) {
                lastSync[generation.rawValue] = value
            }
        }

        return CacheStats(
            speciesCount: try database.speciesCount(),
            databaseBytes: database.databaseFileSize,
            lastSyncByGeneration: lastSync
        )
    }

    func species(in gameGeneration: PokemonGeneration) throws -> [PokemonSpecies] {
        try database.species(inGameGeneration: gameGeneration.rawValue)
    }

    func species(for generation: Int) throws -> [PokemonSpecies] {
        try database.species(inGameGeneration: generation)
    }

    func search(name: String, in gameGeneration: PokemonGeneration) throws -> [PokemonSpecies] {
        try database.search(name: name, inGameGeneration: gameGeneration.rawValue)
    }

    func search(name: String, generation: Int) throws -> [PokemonSpecies] {
        try database.search(name: name, inGameGeneration: generation)
    }

    func isSpeciesAvailable(_ species: PokemonSpecies, in gameGeneration: PokemonGeneration) throws -> Bool {
        try database.isSpeciesAvailable(species.id, inGameGeneration: gameGeneration.rawValue)
    }

    func needsGameSync(for gameGeneration: PokemonGeneration) throws -> Bool {
        try database.metadataValue(for: Self.syncMetadataKey(for: gameGeneration)) == nil
    }

    func needsAnySync() throws -> Bool {
        try PokemonGeneration.allSyncSources.contains {
            try database.metadataValue(for: $0.metadataKey) == nil
        }
    }

    func syncGeneration(
        _ generation: Int,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> SyncResult {
        try await syncGameData(for: PokemonGeneration(rawValue: generation) ?? .gen1, progress: progress)
    }

    func syncAllMissingData(
        progress: (@Sendable (Int, Int, PokemonGeneration) -> Void)? = nil
    ) async throws -> SyncResult {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let sources = PokemonGeneration.allSyncSources
        var syncedSpeciesCount = 0

        for (index, source) in sources.enumerated() {
            let sourceProgress: (@Sendable (Int, Int) -> Void)?
            if let progress {
                let capturedIndex = index
                let capturedSourceCount = sources.count
                sourceProgress = { completed, total in
                    progress(
                        capturedIndex * 1000 + completed,
                        capturedSourceCount * 1000 + total,
                        .gen1
                    )
                }
            } else {
                sourceProgress = nil
            }

            let fetched = try await syncSourceIfNeeded(source, progress: sourceProgress)
            syncedSpeciesCount = max(syncedSpeciesCount, fetched)
        }

        for gameGeneration in PokemonGeneration.allCases {
            try database.rebuildAvailability(for: gameGeneration.rawValue)
            try database.setMetadata(key: Self.syncMetadataKey(for: gameGeneration), value: timestamp)
        }

        try database.setMetadata(key: "data_source", value: "api")
        try database.setMetadata(key: "total_species_count", value: String(try database.speciesCount()))

        return SyncResult(
            generation: 0,
            speciesCount: try database.speciesCount(),
            errors: []
        )
    }

    func syncGameData(
        for gameGeneration: PokemonGeneration,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> SyncResult {
        let sources = gameGeneration.syncSources
        var completedSources = 0
        let totalSources = sources.count

        for source in sources {
            let sourceProgress: (@Sendable (Int, Int) -> Void)?
            if let progress {
                let capturedCompletedSources = completedSources
                let capturedTotalSources = totalSources
                sourceProgress = { completed, total in
                    let overallTotal = max(total, 1) * capturedTotalSources
                    let overallCompleted = capturedCompletedSources * max(total, 1) + completed
                    progress(overallCompleted, overallTotal)
                }
            } else {
                sourceProgress = nil
            }

            _ = try await syncSourceIfNeeded(source, progress: sourceProgress)
            completedSources += 1
        }

        try database.rebuildAvailability(for: gameGeneration.rawValue)

        let timestamp = ISO8601DateFormatter().string(from: Date())
        try database.setMetadata(key: Self.syncMetadataKey(for: gameGeneration), value: timestamp)
        try database.setMetadata(key: "data_source", value: "api")
        try database.setMetadata(key: "total_species_count", value: String(try database.speciesCount()))

        let availableCount = try database.availabilityCount(for: gameGeneration.rawValue)

        return SyncResult(
            generation: gameGeneration.rawValue,
            speciesCount: availableCount,
            errors: []
        )
    }

    func loadSeedFallbackIfNeeded() throws -> Bool {
        guard try database.speciesCount() == 0 else { return false }

        guard let url = Bundle.main.url(forResource: "gen1_seed", withExtension: "json") else {
            return false
        }

        let data = try Data(contentsOf: url)
        let entries = try JSONDecoder().decode([SpeciesSeedEntry].self, from: data)
        let dtos = entries.map {
            SpeciesDTO(
                id: $0.id,
                name: $0.name,
                generation: $0.generation,
                baseHP: $0.baseHP,
                catchRate: $0.catchRate,
                type1: $0.type1,
                type2: $0.type2
            )
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        try database.upsertSpecies(dtos, timestamp: timestamp)
        try database.markSpeciesAvailable(dtos.map(\.id), gameGeneration: PokemonGeneration.gen1.rawValue)
        try database.setMetadata(key: "data_source", value: "seed_fallback")
        return true
    }

    func clearCache() throws {
        try database.clearAllData()
    }

    private func syncSourceIfNeeded(
        _ source: GameSyncSource,
        progress: (@Sendable (Int, Int) -> Void)?
    ) async throws -> Int {
        if try database.metadataValue(for: source.metadataKey) != nil {
            return try database.speciesCount()
        }

        let fetched: [SpeciesDTO]
        switch source {
        case .generation(let generation):
            fetched = try await apiClient.fetchGeneration(generation, progress: progress)
        case .pokedex(let pokedexID):
            fetched = try await apiClient.fetchPokedex(pokedexID, progress: progress)
        }

        let uniqueSpecies = Self.uniqueSpecies(fetched)
        let timestamp = ISO8601DateFormatter().string(from: Date())

        try database.upsertSpecies(uniqueSpecies, timestamp: timestamp)

        if case .pokedex(let pokedexID) = source {
            try database.replacePokedexMembership(
                pokedexID: pokedexID,
                speciesIDs: uniqueSpecies.map(\.id)
            )
        }

        try database.setMetadata(key: source.metadataKey, value: timestamp)
        return uniqueSpecies.count
    }

    private static func syncMetadataKey(for gameGeneration: PokemonGeneration) -> String {
        "last_sync_gen_\(gameGeneration.rawValue)"
    }

    private static func uniqueSpecies(_ species: [SpeciesDTO]) -> [SpeciesDTO] {
        var seen: Set<Int> = []
        var unique: [SpeciesDTO] = []
        unique.reserveCapacity(species.count)

        for entry in species.sorted(by: { $0.id < $1.id }) {
            guard seen.insert(entry.id).inserted else { continue }
            unique.append(entry)
        }

        return unique
    }
}
