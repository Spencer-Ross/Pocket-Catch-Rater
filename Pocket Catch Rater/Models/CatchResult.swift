import Foundation

struct CatchResult: Sendable {
    let probability: Double
    let hpFactor: Int
    let wobbleCount: Int
    let isAtHPCap: Bool
    let maxHP: Int
    let currentHP: Int
    let speciesCatchRate: Int
    let effectiveCatchRate: Int
    let ballBonus: Double?

    var probabilityPercent: Double { probability * 100 }
}
