import Foundation

/// Species whose evolution line includes a Moon Stone evolution.
enum MoonBallEligibility {
    /// HGSS (Gen III/IV): bonus applies to every member of a Moon Stone family.
    static let hgssEligibleSpeciesIDs: Set<Int> = [
        29, 30, 31,   // Nidoran♀, Nidorina, Nidoqueen
        32, 33, 34,   // Nidoran♂, Nidorino, Nidoking
        173, 35, 36,  // Cleffa, Clefairy, Clefable
        174, 39, 40,  // Igglybuff, Jigglypuff, Wigglytuff
        300, 301,     // Skitty, Delcatty
        517, 518,     // Munna, Musharna
    ]

    /// Gen VI+: bonus applies only to the Pokémon that directly evolve via Moon Stone.
    static let modernEligibleSpeciesIDs: Set<Int> = [
        30,  // Nidorina  → Nidoqueen
        33,  // Nidorino  → Nidoking
        35,  // Clefairy  → Clefable
        39,  // Jigglypuff → Wigglytuff
        300, // Skitty    → Delcatty
        517, // Munna     → Musharna
    ]

    /// For Gen III/IV (HGSS) — entire family qualifies.
    static func isEligibleHGSS(speciesID: Int) -> Bool {
        hgssEligibleSpeciesIDs.contains(speciesID)
    }

    /// For Gen VI+ — only direct Moon Stone evolvers qualify.
    static func isEligibleModern(speciesID: Int) -> Bool {
        modernEligibleSpeciesIDs.contains(speciesID)
    }
}

enum FastBallEligibility {
    static let minimumBaseSpeed = 100

    static func isEligible(baseSpeed: Int?) -> Bool {
        guard let baseSpeed else { return false }
        return baseSpeed >= minimumBaseSpeed
    }
}

/// Gen 2 Fast Ball only gives 4× for the first three flee-capable species in the data tables:
/// Grimer (#88), Tangela (#114), Magnemite (#81). All others get no bonus.
/// (Intended to cover all flee-capable Pokémon, but only these three were checked due to a bug.)
enum Gen2FastBallEligibility {
    static let eligibleSpeciesIDs: Set<Int> = [81, 88, 114]

