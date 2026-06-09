import Foundation

protocol CatchCalculator: Sendable {
    func calculate(inputs: CatchInputs, catchRate: Int, maxHP: Int, currentHP: Int) -> CatchResult

    func calculateWithEstimatedHP(inputs: CatchInputs, catchRate: Int, baseHP: Int) -> CatchResult
}

extension CatchCalculator {
    func calculateWithEstimatedHP(inputs: CatchInputs, catchRate: Int, baseHP: Int) -> CatchResult {
        let hp = HPEstimator.estimate(
            baseHP: baseHP,
            level: inputs.level,
            hpPercent: inputs.effectiveHPPercent
        )
        return calculate(
            inputs: inputs,
            catchRate: catchRate,
            maxHP: hp.maxHP,
            currentHP: hp.currentHP
        )
    }
}

enum HPEstimator {
    /// Median wild IV used for all HP estimates (Gen 1 IV range 0–15).
    static let medianIV = 8

    static func maxHP(baseHP: Int, level: Int) -> Int {
        let inner = (2 * baseHP + medianIV + 100) * level
        return (inner / 100) + 10
    }

    static func currentHP(maxHP: Int, hpPercent: Double) -> Int {
        max(1, Int(Double(maxHP) * hpPercent / 100.0))
    }

    static func estimate(baseHP: Int, level: Int, hpPercent: Double) -> (maxHP: Int, currentHP: Int) {
        let maxHP = maxHP(baseHP: baseHP, level: level)
        let currentHP = currentHP(maxHP: maxHP, hpPercent: hpPercent)
        return (maxHP, currentHP)
    }
}

enum CatchCalculatorEngine {
    static func calculator(for generation: PokemonGeneration) -> CatchCalculator {
        switch generation.formulaFamily {
        case .gen1:
            return Gen1CatchCalculator()
        default:
            return ModernCatchCalculator(formulaFamily: generation.formulaFamily)
        }
    }
}
