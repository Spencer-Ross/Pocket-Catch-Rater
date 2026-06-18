import SwiftUI

struct CompactResultsHeader: View {
    let result: CatchResult?
    let species: PokemonSpecies?
    @Binding var ruleSet: CatchRuleSet
    @Binding var level: Int
    let onSpeciesTap: () -> Void
    let onLevelChange: () -> Void
    let onRuleSetChange: (CatchRuleSet) -> Void

    @State private var showBreakdown = false
    @State private var showRuleSetPicker = false

    private let spriteSize: CGFloat = 128
    private let rightRailWidth: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 0) {
                speciesPickerButton
                    .frame(width: spriteSize, height: spriteSize)

                VStack(alignment: .leading, spacing: 8) {
                    catchRateBlock
                    LevelPickerButton(level: $level, style: .headerInline, onChange: onLevelChange)
                }
                .padding(.leading, 14)
                .frame(maxWidth: .infinity, alignment: .leading)

                rightRail
                    .frame(width: rightRailWidth, alignment: .center)
            }

            speciesLabel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .sheet(isPresented: $showBreakdown) {
            if let result {
                CatchBreakdownSheet(result: result, ruleSet: ruleSet)
            }
        }
        .sheet(isPresented: $showRuleSetPicker) {
            GenerationPickerSheet(selection: $ruleSet, onChange: onRuleSetChange)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var rightRail: some View {
        VStack(alignment: .center, spacing: 0) {
            if result != nil {
                Button {
                    showBreakdown = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Calculation details")
                .accessibilityHint("Shows how catch rate was calculated")
            }

            Button {
                showRuleSetPicker = true
            } label: {
                VStack(alignment: .center, spacing: 2) {
                    Text("Formula")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    VStack(alignment: .center, spacing: 0) {
                        Text("Gen")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))

                        Text(ruleSet.headerGenerationValue)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, result != nil ? 20 : 0)
            .accessibilityLabel("Catch formula \(ruleSet.displayName)")
            .accessibilityHint("Opens catch rules picker")
        }
    }

    private var catchRateBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Catch Rate")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if let result {
                Text(formattedPercent(result.probabilityPercent))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .layoutPriority(1)

                if result.isAtHPCap {
                    Label("HP effective cap", systemImage: "checkmark.circle")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .lineLimit(1)
                }
            } else {
                Text("—")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var speciesLabel: some View {
        let entry = species ?? PokemonSpecies.fallbackPikachu

        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(String(format: "#%03d", entry.id))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Text(entry.name)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)
        }
    }

    private var speciesPickerButton: some View {
        Button(action: onSpeciesTap) {
            RemoteSpriteImage(
                url: (species ?? PokemonSpecies.fallbackPikachu).spriteURL,
                size: spriteSize - 8
            )
            .padding(2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .offset(x: 2, y: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change Pokémon")
        .accessibilityHint("Opens the Pokémon picker")
    }

    private func formattedPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
}

private struct CatchBreakdownSheet: View {
    let result: CatchResult
    let ruleSet: CatchRuleSet

    var body: some View {
        NavigationStack {
            List {
                Section {
                    breakdownRow(
                        "Estimated HP",
                        "\(result.currentHP) / \(result.maxHP)",
                        footnote: "From species base HP, level, and HP slider (median IV)."
                    )
                    breakdownRow(
                        "Species catch rate",
                        "\(result.speciesCatchRate)",
                        footnote: "Base catch rate for this species in the games."
                    )
                    if ruleSet.formulaFamily == .gen1 {
                        breakdownRow(
                            "HP factor",
                            "\(result.hpFactor)",
                            footnote: "Gen 1 HP check value (0–255). Higher improves odds."
                        )
                        breakdownRow(
                            "Wobbles",
                            "\(result.wobbleCount)",
                            footnote: "Expected ball wobbles before catch or break (0–3)."
                        )
                    } else {
                        breakdownRow(
                            "Modified catch rate",
                            "\(result.effectiveCatchRate)",
                            footnote: "Catch rate after HP, ball, status, and other modifiers (1–255)."
                        )
                        breakdownRow(
                            "Est. wobbles",
                            "\(result.wobbleCount)",
                            footnote: "Rough wobble estimate from the modified rate."
                        )
                    }
                }

                if result.isAtHPCap {
                    Section {
                        Label {
                            Text("HP is at the effective cap for this ball — lowering HP further won't help.")
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .navigationTitle("Calculation Details")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func breakdownRow(_ title: String, _ value: String, footnote: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(title, value: value)
                .monospacedDigit()
            Text(footnote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    @Previewable @State var level = 30
    CompactResultsHeader(
        result: CatchResult(
            probability: 1.0,
            hpFactor: 255,
            wobbleCount: 0,
            isAtHPCap: true,
            maxHP: 68,
            currentHP: 1,
            speciesCatchRate: 45,
            effectiveCatchRate: 255,
            ballBonus: 2
        ),
        species: PokemonSpecies.fallbackPikachu,
        ruleSet: .constant(.gen3to4),
        level: $level,
        onSpeciesTap: {},
        onLevelChange: {},
        onRuleSetChange: { _ in }
    )
}
