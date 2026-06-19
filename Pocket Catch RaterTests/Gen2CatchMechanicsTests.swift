import XCTest
@testable import Pocket_Catch_Rater

/// Tests for Gen II capture mechanics per https://www.dragonflycave.com/mechanics/gen-ii-capturing/
final class Gen2CatchMechanicsTests: XCTestCase {

    private let calculator = ModernCatchCalculator(formulaFamily: .gen2)

    // MARK: - Status bonus (Gen 2 bug)

    func testSleepAddsBonus() {
        // Sleep adds +10 to X in Gen 2
        var inputs = makeInputs()
        inputs.status = .sleep
        let asleep = calculator.calculate(inputs: inputs, catchRate: 45, maxHP: 100, currentHP: 50)

        inputs.status = .none
        let normal = calculator.calculate(inputs: inputs, catchRate: 45, maxHP: 100, currentHP: 50)

        XCTAssertGreaterThan(asleep.probability, normal.probability)
    }

    func testFreezeAddsBonus() {
        // Freeze also adds +10 (same slot as sleep)
        var inputs = makeInputs()
        inputs.status = .freeze
        let frozen = calculator.calculate(inputs: inputs, catchRate: 45, maxHP: 100, currentHP: 50)

        inputs.status = .none
        let normal = calculator.calculate(inputs: inputs, catchRate: 45, maxHP: 100, currentHP: 50)

        XCTAssertGreaterThan(frozen.probability, normal.probability)
    }

    func testPoisonDoesNotAddBonus() {
        // Gen 2 bug: the poison/burn/paralysis check always fails, so these add 0
        var inputs = makeInputs()
        inputs.status = .poison
        let poisoned = calculator.calculate(inputs: inputs, catchRate: 45, maxHP: 100, currentHP: 50)

        inputs.status = .none
        let normal = calculator.calculate(inputs: inputs, catchRate: 45, maxHP: 100, currentHP: 50)

        XCTAssertEqual(poisoned.probability, normal.probability, accuracy: 0.0001)
    }

    func testBurnDoesNotAddBonus() {
        var inputs = makeInputs()
        inputs.status = .burn
        let burned = calculator.calculate(inputs: inputs, catchRate: 45, maxHP: 100, currentHP: 50)

        inputs.status = .none
        let normal = calculator.calculate(inputs: inputs, catchRate: 45, maxHP: 100, currentHP: 50)

        XCTAssertEqual(burned.probability, normal.probability, accuracy: 0.0001)
    }

    func testParalysisDoesNotAddBonus() {
        var inputs = makeInputs()
        inputs.status = .paralysis
        let paralyzed = calculator.calculate(inputs: inputs, catchRate: 45, maxHP: 100, currentHP: 50)

        inputs.status = .none
        let normal = calculator.calculate(inputs: inputs, catchRate: 45, maxHP: 100, currentHP: 50)

        XCTAssertEqual(paralyzed.probability, normal.probability, accuracy: 0.0001)
    }

    // MARK: - Ball multipliers

    func testGreatBallMultiplier() {
        var great = makeInputs(); great.catchBall = .great
        var poke  = makeInputs(); poke.catchBall  = .poke
        let r1 = calculator.calculate(inputs: great, catchRate: 45, maxHP: 100, currentHP: 50)
        let r2 = calculator.calculate(inputs: poke,  catchRate: 45, maxHP: 100, currentHP: 50)
        XCTAssertGreaterThan(r1.probability, r2.probability)
    }

    func testUltraBallMultiplier() {
        var ultra = makeInputs(); ultra.catchBall = .ultra
        var great = makeInputs(); great.catchBall = .great
        let r1 = calculator.calculate(inputs: ultra, catchRate: 45, maxHP: 100, currentHP: 50)
        let r2 = calculator.calculate(inputs: great, catchRate: 45, maxHP: 100, currentHP: 50)
        XCTAssertGreaterThan(r1.probability, r2.probability)
    }

    func testLureBallFishingMultiplierIs3x() {
        var inputs = makeInputs()
        inputs.catchBall = .lure
        inputs.isFishing = true
        let lureBonus = CatchBall.lure.gen2CatchRateMultiplier(context: inputs.ballContext)
        XCTAssertEqual(lureBonus, 3.0, accuracy: 0.001)
    }

    func testLureBallNoFishingIsNoBonus() {
        var inputs = makeInputs()
        inputs.catchBall = .lure
        inputs.isFishing = false
        let bonus = CatchBall.lure.gen2CatchRateMultiplier(context: inputs.ballContext)
        XCTAssertEqual(bonus, 1.0, accuracy: 0.001)
    }

    func testFastBallOnlyBonusForEligibleSpecies() {
        // Grimer (#88), Tangela (#114), Magnemite (#81) → 4×
        var inputs = makeInputs(); inputs.catchBall = .fast; inputs.gen2FastBallActive = true
        XCTAssertEqual(CatchBall.fast.gen2CatchRateMultiplier(context: inputs.ballContext), 4.0, accuracy: 0.001)

        // Any other species → 1×
        inputs.gen2FastBallActive = false
        XCTAssertEqual(CatchBall.fast.gen2CatchRateMultiplier(context: inputs.ballContext), 1.0, accuracy: 0.001)
    }

    func testGen2FastBallEligibilitySpecies() {
        XCTAssertTrue(Gen2FastBallEligibility.isEligible(speciesID: 81))   // Magnemite
        XCTAssertTrue(Gen2FastBallEligibility.isEligible(speciesID: 88))   // Grimer
        XCTAssertTrue(Gen2FastBallEligibility.isEligible(speciesID: 114))  // Tangela
        XCTAssertFalse(Gen2FastBallEligibility.isEligible(speciesID: 25))  // Pikachu — fast but not listed
        XCTAssertFalse(Gen2FastBallEligibility.isEligible(speciesID: 130)) // Gyarados
    }

