import Foundation

struct ModernCatchCalculator: CatchCalculator {
    let formulaFamily: CaptureFormulaFamily

    func calculate(inputs: CatchInputs, catchRate: Int, maxHP: Int, currentHP: Int) -> CatchResult {
        let ball = inputs.effectiveBall
        let status = inputs.effectiveStatus
        let context = inputs.ballContext
        let weightKg = inputs.species?.weightKg

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

            let modifiedCatchRate: Int
            if ball == .heavy {
                modifiedCatchRate = HeavyBallMath.adjustedSpeciesCatchRate(
                    base: catchRate,
                    ball: ball,
                    weightKg: weightKg,
                    formulaFamily: formulaFamily
                )
            } else {
                modifiedCatchRate = min(255, max(1, Int(floor(Double(catchRate) * multiplier))))
            }

            // Level Ball in Gen 2 skips the HP formula entirely — X = C directly.
            // This is the only non-Master-Ball way to guarantee capture without status in G/S/C.
            if ball == .level {
                let x = modifiedCatchRate
                return CatchResult(
                    probability: CaptureMath.gen2Probability(modifiedRate: x),
                    hpFactor: x,
                    wobbleCount: x >= 255 ? 0 : 1,
                    isAtHPCap: false,
                    maxHP: maxHP,
                    currentHP: currentHP,
                    speciesCatchRate: catchRate,
                    effectiveCatchRate: x,
                    ballBonus: multiplier
                )
            }

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
                ballBonus: multiplier
            )

        case .gen3to4:
            let effectiveCatchRate = HeavyBallMath.adjustedSpeciesCatchRate(
                base: catchRate,
                ball: ball,
                weightKg: weightKg,
                formulaFamily: formulaFamily,
                context: context
            )
            let ballBonus = ball.modernBallBonus(generation: inputs.generation, context: context)
            let x = CaptureMath.gen3ModifiedRate(
                maxHP: maxHP,
                currentHP: currentHP,
                catchRate: effectiveCatchRate,
                ballBonus: ballBonus,
                status: status,
                formulaFamily: formulaFamily
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
            let effectiveCatchRate = HeavyBallMath.adjustedSpeciesCatchRate(
                base: catchRate,
                ball: ball,
                weightKg: weightKg,
                formulaFamily: formulaFamily
            )
            let ballBonus = ball.modernBallBonus(generation: inputs.generation, context: context)
            let grass = CaptureMath.grassModifier(
                isThickGrass: inputs.isThickGrass,
                pokedexCaught: inputs.pokedexCaught
            )
            let x = CaptureMath.gen5ModifiedRate(
                maxHP: maxHP,
                currentHP: currentHP,
                catchRate: effectiveCatchRate,
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

        case .gen6to7:
            let effectiveCatchRate = HeavyBallMath.adjustedSpeciesCatchRate(
                base: catchRate,
                ball: ball,
                weightKg: weightKg,
                formulaFamily: formulaFamily
            )
            let ballBonus = ball.modernBallBonus(generation: inputs.generation, context: context)
            let grass = CaptureMath.grassModifier(
                isThickGrass: inputs.isThickGrass,
                pokedexCaught: inputs.pokedexCaught
            )
            let x = CaptureMath.gen6ModifiedRate(
                maxHP: maxHP,
                currentHP: currentHP,
                catchRate: effectiveCatchRate,
                ballBonus: ballBonus,
                status: status,
                grassModifier: grass,
                oPowerBonus: inputs.oPowerBonus
            )
            return CatchResult(
                probability: CaptureMath.gen6Probability(x: x),
                hpFactor: x,
                wobbleCount: CaptureMath.estimatedGen6Wobbles(x: x),
                isAtHPCap: x >= 255,
                maxHP: maxHP,
                currentHP: currentHP,
                speciesCatchRate: catchRate,
                effectiveCatchRate: x,
                ballBonus: ballBonus
            )

        case .gen8to9:
            let isGen9 = inputs.generation == .gen9
            let effectiveCatchRate = HeavyBallMath.adjustedSpeciesCatchRate(
                base: catchRate,
                ball: ball,
                weightKg: weightKg,
                formulaFamily: formulaFamily
            )
            let ballBonus = ball.modernBallBonus(generation: inputs.generation, context: context)
            let grass = CaptureMath.grassModifier(
                isThickGrass: inputs.isThickGrass,
                pokedexCaught: inputs.pokedexCaught
            )
            // Gen 9: (36 − 2×level)/10 for level ≤ 13. Gen 8: (30 − level)/10 for level < 21.
            let lowLevel = isGen9
                ? CaptureMath.gen9LowLevelModifier(targetLevel: inputs.level)
                : CaptureMath.lowLevelModifier(targetLevel: inputs.level)
            // Gen 9 BP: 0.8 per missing badge. Folds into ballBonus — same position in formula.
            let bp = isGen9
                ? CaptureMath.gen9BadgePenalty(targetLevel: inputs.level, badgeCount: inputs.badgeCount)
                : 1.0
            // Gen 9 D modifier: Capture Power × off-guard doubling. Gen 8: 1.
            let difficultyMod: Double = isGen9
                ? inputs.oPowerBonus * (inputs.isOffGuard ? 2.0 : 1.0)
                : 1.0
            let x = CaptureMath.gen6ModifiedRate(
                maxHP: maxHP,
                currentHP: currentHP,
                catchRate: effectiveCatchRate,
                ballBonus: ballBonus * bp,
                status: status,
                grassModifier: grass,
                lowLevelModifier: lowLevel,
                oPowerBonus: difficultyMod
            )
            return CatchResult(
                probability: CaptureMath.gen6Probability(x: x),
                hpFactor: x,
                wobbleCount: CaptureMath.estimatedGen6Wobbles(x: x),
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
