import XCTest
@testable import Pocket_Catch_Rater

final class CatchBallTests: XCTestCase {
    func testGen1BallsAreStaplesInOrder() {
        let balls = CatchBall.balls(for: .gen1).filter { $0 != .safari }
        XCTAssertEqual(balls, [.poke, .great, .ultra, .master])
    }

    func testGen4BallsLeadWithStaplesThenSituationalStaples() {
        let balls = CatchBall.balls(for: .gen4).filter { $0 != .safari }
        let prefix = Array(balls.prefix(8))
        XCTAssertEqual(prefix, [.poke, .great, .ultra, .master, .quick, .dusk, .timer, .net])
    }

    func testGen2PromotesLevelAndLureBeforeApricornBalls() {
        let balls = CatchBall.balls(for: .gen2).filter { $0 != .safari }
        let prefix = Array(balls.prefix(6))
        XCTAssertEqual(prefix, [.poke, .great, .ultra, .master, .level, .lure])
    }

    func testGen3PromotesTimerAndNetBeforeLevelAndLure() {
        let balls = CatchBall.balls(for: .gen3).filter { $0 != .safari }
        let prefix = Array(balls.prefix(8))
        XCTAssertEqual(prefix, [.poke, .great, .ultra, .master, .timer, .net, .repeatBall, .dive])
    }
}
