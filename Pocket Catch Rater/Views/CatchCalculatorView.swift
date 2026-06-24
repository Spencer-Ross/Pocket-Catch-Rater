import SwiftUI

struct CatchCalculatorView: View {
    @Bindable var dataStore: PokemonDataStore

    @AppStorage("selectedCatchRuleSet") private var selectedRuleSetRaw = CatchRuleSet.gen1.rawValue
    @AppStorage("selectedGeneration") private var legacyGenerationRaw = 0

    @State private var inputs = CatchInputs()
    @State private var showPokemonPicker = false
    @State private var showBallConditions = false
    @State private var showStandardBallSkinPicker = false
    @State private var showSettings = false
    @State private var catchResult: CatchResult?

    private var selectedRuleSet: CatchRuleSet {
        get { CatchRuleSet.resolved(storedRaw: selectedRuleSetRaw) }
        nonmutating set { selectedRuleSetRaw = newValue.rawValue }
    }

    private var dataGeneration: PokemonGeneration {
        selectedRuleSet.representativeGeneration
    }

    private var availableBalls: [CatchBall] {
        CatchBall.pickerBalls(for: dataGeneration)
    }

    var body: some View {
        VStack(spacing: 0) {
            CompactResultsHeader(
                result: catchResult,
                species: inputs.species,
                ruleSet: Binding(
                    get: { selectedRuleSet },
                    set: { selectedRuleSet = $0 }
                ),
                level: Binding(
                    get: { inputs.level },
                    set: { inputs.level = $0 }
                ),
                onSpeciesTap: { showPokemonPicker = true },
                onLevelChange: { recalculate() },
                onRuleSetChange: selectRuleSet
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hpRemainingSection

                    if selectedRuleSet.isGen1 {
                        Toggle("Safari Zone", isOn: Binding(
                            get: { inputs.battleMode == .safari },
                            set: { inputs.battleMode = $0 ? .safari : .wild; recalculate() }
                        ))
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if inputs.battleMode == .safari && selectedRuleSet.isGen1 {
                        inputSection(title: "Safari Modifiers") {
                            Stepper("Rocks thrown: \(inputs.rocksThrown)", value: Binding(
                                get: { inputs.rocksThrown },
                                set: { inputs.rocksThrown = max(0, $0); recalculate() }
                            ), in: 0...10)
                            Stepper("Bait used: \(inputs.baitUsed)", value: Binding(
                                get: { inputs.baitUsed },
                                set: { inputs.baitUsed = max(0, $0); recalculate() }
                            ), in: 0...10)
                        }
                    } else {
                        inputSection(title: "Status") {
                            CompactStatusGrid(
                                selection: Binding(
                                    get: { inputs.status },
                                    set: { inputs.status = $0 }
                                ),
                                onChange: recalculate
                            )
                        }

                        if showsConditionsRow {
                            conditionsChips
                        }

                        inputSection(title: "Ball") {
                            SelectedCatchBallHeader(
                                name: inputs.displayedBallName,
                                spriteURL: inputs.displayedBallSpriteURL,
                                conditionControl: specialtyBallHeaderControl
                            )

                            if let bonusLabel = activeBallBonusLabel {
                                Text(bonusLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                            }

                            BallSelectionGrid(
                                balls: availableBalls,
                                selection: Binding(
                                    get: { inputs.catchBall },
                                    set: {
                                        inputs.catchBall = $0
                                        inputs.syncSpecialtyBallDefaults()
                                    }
                                ),
                                standardBallAppearance: Binding(
                                    get: { inputs.standardBallAppearance },
                                    set: { inputs.standardBallAppearance = $0 }
                                ),
                                onCustomizeStandardBall: {
                                    showStandardBallSkinPicker = true
                                },
                                onChange: recalculate
                            )

                            if showsBallConditions {
                                Button {
                                    showBallConditions = true
                                } label: {
                                    HStack {
                                        Label("Ball & battle conditions", systemImage: "slider.horizontal.3")
                                        Spacer()
                                        if activeConditionCount > 0 {
                                            Text("\(activeConditionCount) active")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(12)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle("Catch Rater")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SyncStatusIndicator(state: dataStore.syncState)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showPokemonPicker) {
            PokemonPickerView(
                dataStore: dataStore,
                gameGeneration: dataGeneration,
                selectedSpecies: Binding(
                    get: { inputs.species },
                    set: {
                        inputs.species = $0
                        applySpeciesDefaults(from: $0)
                        recalculate()
                    }
                )
            )
        }
        .sheet(isPresented: $showBallConditions) {
            BallConditionsSheet(
                inputs: $inputs,
                ruleSet: selectedRuleSet,
                onChange: recalculate
            )
        }
        .sheet(isPresented: $showStandardBallSkinPicker) {
            StandardBallSkinSheet(
                generation: dataGeneration,
                selection: Binding(
                    get: { inputs.standardBallAppearance },
                    set: { inputs.standardBallAppearance = $0 }
                )
            )
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(dataStore: dataStore)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSettings = false }
                        }
                    }
            }
        }
        .onAppear {
            migrateLegacyGenerationSelectionIfNeeded()
            inputs.generation = dataGeneration
            ensureValidBallSelection()
            recalculate()
            Task {
                await dataStore.ensureGameData(for: dataGeneration)
                await refreshDefaultSpeciesIfNeeded()
            }
        }
        .onChange(of: selectedRuleSetRaw) { _, _ in
            applyRuleSetChange()
            Task { await dataStore.ensureGameData(for: dataGeneration) }
        }
        .onChange(of: dataStore.syncState) { _, _ in
            recalculate()
        }
    }

    private var showsBallConditions: Bool {
        guard !selectedRuleSet.isGen1,
              inputs.battleMode != .safari,
              inputs.catchBall != .master else { return false }
        // Gen 2 uses a sheet for Level Ball (player level stepper), Lure Ball (fishing),
        // and Love Ball (same-gender toggle). Gen 3+: all conditions are inline/header.
        return selectedRuleSet.formulaFamily == .gen2
    }

    private var specialtyBallHeaderControl: SelectedCatchBallHeader.ConditionControl? {
        guard SpecialtyBallMath.isModernGen(ruleSet: selectedRuleSet) else { return nil }

        if SpecialtyBallMath.showsTurnPicker(for: inputs.catchBall, ruleSet: selectedRuleSet) {
            return .turnPicker(
                turn: Binding(
                    get: { inputs.battleTurn },
                    set: {
                        inputs.battleTurn = max(1, min(30, $0))
                        recalculate()
                    }
                ),
                onChange: recalculate
            )
        }

        if SpecialtyBallMath.showsPlayerLevelPicker(for: inputs.catchBall, ruleSet: selectedRuleSet) {
            return .levelPicker(
                level: Binding(
                    get: { inputs.playerLevel },
                    set: {
                        inputs.playerLevel = min(100, max(1, $0))
                        recalculate()
                    }
                ),
                label: "Your Level",
                sheetTitle: "Your Pokémon Level",
                onChange: recalculate
            )
        }

        guard SpecialtyBallMath.showsConditionToggle(for: inputs.catchBall, ruleSet: selectedRuleSet),
              let label = SpecialtyBallMath.toggleLabel(for: inputs.catchBall) else {
            return nil
        }

        switch inputs.catchBall {
        case .love:
            return .toggle(
                label: label,
                isOn: Binding(
                    get: { inputs.loveBallOppositeGender },
                    set: {
                        inputs.loveBallOppositeGender = $0
                        recalculate()
                    }
                )
            )
        case .moon:
            return .toggle(
                label: label,
                isOn: Binding(
                    get: { inputs.moonBallBonusActive },
                    set: {
                        inputs.moonBallBonusActive = $0
                        recalculate()
                    }
                )
            )
        case .fast:
            return .toggle(
                label: label,
                isOn: Binding(
                    get: { inputs.fastBallBonusActive },
                    set: {
                        inputs.fastBallBonusActive = $0
                        recalculate()
                    }
                ),
                isEnabled: inputs.species?.baseSpeed != nil
            )
        case .lure:
            return .toggle(
                label: label,
                isOn: Binding(
                    get: { inputs.isFishing },
                    set: {
                        inputs.isFishing = $0
                        recalculate()
                    }
                )
            )
        case .dive:
            return .toggle(
                label: label,
                isOn: Binding(
                    get: { inputs.isWaterTerrain },
                    set: {
                        inputs.isWaterTerrain = $0
                        recalculate()
                    }
                )
            )
        case .repeatBall:
            return .toggle(
                label: label,
                isOn: Binding(
                    get: { inputs.isRepeatRegistered },
                    set: {
                        inputs.isRepeatRegistered = $0
                        recalculate()
                    }
                )
            )
        case .dusk:
            return .toggle(
                label: label,
                isOn: Binding(
                    get: { inputs.isDarkTerrain },
                    set: {
                        inputs.isDarkTerrain = $0
                        recalculate()
                    }
                )
            )
        case .quick:
            return .toggle(
                label: label,
                isOn: Binding(
                    get: { inputs.quickBallFirstTurn },
                    set: {
                        inputs.quickBallFirstTurn = $0
                        recalculate()
                    }
                )
            )
        default:
            return nil
        }
    }

    private var activeBallBonusLabel: String? {
        if let heavyBallLabel = heavyBallBonusLabel {
            return heavyBallLabel
        }

        if inputs.catchBall == .fast,
           inputs.species?.baseSpeed == nil,
           selectedRuleSet.formulaFamily == .gen6to7 || selectedRuleSet.formulaFamily == .gen8to9 {
            return "Fast Ball bonus needs species speed (sync details)"
        }

        return SpecialtyBallMath.bonusLabel(
            ball: inputs.catchBall,
            ruleSet: selectedRuleSet,
            context: inputs.ballContext,
            species: inputs.species
        )
    }

    private var heavyBallBonusLabel: String? {
        guard inputs.catchBall == .heavy else { return nil }
        guard let weightKg = inputs.species?.weightKg else {
            return "Heavy Ball bonus needs species weight (sync details)"
        }
        return HeavyBallMath.info(weightKg: weightKg, ruleSet: selectedRuleSet).label
    }

    private var activeConditionCount: Int {
        var count = 0
        if selectedRuleSet.formulaFamily != .gen8to9 {
            if inputs.isFishing { count += 1 }
            if inputs.isWaterTerrain { count += 1 }
            if inputs.isDarkTerrain { count += 1 }
            if inputs.isRepeatRegistered { count += 1 }
            if inputs.battleTurn != 1 { count += 1 }
            if inputs.hasWaterOrBugType { count += 1 }
        }
        if selectedRuleSet.formulaFamily != .gen8to9, inputs.playerLevel != 50 { count += 1 }
        return count
    }

    @ViewBuilder
    private var hpRemainingSection: some View {
        let showsHPBar = inputs.battleMode != .safari || selectedRuleSet.isGen1

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("HP Remaining")
                    .font(.headline)

                Spacer()

                Text(showsHPBar ? "\(Int(inputs.hpPercent))%" : "100%")
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(showsHPBar ? .primary : .secondary)
            }

            if showsHPBar {
                HPBarSlider(hpPercent: Binding(
                    get: { inputs.hpPercent },
                    set: { inputs.hpPercent = $0; recalculate() }
                ))
            }
        }
    }

    // Gen 5–7 only: Gen 8/9 docs confirm G is never triggered in those games.
    private var showsGrassToggle: Bool {
        let gen = selectedRuleSet.representativeGeneration.rawValue
        return gen >= 5 && gen <= 7
    }

    private var showsPokedexPicker: Bool {
        selectedRuleSet.representativeGeneration.rawValue >= 5 && inputs.isThickGrass
    }

    // O-Power (Gen 6) and Roto Catch (Gen 7 USUM) both factor into the capture formula.
    // Sun/Moon has no catch power, but the picker's "None" default handles that correctly.
    private var showsOPowerPicker: Bool {
        selectedRuleSet.formulaFamily == .gen6to7
    }

    // Gen 9: Capture Power from sandwiches (D modifier).
    private var showsCapturePowerPicker: Bool {
        selectedRuleSet == .gen9
    }

    // Gen 9: catching the Pokémon off-guard doubles D.
    private var showsOffGuardToggle: Bool {
        selectedRuleSet == .gen9
    }

    // Gen 9: badge count affects the BP penalty multiplier.
    private var showsBadgePicker: Bool {
        selectedRuleSet == .gen9
    }

    private var showsConditionsRow: Bool {
        showsGrassToggle || showsOPowerPicker || showsCapturePowerPicker || showsOffGuardToggle || showsBadgePicker
    }

    private var badgeChipLabel: String {
        "\(inputs.badgeCount) badge\(inputs.badgeCount == 1 ? "" : "s")"
    }

    private var oPowerChipLabel: String {
        if inputs.oPowerBonus == 1 {
            return selectedRuleSet == .gen9 ? "Capture Power" : "O-Power"
        }
        if selectedRuleSet == .gen9 {
            return Self.capturePowerOptions.first(where: { $0.value == inputs.oPowerBonus })?.label ?? "Capture Power"
        }
        return Self.oPowerOptions.first(where: { $0.value == inputs.oPowerBonus })?.label ?? "O-Power"
    }

    private var dexChipLabel: String {
        Self.dexBuckets.first(where: { $0.value == inputs.pokedexCaught })?.label ?? "Pokédex"
    }

    @ViewBuilder
    private var conditionsChips: some View {
        HStack(spacing: 8) {
            if showsGrassToggle {
                Button {
                    inputs.isThickGrass.toggle()
                    recalculate()
                } label: {
                    conditionChip(
                        symbol: inputs.isThickGrass ? "leaf.fill" : "leaf",
                        label: "Dark grass",
                        isActive: inputs.isThickGrass
                    )
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: inputs.isThickGrass)
            }

            if showsOPowerPicker {
                Menu {
                    ForEach(Self.oPowerOptions, id: \.value) { option in
                        Button {
                            inputs.oPowerBonus = option.value
                            recalculate()
                        } label: {
                            if inputs.oPowerBonus == option.value {
                                Label(option.label, systemImage: "checkmark")
                            } else {
                                Text(option.label)
                            }
                        }
                    }
                } label: {
                    conditionChip(
                        symbol: "bolt.fill",
                        label: oPowerChipLabel,
                        isActive: inputs.oPowerBonus > 1
                    )
                }
                .animation(.easeInOut(duration: 0.15), value: inputs.oPowerBonus)
            }

            if showsCapturePowerPicker {
                Menu {
                    ForEach(Self.capturePowerOptions, id: \.value) { option in
                        Button {
                            inputs.oPowerBonus = option.value
                            recalculate()
                        } label: {
                            if inputs.oPowerBonus == option.value {
                                Label(option.label, systemImage: "checkmark")
                            } else {
                                Text(option.label)
                            }
                        }
                    }
                } label: {
                    conditionChip(
                        symbol: "fork.knife",
                        label: oPowerChipLabel,
                        isActive: inputs.oPowerBonus > 1
                    )
                }
                .animation(.easeInOut(duration: 0.15), value: inputs.oPowerBonus)
            }

            if showsBadgePicker {
                let hasPenalty = inputs.badgeCount < 8
                Menu {
                    ForEach(0...8, id: \.self) { count in
                        Button {
                            inputs.badgeCount = count
                            recalculate()
                        } label: {
                            if inputs.badgeCount == count {
                                Label("\(count) badge\(count == 1 ? "" : "s")", systemImage: "checkmark")
                            } else {
                                Text("\(count) badge\(count == 1 ? "" : "s")")
                            }
                        }
                    }
                } label: {
                    conditionChip(
                        symbol: "shield",
                        label: badgeChipLabel,
                        isActive: hasPenalty
                    )
                }
                .animation(.easeInOut(duration: 0.15), value: inputs.badgeCount)
            }

            if showsOffGuardToggle {
                Button {
                    inputs.isOffGuard.toggle()
                    recalculate()
                } label: {
                    HStack(spacing: 5) {
                        Text("😱")
                            .font(.caption)
                        Text("Off-guard")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(inputs.isOffGuard ? .white : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(inputs.isOffGuard ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: inputs.isOffGuard)
            }

            if showsPokedexPicker {
                Menu {
                    ForEach(Self.dexBuckets, id: \.value) { bucket in
                        Button {
                            inputs.pokedexCaught = bucket.value
                            recalculate()
                        } label: {
                            if inputs.pokedexCaught == bucket.value {
                                Label(bucket.label, systemImage: "checkmark")
                            } else {
                                Text(bucket.label)
                            }
                        }
                    }
                } label: {
                    conditionChip(
                        symbol: "book.closed.fill",
                        label: dexChipLabel,
                        isActive: true
                    )
                }
            }

            Spacer()
        }
    }

    private func conditionChip(symbol: String, label: String, isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
            Text(label)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(isActive ? .white : .secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isActive ? Color.accentColor : Color(.secondarySystemGroupedBackground))
        .clipShape(Capsule())
    }

    private static let oPowerOptions: [(label: String, value: Double)] = [
        ("None",        1.0),
        ("Lv.1 (1.5×)", 1.5),
        ("Lv.2 (2.0×)", 2.0),
        ("Lv.3+ (2.5×)", 2.5),
    ]

    // Gen 9 sandwich Capture Power levels (D modifier).
    private static let capturePowerOptions: [(label: String, value: Double)] = [
        ("None",         1.0),
        ("Lv.1 (1.1×)",  1.1),
        ("Lv.2 (1.25×)", 1.25),
        ("Lv.3 (2.0×)",  2.0),
    ]

    private static let dexBuckets: [(label: String, value: Int)] = [
        ("0–30",    10),
        ("31–150",  100),
        ("151–300", 200),
        ("301–450", 350),
        ("451–600", 500),
        ("601+",    650),
    ]


    @ViewBuilder
    private func inputSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func migrateLegacyGenerationSelectionIfNeeded() {
        if selectedRuleSetRaw == "gen6to7" {
            selectedRuleSetRaw = CatchRuleSet.gen7.rawValue
        }
        guard legacyGenerationRaw >= 1, legacyGenerationRaw <= 9 else { return }
        selectedRuleSetRaw = CatchRuleSet.migrated(fromLegacyGenerationRaw: legacyGenerationRaw).rawValue
        legacyGenerationRaw = 0
    }

    private func applyRuleSetChange() {
        inputs.generation = dataGeneration
        inputs.battleMode = .wild
        inputs.rocksThrown = 0
        inputs.baitUsed = 0
        inputs.oPowerBonus = 1
        inputs.isOffGuard = false
        inputs.badgeCount = 8

        if let species = inputs.species,
           (try? dataStore.isSpeciesAvailable(species, in: dataGeneration)) == false {
            inputs.species = PokemonSpecies.fallbackPikachu
            applySpeciesDefaults(from: inputs.species)
        } else if inputs.species == nil {
            inputs.species = PokemonSpecies.fallbackPikachu
            applySpeciesDefaults(from: inputs.species)
        }

        ensureValidBallSelection()
        inputs.syncSpecialtyBallDefaults()
        recalculate()
    }

    private func selectRuleSet(_ ruleSet: CatchRuleSet) {
        selectedRuleSet = ruleSet
        applyRuleSetChange()
        Task { await dataStore.ensureGameData(for: ruleSet.representativeGeneration) }
    }

    private func ensureValidBallSelection() {
        inputs.normalizeStandardBallSelection(for: dataGeneration)

        let balls = availableBalls
        guard !balls.isEmpty else { return }

        if balls.contains(inputs.catchBall) {
            return
        }

        inputs.catchBall = balls.first ?? .poke
    }

    private func applySpeciesDefaults(from species: PokemonSpecies?) {
        guard let species else { return }
        inputs.hasWaterOrBugType = species.hasWaterOrBugType
        inputs.syncSpecialtyBallDefaults()
    }

    private func refreshDefaultSpeciesIfNeeded() async {
        guard inputs.species?.id == PokemonSpecies.defaultSpeciesID
            || inputs.species == nil else {
            if inputs.species?.hasCompleteDetails == false,
               let speciesID = inputs.species?.id,
               let detailed = try? await dataStore.ensureSpeciesDetails(for: speciesID) {
                inputs.species = detailed
                applySpeciesDefaults(from: detailed)
                recalculate()
            }
            return
        }

        if let cached = try? dataStore.species(id: PokemonSpecies.defaultSpeciesID), cached.hasCompleteDetails {
            inputs.species = cached
            applySpeciesDefaults(from: cached)
            recalculate()
            return
        }

        if let detailed = try? await dataStore.ensureSpeciesDetails(for: PokemonSpecies.defaultSpeciesID) {
            inputs.species = detailed
            applySpeciesDefaults(from: detailed)
            recalculate()
        }
    }

    private func recalculate() {
        inputs.generation = dataGeneration
        ensureValidBallSelection()

        guard let species = inputs.species, species.hasDetails else {
            catchResult = nil
            return
        }

        let calculator = CatchCalculatorEngine.calculator(for: selectedRuleSet)
        catchResult = calculator.calculateWithEstimatedHP(
            inputs: inputs,
            catchRate: species.catchRate,
            baseHP: species.baseHP
        )
    }
}
