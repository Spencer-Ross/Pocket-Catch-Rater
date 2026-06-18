import Foundation

/// User-facing catch formula groups — one option per distinct ruleset in the app.
nonisolated enum CatchRuleSet: String, CaseIterable, Identifiable, Sendable {
    case gen1
    case gen2
    case gen3to4
    case gen5
    case gen6
    case gen7
    case gen8to9

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gen1: "Gen 1"
        case .gen2: "Gen 2"
        case .gen3to4: "Gen 3–4"
        case .gen5: "Gen 5"
        case .gen6: "Gen 6"
        case .gen7: "Gen 7"
        case .gen8to9: "Gen 8–9"
        }
    }

    var gamesLabel: String {
        switch self {
        case .gen1: "Red, Blue & Yellow"
        case .gen2: "Gold, Silver & Crystal"
        case .gen3to4: "Ruby–Emerald, Diamond–Platinum, HeartGold & SoulSilver"
        case .gen5: "Black & White"
        case .gen6: "X & Y, Omega Ruby & Alpha Sapphire"
        case .gen7: "Sun & Moon, Ultra Sun & Ultra Moon"
        case .gen8to9: "Sword & Shield, Scarlet & Violet"
        }
    }

    var formulaFamily: CaptureFormulaFamily {
        switch self {
        case .gen1: .gen1
        case .gen2: .gen2
        case .gen3to4: .gen3to4
        case .gen5: .gen5
        case .gen6, .gen7: .gen6to7
        case .gen8to9: .gen8to9
        }
    }

    /// Generation used for species lists, balls, and sync.
    var representativeGeneration: PokemonGeneration {
        switch self {
        case .gen1: .gen1
        case .gen2: .gen2
        case .gen3to4: .gen4
        case .gen5: .gen5
        case .gen6: .gen6
        case .gen7: .gen7
        case .gen8to9: .gen9
        }
    }

    var isGen1: Bool { self == .gen1 }

    /// Compact header label below "Gen" (e.g. `3–4`, `8–9`).
    var headerGenerationValue: String {
        switch self {
        case .gen1: "1"
        case .gen2: "2"
        case .gen3to4: "3–4"
        case .gen5: "5"
        case .gen6: "6"
        case .gen7: "7"
        case .gen8to9: "8–9"
        }
    }

    static func resolved(storedRaw: String) -> CatchRuleSet {
        if storedRaw == "gen6to7" { return .gen7 }
        return CatchRuleSet(rawValue: storedRaw) ?? .gen1
    }

    static func migrated(fromLegacyGenerationRaw raw: Int) -> CatchRuleSet {
        switch raw {
        case 1: return .gen1
        case 2: return .gen2
        case 3, 4: return .gen3to4
        case 5: return .gen5
        case 6: return .gen6
        case 7: return .gen7
        default: return .gen8to9
        }
    }
}
