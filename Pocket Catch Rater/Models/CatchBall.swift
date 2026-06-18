import Foundation

enum CatchBall: String, CaseIterable, Identifiable, Sendable {
    case poke
    case great
    case ultra
    case master
    case safari
    case friend
    case level
    case lure
    case heavy
    case love
    case moon
    case fast
    case nest
    case repeatBall
    case timer
    case premier
    case luxury
    case dive
    case net
    case dusk
    case heal
    case quick
    case dream
    case beast

    var id: String { rawValue }

    var itemSlug: String {
        switch self {
        case .poke: "poke-ball"
        case .great: "great-ball"
        case .ultra: "ultra-ball"
        case .master: "master-ball"
        case .safari: "safari-ball"
        case .friend: "friend-ball"
        case .level: "level-ball"
        case .lure: "lure-ball"
        case .heavy: "heavy-ball"
        case .love: "love-ball"
        case .moon: "moon-ball"
        case .fast: "fast-ball"
        case .nest: "nest-ball"
        case .repeatBall: "repeat-ball"
        case .timer: "timer-ball"
        case .premier: "premier-ball"
        case .luxury: "luxury-ball"
        case .dive: "dive-ball"
        case .net: "net-ball"
        case .dusk: "dusk-ball"
        case .heal: "heal-ball"
        case .quick: "quick-ball"
        case .dream: "dream-ball"
        case .beast: "beast-ball"
        }
    }

    var spriteURL: URL? {
        GameMediaURL.ballSprite(for: self)
    }

    var displayName: String {
        switch self {
        case .poke: "Poké Ball"
        case .great: "Great Ball"
        case .ultra: "Ultra Ball"
        case .master: "Master Ball"
        case .safari: "Safari Ball"
        case .friend: "Friend Ball"
        case .level: "Level Ball"
        case .lure: "Lure Ball"
        case .heavy: "Heavy Ball"
        case .love: "Love Ball"
        case .moon: "Moon Ball"
        case .fast: "Fast Ball"
        case .nest: "Nest Ball"
        case .repeatBall: "Repeat Ball"
        case .timer: "Timer Ball"
        case .premier: "Premier Ball"
        case .luxury: "Luxury Ball"
        case .dive: "Dive Ball"
        case .net: "Net Ball"
        case .dusk: "Dusk Ball"
        case .heal: "Heal Ball"
        case .quick: "Quick Ball"
        case .dream: "Dream Ball"
        case .beast: "Beast Ball"
        }
    }

    var minimumGeneration: Int {
        switch self {
        case .poke, .great, .ultra, .master: 1
        case .safari: 1
        case .friend, .level, .lure, .heavy, .love, .moon, .fast: 2
        case .nest, .repeatBall, .timer, .premier, .luxury, .dive, .net: 3
        case .dusk, .heal, .quick: 4
        case .dream: 5
        case .beast: 7
        }
    }

    static func balls(for generation: PokemonGeneration) -> [CatchBall] {
        allCases
            .filter { $0.minimumGeneration <= generation.rawValue }
            .sorted { $0.usageSortRank(for: generation) < $1.usageSortRank(for: generation) }
    }

    /// Cosmetic-only standard-ball skins hidden from the main picker.
    static let cosmeticStandardBalls: Set<CatchBall> = [.premier, .luxury, .heal]

    static func pickerBalls(for generation: PokemonGeneration) -> [CatchBall] {
        balls(for: generation).filter { $0 != .safari && !cosmeticStandardBalls.contains($0) }
    }

    /// Curated picker order by typical player use (no official per-generation usage data exists).
    /// Staples first, then era-appropriate situational balls, then specialty options.
    func usageSortRank(for generation: PokemonGeneration) -> Int {
        let gen = generation.rawValue
        var rank = modernUsageRank

        if gen < 4 {
            switch self {
            case .timer where gen >= 3: rank = 10
            case .net where gen >= 3: rank = 11
            case .repeatBall where gen >= 3: rank = 12
            case .dive where gen >= 3: rank = 13
            case .nest where gen >= 3: rank = 14
            case .level: rank = gen == 2 ? 10 : 15
            case .lure: rank = gen == 2 ? 11 : 16
            case .heavy where gen == 2: rank = 17
            case .fast where gen == 2: rank = 18
            case .moon where gen == 2: rank = 19
            case .friend where gen == 2: rank = 20
            case .love where gen == 2: rank = 21
            default: break
            }
        }

        if gen == 5 || gen == 6, self == .dream {
            rank = 19
        }

        if gen >= 7, self == .beast {
            rank = 19
        }

        return rank
    }

