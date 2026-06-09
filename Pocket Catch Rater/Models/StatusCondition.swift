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

    /// Gen 2 additive status bonus
    var gen2CaptureBonus: Int {
        switch self {
        case .sleep, .freeze: 10
        case .poison, .burn, .paralysis: 5
        case .none: 0
        }
    }

    /// Gen 3+ status multiplier S
    var modernMultiplier: Double {
        switch self {
        case .sleep, .freeze: 2.5
        case .poison, .burn, .paralysis: 1.5
        case .none: 1
        }
    }
}
