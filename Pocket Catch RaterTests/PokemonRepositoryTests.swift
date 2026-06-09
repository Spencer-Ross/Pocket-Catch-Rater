import XCTest
@testable import Pocket_Catch_Rater

final class PokemonRepositoryTests: XCTestCase {
    func testSeedFallbackLoads151Species() throws {
        let database = try PokemonDatabase(inMemory: true)
        let repository = PokemonRepository(database: database)

        let loaded = try repository.loadSeedFallbackIfNeeded()
        XCTAssertTrue(loaded)
        XCTAssertEqual(try repository.speciesCount(), 151)
    }

    func testSearchFindsPikachu() throws {
        let database = try PokemonDatabase(inMemory: true)
        let repository = PokemonRepository(database: database)
        _ = try repository.loadSeedFallbackIfNeeded()

        let results = try repository.search(name: "Pikachu", in: .gen1)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, 25)
        XCTAssertEqual(results.first?.catchRate, 190)
    }

    func testSeedFallbackMarksGen1Availability() throws {
        let database = try PokemonDatabase(inMemory: true)
        let repository = PokemonRepository(database: database)
        _ = try repository.loadSeedFallbackIfNeeded()

        XCTAssertEqual(try database.availabilityCount(for: 1), 151)
        XCTAssertEqual(try repository.speciesCount(inGameGeneration: 1), 151)
    }

    func testUpsertIsIdempotent() throws {
        let database = try PokemonDatabase(inMemory: true)
        let repository = PokemonRepository(database: database)

        let dto = SpeciesDTO(id: 25, name: "Pikachu", generation: 1, baseHP: 35, catchRate: 190)
        let timestamp = ISO8601DateFormatter().string(from: Date())

        try database.upsertSpecies([dto], timestamp: timestamp)
        try database.upsertSpecies([dto], timestamp: timestamp)

        XCTAssertEqual(try repository.speciesCount(), 1)
    }
}
