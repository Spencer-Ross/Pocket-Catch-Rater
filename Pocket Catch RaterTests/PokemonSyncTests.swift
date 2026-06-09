import XCTest
@testable import Pocket_Catch_Rater

final class PokemonSyncTests: XCTestCase {
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
    var fetchGenerationCallCount: [Int: Int] = [:]
    var fetchPokedexCallCount: [Int: Int] = [:]

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
