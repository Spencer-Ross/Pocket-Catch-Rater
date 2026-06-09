import Foundation
import GRDB

nonisolated struct PokemonDatabase {
    let dbQueue: DatabaseQueue

    init(inMemory: Bool = false) throws {
        if inMemory {
            dbQueue = try DatabaseQueue()
        } else {
            let url = try Self.databaseURL()
            dbQueue = try DatabaseQueue(path: url.path)
        }
        try migrator.migrate(dbQueue)
    }

    private static func databaseURL() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return support.appendingPathComponent("pokemon.db")
    }

    var databaseFileSize: Int64 {
        guard let url = try? Self.databaseURL(),
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return 0
        }
        return size
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial") { db in
            try db.create(table: "species") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text).notNull().collate(.nocase)
                t.column("generation", .integer).notNull()
                t.column("base_hp", .integer).notNull()
                t.column("catch_rate", .integer).notNull()
                t.column("updated_at", .text).notNull()
            }
            try db.create(index: "idx_species_generation", on: "species", columns: ["generation"])
            try db.create(index: "idx_species_name", on: "species", columns: ["name"])

            try db.create(table: "game_catch_rate_overrides") { t in
                t.column("species_id", .integer).notNull().references("species", onDelete: .cascade)
                t.column("game_key", .text).notNull()
                t.column("catch_rate", .integer).notNull()
                t.primaryKey(["species_id", "game_key"])
            }

            try db.create(table: "sync_metadata") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
            }

            try db.create(table: "api_response_cache") { t in
                t.column("url", .text).primaryKey()
                t.column("json_body", .text).notNull()
                t.column("fetched_at", .text).notNull()
            }
        }

        migrator.registerMigration("v2_game_availability") { db in
            try db.create(table: "species_game_availability") { t in
                t.column("species_id", .integer).notNull().references("species", onDelete: .cascade)
                t.column("game_generation", .integer).notNull()
                t.primaryKey(["species_id", "game_generation"])
            }
            try db.create(
                index: "idx_availability_game_generation",
                on: "species_game_availability",
                columns: ["game_generation"]
            )

            try db.execute(sql: """
                INSERT INTO species_game_availability (species_id, game_generation)
                SELECT id, generation FROM species
                """)
        }

        migrator.registerMigration("v3_types_and_pokedex") { db in
            try db.alter(table: "species") { t in
                t.add(column: "type1", .text)
                t.add(column: "type2", .text)
            }

            try db.create(table: "species_pokedex_membership") { t in
                t.column("pokedex_id", .integer).notNull()
                t.column("species_id", .integer).notNull().references("species", onDelete: .cascade)
                t.primaryKey(["pokedex_id", "species_id"])
            }
            try db.create(
                index: "idx_pokedex_membership_species",
                on: "species_pokedex_membership",
                columns: ["species_id"]
            )
        }

        return migrator
    }

    // MARK: - Writes

    func upsertSpecies(_ species: [SpeciesDTO], timestamp: String) throws {
        try dbQueue.write { db in
            for entry in species {
                try db.execute(
                    sql: """
                    INSERT INTO species (id, name, generation, base_hp, catch_rate, type1, type2, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        name = excluded.name,
                        generation = excluded.generation,
                        base_hp = excluded.base_hp,
                        catch_rate = excluded.catch_rate,
                        type1 = COALESCE(excluded.type1, species.type1),
                        type2 = COALESCE(excluded.type2, species.type2),
                        updated_at = excluded.updated_at
                    """,
                    arguments: [
                        entry.id,
                        entry.name,
                        entry.generation,
                        entry.baseHP,
                        entry.catchRate,
                        entry.type1,
                        entry.type2,
                        timestamp,
                    ]
                )
            }
        }
    }

    func replacePokedexMembership(pokedexID: Int, speciesIDs: [Int]) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM species_pokedex_membership WHERE pokedex_id = ?",
                arguments: [pokedexID]
            )

            for speciesID in speciesIDs {
                try db.execute(
                    sql: """
                    INSERT INTO species_pokedex_membership (pokedex_id, species_id)
                    VALUES (?, ?)
                    ON CONFLICT(pokedex_id, species_id) DO NOTHING
                    """,
                    arguments: [pokedexID, speciesID]
                )
            }
        }
    }

    func rebuildAvailability(for gameGeneration: Int) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM species_game_availability WHERE game_generation = ?",
                arguments: [gameGeneration]
            )

            if gameGeneration == PokemonGeneration.gen9.rawValue {
                try db.execute(sql: """
                    INSERT INTO species_game_availability (species_id, game_generation)
                    SELECT DISTINCT species_id, ?
                    FROM species_pokedex_membership
                    WHERE pokedex_id IN (31, 32, 33)
                    ON CONFLICT(species_id, game_generation) DO NOTHING
                    """, arguments: [gameGeneration])
            } else {
                try db.execute(sql: """
                    INSERT INTO species_game_availability (species_id, game_generation)
                    SELECT id, ?
                    FROM species
                    WHERE generation <= ?
                    ON CONFLICT(species_id, game_generation) DO NOTHING
                    """, arguments: [gameGeneration, gameGeneration])
            }
        }
    }

    func markSpeciesAvailable(_ speciesIDs: [Int], gameGeneration: Int) throws {
        guard !speciesIDs.isEmpty else { return }

        try dbQueue.write { db in
            for speciesID in speciesIDs {
                try db.execute(
                    sql: """
                    INSERT INTO species_game_availability (species_id, game_generation)
                    VALUES (?, ?)
                    ON CONFLICT(species_id, game_generation) DO NOTHING
                    """,
                    arguments: [speciesID, gameGeneration]
                )
            }
        }
    }

    func upsertOverride(speciesID: Int, gameKey: String, catchRate: Int) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO game_catch_rate_overrides (species_id, game_key, catch_rate)
                VALUES (?, ?, ?)
                ON CONFLICT(species_id, game_key) DO UPDATE SET catch_rate = excluded.catch_rate
                """,
                arguments: [speciesID, gameKey, catchRate]
            )
        }
    }

    func setMetadata(key: String, value: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO sync_metadata (key, value) VALUES (?, ?)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """,
                arguments: [key, value]
            )
        }
    }

    func clearAllData() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM api_response_cache")
            try db.execute(sql: "DELETE FROM game_catch_rate_overrides")
            try db.execute(sql: "DELETE FROM species_pokedex_membership")
            try db.execute(sql: "DELETE FROM species_game_availability")
            try db.execute(sql: "DELETE FROM species")
            try db.execute(sql: "DELETE FROM sync_metadata")
        }
    }

    // MARK: - Reads

    func speciesCount() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM species") ?? 0
        }
    }

    func metadataValue(for key: String) throws -> String? {
        try dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM sync_metadata WHERE key = ?", arguments: [key])
        }
    }

    func species(inGameGeneration gameGeneration: Int) throws -> [PokemonSpecies] {
        if try availabilityCount(for: gameGeneration) > 0 {
            return try speciesFromAvailability(gameGeneration: gameGeneration, namePrefix: nil)
        }

        return try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, name, generation, base_hp, catch_rate, type1, type2
                FROM species
                WHERE generation <= ?
                ORDER BY id
                """,
                arguments: [gameGeneration]
            )
            return rows.map(Self.mapSpecies)
        }
    }

    func search(name: String, inGameGeneration gameGeneration: Int) throws -> [PokemonSpecies] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if try availabilityCount(for: gameGeneration) > 0 {
            let prefix = trimmed.isEmpty ? nil : trimmed
            return try speciesFromAvailability(gameGeneration: gameGeneration, namePrefix: prefix)
        }

        guard !trimmed.isEmpty else {
            return try species(inGameGeneration: gameGeneration)
        }

        return try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, name, generation, base_hp, catch_rate, type1, type2
                FROM species
                WHERE generation <= ? AND name LIKE ? || '%'
                ORDER BY id
                """,
                arguments: [gameGeneration, trimmed]
            )
            return rows.map(Self.mapSpecies)
        }
    }

    func availabilityCount(for gameGeneration: Int) throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*) FROM species_game_availability
                WHERE game_generation = ?
                """,
                arguments: [gameGeneration]
            ) ?? 0
        }
    }

    func isSpeciesAvailable(_ speciesID: Int, inGameGeneration gameGeneration: Int) throws -> Bool {
        if try availabilityCount(for: gameGeneration) > 0 {
            return try dbQueue.read { db in
                try Int.fetchOne(
                    db,
                    sql: """
                    SELECT 1 FROM species_game_availability
                    WHERE species_id = ? AND game_generation = ?
                    LIMIT 1
                    """,
                    arguments: [speciesID, gameGeneration]
                ) != nil
            }
        }

        guard let species = try species(id: speciesID) else { return false }
        return species.generation <= gameGeneration
    }

    private func speciesFromAvailability(
        gameGeneration: Int,
        namePrefix: String?
    ) throws -> [PokemonSpecies] {
        try dbQueue.read { db in
            let rows: [Row]
            if let namePrefix, !namePrefix.isEmpty {
                rows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT s.id, s.name, s.generation, s.base_hp, s.catch_rate, s.type1, s.type2
                    FROM species s
                    INNER JOIN species_game_availability a ON a.species_id = s.id
                    WHERE a.game_generation = ? AND s.name LIKE ? || '%'
                    ORDER BY s.id
                    """,
                    arguments: [gameGeneration, namePrefix]
                )
            } else {
                rows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT s.id, s.name, s.generation, s.base_hp, s.catch_rate, s.type1, s.type2
                    FROM species s
                    INNER JOIN species_game_availability a ON a.species_id = s.id
                    WHERE a.game_generation = ?
                    ORDER BY s.id
                    """,
                    arguments: [gameGeneration]
                )
            }
            return rows.map(Self.mapSpecies)
        }
    }

    func species(for generation: Int) throws -> [PokemonSpecies] {
        try species(inGameGeneration: generation)
    }

    func search(name: String, generation: Int) throws -> [PokemonSpecies] {
        try search(name: name, inGameGeneration: generation)
    }

    func species(id: Int) throws -> PokemonSpecies? {
        try dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                SELECT id, name, generation, base_hp, catch_rate, type1, type2
                FROM species WHERE id = ?
                """,
                arguments: [id]
            ) else { return nil }
            return Self.mapSpecies(row)
        }
    }

    func effectiveCatchRate(speciesID: Int, gameKey: String) throws -> Int? {
        try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: """
                SELECT COALESCE(o.catch_rate, s.catch_rate)
                FROM species s
                LEFT JOIN game_catch_rate_overrides o
                  ON o.species_id = s.id AND o.game_key = ?
                WHERE s.id = ?
                """,
                arguments: [gameKey, speciesID]
            )
        }
    }

    nonisolated private static func mapSpecies(_ row: Row) -> PokemonSpecies {
        PokemonSpecies(
            id: row["id"],
            name: row["name"],
            generation: row["generation"],
            baseHP: row["base_hp"],
            catchRate: row["catch_rate"],
            type1: row["type1"],
            type2: row["type2"]
        )
    }
}
