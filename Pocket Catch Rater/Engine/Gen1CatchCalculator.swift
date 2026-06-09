import Foundation

struct Gen1CatchCalculator: CatchCalculator {
    func calculate(inputs: CatchInputs, catchRate: Int, maxHP: Int, currentHP: Int) -> CatchResult {
        var effectiveRate = catchRate

        for _ in 0..<inputs.rocksThrown {
            effectiveRate = min(255, effectiveRate * 2)
        }
        for _ in 0..<inputs.baitUsed {
            effectiveRate /= 2
        }

        let ball = inputs.effectiveBall
        let status = inputs.effectiveStatus

        if ball == .master {
            return CatchResult(
                probability: 1,
                hpFactor: 255,
                wobbleCount: 0,
                isAtHPCap: true,
                maxHP: maxHP,
                currentHP: currentHP,
                speciesCatchRate: catchRate,
                effectiveCatchRate: effectiveRate,
                ballBonus: nil
            )
        }

        let hpFactor = Self.hpFactor(maxHP: maxHP, currentHP: currentHP, ball: ball)
        let probability = Self.catchProbability(
            catchRate: effectiveRate,
            maxHP: maxHP,
            currentHP: currentHP,
            ball: ball,
            status: status
        )
        let wobbles = Self.wobbleCount(
            catchRate: effectiveRate,
            hpFactor: hpFactor,
            ball: ball,
            status: status
        )
        let isAtCap = Self.isAtHPCap(maxHP: maxHP, currentHP: currentHP, ball: ball)

        return CatchResult(
            probability: probability,
            hpFactor: hpFactor,
            wobbleCount: wobbles,
            isAtHPCap: isAtCap,
            maxHP: maxHP,
            currentHP: currentHP,
            speciesCatchRate: catchRate,
            effectiveCatchRate: effectiveRate,
            ballBonus: nil
        )
    }

    static func hpFactor(maxHP: Int, currentHP: Int, ball: CatchBall) -> Int {
        let hpDiv = max(1, currentHP / 4)
        let numerator = (maxHP * 255) / ball.gen1HpDivisor
        return min(255, numerator / hpDiv)
    }

    static func catchProbability(
        catchRate: Int,
        maxHP: Int,
        currentHP: Int,
        ball: CatchBall,
        status: StatusCondition
    ) -> Double {
        let B = ball.gen1SampleSpace
        let S = status.captureThreshold
        let F = hpFactor(maxHP: maxHP, currentHP: currentHP, ball: ball)

        let autoCapture = Double(S) / Double(B)
        let window = Double(min(catchRate + 1, B - S)) / Double(B)
        let hpCheck = F >= 255 ? 1.0 : Double(F + 1) / 256.0

        return autoCapture + window * hpCheck
    }

    static func wobbleCount(
        catchRate: Int,
        hpFactor: Int,
        ball: CatchBall,
        status: StatusCondition
    ) -> Int {
        let X = hpFactor
        let Y = (catchRate * 100) / ball.gen1WobbleDivisor
        let Z = (X * Y / 255) + status.wobbleBonus

        if Z < 10 { return 0 }
        if Z < 30 { return 1 }
        if Z < 70 { return 2 }
        return 3
    }

    static func isAtHPCap(maxHP: Int, currentHP: Int, ball: CatchBall) -> Bool {
        hpFactor(maxHP: maxHP, currentHP: currentHP, ball: ball) >= 255
    }
}
