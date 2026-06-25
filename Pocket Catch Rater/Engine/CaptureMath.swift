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

    /// Gen 8 low-level modifier: (30 − level) / 10 for level < 21; 1 otherwise.
    static func lowLevelModifier(targetLevel: Int) -> Double {
        guard targetLevel < 21 else { return 1 }
        return Double(30 - targetLevel) / 10.0
    }

    /// Gen 9 low-level modifier: (36 − 2×level) / 10 for level ≤ 13; 1 otherwise.
    /// Level 13 → 1.0; level 1 → 3.4.
    static func gen9LowLevelModifier(targetLevel: Int) -> Double {
        guard targetLevel <= 13 else { return 1 }
        return Double(36 - 2 * targetLevel) / 10.0
    }

    /// Gen 9 badge penalty (BP): 0.8 per missing badge needed to control the target's level.
    /// Returns 1 when the player has enough badges (no penalty).
    static func gen9BadgePenalty(targetLevel: Int, badgeCount: Int) -> Double {
        let badgesNeeded: Int
        switch targetLevel {
        case ...25:  badgesNeeded = 0
        case 26...30: badgesNeeded = 1
        case 31...35: badgesNeeded = 2
        case 36...40: badgesNeeded = 3
        case 41...45: badgesNeeded = 4
        case 46...50: badgesNeeded = 5
        case 51...55: badgesNeeded = 6
        case 56...60: badgesNeeded = 7
        default:      badgesNeeded = 8
        }
        let missing = max(0, badgesNeeded - badgeCount)
        return missing > 0 ? pow(0.8, Double(missing)) : 1
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
        grassModifier: Double = 1,
        formulaFamily: CaptureFormulaFamily = .gen8to9
    ) -> Int {
        let hpTerm = Double(3 * maxHP - 2 * currentHP)
        let statusMult = status.modernMultiplier(for: formulaFamily)
        let value = hpTerm * Double(catchRate) * ballBonus * statusMult * grassModifier
        let scaled = value / Double(3 * maxHP)
        return max(Int(scaled.rounded(.down)), 1)
    }

    /// Gen 3–4 shake probability.
    /// Y = 1048560 / sqrt(sqrt(16711680 / X)) (actual game formula with integer arithmetic).
    /// Capture succeeds when all four random numbers [0, 65535] are strictly less than Y.
    static func gen3Probability(x: Int) -> Double {
        if x >= 255 { return 1 }
        let rate = max(x, 1)
        let y = floor(1048560.0 / sqrt(sqrt(16711680.0 / Double(rate))))
        return pow(y / 65536.0, 4)
    }

    static func estimatedGen3Wobbles(x: Int) -> Int {
        if x >= 255 { return 0 }
        let rate = max(x, 1)
        let y = floor(1048560.0 / sqrt(sqrt(16711680.0 / Double(rate))))
        let p = y / 65536.0
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

    /// Gen V capture probability.
    /// Y = floor(65536 / sqrt(sqrt(255 / X))).
    /// Capture succeeds when all three random numbers [0, 65535] are strictly less than Y.
    static func gen5Probability(x: Int) -> Double {
        if x >= 255 { return 1 }
        let rate = max(x, 1)
        let y = floor(65536.0 / pow(255.0 / Double(rate), 0.25))
        return pow(y / 65536.0, 3)
    }

    /// Estimated wobble count for a Gen V capture attempt (0, 1, or 3 — Gen V has no 2-wobble case).
    static func estimatedGen5Wobbles(x: Int) -> Int {
        if x >= 255 { return 0 }
        let rate = max(x, 1)
        let y = floor(65536.0 / pow(255.0 / Double(rate), 0.25))
        let p = y / 65536.0
        if p > 0.66 { return 3 }
        if p > 0.33 { return 1 }
        return 0
    }

    // MARK: - Gen 6-7

    /// Gen VI/VII capture probability.
    /// Y = floor(65536 / (255 / X)^(3/16)).
    /// Capture succeeds when all four random numbers [0, 65535] are strictly less than Y.
    /// Note: the final capture chance (Y/65536)^4 = (X/255)^(3/4) — identical to Gen V —
    /// but the higher per-shake Y means more visible wobbles before a break-out.
    static func gen6Probability(x: Int) -> Double {
        if x >= 255 { return 1 }
        let rate = max(x, 1)
        let y = floor(65536.0 / pow(255.0 / Double(rate), 3.0 / 16.0))
        return pow(y / 65536.0, 4)
    }

    static func estimatedGen6Wobbles(x: Int) -> Int {
        if x >= 255 { return 0 }
        let rate = max(x, 1)
        let y = floor(65536.0 / pow(255.0 / Double(rate), 3.0 / 16.0))
        let p = y / 65536.0
        if p > 0.75 { return 3 }
        if p > 0.5  { return 2 }
        if p > 0.25 { return 1 }
        return 0
    }

    static func gen6ModifiedRate(
        maxHP: Int,
        currentHP: Int,
        catchRate: Int,
        ballBonus: Double,
        status: StatusCondition,
        grassModifier: Double,
        lowLevelModifier: Double = 1,
        oPowerBonus: Double = 1
    ) -> Int {
        let hpTerm = Double(3 * maxHP - 2 * currentHP) * grassModifier
        let value = hpTerm * Double(catchRate) * ballBonus * status.modernMultiplier
            * lowLevelModifier * oPowerBonus
        let scaled = value / Double(3 * maxHP)
        return max(Int(scaled.rounded(.down)), 1)
    }
}
