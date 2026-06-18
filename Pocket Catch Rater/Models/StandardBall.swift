import Foundation

/// Cosmetic Poké Ball variants that share identical catch-rate mechanics.
enum StandardBall: String, CaseIterable, Identifiable, Sendable {
    case poke
    case friend
    case premier
    case luxury
    case heal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .poke: "Poké Ball"
        case .friend: "Friend Ball"
        case .premier: "Premier Ball"
        case .luxury: "Luxury Ball"
        case .heal: "Heal Ball"
        }
    }

    var itemSlug: String {
        switch self {
        case .poke: "poke-ball"
        case .friend: "friend-ball"
        case .premier: "premier-ball"
        case .luxury: "luxury-ball"
        case .heal: "heal-ball"
        }
    }

    var spriteURL: URL? {
        GameMediaURL.itemSprite(slug: itemSlug)
    }

    var minimumGeneration: Int {
        switch self {
        case .poke: 1
        case .friend: 2
        case .premier, .luxury: 3
        case .heal: 4
        }
    }

    init?(catchBall: CatchBall) {
        switch catchBall {
        case .poke: self = .poke
        case .friend: self = .friend
        case .premier: self = .premier
        case .luxury: self = .luxury
        case .heal: self = .heal
        default: return nil
        }
    }

    static func available(for generation: PokemonGeneration) -> [StandardBall] {
        allCases.filter { $0.minimumGeneration <= generation.rawValue }
    }
}
