import XCTest
@testable import Pocket_Catch_Rater

final class PokemonWeightClassTests: XCTestCase {
    func testModernWeightClasses() {
        XCTAssertEqual(
            PokemonWeightClass.classify(weightKg: 3.5, formulaFamily: .gen8to9),
            .light
        )
        XCTAssertEqual(
            PokemonWeightClass.classify(weightKg: 120, formulaFamily: .gen8to9),
            .medium
        )
        XCTAssertEqual(
            PokemonWeightClass.classify(weightKg: 210, formulaFamily: .gen8to9),
            .heavy
        )
        XCTAssertEqual(
            PokemonWeightClass.classify(weightKg: 460, formulaFamily: .gen8to9),
            .veryHeavy
        )
    }

    func testClassicWeightClasses() {
        XCTAssertEqual(
            PokemonWeightClass.classify(weightKg: 3.5, formulaFamily: .gen2),
            .light
        )
        XCTAssertEqual(
            PokemonWeightClass.classify(weightKg: 210, formulaFamily: .gen2),
            .heavy
        )
        XCTAssertEqual(
            PokemonWeightClass.classify(weightKg: 350, formulaFamily: .gen2),
            .veryHeavy
        )
        XCTAssertEqual(
            PokemonWeightClass.classify(weightKg: 460, formulaFamily: .gen2),
            .ultraHeavy
        )
    }

    func testHeavyBallBonuses() {
        XCTAssertEqual(PokemonWeightClass.light.heavyBallCatchRateBonus(formulaFamily: .gen8to9), -20)
        XCTAssertEqual(PokemonWeightClass.heavy.heavyBallCatchRateBonus(formulaFamily: .gen8to9), 20)
        XCTAssertEqual(PokemonWeightClass.veryHeavy.heavyBallCatchRateBonus(formulaFamily: .gen8to9), 30)
        XCTAssertEqual(PokemonWeightClass.ultraHeavy.heavyBallCatchRateBonus(formulaFamily: .gen2), 40)
    }

    func testHeavyBallImprovesCatchRateForOnix() {
        var heavyInputs = CatchInputs()
        heavyInputs.generation = .gen8
        heavyInputs.catchBall = .heavy
        heavyInputs.species = PokemonSpecies(
            id: 95,
            name: "Onix",
            generation: 1,
            baseHP: 35,
            catchRate: 45,
            weightKg: 210
        )

        var pokeInputs = heavyInputs
        pokeInputs.catchBall = .poke

        let calculator = ModernCatchCalculator(formulaFamily: .gen8to9)
        let heavy = calculator.calculate(inputs: heavyInputs, catchRate: 45, maxHP: 100, currentHP: 1)
        let poke = calculator.calculate(inputs: pokeInputs, catchRate: 45, maxHP: 100, currentHP: 1)

        XCTAssertGreaterThan(heavy.probability, poke.probability)
    }

    func testHeavyBallLabelIncludesWeightClass() {
        let info = HeavyBallMath.info(weightKg: 210, ruleSet: .gen8to9)
        XCTAssertEqual(info.bonus, 20)
        XCTAssertTrue(info.label.contains("Heavy Ball: +20"))
        XCTAssertTrue(info.label.contains("210 kg"))
    }
}
