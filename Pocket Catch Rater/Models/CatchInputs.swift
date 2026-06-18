import Foundation

struct CatchInputs: Sendable {
    var species: PokemonSpecies? = PokemonSpecies.fallbackPikachu
    var generation: PokemonGeneration = .gen1
    var battleMode: BattleMode = .wild
    var level: Int = 30
    var playerLevel: Int = 50
    var hpPercent: Double = 100
    var catchBall: CatchBall = .poke
    var standardBallAppearance: StandardBall = .poke
    var status: StatusCondition = .none
    var battleTurn: Int = 1
    var rocksThrown: Int = 0
    var baitUsed: Int = 0

    // Optional ball-condition toggles (Gen 3+ specialty balls)
    var isFishing: Bool = false
    var isWaterTerrain: Bool = false
    var isDarkTerrain: Bool = false
    var isRepeatRegistered: Bool = true
    var hasWaterOrBugType: Bool = false
    var isThickGrass: Bool = false
    var pokedexCaught: Int = 600

    // Gen 8–9 apricorn ball conditions (header toggles)
    var loveBallOppositeGender: Bool = false
    var moonBallBonusActive: Bool = false
    var fastBallBonusActive: Bool = false

    var effectiveBall: CatchBall {
        if battleMode == .safari { return .safari }
        return catchBall
    }

    var displayedBallName: String {
        if catchBall == .poke {
            return standardBallAppearance.displayName
        }
        return catchBall.displayName
    }

    var displayedBallSpriteURL: URL? {
        if catchBall == .poke {
            return standardBallAppearance.spriteURL
        }
        return catchBall.spriteURL
    }

    mutating func normalizeStandardBallSelection(for generation: PokemonGeneration) {
        if let appearance = StandardBall(catchBall: catchBall), catchBall != .poke {
            standardBallAppearance = appearance
            catchBall = .poke
        }

        let availableAppearances = StandardBall.available(for: generation)
        if !availableAppearances.contains(standardBallAppearance) {
            standardBallAppearance = .poke
        }
    }

    var effectiveStatus: StatusCondition {
        battleMode == .safari ? .none : status
    }

    var effectiveHPPercent: Double {
        battleMode == .safari ? 100 : hpPercent
    }

    mutating func syncSpecialtyBallDefaults() {
        guard let species else { return }

        switch catchBall {
        case .moon:
            moonBallBonusActive = MoonBallEligibility.isEligible(speciesID: species.id)
        case .fast:
            fastBallBonusActive = FastBallEligibility.isEligible(baseSpeed: species.baseSpeed)
        default:
            break
        }
    }

    var ballContext: BallContext {
        BallContext(
            playerLevel: playerLevel,
            targetLevel: level,
            battleTurn: battleTurn,
            status: effectiveStatus,
            isFishing: isFishing,
            isWaterTerrain: isWaterTerrain,
            isDarkTerrain: isDarkTerrain,
            isRepeatRegistered: isRepeatRegistered,
            hasWaterOrBugType: hasWaterOrBugType,
            isUltraBeast: species?.isUltraBeast ?? false,
            pokedexCaught: pokedexCaught,
            loveBallOppositeGender: loveBallOppositeGender,
            moonBallBonusActive: moonBallBonusActive,
            fastBallBonusActive: fastBallBonusActive
        )
    }
}
