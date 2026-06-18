import XCTest
@testable import Pocket_Catch_Rater

final class PokemonSyncTests: XCTestCase {
    func testSyncRosterUpsertsStubsAndAvailability() async throws {
        let database = try PokemonDatabase(inMemory: true)
        let mock = MockPokemonAPIClient()
        mock.rosterByGeneration = [
            1: [
                RosterEntryDTO(id: 1, name: "Bulbasaur", generation: 1),
                RosterEntryDTO(id: 4, name: "Charmander", generation: 1),
            ],
        ]

        let repository = PokemonRepository(database: database, apiClient: mock)
        let result = try await repository.syncRoster(for: .gen1)

        XCTAssertEqual(result.speciesCount, 2)
        XCTAssertEqual(try repository.speciesCount(inGameGeneration: 1), 2)
        XCTAssertEqual(mock.fetchGenerationRosterCallCount[1], 1)
        XCTAssertEqual(mock.fetchGenerationCallCount[1], nil)

        let bulbasaur = try XCTUnwrap(try repository.species(id: 1))
        XCTAssertFalse(bulbasaur.hasDetails)
        XCTAssertEqual(bulbasaur.catchRate, 0)
        XCTAssertNotNil(try database.metadataValue(for: "roster_source_generation_1"))
    }

    func testEnsureSpeciesDetailsBackfillsMissingWeight() async throws {
        let database = try PokemonDatabase(inMemory: true)
        let mock = MockPokemonAPIClient()
        let timestamp = ISO8601DateFormatter().string(from: Date())

        try database.upsertSpecies(
            [SpeciesDTO(id: 25, name: "Pikachu", generation: 1, baseHP: 35, catchRate: 190, type1: "electric")],
            timestamp: timestamp
        )

        let stale = try XCTUnwrap(try database.species(id: 25))
        XCTAssertTrue(stale.hasDetails)
        XCTAssertNil(stale.weightKg)

        mock.speciesDetails[25] = SpeciesDTO(
            id: 25,
            name: "Pikachu",
            generation: 1,
            baseHP: 35,
            catchRate: 190,
            type1: "electric",
            weightKg: 6.0,
            baseSpeed: 90
        )

        let repository = PokemonRepository(database: database, apiClient: mock)
        let detailed = try await repository.ensureSpeciesDetails(speciesID: 25)

        XCTAssertEqual(detailed.weightKg, 6.0)
        XCTAssertEqual(detailed.baseSpeed, 90)
        XCTAssertTrue(detailed.hasCompleteDetails)
        XCTAssertEqual(mock.fetchSpeciesDetailsCallCount[25], 1)

        let cached = try await repository.ensureSpeciesDetails(speciesID: 25)
        XCTAssertEqual(cached.weightKg, 6.0)
        XCTAssertEqual(mock.fetchSpeciesDetailsCallCount[25], 1)
    }

    func testEnsureSpeciesDetailsFetchesAndCaches() async throws {
        let database = try PokemonDatabase(inMemory: true)
        let mock = MockPokemonAPIClient()
        mock.rosterByGeneration = [
            1: [RosterEntryDTO(id: 25, name: "Pikachu", generation: 1)],
        ]
        mock.speciesDetails = [
            25: SpeciesDTO(
                id: 25,
                name: "Pikachu",
                generation: 1,
                baseHP: 35,
                catchRate: 190,
                type1: "electric",
                weightKg: 6.0,
                baseSpeed: 90
            ),
        ]

        let repository = PokemonRepository(database: database, apiClient: mock)
        _ = try await repository.syncRoster(for: .gen1)

        let detailed = try await repository.ensureSpeciesDetails(speciesID: 25)
        XCTAssertTrue(detailed.hasDetails)
        XCTAssertEqual(detailed.catchRate, 190)
        XCTAssertEqual(mock.fetchSpeciesDetailsCallCount[25], 1)

        let cached = try await repository.ensureSpeciesDetails(speciesID: 25)
        XCTAssertEqual(cached.catchRate, 190)
        XCTAssertEqual(mock.fetchSpeciesDetailsCallCount[25], 1)
    }

