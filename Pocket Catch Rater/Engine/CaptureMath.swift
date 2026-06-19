import Foundation

enum CaptureMath {
    static func grassModifier(isThickGrass: Bool, pokedexCaught: Int) -> Double {
        guard isThickGrass else { return 1 }

        switch pokedexCaught {
        case 601...: return 1
        case 451...600: return 3686.0 / 4096.0
        case 301...450: return 3277.0 / 4096.0
        case 151...300: return 2867.0 / 4096.0
        case 31...150: return 0.5
        default: return 1229.0 / 4096.0
        }
    }

    static func lowLevelModifier(targetLevel: Int) -> Double {
        guard targetLevel < 21 else { return 1 }
        return Double(30 - targetLevel) / 10.0
    }

    // MARK: - Gen 2

    /// Gen 2 capture formula: X = max(((3M - 2H) × C) / (3M), 1) + S
    ///
    /// The Game Boy's division routine only handles 8-bit divisors (0–255). If 3M > 255,
    /// both 3M and 2H are divided by 4 (integer) before the formula to keep the divisor
    /// in range. This gives the same result up to minor rounding errors for legal encounters.
    static func gen2ModifiedRate(
        maxHP: Int,
        currentHP: Int,
        catchRate: Int,
        status: StatusCondition
    ) -> Int {
        var tripleMax = 3 * maxHP
        var doubleHP  = 2 * currentHP

        if tripleMax > 255 {
            tripleMax = tripleMax / 4
            doubleHP  = doubleHP  / 4
        }

        guard tripleMax > 0 else { return 1 }   // division-by-zero guard (impossible for legal HP)
        let hpTerm = (tripleMax - doubleHP) * catchRate
        let base = max(hpTerm / tripleMax, 1)
        return min(base + status.gen2CaptureBonus, 255)
    }

    static func gen2Probability(modifiedRate: Int) -> Double {
        if modifiedRate >= 255 { return 1 }
        return Double(modifiedRate + 1) / 256.0
    }

    // MARK: - Gen 3-4

    static func gen3ModifiedRate(
        maxHP: Int,
        currentHP: Int,
        catchRate: Int,
        ballBonus: Double,
        status: StatusCondition,
        grassModifier: Double = 1
    ) -> Int {
        let hpTerm = Double(3 * maxHP - 2 * currentHP)
        let value = hpTerm * Double(catchRate) * ballBonus * status.modernMultiplier * grassModifier
        let scaled = value / Double(3 * maxHP)
        return max(Int(scaled.rounded(.down)), 1)
    }

    static func gen3Probability(x: Int) -> Double {
        if x >= 255 { return 1 }
        let rate = max(x, 1)
        let y = floor(65536.0 / sqrt(255.0 / Double(rate)))
        let shakeSuccess = (y + 1.0) / 65536.0
        return pow(shakeSuccess, 4)
    }

    static func estimatedGen3Wobbles(x: Int) -> Int {
        if x >= 255 { return 0 }
        let rate = max(x, 1)
        let y = floor(65536.0 / sqrt(255.0 / Double(rate)))
        let p = (y + 1.0) / 65536.0
        if p > 0.75 { return 3 }
        if p > 0.5 { return 2 }
        if p > 0.25 { return 1 }
        return 0
    }

    // MARK: - Gen 5

    static func gen5ModifiedRate(
        maxHP: Int,
        currentHP: Int,
        catchRate: Int,
        ballBonus: Double,
        status: StatusCondition,
        grassModifier: Double
    ) -> Int {
        let hpTerm = Double(3 * maxHP - 2 * currentHP) * grassModifier
        let value = hpTerm * Double(catchRate) * ballBonus * status.modernMultiplier
        let scaled = value / Double(3 * maxHP)
        return max(Int(scaled.rounded(.down)), 1)
    }

    static func gen5Probability(x: Int) -> Double {
        if x >= 255 { return 1 }
        let rate = max(x, 1)
        let y = floor(65536.0 / pow(255.0 / Double(rate), 0.25))
        let shakeSuccess = (y + 1.0) / 65536.0
        return pow(shakeSuccess, 3)
    }

    static func estimatedGen5Wobbles(x: Int) -> Int {
        if x >= 255 { return 0 }
        let rate = max(x, 1)
        let y = floor(65536.0 / pow(255.0 / Double(rate), 0.25))
        let p = (y + 1.0) / 65536.0
        if p > 0.66 { return 3 }
        if p > 0.33 { return 1 }
        return 0
    }

    // MARK: - Gen 6-9 (Gen 6/7 use gen3 shake math; Gen 8/9 add low-level modifier)

    static func gen6ModifiedRate(
        maxHP: Int,
        currentHP: Int,
        catchRate: Int,
        ballBonus: Double,
        status: StatusCondition,
        grassModifier: Double,
        lowLevelModifier: Double = 1
    ) -> Int {
        let hpTerm = Double(3 * maxHP - 2 * currentHP) * grassModifier
        let value = hpTerm * Double(catchRate) * ballBonus * status.modernMultiplier * lowLevelModifier
        let scaled = value / Double(3 * maxHP)
        return max(Int(scaled.rounded(.down)), 1)
    }
}
