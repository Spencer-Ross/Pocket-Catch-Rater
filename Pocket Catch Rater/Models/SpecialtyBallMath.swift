import Foundation

/// Species whose evolution line includes a Moon Stone evolution (Gen 8–9 Moon Ball bonus).
/// Add new national dex IDs here when future games introduce Moon Stone evolutions.
enum MoonBallEligibility {
    static let eligibleSpeciesIDs: Set<Int> = [
        29, 30, 31,   // Nidoran♀, Nidorina, Nidoqueen
        32, 33, 34,   // Nidoran♂, Nidorino, Nidoking
        173, 35, 36,  // Cleffa, Clefairy, Clefable
        174, 39, 40,  // Igglybuff, Jigglypuff, Wigglytuff
        300, 301,     // Skitty, Delcatty
        517, 518,     // Munna, Musharna
    ]

    static func isEligible(speciesID: Int) -> Bool {
        eligibleSpeciesIDs.contains(speciesID)
    }
}

enum FastBallEligibility {
    static let minimumBaseSpeed = 100

    static func isEligible(baseSpeed: Int?) -> Bool {
        guard let baseSpeed else { return false }
        return baseSpeed >= minimumBaseSpeed
    }
}

/// National dex IDs for Ultra Beasts (Gen 7–9 Beast Ball bonus).
/// Add new IDs here when future games introduce additional Ultra Beasts.
enum UltraBeastEligibility {
    static let speciesIDs: Set<Int> = Set(793...799).union(Set(803...806))

    static func isUltraBeast(speciesID: Int) -> Bool {
        speciesIDs.contains(speciesID)
    }
}

enum SpecialtyBallMath {
    static let gen8LoveBallMultiplier = 8.0
    static let gen8MoonBallMultiplier = 4.0
    static let gen8FastBallMultiplier = 4.0
    static let gen8DreamBallMultiplier = 4.0
    static let beastBallUltraBeastMultiplier = 5.0
    static let beastBallPenaltyMultiplier = 410.0 / 4096.0

    static func toggleLabel(for ball: CatchBall) -> String? {
        switch ball {
        case .love: "Opposite Gender"
        case .moon: "Moon Stone"
        case .fast: "Speed ≥ 100"
        default: nil
        }
    }

    static func showsConditionToggle(for ball: CatchBall, ruleSet: CatchRuleSet) -> Bool {
        ruleSet.formulaFamily == .gen8to9 && toggleLabel(for: ball) != nil
    }

    static func beastBallBonus(isUltraBeast: Bool) -> Double {
        isUltraBeast ? beastBallUltraBeastMultiplier : beastBallPenaltyMultiplier
    }

    static func showsBeastBallEffect(for ruleSet: CatchRuleSet) -> Bool {
        ruleSet.representativeGeneration.rawValue >= 7
    }

    static func bonusLabel(
        ball: CatchBall,
        ruleSet: CatchRuleSet,
        loveOppositeGender: Bool,
        moonBonusActive: Bool,
        fastBonusActive: Bool,
        status: StatusCondition,
        species: PokemonSpecies?
    ) -> String? {
        switch ball {
        case .beast:
            guard showsBeastBallEffect(for: ruleSet), let species else { return nil }
            let isUltraBeast = UltraBeastEligibility.isUltraBeast(speciesID: species.id)
            let multiplier = beastBallBonus(isUltraBeast: isUltraBeast)
            if isUltraBeast {
                return "Beast Ball: \(formatMultiplier(multiplier)) catch rate (Ultra Beast)"
            }
            return "Beast Ball: \(formatPenaltyMultiplier(multiplier)) catch rate (not an Ultra Beast)"
        case .love, .moon, .fast, .dream:
            guard ruleSet.formulaFamily == .gen8to9 else { return nil }
            return gen8BonusLabel(
                ball: ball,
                loveOppositeGender: loveOppositeGender,
                moonBonusActive: moonBonusActive,
                fastBonusActive: fastBonusActive,
                status: status,
                species: species
            )
        default:
            return nil
        }
    }

    private static func gen8BonusLabel(
        ball: CatchBall,
        loveOppositeGender: Bool,
        moonBonusActive: Bool,
        fastBonusActive: Bool,
        status: StatusCondition,
        species: PokemonSpecies?
    ) -> String? {
        switch ball {
        case .love:
            guard loveOppositeGender else { return nil }
            return "Love Ball: \(formatMultiplier(gen8LoveBallMultiplier)) catch rate (opposite gender)"
        case .moon:
            guard moonBonusActive else { return nil }
            return "Moon Ball: \(formatMultiplier(gen8MoonBallMultiplier)) catch rate (Moon Stone evolution)"
        case .fast:
            guard fastBonusActive else { return nil }
            if let baseSpeed = species?.baseSpeed {
                return "Fast Ball: \(formatMultiplier(gen8FastBallMultiplier)) catch rate (base Speed \(baseSpeed))"
            }
            return "Fast Ball: \(formatMultiplier(gen8FastBallMultiplier)) catch rate (base Speed ≥ \(FastBallEligibility.minimumBaseSpeed))"
        case .dream:
            guard status == .sleep else { return nil }
            return "Dream Ball: \(formatMultiplier(gen8DreamBallMultiplier)) catch rate (asleep)"
        default:
            return nil
        }
    }

    private static func formatPenaltyMultiplier(_ value: Double) -> String {
        if value < 1 {
            return String(format: "%.2f×", value)
        }
        return formatMultiplier(value)
    }

    private static func formatMultiplier(_ value: Double) -> String {
        value == floor(value) ? "\(Int(value))×" : String(format: "%.1f×", value)
    }
}
