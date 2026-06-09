import XCTest
@testable import Pocket_Catch_Rater

final class ModernCatchCalculatorTests: XCTestCase {
    func testGen2SleepIncreasesCatchChance() {
        var inputs = CatchInputs()
        inputs.generation = .gen2
        inputs.catchBall = .ultra
        inputs.status = .sleep

        let calculator = ModernCatchCalculator(formulaFamily: .gen2)
        let asleep = calculator.calculate(inputs: inputs, catchRate: 45, maxHP: 100, currentHP: 100)

        inputs.status = .none
        let awake = calculator.calculate(inputs: inputs, catchRate: 45, maxHP: 100, currentHP: 100)

        XCTAssertGreaterThan(asleep.probability, awake.probability)
    }

    func testGen3MasterBallAlwaysCatches() {
        var inputs = CatchInputs()
        inputs.generation = .gen3
        inputs.catchBall = .master

        let calculator = ModernCatchCalculator(formulaFamily: .gen3to4)
        let result = calculator.calculate(inputs: inputs, catchRate: 3, maxHP: 200, currentHP: 200)

        XCTAssertEqual(result.probability, 1.0, accuracy: 0.0001)
    }

    func testGen8LowLevelBoostsCatchRate() {
        var lowLevelInputs = CatchInputs()
        lowLevelInputs.generation = .gen8
        lowLevelInputs.catchBall = .ultra
        lowLevelInputs.level = 10

        var highLevelInputs = CatchInputs()
        highLevelInputs.generation = .gen8
        highLevelInputs.catchBall = .ultra
        highLevelInputs.level = 30

        let calculator = ModernCatchCalculator(formulaFamily: .gen8to9)
        let low = calculator.calculateWithEstimatedHP(
            inputs: lowLevelInputs,
            catchRate: 45,
            baseHP: 45
        )
        let high = calculator.calculateWithEstimatedHP(
            inputs: highLevelInputs,
            catchRate: 45,
            baseHP: 45
        )

        XCTAssertGreaterThan(low.probability, high.probability)
    }

    func testGen5QuickBallFirstTurnBeatsPokeBall() {
        var quickInputs = CatchInputs()
        quickInputs.generation = .gen5
        quickInputs.catchBall = .quick
        quickInputs.battleTurn = 1

        var pokeInputs = CatchInputs()
        pokeInputs.generation = .gen5
        pokeInputs.catchBall = .poke
        pokeInputs.battleTurn = 1

        let calculator = ModernCatchCalculator(formulaFamily: .gen5)
        let quick = calculator.calculate(inputs: quickInputs, catchRate: 45, maxHP: 100, currentHP: 50)
        let poke = calculator.calculate(inputs: pokeInputs, catchRate: 45, maxHP: 100, currentHP: 50)

        XCTAssertGreaterThan(quick.probability, poke.probability)
    }
}
