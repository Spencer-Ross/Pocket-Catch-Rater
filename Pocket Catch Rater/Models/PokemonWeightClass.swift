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
        case .gen8to9:
            return classifyModern(weightKg: weightKg)
        case .gen1, .gen2, .gen3to4, .gen5, .gen6to7:
            return classifyClassic(weightKg: weightKg)
        }
    }

    func heavyBallCatchRateBonus(formulaFamily: CaptureFormulaFamily) -> Int {
        switch formulaFamily {
        case .gen8to9:
            switch self {
            case .light: -20
            case .medium: 0
            case .heavy: 20
            case .veryHeavy, .ultraHeavy: 30
            }
        case .gen1, .gen2, .gen3to4, .gen5, .gen6to7:
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

    static func adjustedSpeciesCatchRate(
        base catchRate: Int,
        ball: CatchBall,
        weightKg: Double?,
        formulaFamily: CaptureFormulaFamily
    ) -> Int {
        guard ball == .heavy, let weightKg else { return catchRate }
        let bonus = PokemonWeightClass.classify(weightKg: weightKg, formulaFamily: formulaFamily)
            .heavyBallCatchRateBonus(formulaFamily: formulaFamily)
        let adjusted = catchRate + bonus
        return max(1, min(255, adjusted))
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
