import XCTest
@testable import Pocket_Catch_Rater

final class StandardBallTests: XCTestCase {
    func testPickerBallsExcludeCosmeticStandardBalls() {
        let pickerBalls = CatchBall.pickerBalls(for: .gen4)
        XCTAssertTrue(pickerBalls.contains(.poke))
        XCTAssertFalse(pickerBalls.contains(.premier))
        XCTAssertFalse(pickerBalls.contains(.luxury))
        XCTAssertFalse(pickerBalls.contains(.heal))
    }

    func testStandardBallAvailabilityByGeneration() {
        XCTAssertEqual(StandardBall.available(for: .gen1), [.poke])
        XCTAssertEqual(StandardBall.available(for: .gen3), [.poke, .premier, .luxury])
        XCTAssertEqual(StandardBall.available(for: .gen4), StandardBall.allCases)
    }

    func testNormalizeMapsLegacyCosmeticCatchBallToPokeWithAppearance() {
        var inputs = CatchInputs()
        inputs.catchBall = .premier

        inputs.normalizeStandardBallSelection(for: .gen4)

        XCTAssertEqual(inputs.catchBall, .poke)
        XCTAssertEqual(inputs.standardBallAppearance, .premier)
    }

    func testDisplayedBallUsesAppearanceWhenPokeSelected() {
        var inputs = CatchInputs()
        inputs.catchBall = .poke
        inputs.standardBallAppearance = .luxury

        XCTAssertEqual(inputs.displayedBallName, "Luxury Ball")
        XCTAssertEqual(inputs.displayedBallSpriteURL, StandardBall.luxury.spriteURL)
        XCTAssertEqual(inputs.effectiveBall, .poke)
    }

    func testDisplayedBallUsesCatchBallWhenNotPoke() {
        var inputs = CatchInputs()
        inputs.catchBall = .ultra
        inputs.standardBallAppearance = .premier

        XCTAssertEqual(inputs.displayedBallName, "Ultra Ball")
        XCTAssertEqual(inputs.effectiveBall, .ultra)
    }

    func testAppearanceClampsWhenGenerationDoesNotSupportHeal() {
        var inputs = CatchInputs()
        inputs.catchBall = .poke
        inputs.standardBallAppearance = .heal

        inputs.normalizeStandardBallSelection(for: .gen3)

        XCTAssertEqual(inputs.standardBallAppearance, .poke)
    }
}
