import Foundation

nonisolated enum PokemonGeneration: Int, CaseIterable, Identifiable, Sendable {
    case gen1 = 1
    case gen2 = 2
    case gen3 = 3
    case gen4 = 4
    case gen5 = 5
    case gen6 = 6
    case gen7 = 7
    case gen8 = 8
    case gen9 = 9

    var id: Int { rawValue }

    var displayName: String {
        "Gen \(rawValue)"
    }

    var gamesLabel: String {
        switch self {
        case .gen1: "Red, Blue & Yellow"
        case .gen2: "Gold, Silver & Crystal"
        case .gen3: "Ruby, Sapphire & Emerald"
        case .gen4: "Diamond, Pearl & Platinum"
        case .gen5: "Black & White"
        case .gen6: "X & Y"
        case .gen7: "Sun & Moon"
        case .gen8: "Sword & Shield"
        case .gen9: "Scarlet & Violet"
        }
    }

    var isCalculatorAvailable: Bool { true }

    var formulaFamily: CaptureFormulaFamily {
        switch self {
        case .gen1: .gen1
        case .gen2: .gen2
        case .gen3, .gen4: .gen3to4
        case .gen5: .gen5
        case .gen6, .gen7: .gen6to7
        case .gen8, .gen9: .gen8to9
        }
    }

    /// Data sources that define which species are catchable in this generation's games.
    var syncSources: [GameSyncSource] {
        switch self {
        case .gen9:
            return [.pokedex(31), .pokedex(32), .pokedex(33)]
        default:
            return (1...rawValue).map { .generation($0) }
        }
    }

    static var allSyncSources: [GameSyncSource] {
        let generationSources = (1...8).map { GameSyncSource.generation($0) }
        let pokedexSources = [31, 32, 33].map { GameSyncSource.pokedex($0) }
        return generationSources + pokedexSources
    }
}

nonisolated enum GameSyncSource: Sendable, Equatable, Hashable {
    case generation(Int)
    case pokedex(Int)

    var metadataKey: String {
        switch self {
        case .generation(let generation):
            "last_sync_source_generation_\(generation)"
        case .pokedex(let pokedexID):
            "last_sync_source_pokedex_\(pokedexID)"
        }
    }
}

nonisolated enum CaptureFormulaFamily: Sendable {
    case gen1
    case gen2
    case gen3to4
    case gen5
    case gen6to7
    case gen8to9
}
