import XCTest
@testable import Pocket_Catch_Rater

final class SpecialtyBallTests: XCTestCase {
    func testMoonBallEligibilityCoversMoonStoneFamilies() {
        // Direct evolvers qualify in all gens
        XCTAssertTrue(MoonBallEligibility.isEligibleModern(speciesID: 35))  // Clefairy
        XCTAssertTrue(MoonBallEligibility.isEligibleModern(speciesID: 39))  // Jigglypuff
        XCTAssertFalse(MoonBallEligibility.isEligibleModern(speciesID: 25)) // Pikachu

        // HGSS (Gen 3/4): whole evolution family qualifies
        XCTAssertTrue(MoonBallEligibility.isEligibleHGSS(speciesID: 36))   // Clefable
        XCTAssertTrue(MoonBallEligibility.isEligibleHGSS(speciesID: 40))   // Wigglytuff
        XCTAssertFalse(MoonBallEligibility.isEligibleHGSS(speciesID: 25))  // Pikachu

        // Non-evolvers do NOT qualify in modern gens
        XCTAssertFalse(MoonBallEligibility.isEligibleModern(speciesID: 36)) // Clefable (fully evolved)
        XCTAssertFalse(MoonBallEligibility.isEligibleModern(speciesID: 40)) // Wigglytuff (fully evolved)
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
        var context = BallContext()
        context.status = .sleep

        let label = SpecialtyBallMath.bonusLabel(
            ball: .dream,
            ruleSet: .gen9,
            context: context,
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
            ruleSet: .gen9,
            context: BallContext(),
            species: nihilego
        )
        XCTAssertEqual(bonusLabel, "Beast Ball: 5× catch rate (Ultra Beast)")

        let penaltyLabel = SpecialtyBallMath.bonusLabel(
            ball: .beast,
            ruleSet: .gen7,
            context: BallContext(),
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

    func testSituationalBallToggleLabels() {
        XCTAssertEqual(SpecialtyBallMath.toggleLabel(for: .lure), "Fishing")
        XCTAssertEqual(SpecialtyBallMath.toggleLabel(for: .dive), "In Water")
        XCTAssertEqual(SpecialtyBallMath.toggleLabel(for: .repeatBall), "Caught")
        XCTAssertEqual(SpecialtyBallMath.toggleLabel(for: .dusk), "Night/Cave")
        XCTAssertEqual(SpecialtyBallMath.toggleLabel(for: .quick), "First Turn")
        // Turn picker shown for all Gen 3+ (not Gen 1 or Gen 2)
        XCTAssertTrue(SpecialtyBallMath.showsTurnPicker(for: .timer, ruleSet: .gen9))
        XCTAssertTrue(SpecialtyBallMath.showsTurnPicker(for: .timer, ruleSet: .gen3to4))
        XCTAssertFalse(SpecialtyBallMath.showsTurnPicker(for: .timer, ruleSet: .gen2))
        XCTAssertFalse(SpecialtyBallMath.showsTurnPicker(for: .timer, ruleSet: .gen1))
    }

    func testGen9SituationalBallBonusLabels() {
        var waterTerrain = BallContext()
        waterTerrain.isWaterTerrain = true
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .lure, ruleSet: .gen9, context: waterTerrain, species: nil),
            "Lure Ball: 4× catch rate (near water)"
        )

        var underwater = BallContext()
        underwater.isWaterTerrain = true
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .dive, ruleSet: .gen9, context: underwater, species: nil),
            "Dive Ball: 3.5× catch rate (in water)"
        )

        var caught = BallContext()
        caught.isRepeatRegistered = true
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .repeatBall, ruleSet: .gen9, context: caught, species: nil),
            "Repeat Ball: 3.5× catch rate (already caught)"
        )

        var dark = BallContext()
        dark.isDarkTerrain = true
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .dusk, ruleSet: .gen9, context: dark, species: nil),
            "Dusk Ball: 3× catch rate (night or cave)"
        )

        var turnFive = BallContext()
        turnFive.battleTurn = 5
        let timerLabel = SpecialtyBallMath.bonusLabel(
            ball: .timer,
            ruleSet: .gen9,
            context: turnFive,
            species: nil
        )
        XCTAssertEqual(timerLabel, "Timer Ball: 2.2× catch rate (turn 5)")
        XCTAssertEqual(
            SpecialtyBallMath.timerBallMultiplier(turn: 5),
            CatchBall.timer.modernBallBonus(generation: .gen9, context: turnFive),
            accuracy: 0.0001
        )
    }

    func testQuickBallAlwaysUsesFirstTurnToggle() {
        var active = BallContext()
        active.quickBallFirstTurnActive = true
        var inactive = BallContext()
        inactive.quickBallFirstTurnActive = false

        // Gen 9: B = 5
        XCTAssertEqual(CatchBall.quick.modernBallBonus(generation: .gen9, context: active), 5)
        XCTAssertEqual(CatchBall.quick.modernBallBonus(generation: .gen9, context: inactive), 1)
        // Gen 4: B = 4 per dragonflycave.com/mechanics/gen-iii-iv-capturing
        XCTAssertEqual(CatchBall.quick.modernBallBonus(generation: .gen4, context: active), 4)
        XCTAssertEqual(CatchBall.quick.modernBallBonus(generation: .gen4, context: inactive), 1)

        let labelGen9 = SpecialtyBallMath.bonusLabel(ball: .quick, ruleSet: .gen9, context: active, species: nil)
        XCTAssertEqual(labelGen9, "Quick Ball: 5× catch rate (first turn)")

        let labelGen4 = SpecialtyBallMath.bonusLabel(ball: .quick, ruleSet: .gen3to4, context: active, species: nil)
        XCTAssertEqual(labelGen4, "Quick Ball: 4× catch rate (first turn)")

        XCTAssertNil(SpecialtyBallMath.bonusLabel(ball: .quick, ruleSet: .gen3to4, context: inactive, species: nil))
    }

    func testGen9NetBallBonusLabelUsesSpeciesTypes() {
        let magikarp = PokemonSpecies(
            id: 129,
            name: "Magikarp",
            generation: 1,
            baseHP: 20,
            catchRate: 255,
            type1: "water",
            type2: nil
        )
        let pikachu = PokemonSpecies.fallbackPikachu

        var waterContext = BallContext()
        waterContext.hasWaterOrBugType = true
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .net, ruleSet: .gen9, context: waterContext, species: magikarp),
            "Net Ball: 3.5× catch rate (Water)"
        )

        var normalContext = BallContext()
        normalContext.hasWaterOrBugType = false
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .net, ruleSet: .gen9, context: normalContext, species: pikachu),
            "Net Ball: no bonus (Electric — not Water or Bug)"
        )
    }

    func testGen9NestBallBonusLabelReflectsTargetLevel() {
        var lowLevel = BallContext()
        lowLevel.targetLevel = 10
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .nest, ruleSet: .gen9, context: lowLevel, species: nil),
            "Nest Ball: 3.1× catch rate (target level 10)"
        )

        var highLevel = BallContext()
        highLevel.targetLevel = 35
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .nest, ruleSet: .gen9, context: highLevel, species: nil),
            "Nest Ball: no bonus (target level 35 — need below 30)"
        )
    }

    func testGen9LevelBallBonusLabelReflectsPlayerAndTargetLevels() {
        var strong = BallContext()
        strong.playerLevel = 50
        strong.targetLevel = 10
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .level, ruleSet: .gen9, context: strong, species: nil),
            "Level Ball: 8× catch rate (Lv. 50 vs Lv. 10)"
        )

        var weak = BallContext()
        weak.playerLevel = 30
        weak.targetLevel = 50
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .level, ruleSet: .gen9, context: weak, species: nil),
            "Level Ball: no bonus (Lv. 30 vs Lv. 50 — not high enough)"
        )
    }

    func testGen3to7BonusLabelsMatchCorrectMultipliers() {
        // Lure Ball: in Gen 3–4 (HGSS), modifies species catch rate C by 3× — B = 1.
        // Gen 5–7: B = 5× when fishing. Gen 8: B = 4× when fishing. Gen 9: B = 4× near water (no fishing).
        var fishing = BallContext()
        fishing.isFishing = true
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .lure, ruleSet: .gen3to4, context: fishing, species: nil),
            "Lure Ball: 3× species catch rate (fishing)"
        )
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .lure, ruleSet: .gen8, context: fishing, species: nil),
            "Lure Ball: 4× catch rate (fishing)"
        )
        var waterTerrain = BallContext()
        waterTerrain.isWaterTerrain = true
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .lure, ruleSet: .gen9, context: waterTerrain, species: nil),
            "Lure Ball: 4× catch rate (near water)"
        )

        // Net Ball: 3× in Gen 3–7, 3.5× in Gen 8–9
        let magikarp = PokemonSpecies(id: 129, name: "Magikarp", generation: 1, baseHP: 20, catchRate: 255, type1: "water", type2: nil)
        var waterCtx = BallContext()
        waterCtx.hasWaterOrBugType = true
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .net, ruleSet: .gen3to4, context: waterCtx, species: magikarp),
            "Net Ball: 3× catch rate (Water)"
        )
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .net, ruleSet: .gen9, context: waterCtx, species: magikarp),
            "Net Ball: 3.5× catch rate (Water)"
        )

        // Dusk Ball: 3.5× in Gen 3–7, 3× in Gen 8–9
        var dark = BallContext()
        dark.isDarkTerrain = true
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .dusk, ruleSet: .gen3to4, context: dark, species: nil),
            "Dusk Ball: 3.5× catch rate (night or cave)"
        )
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .dusk, ruleSet: .gen9, context: dark, species: nil),
            "Dusk Ball: 3× catch rate (night or cave)"
        )

        // Repeat Ball: 3× in Gen 3–7, 3.5× in Gen 8–9
        var caught = BallContext()
        caught.isRepeatRegistered = true
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .repeatBall, ruleSet: .gen3to4, context: caught, species: nil),
            "Repeat Ball: 3× catch rate (already caught)"
        )
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .repeatBall, ruleSet: .gen9, context: caught, species: nil),
            "Repeat Ball: 3.5× catch rate (already caught)"
        )

        // Gen 2 Lure Ball shows 3× when fishing (Gen 2 has its own label system)
        XCTAssertEqual(
            SpecialtyBallMath.bonusLabel(ball: .lure, ruleSet: .gen2, context: fishing, species: nil),
            "Lure Ball: 3× catch rate (fishing)"
        )
        // Gen 1 has no specialty ball labels
        XCTAssertNil(SpecialtyBallMath.bonusLabel(ball: .dusk, ruleSet: .gen1, context: dark, species: nil))
    }
}
