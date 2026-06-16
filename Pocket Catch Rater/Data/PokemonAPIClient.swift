import Foundation

protocol PokemonAPIClient: Sendable {
    func fetchGenerationRoster(_ generation: Int) async throws -> [RosterEntryDTO]

    func fetchPokedexRoster(_ pokedexID: Int) async throws -> [RosterEntryDTO]

    func fetchSpeciesDetails(_ speciesID: Int) async throws -> SpeciesDTO

    func fetchGeneration(
        _ generation: Int,
        progress: (@Sendable (Int, Int) -> Void)?
    ) async throws -> [SpeciesDTO]

    func fetchPokedex(
        _ pokedexID: Int,
        progress: (@Sendable (Int, Int) -> Void)?
    ) async throws -> [SpeciesDTO]
}

extension PokeAPIClient: PokemonAPIClient {}