    static func isEligible(speciesID: Int) -> Bool {
        eligibleSpeciesIDs.contains(speciesID)
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
        case .lure: "Fishing"
        case .dive: "In Water"
        case .repeatBall: "Caught"
        case .dusk: "Night/Cave"
        case .quick: "First Turn"
        default: nil
        }
    }

    /// True for Gen 3+ — these gens all use modern ball mechanics with per-ball header controls.
    static func isModernGen(ruleSet: CatchRuleSet) -> Bool {
        ruleSet.formulaFamily != .gen1 && ruleSet.formulaFamily != .gen2
    }

    static func showsTurnPicker(for ball: CatchBall, ruleSet: CatchRuleSet) -> Bool {
        isModernGen(ruleSet: ruleSet) && ball == .timer
    }

    static func showsPlayerLevelPicker(for ball: CatchBall, ruleSet: CatchRuleSet) -> Bool {
        isModernGen(ruleSet: ruleSet) && ball == .level
    }

    static func showsConditionToggle(for ball: CatchBall, ruleSet: CatchRuleSet) -> Bool {
        isModernGen(ruleSet: ruleSet) && toggleLabel(for: ball) != nil
    }

    static func showsHeaderConditionControl(for ball: CatchBall, ruleSet: CatchRuleSet) -> Bool {
        showsConditionToggle(for: ball, ruleSet: ruleSet)
            || showsTurnPicker(for: ball, ruleSet: ruleSet)
            || showsPlayerLevelPicker(for: ball, ruleSet: ruleSet)
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
        context: BallContext,
        species: PokemonSpecies?
    ) -> String? {
        let gen = ruleSet.representativeGeneration
        let isGen3to4 = ruleSet.formulaFamily == .gen3to4

        // Gen 2 has its own apricorn ball mechanics
        if ruleSet.formulaFamily == .gen2 {
            return gen2BonusLabel(ball: ball, context: context, species: species)
        }

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
            // Gen 3–4 (HGSS): apricorn balls modify the species catch rate C.
            // Gen 6+: B-multiplier (same values as Gen 8/9; Dream Ball only exists in Gen 8+).
            if isGen3to4 {
                return gen3to4ApricornBonusLabel(ball: ball, context: context, species: species)
            }
            guard ruleSet.formulaFamily == .gen6to7 || ruleSet.formulaFamily == .gen8to9 else { return nil }
            return gen8ApricornBonusLabel(ball: ball, context: context, species: species)
        case .lure:
            guard isModernGen(ruleSet: ruleSet) else { return nil }
            if isGen3to4 {
                // Lure Ball modifies C by 3× in HGSS when fishing.
                guard context.isFishing else { return nil }
                return "Lure Ball: 3× species catch rate (fishing)"
            }
            let mult = ball.modernBallBonus(generation: gen, context: context)
            guard mult > 1 else { return nil }
            // Gen 9: no fishing; condition is being in or above water.
            let lureCondition = gen == .gen9 ? "near water" : "fishing"
            return "Lure Ball: \(formatMultiplier(mult)) catch rate (\(lureCondition))"
        case .dive:
            guard isModernGen(ruleSet: ruleSet) else { return nil }
            let mult = ball.modernBallBonus(generation: gen, context: context)
            guard mult > 1 else { return nil }
            return "Dive Ball: \(formatMultiplier(mult)) catch rate (in water)"
        case .repeatBall:
            guard isModernGen(ruleSet: ruleSet) else { return nil }
            let mult = ball.modernBallBonus(generation: gen, context: context)
            guard mult > 1 else { return nil }
            return "Repeat Ball: \(formatMultiplier(mult)) catch rate (already caught)"
        case .dusk:
            guard isModernGen(ruleSet: ruleSet) else { return nil }
            let mult = ball.modernBallBonus(generation: gen, context: context)
            guard mult > 1 else { return nil }
            return "Dusk Ball: \(formatMultiplier(mult)) catch rate (night or cave)"
        case .timer:
            guard isModernGen(ruleSet: ruleSet) else { return nil }
            let mult = timerBallMultiplier(turn: context.battleTurn, ruleSet: ruleSet)
            guard mult > 1 else { return nil }
            return "Timer Ball: \(formatMultiplier(mult)) catch rate (turn \(context.battleTurn))"
        case .quick:
            guard isModernGen(ruleSet: ruleSet) else { return nil }
            let mult = ball.modernBallBonus(generation: gen, context: context)
            guard mult > 1 else { return nil }
            return "Quick Ball: \(formatMultiplier(mult)) catch rate (first turn)"
        case .net:
            guard isModernGen(ruleSet: ruleSet) else { return nil }
            return netBallBonusLabel(generation: gen, context: context, species: species)
        case .nest:
            guard isModernGen(ruleSet: ruleSet) else { return nil }
            return nestBallBonusLabel(context: context, ruleSet: ruleSet)
        case .level:
            guard isModernGen(ruleSet: ruleSet) else { return nil }
            if isGen3to4 {
                return gen3to4LevelBallBonusLabel(context: context)
            }
            return levelBallBonusLabel(context: context)
        default:
            return nil
        }
    }

    /// Gen 8–9 Timer Ball multiplier (increment formula).
    static func timerBallMultiplier(turn: Int) -> Double {
        let turns = max(1, turn)
        let increment = 1229.0 / 4096.0
        return min(4, 1 + Double(turns - 1) * increment)
    }

    /// Generation-aware Timer Ball multiplier.
    /// Gen 3–4: B = floor((turn + 10) / 10), max 4.
    /// Gen 8–9: increment formula.
    static func timerBallMultiplier(turn: Int, ruleSet: CatchRuleSet) -> Double {
        if ruleSet.formulaFamily == .gen3to4 {
            return Double(min(4, (turn + 10) / 10))
        }
        return timerBallMultiplier(turn: turn)
    }

    static func levelBallMultiplier(playerLevel: Int, targetLevel: Int) -> Double {
        if playerLevel / 4 >= targetLevel { return 8 }
        if playerLevel / 2 >= targetLevel { return 4 }
        if playerLevel > targetLevel { return 2 }
        return 1
    }

    /// Gen 8–9 Nest Ball multiplier: (41 − level) / 10, minimum 1.
    static func nestBallMultiplier(targetLevel: Int) -> Double {
        if targetLevel < 30 {
            return max(1, Double(41 - targetLevel) / 10)
        }
        return 1
    }

    /// Generation-aware Nest Ball multiplier.
    /// Gen 3–4: B = floor((40 − level) / 10), minimum 1.
    static func nestBallMultiplier(targetLevel: Int, ruleSet: CatchRuleSet) -> Double {
        if ruleSet.formulaFamily == .gen3to4 {
            return Double(max(1, (40 - targetLevel) / 10))
        }
        return nestBallMultiplier(targetLevel: targetLevel)
    }

    private static func gen8ApricornBonusLabel(ball: CatchBall, context: BallContext, species: PokemonSpecies?) -> String? {
        switch ball {
        case .love:
            guard context.loveBallOppositeGender else { return nil }
            return "Love Ball: \(formatMultiplier(gen8LoveBallMultiplier)) catch rate (opposite gender)"
        case .moon:
            guard context.moonBallBonusActive else { return nil }
            return "Moon Ball: \(formatMultiplier(gen8MoonBallMultiplier)) catch rate (Moon Stone evolution)"
        case .fast:
            guard context.fastBallBonusActive else { return nil }
            if let baseSpeed = species?.baseSpeed {
                return "Fast Ball: \(formatMultiplier(gen8FastBallMultiplier)) catch rate (base Speed \(baseSpeed))"
            }
            return "Fast Ball: \(formatMultiplier(gen8FastBallMultiplier)) catch rate (base Speed ≥ \(FastBallEligibility.minimumBaseSpeed))"
        case .dream:
            guard context.status == .sleep else { return nil }
            return "Dream Ball: \(formatMultiplier(gen8DreamBallMultiplier)) catch rate (asleep)"
        default:
            return nil
        }
    }

    private static func netBallBonusLabel(generation: PokemonGeneration, context: BallContext, species: PokemonSpecies?) -> String? {
        guard let species else { return nil }

        let types = [species.type1, species.type2].compactMap { $0?.capitalized }
        guard !types.isEmpty else {
            return "Net Ball bonus needs species types (sync details)"
        }

        let typeLabel = types.joined(separator: "/")
        if context.hasWaterOrBugType {
            let mult = CatchBall.net.modernBallBonus(generation: generation, context: context)
            return "Net Ball: \(formatMultiplier(mult)) catch rate (\(typeLabel))"
        }

        return "Net Ball: no bonus (\(typeLabel) — not Water or Bug)"
    }

    private static func nestBallBonusLabel(context: BallContext, ruleSet: CatchRuleSet = .gen9) -> String? {
        let targetLevel = context.targetLevel
        let multiplier = nestBallMultiplier(targetLevel: targetLevel, ruleSet: ruleSet)

        if multiplier > 1 {
            return "Nest Ball: \(formatMultiplier(multiplier)) catch rate (target level \(targetLevel))"
        }

        return "Nest Ball: no bonus (target level \(targetLevel) — need below 30)"
    }

    // MARK: - Gen 3–4 (HGSS) apricorn ball labels

    private static func gen3to4ApricornBonusLabel(ball: CatchBall, context: BallContext, species: PokemonSpecies?) -> String? {
        switch ball {
        case .love:
            if context.loveBallOppositeGender {
                return "Love Ball: 8× species catch rate (opposite gender)"
            }
            return "Love Ball: no bonus (need opposite gender)"
        case .moon:
            if context.moonBallBonusActive {
                return "Moon Ball: 4× species catch rate (Moon Stone evolution)"
            }
            return "Moon Ball: no bonus (not a Moon Stone evolution)"
        case .fast:
            if context.fastBallBonusActive {
                if let baseSpeed = species?.baseSpeed {
                    return "Fast Ball: 4× species catch rate (base Speed \(baseSpeed))"
                }
                return "Fast Ball: 4× species catch rate (base Speed ≥ \(FastBallEligibility.minimumBaseSpeed))"
            }
            return "Fast Ball: no bonus (base Speed below \(FastBallEligibility.minimumBaseSpeed))"
        default:
            return nil
        }
    }

    private static func gen3to4LevelBallBonusLabel(context: BallContext) -> String? {
        let player = context.playerLevel
        let target = context.targetLevel
        // HGSS uses strict > (integer division), matching the game source.
        if player / 4 > target {
            return "Level Ball: 8× species catch rate (Lv. \(player) vs Lv. \(target))"
        }
        if player / 2 > target {
            return "Level Ball: 4× species catch rate (Lv. \(player) vs Lv. \(target))"
        }
        if player > target {
            return "Level Ball: 2× species catch rate (Lv. \(player) vs Lv. \(target))"
        }
        return "Level Ball: no bonus (Lv. \(player) vs Lv. \(target) — not higher level)"
    }

    private static func levelBallBonusLabel(context: BallContext) -> String? {
        let playerLevel = context.playerLevel
        let targetLevel = context.targetLevel
        let multiplier = levelBallMultiplier(playerLevel: playerLevel, targetLevel: targetLevel)

        if multiplier > 1 {
            return "Level Ball: \(formatMultiplier(multiplier)) catch rate (Lv. \(playerLevel) vs Lv. \(targetLevel))"
        }

        return "Level Ball: no bonus (Lv. \(playerLevel) vs Lv. \(targetLevel) — not high enough)"
    }

    // MARK: - Gen 2 bonus labels

    private static func gen2BonusLabel(ball: CatchBall, context: BallContext, species: PokemonSpecies?) -> String? {
        switch ball {
        case .love:
            if context.loveBallSameGender {
                return "Love Ball: 8× catch rate (same gender — Gen II bonus)"
            }
            return "Love Ball: no bonus (need same species, same gender)"
        case .fast:
            if context.gen2FastBallActive {
                return "Fast Ball: 4× catch rate (Grimer/Tangela/Magnemite — Gen II bug)"
            }
            return "Fast Ball: no bonus (only Grimer, Tangela, Magnemite in Gen II)"
        case .lure:
            if context.isFishing {
                return "Lure Ball: 3× catch rate (fishing)"
            }
            return nil
        case .moon:
            // Gen 2 Moon Ball is always bugged — no real Pokémon triggers the bonus
            return "Moon Ball: no bonus (bugged in Gen II — never activates)"
        case .level:
            return gen2LevelBallLabel(context: context)
        default:
            return nil
        }
    }

    private static func gen2LevelBallLabel(context: BallContext) -> String? {
        let player = context.playerLevel
        let target = context.targetLevel
        // Level Ball in Gen 2 skips the HP formula (X = C directly)
        if player / 4 >= target {
            return "Level Ball: 8× catch rate + skips HP formula (Lv. \(player) vs Lv. \(target))"
        }
        if player / 2 >= target {
            return "Level Ball: 4× catch rate + skips HP formula (Lv. \(player) vs Lv. \(target))"
        }
        if player > target {
            return "Level Ball: 2× catch rate + skips HP formula (Lv. \(player) vs Lv. \(target))"
        }
        return "Level Ball: 1× catch rate + skips HP formula (Lv. \(player) vs Lv. \(target))"
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
