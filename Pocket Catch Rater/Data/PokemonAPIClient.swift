import Foundation

protocol PokemonAPIClient: Sendable {
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