    func testLoveBallSameGenderIs8x() {
        var inputs = makeInputs(); inputs.catchBall = .love; inputs.loveBallSameGender = true
        XCTAssertEqual(CatchBall.love.gen2CatchRateMultiplier(context: inputs.ballContext), 8.0, accuracy: 0.001)
    }

    func testLoveBallNoMatchIsNoBonus() {
        var inputs = makeInputs(); inputs.catchBall = .love; inputs.loveBallSameGender = false
        XCTAssertEqual(CatchBall.love.gen2CatchRateMultiplier(context: inputs.ballContext), 1.0, accuracy: 0.001)
    }

    func testMoonBallIsAlwaysNoBonus() {
        // Moon Ball is bugged in Gen 2 — never activates for any real Pokémon
        var inputs = makeInputs(); inputs.catchBall = .moon
        XCTAssertEqual(CatchBall.moon.gen2CatchRateMultiplier(context: inputs.ballContext), 1.0, accuracy: 0.001)
    }

    // MARK: - Level Ball skips HP formula (X = C)

    func testLevelBallSkipsHPFormula() {
        // For a regular ball, lowering HP increases catch rate. For Level Ball in Gen 2, X = C,
        // so the probability is the same at full HP and 1 HP.
        var inputs = makeInputs()
        inputs.catchBall = .level
        inputs.playerLevel = 50
        inputs.level = 5   // playerLevel/4 = 12 >= 5 → 8× multiplier → C = min(255, 45*8) = 255

        let fullHP = calculator.calculate(inputs: inputs, catchRate: 45, maxHP: 100, currentHP: 100)
        let lowHP  = calculator.calculate(inputs: inputs, catchRate: 45, maxHP: 100, currentHP: 1)

        // Both should have the same probability because HP is irrelevant for Level Ball in Gen 2
        XCTAssertEqual(fullHP.probability, lowHP.probability, accuracy: 0.0001)
    }

    func testLevelBallMultipliersGen2() {
        // player/4 >= target → 8×
        var ctx = BallContext(); ctx.playerLevel = 40; ctx.targetLevel = 5
        XCTAssertEqual(CatchBall.level.gen2CatchRateMultiplier(context: ctx), 8.0, accuracy: 0.001)

        // player/2 >= target → 4×
        ctx.playerLevel = 20; ctx.targetLevel = 9
        XCTAssertEqual(CatchBall.level.gen2CatchRateMultiplier(context: ctx), 4.0, accuracy: 0.001)

        // player > target → 2×
        ctx.playerLevel = 20; ctx.targetLevel = 15
        XCTAssertEqual(CatchBall.level.gen2CatchRateMultiplier(context: ctx), 2.0, accuracy: 0.001)

        // player ≤ target → 1×
        ctx.playerLevel = 15; ctx.targetLevel = 20
        XCTAssertEqual(CatchBall.level.gen2CatchRateMultiplier(context: ctx), 1.0, accuracy: 0.001)
    }

    // MARK: - Gen 2 formula accuracy (from the reference calculator)

    func testGen2FullHPCatchRateIsRoughlyOneThirdOfMaxHP() {
        // At full HP the formula simplifies to ~max(C/3, 1) + S.
        // For Ultra Ball: C = catchRate * 2. At full HP X ≈ catchRate*2/3.
        // Pikachu (catch rate 190), Ultra Ball, full HP, no status:
        // C = min(255, 190*2) = 255; X = max(255/3, 1) = 85; P = 86/256 ≈ 0.336
        var inputs = makeInputs()
        inputs.catchBall = .ultra
        let result = calculator.calculate(inputs: inputs, catchRate: 190, maxHP: 100, currentHP: 100)
        let expected = Double(85 + 1) / 256.0
        XCTAssertEqual(result.probability, expected, accuracy: 0.005)
    }

    func testGen2Probability255IsGuaranteed() {
        let p = CaptureMath.gen2Probability(modifiedRate: 255)
        XCTAssertEqual(p, 1.0, accuracy: 0.0001)
    }

    func testGen2ProbabilityFormula() {
        // P = (X + 1) / 256
        XCTAssertEqual(CaptureMath.gen2Probability(modifiedRate: 0),   1.0 / 256.0, accuracy: 0.0001)
        XCTAssertEqual(CaptureMath.gen2Probability(modifiedRate: 127), 128.0 / 256.0, accuracy: 0.0001)
        XCTAssertEqual(CaptureMath.gen2Probability(modifiedRate: 254), 255.0 / 256.0, accuracy: 0.0001)
    }

    // MARK: - Large HP divide-by-4 fix

    func testLargeHPTriggersDivideBy4() {
        // maxHP = 249 (Lugia/Ho-Oh level 70 in G/S) → 3M = 747 > 255 → divide by 4
        // Ultra Ball: C = 3*2 = 6; 3M/4 = 186; 2H/4 = 124
        // X = max((186 - 124) * 6 / 186, 1) = max(372/186, 1) = max(2, 1) = 2; no status
        var inputs = makeInputs()
        inputs.catchBall = .ultra
        let result = calculator.calculate(inputs: inputs, catchRate: 3, maxHP: 249, currentHP: 249)
        // X = max((186 - 124) * 6 / 186, 1) = max(2, 1) = 2
        XCTAssertEqual(result.effectiveCatchRate, 2)
    }

    // MARK: - Helpers

    private func makeInputs() -> CatchInputs {
        var inputs = CatchInputs()
        inputs.generation = .gen2
        inputs.catchBall = .poke
        inputs.status = .none
        inputs.level = 30
        inputs.playerLevel = 50
        return inputs
    }
}
