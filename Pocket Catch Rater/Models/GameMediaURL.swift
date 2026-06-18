import Foundation

enum GameMediaURL {
    private static let pokemonSpriteBase =
        "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon"
    private static let itemSpriteBase =
        "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items"

    static func pokemonSprite(speciesID: Int) -> URL? {
        URL(string: "\(pokemonSpriteBase)/\(speciesID).png")
    }

    static func ballSprite(for ball: CatchBall) -> URL? {
        itemSprite(slug: ball.itemSlug)
    }

    static func itemSprite(slug: String) -> URL? {
        URL(string: "\(itemSpriteBase)/\(slug).png")
    }
}
