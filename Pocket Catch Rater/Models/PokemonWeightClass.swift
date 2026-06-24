import Foundation

/// Discrete weight buckets used by Heavy Ball catch-rate modifiers.
nonisolated enum PokemonWeightClass: String, Sendable {
    case light
    case medium
    case heavy
    case veryHeavy
    case ultraHeavy

    var displayName: String {
        switch self {
        case .light: "Light"
        case .medium: "Medium"
        case .heavy: "Heavy"
        case .veryHeavy: "Very Heavy"
        case .ultraHeavy: "Ultra Heavy"
        }
    }

    static func classify(weightKg: Double, formulaFamily: CaptureFormulaFamily) -> PokemonWeightClass {
        switch formulaFamily {
        case .gen8to9, .gen6to7:
            // Gen VII uses the same 100/200/300 kg thresholds as Gen VIII/IX.
            return classifyModern(weightKg: weightKg)
        case .gen1, .gen2, .gen3to4, .gen5:
            return classifyClassic(weightKg: weightKg)
        }
    }

    func heavyBallCatchRateBonus(formulaFamily: CaptureFormulaFamily) -> Int {
        switch formulaFamily {
        case .gen8to9, .gen6to7:
            // Gen VII removed the +40 tier. Matches Gen VIII/IX: +30/+20/0/−20.
            switch self {
            case .light: -20
            case .medium: 0
            case .heavy: 20
            case .veryHeavy, .ultraHeavy: 30
            }
        case .gen1, .gen2, .gen3to4, .gen5:
            switch self {
            case .light: -20
            case .medium: 0   // ≥102.4 kg to <204.8 kg — no bonus
            case .heavy: 20
            case .veryHeavy: 30
            case .ultraHeavy: 40
            }
        }
    }

    private static func classifyModern(weightKg: Double) -> PokemonWeightClass {
        if weightKg < 100 { return .light }
        if weightKg < 200 { return .medium }
        if weightKg < 300 { return .heavy }
        return .veryHeavy
    }

    /// Gen 1–7 classic weight thresholds (Gen II source: dragonflycave.com/mechanics/gen-ii-capturing)
    private static func classifyClassic(weightKg: Double) -> PokemonWeightClass {
        if weightKg < 102.4 { return .light }    // < 225.8 lbs → -20
        if weightKg < 204.8 { return .medium }   // < 451.5 lbs → ±0
        if weightKg < 307.2 { return .heavy }    // < 677.3 lbs → +20
        if weightKg < 409.6 { return .veryHeavy }// < 903.0 lbs → +30
        return .ultraHeavy                        // ≥ 903.0 lbs → +40
    }
}

enum HeavyBallMath {
    static func heavyBallBonus(weightKg: Double?, formulaFamily: CaptureFormulaFamily) -> Int? {
        guard let weightKg else { return nil }
        let weightClass = PokemonWeightClass.classify(weightKg: weightKg, formulaFamily: formulaFamily)
        return weightClass.heavyBallCatchRateBonus(formulaFamily: formulaFamily)
    }

    /// Adjusts the species catch rate C before the capture formula.
    ///
    /// - For all generations: Heavy Ball adds/subtracts a fixed amount to C.
    /// - For Gen 3–4 (HGSS): the other Apricorn balls also modify C directly rather than
    ///   contributing a B multiplier. The modified C is capped at 255 (minimum 1 for Heavy Ball).
    static func adjustedSpeciesCatchRate(
        base catchRate: Int,
        ball: CatchBall,
        weightKg: Double?,
        formulaFamily: CaptureFormulaFamily,
        context: BallContext = BallContext()
    ) -> Int {
        if formulaFamily == .gen3to4 {
            return gen3to4ApricornCatchRate(
                base: catchRate, ball: ball, weightKg: weightKg, context: context
            )
        }
        guard ball == .heavy, let weightKg else { return catchRate }
        let bonus = PokemonWeightClass.classify(weightKg: weightKg, formulaFamily: formulaFamily)
            .heavyBallCatchRateBonus(formulaFamily: formulaFamily)
        return max(1, min(255, catchRate + bonus))
    }

    // MARK: - Gen 3–4 (HGSS) Apricorn C-modifications

    /// Applies the HGSS Apricorn-ball catch rate modification to C.
    /// Source: https://www.dragonflycave.com/mechanics/gen-iii-iv-capturing/
    ///
    /// Level Ball thresholds use strict `>` (integer division), as described in the source.
    private static func gen3to4ApricornCatchRate(
        base catchRate: Int,
        ball: CatchBall,
        weightKg: Double?,
        context: BallContext
    ) -> Int {
        switch ball {
        case .heavy:
            guard let weightKg else { return catchRate }
            let bonus = PokemonWeightClass.classify(weightKg: weightKg, formulaFamily: .gen3to4)
                .heavyBallCatchRateBonus(formulaFamily: .gen3to4)
            return max(1, min(255, catchRate + bonus))
        case .fast:
            let multiplier = context.fastBallBonusActive ? 4 : 1
            return min(255, catchRate * multiplier)
        case .level:
            let player = context.playerLevel
            let target = context.targetLevel
            let multiplier: Int
            if player / 4 > target { multiplier = 8 }
            else if player / 2 > target { multiplier = 4 }
            else if player > target { multiplier = 2 }
            else { multiplier = 1 }
            return min(255, catchRate * multiplier)
        case .love:
            let multiplier = context.loveBallOppositeGender ? 8 : 1
            return min(255, catchRate * multiplier)
        case .lure:
            let multiplier = context.isFishing ? 3 : 1
            return min(255, catchRate * multiplier)
        case .moon:
            let multiplier = context.moonBallBonusActive ? 4 : 1
            return min(255, catchRate * multiplier)
        default:
            return catchRate
        }
    }

    static func info(weightKg: Double, ruleSet: CatchRuleSet) -> (weightClass: PokemonWeightClass, bonus: Int, label: String) {
        let formulaFamily = ruleSet.formulaFamily
        let weightClass = PokemonWeightClass.classify(weightKg: weightKg, formulaFamily: formulaFamily)
        let bonus = weightClass.heavyBallCatchRateBonus(formulaFamily: formulaFamily)
        let bonusText = bonus >= 0 ? "+\(bonus)" : "\(bonus)"
        let weightText = weightKg == floor(weightKg)
            ? "\(Int(weightKg)) kg"
            : String(format: "%.1f kg", weightKg)
        let label = "Heavy Ball: \(bonusText) catch rate (\(weightClass.displayName), \(weightText))"
        return (weightClass, bonus, label)
    }
}
