import SwiftUI

struct CompactStatusGrid: View {
    @Binding var selection: StatusCondition
    var onChange: () -> Void = {}

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(StatusCondition.allCases) { status in
                Button {
                    selection = status
                    onChange()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: status.iconSystemName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(statusColor(for: status))

                        Text(status.gridLabel)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selection == status
                            ? Color.accentColor.opacity(0.18)
                            : Color(.secondarySystemGroupedBackground)
                    )
                    .foregroundStyle(selection == status ? Color.accentColor : Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(selection == status ? Color.accentColor : Color.clear, lineWidth: 2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(status.displayName)
            }
        }
    }

    private func statusColor(for status: StatusCondition) -> Color {
        switch status.iconColorName {
        case "purple": .purple
        case "orange": .orange
        case "yellow": .yellow
        case "indigo": .indigo
        case "cyan": .cyan
        default: .secondary
        }
    }
}

struct GenerationChipRow: View {
    @Binding var selection: PokemonGeneration
    var onChange: (PokemonGeneration) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PokemonGeneration.allCases) { generation in
                        Button {
                            selection = generation
                            onChange(generation)
                        } label: {
                            Text(generation.displayName)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selection == generation ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                                .foregroundStyle(selection == generation ? Color.white : Color.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }

            Text(selection.gamesLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct BallPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let balls: [CatchBall]
    @Binding var selection: CatchBall
    var onChange: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                BallSelectionGrid(
                    balls: balls,
                    selection: $selection,
                    onChange: {
                        onChange()
                        dismiss()
                    }
                )
                .padding()
            }
            .navigationTitle("Choose Ball")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                clampSelectionToAvailableBalls()
            }
            .onChange(of: balls.map(\.id)) { _, _ in
                clampSelectionToAvailableBalls()
            }
        }
    }

    private func clampSelectionToAvailableBalls() {
        guard !balls.isEmpty else { return }
        if !balls.contains(selection) {
            selection = balls[0]
            onChange()
        }
    }
}

struct BallConditionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var inputs: CatchInputs
    let generation: PokemonGeneration
    var onChange: () -> Void = {}

    var body: some View {
        NavigationStack {
            Form {
                if generation.rawValue >= 2 {
                    Section("Level Ball") {
                        Stepper("Your Pokémon level: \(inputs.playerLevel)", value: Binding(
                            get: { inputs.playerLevel },
                            set: { inputs.playerLevel = min(100, max(1, $0)); onChange() }
                        ), in: 1...100)
                    }
                }

                if generation.rawValue >= 3 {
                    Section("Battle") {
                        Stepper("Battle turn: \(inputs.battleTurn)", value: Binding(
                            get: { inputs.battleTurn },
                            set: { inputs.battleTurn = max(1, $0); onChange() }
                        ), in: 1...30)
                    }

                    Section("Terrain & Activity") {
                        Toggle("Fishing", isOn: binding(\.isFishing))
                        Toggle("On/in water", isOn: binding(\.isWaterTerrain))
                        Toggle("Dark terrain / night", isOn: binding(\.isDarkTerrain))
                    }

                    Section("Species Match") {
                        Toggle("Already caught (Repeat Ball)", isOn: binding(\.isRepeatRegistered))
                        Toggle("Water or Bug type (Net Ball)", isOn: binding(\.hasWaterOrBugType))
                    }
                }

                if generation.rawValue >= 5 {
                    Section("Environment") {
                        Toggle("Thick grass / dark grass", isOn: binding(\.isThickGrass))
                    }
                }

                if generation.rawValue >= 7 {
                    Section("Ultra Beasts") {
                        Toggle("Ultra Beast target", isOn: binding(\.isUltraBeast))
                    }
                }
            }
            .navigationTitle("Ball Conditions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<CatchInputs, Bool>) -> Binding<Bool> {
        Binding(
            get: { inputs[keyPath: keyPath] },
            set: {
                inputs[keyPath: keyPath] = $0
                onChange()
            }
        )
    }
}