    private var modernUsageRank: Int {
        switch self {
        case .poke: 0
        case .great: 1
        case .ultra: 2
        case .master: 3
        case .quick: 10
        case .dusk: 11
        case .timer: 12
        case .net: 13
        case .repeatBall: 14
        case .dive: 15
        case .nest: 16
        case .level: 17
        case .lure: 18
        case .premier: 25
        case .luxury: 26
        case .heal: 27
        case .heavy: 30
        case .fast: 31
        case .friend: 32
        case .love: 33
        case .moon: 34
        case .dream: 40
        case .beast: 41
        case .safari: 99
        }
    }

    // MARK: - Gen 1 constants

    var gen1SampleSpace: Int {
        switch self {
        case .poke: 256
        case .great: 201
        case .ultra, .safari: 151
        case .master: 0
        default: 256
        }
    }

    var gen1HpDivisor: Int {
        switch self {
        case .poke, .ultra, .safari: 12
        case .great: 8
        case .master: 1
        default: 12
        }
    }

    var gen1WobbleDivisor: Int {
        switch self {
        case .poke: 255
        case .great: 200
        case .ultra, .safari: 150
        case .master: 255
        default: 255
        }
    }

    // MARK: - Gen 2 catch-rate multiplier (applied to C before formula)

    func gen2CatchRateMultiplier(context: BallContext) -> Double {
        switch self {
        case .poke, .friend, .heavy, .love, .moon, .fast, .premier, .luxury, .heal:
            return 1
        case .great: return 1.5
        case .ultra: return 2
        case .safari, .lure: return 1.5
        case .level:
            let player = context.playerLevel
            let target = context.targetLevel
            if player / 4 >= target { return 8 }
            if player / 2 >= target { return 4 }
            if player > target { return 2 }
            return 1
        case .master: return 1
        default: return 1
        }
    }

    // MARK: - Gen 3+ ball bonus multiplier B

    func modernBallBonus(generation: PokemonGeneration, context: BallContext) -> Double {
        switch self {
        case .master:
            return 1
        case .poke, .premier, .luxury, .heal, .friend, .heavy, .love, .moon, .fast:
            return 1
        case .great:
            return 1.5
        case .ultra:
            return 2
        case .safari:
            return generation.rawValue >= 8 ? 1.5 : 1
        case .lure:
            return context.isFishing ? (generation.rawValue >= 8 ? 4 : 5) : 1
        case .level:
            let player = context.playerLevel
            let target = context.targetLevel
            if player / 4 >= target { return 8 }
            if player / 2 >= target { return 4 }
            if player > target { return 2 }
            return 1
        case .nest:
            if context.targetLevel < 30 {
                return max(1, Double(41 - context.targetLevel) / 10)
            }
            return 1
        case .repeatBall:
            return context.isRepeatRegistered ? (generation.rawValue >= 8 ? 3.5 : 3) : 1
        case .timer:
            let turns = max(1, context.battleTurn)
            let increment = 1229.0 / 4096.0
            return min(4, 1 + Double(turns - 1) * increment)
        case .quick:
            return context.battleTurn == 1 ? 5 : 1
        case .dive:
            return context.isWaterTerrain ? (generation.rawValue >= 8 ? 3.5 : 3.5) : 1
        case .net:
            return context.hasWaterOrBugType ? (generation.rawValue >= 8 ? 3.5 : 3) : 1
        case .dusk:
            return context.isDarkTerrain ? (generation.rawValue >= 8 ? 3 : 3.5) : 1
        case .dream:
            if generation.rawValue >= 8 {
                return context.status == .sleep ? 4 : 1
            }
            return 1
        case .beast:
            return context.isUltraBeast ? 5 : (410.0 / 4096.0)
        }
    }
}

struct BallContext: Sendable {
    var playerLevel: Int = 50
    var targetLevel: Int = 30
    var battleTurn: Int = 1
    var status: StatusCondition = .none
    var isFishing: Bool = false
    var isWaterTerrain: Bool = false
    var isDarkTerrain: Bool = false
    var isRepeatRegistered: Bool = true
    var hasWaterOrBugType: Bool = false
    var isUltraBeast: Bool = false
    var pokedexCaught: Int = 600
}
