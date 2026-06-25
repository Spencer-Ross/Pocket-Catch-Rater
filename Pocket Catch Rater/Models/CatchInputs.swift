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

    // Gen 6 O-Power / Gen 7 Roto Catch / Gen 9 Capture Power multiplier.
    // Gen 6/7: 1.5×, 2.0×, or 2.5×. Gen 9: 1.1×, 1.25×, or 2.0×.
    // Default 1 = no power active (lowest/safest value).
    var oPowerBonus: Double = 1

    // Gen 9 only: catching the Pokémon off-guard (backstrike / unaware) doubles D.
    var isOffGuard: Bool = false

    // Gen 9 only: number of gym badges earned (0–8). Affects the BP badge-penalty multiplier.
    // Default 8 = no penalty (most players using a calculator are mid-to-late game).
    var badgeCount: Int = 8

    // Optional ball-condition toggles (Gen 3+ specialty balls)
    var isFishing: Bool = false
    var isWaterTerrain: Bool = false
    var isDarkTerrain: Bool = false
    var isRepeatRegistered: Bool = true
    var hasWaterOrBugType: Bool = false
    var isThickGrass: Bool = false
    var pokedexCaught: Int = 650

    // Gen 8–9 apricorn ball conditions (header toggles)
    var loveBallOppositeGender: Bool = false
    var moonBallBonusActive: Bool = false
    var fastBallBonusActive: Bool = false
    var quickBallFirstTurn: Bool = true

    // Gen 2 apricorn ball conditions (sheet toggles)
    var loveBallSameGender: Bool = false
    var gen2FastBallActive: Bool = false

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
            // HGSS (gen3to4): entire evolution family qualifies.
            // Gen VI+: only the Pokémon that directly evolves via Moon Stone.
            if generation.formulaFamily == .gen3to4 {
                moonBallBonusActive = MoonBallEligibility.isEligibleHGSS(speciesID: species.id)
            } else {
                moonBallBonusActive = MoonBallEligibility.isEligibleModern(speciesID: species.id)
            }
        case .fast:
            fastBallBonusActive = FastBallEligibility.isEligible(baseSpeed: species.baseSpeed)
            // Gen 2: Fast Ball only gives 4× for Grimer (#88), Tangela (#114), Magnemite (#81)
            gen2FastBallActive = Gen2FastBallEligibility.isEligible(speciesID: species.id)
        case .net:
            hasWaterOrBugType = species.hasWaterOrBugType
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
            fastBallBonusActive: fastBallBonusActive,
            quickBallFirstTurnActive: quickBallFirstTurn,
            loveBallSameGender: loveBallSameGender,
            gen2FastBallActive: gen2FastBallActive
        )
    }
}
