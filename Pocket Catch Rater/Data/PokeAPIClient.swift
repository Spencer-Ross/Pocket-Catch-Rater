import Foundation

enum PokeAPIError: LocalizedError {
    case invalidURL
    case badStatus(Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid PokeAPI URL."
        case .badStatus(let code): "PokeAPI returned status \(code)."
        case .decodingFailed: "Failed to decode PokeAPI response."
        }
    }
}

nonisolated final class PokeAPIClient: Sendable {
    private let session: URLSession
    private let baseURL = "https://pokeapi.co/api/v2"
    private let maxConcurrentRequests: Int

    init(session: URLSession = .shared, maxConcurrentRequests: Int = 8) {
        self.session = session
        self.maxConcurrentRequests = maxConcurrentRequests
    }

    func fetchGeneration(
        _ generation: Int,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> [SpeciesDTO] {
        let generationResponse: GenerationResponse = try await get("/generation/\(generation)")
        let entries = generationResponse.pokemonSpecies
        let total = entries.count
        var results: [SpeciesDTO] = []
        results.reserveCapacity(total)

        progress?(0, total)

        for chunkStart in stride(from: 0, to: entries.count, by: maxConcurrentRequests) {
            let chunkEnd = min(chunkStart + maxConcurrentRequests, entries.count)
            let chunk = entries[chunkStart..<chunkEnd]

            let chunkResults = try await withThrowingTaskGroup(of: SpeciesDTO.self) { group in
                for entry in chunk {
                    let speciesID = entry.idFromURL
                    group.addTask {
                        try await self.fetchSpeciesDTO(speciesID: speciesID)
                    }
                }

                var batch: [SpeciesDTO] = []
                batch.reserveCapacity(chunk.count)
                for try await dto in group {
                    batch.append(dto)
                }
                return batch
            }

            results.append(contentsOf: chunkResults)
            progress?(results.count, total)
        }

        return results.sorted { $0.id < $1.id }
    }

    func fetchPokedex(
        _ pokedexID: Int,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> [SpeciesDTO] {
        let pokedexResponse: PokedexResponse = try await get("/pokedex/\(pokedexID)")
        let speciesIDs = Array(
            Set(
                pokedexResponse.pokemonEntries.map(\.speciesID).filter { $0 > 0 }
            )
        ).sorted()
        let total = speciesIDs.count
        var results: [SpeciesDTO] = []
        results.reserveCapacity(total)

        progress?(0, total)

        for chunkStart in stride(from: 0, to: speciesIDs.count, by: maxConcurrentRequests) {
            let chunkEnd = min(chunkStart + maxConcurrentRequests, speciesIDs.count)
            let chunk = speciesIDs[chunkStart..<chunkEnd]

            let chunkResults = try await withThrowingTaskGroup(of: SpeciesDTO.self) { group in
                for speciesID in chunk {
                    group.addTask {
                        try await self.fetchSpeciesDTO(speciesID: speciesID)
                    }
                }

                var batch: [SpeciesDTO] = []
                batch.reserveCapacity(chunk.count)
                for try await dto in group {
                    batch.append(dto)
                }
                return batch
            }

            results.append(contentsOf: chunkResults)
            progress?(results.count, total)
        }

        return results.sorted { $0.id < $1.id }
    }

    private func fetchSpeciesDTO(speciesID: Int) async throws -> SpeciesDTO {
        async let species: PokemonSpeciesResponse = get("/pokemon-species/\(speciesID)")
        async let pokemon: PokemonResponse = get("/pokemon/\(speciesID)")

        let speciesValue = try await species
        let pokemonValue = try await pokemon
        let baseHP = pokemonValue.stats.first(where: { $0.stat.name == "hp" })?.baseStat ?? 0
        let sortedTypes = pokemonValue.types.sorted { $0.slot < $1.slot }.map(\.type.name)

        return SpeciesDTO(
            id: speciesValue.id,
            name: speciesValue.displayName,
            generation: speciesValue.generation.idFromURL,
            baseHP: baseHP,
            catchRate: speciesValue.captureRate,
            type1: sortedTypes.first,
            type2: sortedTypes.count > 1 ? sortedTypes[1] : nil
        )
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw PokeAPIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw PokeAPIError.badStatus(-1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw PokeAPIError.badStatus(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw PokeAPIError.decodingFailed
        }
    }
}

// MARK: - Response types

nonisolated private struct PokedexResponse: Decodable, Sendable {
    let pokemonEntries: [PokedexEntry]

    enum CodingKeys: String, CodingKey {
        case pokemonEntries = "pokemon_entries"
    }
}

nonisolated private struct PokedexEntry: Decodable, Sendable {
    let pokemonSpecies: NamedResource

    enum CodingKeys: String, CodingKey {
        case pokemonSpecies = "pokemon_species"
    }

    var speciesID: Int {
        pokemonSpecies.idFromURL
    }
}

nonisolated private struct GenerationResponse: Decodable, Sendable {
    let pokemonSpecies: [NamedResource]

    enum CodingKeys: String, CodingKey {
        case pokemonSpecies = "pokemon_species"
    }
}

nonisolated private struct NamedResource: Decodable, Sendable {
    let url: String

    var idFromURL: Int {
        let trimmed = url.hasSuffix("/") ? String(url.dropLast()) : url
        return Int(trimmed.split(separator: "/").last ?? "0") ?? 0
    }
}

nonisolated private struct PokemonSpeciesResponse: Decodable, Sendable {
    let id: Int
    let name: String
    let captureRate: Int
    let generation: NamedResource

    enum CodingKeys: String, CodingKey {
        case id, name, generation
        case captureRate = "capture_rate"
    }

    var displayName: String {
        name.split(separator: "-").map { part in
            part.prefix(1).uppercased() + part.dropFirst()
        }.joined(separator: "-")
    }
}

nonisolated private struct PokemonResponse: Decodable, Sendable {
    let stats: [StatEntry]
    let types: [TypeSlot]
}

nonisolated private struct TypeSlot: Decodable, Sendable {
    let slot: Int
    let type: NamedStat
}

nonisolated private struct StatEntry: Decodable, Sendable {
    let baseStat: Int
    let stat: NamedStat

    enum CodingKeys: String, CodingKey {
        case baseStat = "base_stat"
        case stat
    }
}

nonisolated private struct NamedStat: Decodable, Sendable {
    let name: String
}
