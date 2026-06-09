import XCTest
@testable import Pocket_Catch_Rater

final class PokeAPIClientTests: XCTestCase {
    func testDecodesGenerationFixture() throws {
        let json = """
        {
          "pokemon_species": [
            {"name": "bulbasaur", "url": "https://pokeapi.co/api/v2/pokemon-species/1/"}
          ]
        }
        """.data(using: .utf8)!

        struct GenerationResponse: Decodable {
            let pokemonSpecies: [NamedResource]
            enum CodingKeys: String, CodingKey {
                case pokemonSpecies = "pokemon_species"
            }
        }
        struct NamedResource: Decodable {
            let url: String
            var idFromURL: Int {
                let trimmed = url.hasSuffix("/") ? String(url.dropLast()) : url
                return Int(trimmed.split(separator: "/").last ?? "0") ?? 0
            }
        }

        let decoded = try JSONDecoder().decode(GenerationResponse.self, from: json)
        XCTAssertEqual(decoded.pokemonSpecies.first?.idFromURL, 1)
    }

    func testDecodesSpeciesFixture() throws {
        let json = """
        {
          "id": 149,
          "name": "dragonite",
          "capture_rate": 45,
          "generation": {"name": "generation-i", "url": "https://pokeapi.co/api/v2/generation/1/"}
        }
        """.data(using: .utf8)!

        struct SpeciesResponse: Decodable {
            let id: Int
            let captureRate: Int
            enum CodingKeys: String, CodingKey {
                case id
                case captureRate = "capture_rate"
            }
        }

        let decoded = try JSONDecoder().decode(SpeciesResponse.self, from: json)
        XCTAssertEqual(decoded.id, 149)
        XCTAssertEqual(decoded.captureRate, 45)
    }
}
