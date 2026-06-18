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

struct SelectedCatchBallHeader: View {
    let name: String
    let spriteURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            RemoteSpriteImage(url: spriteURL, size: 40)

            Text(name)
                .font(.body.weight(.semibold))

            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct StandardBallSkinSheet: View {
    @Environment(\.dismiss) private var dismiss

    let generation: PokemonGeneration
    @Binding var selection: StandardBall

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(StandardBall.available(for: generation)) { ball in
                        Button {
                            selection = ball
                            dismiss()
                        } label: {
                            VStack(spacing: 6) {
                                RemoteSpriteImage(url: ball.spriteURL, size: 40)
                                    .frame(maxWidth: .infinity)

                                Text(ball.displayName)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, minHeight: 84, alignment: .top)
                            .background(
                                selection == ball
                                    ? Color.accentColor.opacity(0.18)
                                    : Color(.secondarySystemGroupedBackground)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(selection == ball ? Color.accentColor : Color.clear, lineWidth: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Poké Ball Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct GenerationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selection: CatchRuleSet
    var onChange: (CatchRuleSet) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            List(CatchRuleSet.allCases) { ruleSet in
                Button {
                    selection = ruleSet
                    onChange(ruleSet)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(ruleSet.displayName)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(ruleSet.gamesLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        if selection == ruleSet {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Catch Rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct BallConditionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var inputs: CatchInputs
    let ruleSet: CatchRuleSet
    var onChange: () -> Void = {}

    private var generationLevel: Int {
        ruleSet.representativeGeneration.rawValue
    }

    var body: some View {
        NavigationStack {
            Form {
                if generationLevel >= 2 {
                    Section("Level Ball") {
                        Stepper("Your Pokémon level: \(inputs.playerLevel)", value: Binding(
                            get: { inputs.playerLevel },
                            set: { inputs.playerLevel = min(100, max(1, $0)); onChange() }
                        ), in: 1...100)
                    }
                }

                if generationLevel >= 3 {
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

                if generationLevel >= 5 {
                    Section("Environment") {
                        Toggle("Thick grass / dark grass", isOn: binding(\.isThickGrass))
                    }
                }

                if generationLevel >= 7 {
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