    func testSyncGenerationUpsertsSpeciesAndMetadata() async throws {
        let database = try PokemonDatabase(inMemory: true)
        let mock = MockPokemonAPIClient()
        mock.results = [
            SpeciesDTO(id: 1, name: "Bulbasaur", generation: 1, baseHP: 45, catchRate: 45),
            SpeciesDTO(id: 4, name: "Charmander", generation: 1, baseHP: 39, catchRate: 45),
        ]

        let repository = PokemonRepository(database: database, apiClient: mock)
        let progressCollector = ProgressCollector()
        let result = try await repository.syncGameData(for: .gen1) { completed, total in
            progressCollector.append((completed, total))
        }

        XCTAssertEqual(result.speciesCount, 2)
        XCTAssertEqual(try repository.speciesCount(), 2)
        XCTAssertEqual(try repository.speciesCount(inGameGeneration: 1), 2)
        XCTAssertEqual(try database.availabilityCount(for: 1), 2)
        XCTAssertNotNil(try database.metadataValue(for: "last_sync_gen_1"))
        XCTAssertEqual(try database.metadataValue(for: "data_source"), "api")
        XCTAssertFalse(progressCollector.values.isEmpty)

        let bulbasaur = try XCTUnwrap(try repository.species(id: 1))
        XCTAssertTrue(bulbasaur.hasDetails)
    }

    func testGen2SyncMarksAvailabilityForBothGenerations() async throws {
        let database = try PokemonDatabase(inMemory: true)
        let mock = MockPokemonAPIClient()
        mock.resultsByGeneration = [
            1: [SpeciesDTO(id: 1, name: "Bulbasaur", generation: 1, baseHP: 45, catchRate: 45, type1: "grass", type2: "poison")],
            2: [SpeciesDTO(id: 152, name: "Chikorita", generation: 2, baseHP: 45, catchRate: 45, type1: "grass", type2: nil)],
        ]

        let repository = PokemonRepository(database: database, apiClient: mock)
        _ = try await repository.syncGameData(for: .gen2)

        XCTAssertEqual(try repository.speciesCount(inGameGeneration: 2), 2)
        XCTAssertEqual(try database.availabilityCount(for: 2), 2)
    }

    func testGen2SyncSkipsAlreadySyncedGenerationSource() async throws {
        let database = try PokemonDatabase(inMemory: true)
        let mock = MockPokemonAPIClient()
        mock.resultsByGeneration = [
            1: [SpeciesDTO(id: 1, name: "Bulbasaur", generation: 1, baseHP: 45, catchRate: 45)],
            2: [SpeciesDTO(id: 152, name: "Chikorita", generation: 2, baseHP: 45, catchRate: 45)],
        ]

        let repository = PokemonRepository(database: database, apiClient: mock)
        _ = try await repository.syncGameData(for: .gen1)
        XCTAssertEqual(mock.fetchGenerationCallCount[1], 1)

        _ = try await repository.syncGameData(for: .gen2)
        XCTAssertEqual(mock.fetchGenerationCallCount[1], 1)
        XCTAssertEqual(mock.fetchGenerationCallCount[2], 1)
    }

    func testSyncAllMissingDataRebuildsAllGenerations() async throws {
        let database = try PokemonDatabase(inMemory: true)
        let mock = MockPokemonAPIClient()
        mock.resultsByGeneration = [
            1: [SpeciesDTO(id: 1, name: "Bulbasaur", generation: 1, baseHP: 45, catchRate: 45)],
            2: [SpeciesDTO(id: 152, name: "Chikorita", generation: 2, baseHP: 45, catchRate: 45)],
        ]
        mock.pokedexResults = [
            31: [SpeciesDTO(id: 906, name: "Sprigatito", generation: 9, baseHP: 40, catchRate: 45, type1: "grass", type2: nil)],
        ]

        let repository = PokemonRepository(database: database, apiClient: mock)
        let result = try await repository.syncAllMissingData()

        XCTAssertGreaterThan(result.speciesCount, 0)
        XCTAssertEqual(try database.availabilityCount(for: 1), 1)
        XCTAssertEqual(try database.availabilityCount(for: 2), 2)
        XCTAssertEqual(try database.availabilityCount(for: 9), 1)
    }

    func testRebuildGameDataLocallyUsesCachedSourcesWithoutAPI() async throws {
        let database = try PokemonDatabase(inMemory: true)
        let mock = MockPokemonAPIClient()
        mock.resultsByGeneration = [
            1: [SpeciesDTO(id: 1, name: "Bulbasaur", generation: 1, baseHP: 45, catchRate: 45)],
            2: [SpeciesDTO(id: 152, name: "Chikorita", generation: 2, baseHP: 45, catchRate: 45)],
        ]

        let repository = PokemonRepository(database: database, apiClient: mock)
        _ = try await repository.syncAllMissingData()
        mock.fetchGenerationCallCount = [:]

        XCTAssertTrue(try repository.rebuildGameDataLocally(for: .gen2))
        XCTAssertEqual(try repository.speciesCount(inGameGeneration: 2), 2)
        XCTAssertEqual(mock.fetchGenerationCallCount[1], nil)
        XCTAssertEqual(mock.fetchGenerationCallCount[2], nil)
    }

