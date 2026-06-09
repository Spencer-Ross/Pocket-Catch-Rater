import XCTest
@testable import Pocket_Catch_Rater

final class Gen1CatchCalculatorTests: XCTestCase {
    private let calculator = Gen1CatchCalculator()

    func testMasterBallAlwaysCatches() {
        var inputs = CatchInputs()
        inputs.catchBall = .master

        let result = calculator.calculate(
            inputs: inputs,
            catchRate: 3,
            maxHP: 400,
            currentHP: 400
        )

        XCTAssertEqual(result.probability, 1.0, accuracy: 0.0001)
    }

    func testFullHPMewtwoUltraBallIsVeryLow() {
        var inputs = CatchInputs()
        inputs.catchBall = .ultra
        inputs.status = .none

        let result = calculator.calculate(
            inputs: inputs,
            catchRate: 3,
            maxHP: 400,
            currentHP: 400
        )

        XCTAssertLessThan(result.probability, 0.01)
    }

    func testSleepAddsBaselineCaptureChanceWithUltraBall() {
        var inputs = CatchInputs()
        inputs.catchBall = .ultra
        inputs.status = .sleep

        let asleep = calculator.calculate(
            inputs: inputs,
            catchRate: 3,
            maxHP: 400,
            currentHP: 400
        )

        inputs.status = .none
        let awake = calculator.calculate(
            inputs: inputs,
            catchRate: 3,
            maxHP: 400,
            currentHP: 400
        )

        XCTAssertGreaterThan(asleep.probability, awake.probability)
        XCTAssertEqual(asleep.probability - awake.probability, 25.0 / 151.0, accuracy: 0.0001)
    }

    func testGreatBallCanBeatUltraAtHighHP() {
        var greatInputs = CatchInputs()
        greatInputs.catchBall = .great

        var ultraInputs = CatchInputs()
        ultraInputs.catchBall = .ultra

        let great = calculator.calculate(
            inputs: greatInputs,
            catchRate: 45,
            maxHP: 200,
            currentHP: 200
        )
        let ultra = calculator.calculate(
            inputs: ultraInputs,
            catchRate: 45,
            maxHP: 200,
            currentHP: 200
        )

        XCTAssertGreaterThan(great.probability, ultra.probability)
    }

    func testSafariRockDoublesCatchRate() {
        var withRock = CatchInputs()
        withRock.battleMode = .safari
        withRock.rocksThrown = 1

        var baseline = CatchInputs()
        baseline.battleMode = .safari

        let boosted = calculator.calculate(
            inputs: withRock,
            catchRate: 45,
            maxHP: 100,
            currentHP: 100
        )
        let base = calculator.calculate(
            inputs: baseline,
            catchRate: 45,
            maxHP: 100,
            currentHP: 100
        )

        XCTAssertGreaterThan(boosted.probability, base.probability)
        XCTAssertEqual(boosted.effectiveCatchRate, 90)
    }

    func testHPFactorMatchesNestedFloorFormula() {
        let factor = Gen1CatchCalculator.hpFactor(maxHP: 100, currentHP: 25, ball: .poke)
        XCTAssertEqual(factor, 255)
    }
}
