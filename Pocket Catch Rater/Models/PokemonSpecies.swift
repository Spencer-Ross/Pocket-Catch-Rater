import Foundation

struct PokemonSpecies: Identifiable, Sendable, Hashable {
    let id: Int
    let name: String
    let generation: Int
    let baseHP: Int
    let catchRate: Int
    let type1: String?
    let type2: String?

    var displayName: String {
        String(format: "#%03d %@", id, name)
    }

    var spriteURL: URL? {
        GameMediaURL.pokemonSprite(speciesID: id)
    }

    var hasWaterOrBugType: Bool {
        [type1, type2].compactMap { $0?.lowercased() }.contains { $0 == "water" || $0 == "bug" }
    }
}

struct SpeciesSeedEntry: Codable {
    let id: Int
    let name: String
    let generation: Int
    let baseHP: Int
    let catchRate: Int
    let type1: String?
    let type2: String?

    init(
        id: Int,
        name: String,
        generation: Int,
        baseHP: Int,
        catchRate: Int,
        type1: String? = nil,
        type2: String? = nil
    ) {
        self.id = id
        self.name = name
        self.generation = generation
        self.baseHP = baseHP
        self.catchRate = catchRate
        self.type1 = type1
        self.type2 = type2
    }
}

nonisolated struct SpeciesDTO: Sendable {
    let id: Int
    let name: String
    let generation: Int
    let baseHP: Int
    let catchRate: Int
    let type1: String?
    let type2: String?

    init(
        id: Int,
        name: String,
        generation: Int,
        baseHP: Int,
        catchRate: Int,
        type1: String? = nil,
        type2: String? = nil
    ) {
        self.id = id
        self.name = name
        self.generation = generation
        self.baseHP = baseHP
        self.catchRate = catchRate
        self.type1 = type1
        self.type2 = type2
    }
}
