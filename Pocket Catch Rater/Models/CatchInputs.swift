import Foundation

struct CatchInputs: Sendable {
    var species: PokemonSpecies?
    var generation: PokemonGeneration = .gen1
    var battleMode: BattleMode = .wild
    var level: Int = 30
    var playerLevel: Int = 50
    var hpPercent: Double = 100
    var catchBall: CatchBall = .poke
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
    var isUltraBeast: Bool = false
    var isThickGrass: Bool = false
    var pokedexCaught: Int = 600

    var effectiveBall: CatchBall {
        if battleMode == .safari { return .safari }
        return catchBall
    }

    var effectiveStatus: StatusCondition {
        battleMode == .safari ? .none : status
    }

    var effectiveHPPercent: Double {
        battleMode == .safari ? 100 : hpPercent
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
            isUltraBeast: isUltraBeast,
            pokedexCaught: pokedexCaught
        )
    }
}
