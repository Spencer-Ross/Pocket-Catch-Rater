import Foundation

enum StatusCondition: String, CaseIterable, Identifiable, Sendable {
    case none
    case poison
    case burn
    case paralysis
    case sleep
    case freeze

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "None"
        case .poison: "Poison"
        case .burn: "Burn"
        case .paralysis: "Paralysis"
        case .sleep: "Sleep"
        case .freeze: "Freeze"
        }
    }

    var iconSystemName: String {
        switch self {
        case .none: "circle"
        case .poison: "drop.fill"
        case .burn: "flame.fill"
        case .paralysis: "bolt.fill"
        case .sleep: "moon.zzz.fill"
        case .freeze: "snowflake"
        }
    }

    var iconColorName: String {
        switch self {
        case .none: "secondary"
        case .poison: "purple"
        case .burn: "orange"
        case .paralysis: "yellow"
        case .sleep: "indigo"
        case .freeze: "cyan"
        }
    }

    var gridLabel: String {
        switch self {
        case .none: "None"
        case .poison: "PSN"
        case .burn: "BRN"
        case .paralysis: "PAR"
        case .sleep: "SLP"
        case .freeze: "FRZ"
        }
    }

    /// Gen 1 status capture threshold S
    var captureThreshold: Int {
        switch self {
        case .sleep, .freeze: 25
        case .poison, .burn, .paralysis: 12
        case .none: 0
        }
    }

    /// Gen 1 status wobble bonus S2
    var wobbleBonus: Int {
        switch self {
        case .sleep, .freeze: 10
        case .poison, .burn, .paralysis: 5
        case .none: 0
        }
    }

    /// Gen 2 additive status bonus.
    /// Due to a game bug, only sleep and freeze actually apply — the poison/burn/paralysis
    /// check always fails in G/S/C, so those conditions contribute 0.
    var gen2CaptureBonus: Int {
        switch self {
        case .sleep, .freeze: 10
        case .poison, .burn, .paralysis, .none: 0
        }
    }

    /// Gen 3+ status multiplier S.
    /// Gen III/IV: sleep/freeze = 2; Gen V+: sleep/freeze = 2.5.
    func modernMultiplier(for formulaFamily: CaptureFormulaFamily) -> Double {
        switch self {
        case .sleep, .freeze:
            return formulaFamily == .gen3to4 ? 2.0 : 2.5
        case .poison, .burn, .paralysis:
            return 1.5
        case .none:
            return 1.0
        }
    }

    /// Convenience accessor for gen 8–9 (backwards-compatible default).
    var modernMultiplier: Double { modernMultiplier(for: .gen8to9) }
}
