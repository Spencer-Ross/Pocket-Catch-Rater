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
        // <102.4 kg → -20
        XCTAssertEqual(PokemonWeightClass.classify(weightKg: 3.5, formulaFamily: .gen2), .light)
        // 102.4–204.8 kg → ±0 (medium tier added per Gen 2 spec)
        XCTAssertEqual(PokemonWeightClass.classify(weightKg: 150, formulaFamily: .gen2), .medium)
        // 204.8–307.2 kg → +20
        XCTAssertEqual(PokemonWeightClass.classify(weightKg: 210, formulaFamily: .gen2), .heavy)
        // 307.2–409.6 kg → +30
        XCTAssertEqual(PokemonWeightClass.classify(weightKg: 350, formulaFamily: .gen2), .veryHeavy)
        // ≥409.6 kg → +40
        XCTAssertEqual(PokemonWeightClass.classify(weightKg: 460, formulaFamily: .gen2), .ultraHeavy)
    }

    func testClassicMediumTierIsZeroBonus() {
        // 102.4 kg boundary (exactly at the medium threshold) → +0
        XCTAssertEqual(PokemonWeightClass.classify(weightKg: 102.4, formulaFamily: .gen2), .medium)
        XCTAssertEqual(PokemonWeightClass.medium.heavyBallCatchRateBonus(formulaFamily: .gen2), 0)
        // Just below medium → -20
        XCTAssertEqual(PokemonWeightClass.classify(weightKg: 102.3, formulaFamily: .gen2), .light)
        XCTAssertEqual(PokemonWeightClass.light.heavyBallCatchRateBonus(formulaFamily: .gen2), -20)
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
        let info = HeavyBallMath.info(weightKg: 210, ruleSet: .gen9)
        XCTAssertEqual(info.bonus, 20)
        XCTAssertTrue(info.label.contains("Heavy Ball: +20"))
        XCTAssertTrue(info.label.contains("210 kg"))
    }
}