    func testRebuildGameDataLocallyUsesCachedRosterWithoutAPI() async throws {
        let database = try PokemonDatabase(inMemory: true)
        let mock = MockPokemonAPIClient()
        mock.rosterByGeneration = [
            1: [RosterEntryDTO(id: 1, name: "Bulbasaur", generation: 1)],
            2: [RosterEntryDTO(id: 152, name: "Chikorita", generation: 2)],
        ]

        let repository = PokemonRepository(database: database, apiClient: mock)
        _ = try await repository.syncRoster(for: .gen2)
        mock.fetchGenerationRosterCallCount = [:]

        XCTAssertTrue(try repository.rebuildGameDataLocally(for: .gen2))
        XCTAssertEqual(try repository.speciesCount(inGameGeneration: 2), 2)
        XCTAssertEqual(mock.fetchGenerationRosterCallCount[1], nil)
        XCTAssertEqual(mock.fetchGenerationRosterCallCount[2], nil)
    }

    func testHasPlayableDataReflectsAvailabilityTable() async throws {
        let database = try PokemonDatabase(inMemory: true)
        let mock = MockPokemonAPIClient()
        mock.rosterByGeneration = [
            1: [RosterEntryDTO(id: 1, name: "Bulbasaur", generation: 1)],
        ]

        let repository = PokemonRepository(database: database, apiClient: mock)
        XCTAssertFalse(try repository.hasPlayableData(for: .gen1))

        _ = try await repository.syncRoster(for: .gen1)
        XCTAssertTrue(try repository.hasPlayableData(for: .gen1))
    }
}

private final class ProgressCollector: @unchecked Sendable {
    private var updates: [(Int, Int)] = []
    private let lock = NSLock()

    func append(_ value: (Int, Int)) {
        lock.lock()
        updates.append(value)
        lock.unlock()
    }

    var values: [(Int, Int)] {
        lock.lock()
        defer { lock.unlock() }
        return updates
    }
}

private final class MockPokemonAPIClient: PokemonAPIClient, @unchecked Sendable {
    var results: [SpeciesDTO] = []
    var resultsByGeneration: [Int: [SpeciesDTO]] = [:]
    var pokedexResults: [Int: [SpeciesDTO]] = [:]
    var rosterByGeneration: [Int: [RosterEntryDTO]] = [:]
    var rosterByPokedex: [Int: [RosterEntryDTO]] = [:]
    var speciesDetails: [Int: SpeciesDTO] = [:]
    var fetchGenerationCallCount: [Int: Int] = [:]
    var fetchPokedexCallCount: [Int: Int] = [:]
    var fetchGenerationRosterCallCount: [Int: Int] = [:]
    var fetchPokedexRosterCallCount: [Int: Int] = [:]
    var fetchSpeciesDetailsCallCount: [Int: Int] = [:]

    func fetchGenerationRoster(_ generation: Int) async throws -> [RosterEntryDTO] {
        fetchGenerationRosterCallCount[generation, default: 0] += 1
        return rosterByGeneration[generation] ?? []
    }

    func fetchPokedexRoster(_ pokedexID: Int) async throws -> [RosterEntryDTO] {
        fetchPokedexRosterCallCount[pokedexID, default: 0] += 1
        return rosterByPokedex[pokedexID] ?? []
    }

    func fetchSpeciesDetails(_ speciesID: Int) async throws -> SpeciesDTO {
        fetchSpeciesDetailsCallCount[speciesID, default: 0] += 1
        guard let dto = speciesDetails[speciesID] else {
            throw PokeAPIError.decodingFailed
        }
        return dto
    }

    func fetchGeneration(
        _ generation: Int,
        progress: (@Sendable (Int, Int) -> Void)?
    ) async throws -> [SpeciesDTO] {
        fetchGenerationCallCount[generation, default: 0] += 1
        let batch = resultsByGeneration[generation] ?? results
        progress?(0, batch.count)
        progress?(batch.count, batch.count)
        return batch
    }

    func fetchPokedex(
        _ pokedexID: Int,
        progress: (@Sendable (Int, Int) -> Void)?
    ) async throws -> [SpeciesDTO] {
        fetchPokedexCallCount[pokedexID, default: 0] += 1
        let batch = pokedexResults[pokedexID] ?? []
        progress?(0, batch.count)
        progress?(batch.count, batch.count)
        return batch
    }
}
