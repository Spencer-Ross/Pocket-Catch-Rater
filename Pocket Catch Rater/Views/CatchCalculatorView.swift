import SwiftUI

struct CatchCalculatorView: View {
    @Bindable var dataStore: PokemonDataStore

    @AppStorage("selectedGeneration") private var selectedGenerationRaw = PokemonGeneration.gen1.rawValue

    @State private var inputs = CatchInputs()
    @State private var showPokemonPicker = false
    @State private var showBallPicker = false
    @State private var showBallConditions = false
    @State private var showSettings = false
    @State private var catchResult: CatchResult?

    private var selectedGeneration: PokemonGeneration {
        get { PokemonGeneration(rawValue: selectedGenerationRaw) ?? .gen1 }
        nonmutating set { selectedGenerationRaw = newValue.rawValue }
    }

    private var availableBalls: [CatchBall] {
        CatchBall.balls(for: selectedGeneration).filter { $0 != .safari }
    }

    var body: some View {
        VStack(spacing: 0) {
            CompactResultsHeader(
                result: catchResult,
                species: inputs.species,
                generation: selectedGeneration
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    inputSection(title: "Generation") {
                        GenerationChipRow(selection: Binding(
                            get: { selectedGeneration },
                            set: { selectedGeneration = $0 }
                        )) { selectGeneration($0) }
                    }

                    inputSection(title: "Pokémon") {
                        Button {
                            showPokemonPicker = true
                        } label: {
                            HStack(spacing: 12) {
                                if let species = inputs.species {
                                    RemoteSpriteImage(url: species.spriteURL, size: 40)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Species")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(inputs.species?.displayName ?? "Choose…")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(inputs.species == nil ? .secondary : .primary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        LevelWheelPicker(level: Binding(
                            get: { inputs.level },
                            set: { inputs.level = $0 }
                        )) {
                            recalculate()
                        }

                        if inputs.battleMode != .safari || selectedGeneration != .gen1 {
                            HPBarSlider(hpPercent: Binding(
                                get: { inputs.hpPercent },
                                set: { inputs.hpPercent = $0; recalculate() }
                            ))
                        } else {
                            LabeledContent("HP", value: "100% (full)")
                        }
                    }

                    if selectedGeneration == .gen1 {
                        Toggle("Safari Zone", isOn: Binding(
                            get: { inputs.battleMode == .safari },
                            set: { inputs.battleMode = $0 ? .safari : .wild; recalculate() }
                        ))
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if inputs.battleMode == .safari && selectedGeneration == .gen1 {
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
                        inputSection(title: "Capture") {
                            Button {
                                showBallPicker = true
                            } label: {
                                HStack(spacing: 12) {
                                    RemoteSpriteImage(url: inputs.catchBall.spriteURL, size: 32)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Ball")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(inputs.catchBall.displayName)
                                            .font(.body.weight(.medium))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Status")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                CompactStatusGrid(
                                    selection: Binding(
                                        get: { inputs.status },
                                        set: { inputs.status = $0 }
                                    ),
                                    onChange: recalculate
                                )
                            }

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
                gameGeneration: selectedGeneration,
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
        .sheet(isPresented: $showBallPicker) {
            BallPickerSheet(
                balls: availableBalls,
                selection: Binding(
                    get: { inputs.catchBall },
                    set: { inputs.catchBall = $0 }
                ),
                onChange: recalculate
            )
            .id(selectedGeneration.rawValue)
        }
        .sheet(isPresented: $showBallConditions) {
            BallConditionsSheet(
                inputs: $inputs,
                generation: selectedGeneration,
                onChange: recalculate
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
            inputs.generation = selectedGeneration
            ensureValidBallSelection()
            recalculate()
            Task { await dataStore.ensureGameData(for: selectedGeneration) }
        }
        .onChange(of: selectedGenerationRaw) { _, _ in
            Task { await dataStore.ensureGameData(for: selectedGeneration) }
        }
        .onChange(of: dataStore.syncState) { _, _ in
            recalculate()
        }
    }

    private var showsBallConditions: Bool {
        selectedGeneration.rawValue >= 2
            && inputs.battleMode != .safari
            && inputs.catchBall != .master
    }

    private var activeConditionCount: Int {
        var count = 0
        if inputs.isFishing { count += 1 }
        if inputs.isWaterTerrain { count += 1 }
        if inputs.isDarkTerrain { count += 1 }
        if inputs.isRepeatRegistered { count += 1 }
        if inputs.hasWaterOrBugType { count += 1 }
        if inputs.isThickGrass { count += 1 }
        if inputs.isUltraBeast { count += 1 }
        if inputs.playerLevel != 50 { count += 1 }
        if inputs.battleTurn != 1 { count += 1 }
        return count
    }

    @ViewBuilder
    private func inputSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func applyGenerationChange() {
        inputs.generation = selectedGeneration
        inputs.battleMode = .wild
        inputs.rocksThrown = 0
        inputs.baitUsed = 0

        if let species = inputs.species,
           (try? dataStore.isSpeciesAvailable(species, in: selectedGeneration)) == false {
            inputs.species = nil
        }

        ensureValidBallSelection()
        recalculate()
    }

    private func selectGeneration(_ generation: PokemonGeneration) {
        selectedGeneration = generation
        applyGenerationChange()
        Task { await dataStore.ensureGameData(for: generation) }
    }

    private func ensureValidBallSelection() {
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
    }

    private func recalculate() {
        inputs.generation = selectedGeneration
        ensureValidBallSelection()

        guard let species = inputs.species else {
            catchResult = nil
            return
        }

        let calculator = CatchCalculatorEngine.calculator(for: selectedGeneration)
        catchResult = calculator.calculateWithEstimatedHP(
            inputs: inputs,
            catchRate: species.catchRate,
            baseHP: species.baseHP
        )
    }
}
