import Foundation

struct PokemonSpecies: Identifiable, Sendable, Hashable {
    let id: Int
    let name: String
    let generation: Int
    let baseHP: Int
    let catchRate: Int
    let type1: String?
    let type2: String?
    let weightKg: Double?
    let baseSpeed: Int?
    let hasDetails: Bool

    init(
        id: Int,
        name: String,
        generation: Int,
        baseHP: Int,
        catchRate: Int,
        type1: String? = nil,
        type2: String? = nil,
        weightKg: Double? = nil,
        baseSpeed: Int? = nil,
        hasDetails: Bool = true
    ) {
        self.id = id
        self.name = name
        self.generation = generation
        self.baseHP = baseHP
        self.catchRate = catchRate
        self.type1 = type1
        self.type2 = type2
        self.weightKg = weightKg
        self.baseSpeed = baseSpeed
        self.hasDetails = hasDetails
    }

    func weightClass(for ruleSet: CatchRuleSet) -> PokemonWeightClass? {
        guard let weightKg else { return nil }
        return PokemonWeightClass.classify(weightKg: weightKg, formulaFamily: ruleSet.formulaFamily)
    }

    /// True when catch stats, weight, and speed are available locally (not just a roster stub).
    var hasCompleteDetails: Bool {
        hasDetails && weightKg != nil && baseSpeed != nil
    }

    var displayName: String {
        String(format: "#%03d %@", id, name)
    }

    static let defaultSpeciesID = 25

    /// Offline-safe default used until cached/API stats are available.
    static let fallbackPikachu = PokemonSpecies(
        id: defaultSpeciesID,
        name: "Pikachu",
        generation: 1,
        baseHP: 35,
        catchRate: 190,
        type1: "electric",
        type2: nil,
        weightKg: 6.0,
        baseSpeed: 90
    )

    var spriteURL: URL? {
        GameMediaURL.pokemonSprite(speciesID: id)
    }

    var hasWaterOrBugType: Bool {
        [type1, type2].compactMap { $0?.lowercased() }.contains { $0 == "water" || $0 == "bug" }
    }

    var isUltraBeast: Bool {
        UltraBeastEligibility.isUltraBeast(speciesID: id)
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
    let weightKg: Double?
    let baseSpeed: Int?

    init(
        id: Int,
        name: String,
        generation: Int,
        baseHP: Int,
        catchRate: Int,
        type1: String? = nil,
        type2: String? = nil,
        weightKg: Double? = nil,
        baseSpeed: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.generation = generation
        self.baseHP = baseHP
        self.catchRate = catchRate
        self.type1 = type1
        self.type2 = type2
        self.weightKg = weightKg
        self.baseSpeed = baseSpeed
    }
}

nonisolated struct RosterEntryDTO: Sendable {
    let id: Int
    let name: String
    let generation: Int
}

nonisolated struct SpeciesDTO: Sendable {
    let id: Int
    let name: String
    let generation: Int
    let baseHP: Int
    let catchRate: Int
    let type1: String?
    let type2: String?
    let weightKg: Double?
    let baseSpeed: Int?

    init(
        id: Int,
        name: String,
        generation: Int,
        baseHP: Int,
        catchRate: Int,
        type1: String? = nil,
        type2: String? = nil,
        weightKg: Double? = nil,
        baseSpeed: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.generation = generation
        self.baseHP = baseHP
        self.catchRate = catchRate
        self.type1 = type1
        self.type2 = type2
        self.weightKg = weightKg
        self.baseSpeed = baseSpeed
    }
}
