import Foundation

struct ModernCatchCalculator: CatchCalculator {
    let formulaFamily: CaptureFormulaFamily

    func calculate(inputs: CatchInputs, catchRate: Int, maxHP: Int, currentHP: Int) -> CatchResult {
        let ball = inputs.effectiveBall
        let status = inputs.effectiveStatus
        let context = inputs.ballContext

        if ball == .master {
            return CatchResult(
                probability: 1,
                hpFactor: 255,
                wobbleCount: 0,
                isAtHPCap: true,
                maxHP: maxHP,
                currentHP: currentHP,
                speciesCatchRate: catchRate,
                effectiveCatchRate: catchRate,
                ballBonus: nil
            )
        }

        switch formulaFamily {
        case .gen1:
            return Gen1CatchCalculator().calculate(
                inputs: inputs,
                catchRate: catchRate,
                maxHP: maxHP,
                currentHP: currentHP
            )

        case .gen2:
            let multiplier = ball.gen2CatchRateMultiplier(context: context)
            let modifiedCatchRate = min(255, Int(floor(Double(catchRate) * multiplier)))
            let x = CaptureMath.gen2ModifiedRate(
                maxHP: maxHP,
                currentHP: currentHP,
                catchRate: modifiedCatchRate,
                status: status
            )
            return CatchResult(
                probability: CaptureMath.gen2Probability(modifiedRate: x),
                hpFactor: x,
                wobbleCount: x >= 255 ? 0 : 1,
                isAtHPCap: false,
                maxHP: maxHP,
                currentHP: currentHP,
                speciesCatchRate: catchRate,
                effectiveCatchRate: x,
                ballBonus: ball.gen2CatchRateMultiplier(context: context)
            )

        case .gen3to4:
            let ballBonus = ball.modernBallBonus(generation: inputs.generation, context: context)
            let x = CaptureMath.gen3ModifiedRate(
                maxHP: maxHP,
                currentHP: currentHP,
                catchRate: catchRate,
                ballBonus: ballBonus,
                status: status
            )
            return CatchResult(
                probability: CaptureMath.gen3Probability(x: x),
                hpFactor: x,
                wobbleCount: CaptureMath.estimatedGen3Wobbles(x: x),
                isAtHPCap: x >= 255,
                maxHP: maxHP,
                currentHP: currentHP,
                speciesCatchRate: catchRate,
                effectiveCatchRate: x,
                ballBonus: ballBonus
            )

        case .gen5:
            let ballBonus = ball.modernBallBonus(generation: inputs.generation, context: context)
            let grass = CaptureMath.grassModifier(
                isThickGrass: inputs.isThickGrass,
                pokedexCaught: inputs.pokedexCaught
            )
            let x = CaptureMath.gen5ModifiedRate(
                maxHP: maxHP,
                currentHP: currentHP,
                catchRate: catchRate,
                ballBonus: ballBonus,
                status: status,
                grassModifier: grass
            )
            return CatchResult(
                probability: CaptureMath.gen5Probability(x: x),
                hpFactor: x,
                wobbleCount: CaptureMath.estimatedGen5Wobbles(x: x),
                isAtHPCap: x >= 255,
                maxHP: maxHP,
                currentHP: currentHP,
                speciesCatchRate: catchRate,
                effectiveCatchRate: x,
                ballBonus: ballBonus
            )

        case .gen6to7, .gen8to9:
            let ballBonus = ball.modernBallBonus(generation: inputs.generation, context: context)
            let grass = CaptureMath.grassModifier(
                isThickGrass: inputs.isThickGrass,
                pokedexCaught: inputs.pokedexCaught
            )
            let lowLevel = formulaFamily == .gen8to9
                ? CaptureMath.lowLevelModifier(targetLevel: inputs.level)
                : 1
            let x = CaptureMath.gen6ModifiedRate(
                maxHP: maxHP,
                currentHP: currentHP,
                catchRate: catchRate,
                ballBonus: ballBonus,
                status: status,
                grassModifier: grass,
                lowLevelModifier: lowLevel
            )
            return CatchResult(
                probability: CaptureMath.gen3Probability(x: x),
                hpFactor: x,
                wobbleCount: CaptureMath.estimatedGen3Wobbles(x: x),
                isAtHPCap: x >= 255,
                maxHP: maxHP,
                currentHP: currentHP,
                speciesCatchRate: catchRate,
                effectiveCatchRate: x,
                ballBonus: ballBonus
            )
        }
    }
}
