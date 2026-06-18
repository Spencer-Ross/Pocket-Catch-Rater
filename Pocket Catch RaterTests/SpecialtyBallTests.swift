import XCTest
@testable import Pocket_Catch_Rater

final class SpecialtyBallTests: XCTestCase {
    func testMoonBallEligibilityCoversMoonStoneFamilies() {
        XCTAssertTrue(MoonBallEligibility.isEligible(speciesID: 35))  // Clefairy
        XCTAssertTrue(MoonBallEligibility.isEligible(speciesID: 39))  // Jigglypuff
        XCTAssertFalse(MoonBallEligibility.isEligible(speciesID: 25)) // Pikachu
    }

    func testFastBallEligibilityUsesBaseSpeed100() {
        XCTAssertTrue(FastBallEligibility.isEligible(baseSpeed: 100))
        XCTAssertTrue(FastBallEligibility.isEligible(baseSpeed: 120))
        XCTAssertFalse(FastBallEligibility.isEligible(baseSpeed: 90))
        XCTAssertFalse(FastBallEligibility.isEligible(baseSpeed: nil))
    }

    func testGen9LoveBallBonusWhenOppositeGender() {
        var context = BallContext()
        context.loveBallOppositeGender = true

        XCTAssertEqual(
            CatchBall.love.modernBallBonus(generation: .gen9, context: context),
            8,
            accuracy: 0.001
        )

        context.loveBallOppositeGender = false
        XCTAssertEqual(CatchBall.love.modernBallBonus(generation: .gen9, context: context), 1)
    }

    func testGen9MoonBallBonusWhenEligible() {
        var context = BallContext()
        context.moonBallBonusActive = true

        XCTAssertEqual(
            CatchBall.moon.modernBallBonus(generation: .gen9, context: context),
            4,
            accuracy: 0.001
        )
    }

    func testGen9FastBallBonusWhenActive() {
        var context = BallContext()
        context.fastBallBonusActive = true

        XCTAssertEqual(
            CatchBall.fast.modernBallBonus(generation: .gen9, context: context),
            4,
            accuracy: 0.001
        )
    }

    func testGen9DreamBallBonusWhenAsleep() {
        var asleep = BallContext()
        asleep.status = .sleep

        var awake = BallContext()
        awake.status = .none

        XCTAssertEqual(
            CatchBall.dream.modernBallBonus(generation: .gen9, context: asleep),
            SpecialtyBallMath.gen8DreamBallMultiplier,
            accuracy: 0.001
        )
        XCTAssertEqual(CatchBall.dream.modernBallBonus(generation: .gen9, context: awake), 1)
        XCTAssertEqual(CatchBall.dream.modernBallBonus(generation: .gen7, context: asleep), 1)
    }

    func testDreamBallBonusLabelWhenAsleep() {
        let label = SpecialtyBallMath.bonusLabel(
            ball: .dream,
            ruleSet: .gen8to9,
            loveOppositeGender: false,
            moonBonusActive: false,
            fastBonusActive: false,
            status: .sleep,
            species: nil
        )
        XCTAssertEqual(label, "Dream Ball: 4× catch rate (asleep)")
    }

    func testUltraBeastEligibilityCoversKnownSpecies() {
        XCTAssertTrue(UltraBeastEligibility.isUltraBeast(speciesID: 793))  // Nihilego
        XCTAssertTrue(UltraBeastEligibility.isUltraBeast(speciesID: 799))  // Guzzlord
        XCTAssertTrue(UltraBeastEligibility.isUltraBeast(speciesID: 803))  // Poipole
        XCTAssertTrue(UltraBeastEligibility.isUltraBeast(speciesID: 806))  // Blacephalon
        XCTAssertFalse(UltraBeastEligibility.isUltraBeast(speciesID: 25))  // Pikachu
        XCTAssertFalse(UltraBeastEligibility.isUltraBeast(speciesID: 800)) // Zeraora
    }

    func testGen7BeastBallBonusForUltraBeast() {
        var ultraBeast = BallContext()
        ultraBeast.isUltraBeast = true

        var normal = BallContext()
        normal.isUltraBeast = false

        XCTAssertEqual(
            CatchBall.beast.modernBallBonus(generation: .gen7, context: ultraBeast),
            5,
            accuracy: 0.001
        )
        XCTAssertEqual(
            CatchBall.beast.modernBallBonus(generation: .gen7, context: normal),
            SpecialtyBallMath.beastBallPenaltyMultiplier,
            accuracy: 0.0001
        )
    }

    func testGen9BeastBallBonusForUltraBeast() {
        var context = BallContext()
        context.isUltraBeast = true
        XCTAssertEqual(
            CatchBall.beast.modernBallBonus(generation: .gen9, context: context),
            5,
            accuracy: 0.001
        )
    }

    func testBeastBallBonusLabelForUltraBeastAndNormal() {
        let nihilego = PokemonSpecies(
            id: 793,
            name: "Nihilego",
            generation: 7,
            baseHP: 109,
            catchRate: 45
        )
        let pikachu = PokemonSpecies.fallbackPikachu

        let bonusLabel = SpecialtyBallMath.bonusLabel(
            ball: .beast,
            ruleSet: .gen8to9,
            loveOppositeGender: false,
            moonBonusActive: false,
            fastBonusActive: false,
            status: .none,
            species: nihilego
        )
        XCTAssertEqual(bonusLabel, "Beast Ball: 5× catch rate (Ultra Beast)")

        let penaltyLabel = SpecialtyBallMath.bonusLabel(
            ball: .beast,
            ruleSet: .gen7,
            loveOppositeGender: false,
            moonBonusActive: false,
            fastBonusActive: false,
            status: .none,
            species: pikachu
        )
        XCTAssertEqual(penaltyLabel, "Beast Ball: 0.10× catch rate (not an Ultra Beast)")
    }

    func testCatchInputsSyncsMoonAndFastDefaultsFromSpecies() {
        var inputs = CatchInputs()
        inputs.catchBall = .moon
        inputs.species = PokemonSpecies(
            id: 35,
            name: "Clefairy",
            generation: 1,
            baseHP: 35,
            catchRate: 150,
            weightKg: 7.5,
            baseSpeed: 35
        )
        inputs.syncSpecialtyBallDefaults()
        XCTAssertTrue(inputs.moonBallBonusActive)

        inputs.catchBall = .fast
        inputs.syncSpecialtyBallDefaults()
        XCTAssertFalse(inputs.fastBallBonusActive)

        inputs.species = PokemonSpecies(
            id: 101,
            name: "Electrode",
            generation: 1,
            baseHP: 60,
            catchRate: 60,
            baseSpeed: 140
        )
        inputs.syncSpecialtyBallDefaults()
        XCTAssertTrue(inputs.fastBallBonusActive)
    }
}
