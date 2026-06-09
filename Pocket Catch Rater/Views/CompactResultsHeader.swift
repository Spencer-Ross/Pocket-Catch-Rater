import SwiftUI

struct CompactResultsHeader: View {
    let result: CatchResult?
    let species: PokemonSpecies?
    let generation: PokemonGeneration

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                if let species {
                    RemoteSpriteImage(url: species.spriteURL, size: 56)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Catch Rate")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            if let result {
                                Text(formattedPercent(result.probabilityPercent))
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .minimumScaleFactor(0.7)
                                    .lineLimit(1)
                            } else {
                                Text("—")
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer(minLength: 8)

                        if let result {
                            VStack(alignment: .trailing, spacing: 4) {
                                statLine("Est. HP", "\(result.currentHP)/\(result.maxHP)")
                                statLine("Species C", "\(result.speciesCatchRate)")
                                if generation.formulaFamily == .gen1 {
                                    statLine("HP factor", "\(result.hpFactor)")
                                } else {
                                    statLine("Mod. rate", "\(result.effectiveCatchRate)")
                                }
                                statLine(
                                    generation.formulaFamily == .gen1 ? "Wobbles" : "Est. wobbles",
                                    "\(result.wobbleCount)"
                                )
                            }
                            .font(.caption)
                        }
                    }

                    if let species {
                        Text(species.displayName)
                            .font(.subheadline.weight(.medium))
                    } else {
                        Text("Choose a Pokémon below")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let result, result.isAtHPCap {
                        Label("HP at effective cap for this ball", systemImage: "checkmark.circle")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private func statLine(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
        }
    }

    private func formattedPercent(_ value: Double) -> String {
        String(format: "%.2f%%", value)
    }
}

#Preview {
    CompactResultsHeader(
        result: CatchResult(
            probability: 0.234,
            hpFactor: 120,
            wobbleCount: 2,
            isAtHPCap: false,
            maxHP: 100,
            currentHP: 25,
            speciesCatchRate: 45,
            effectiveCatchRate: 12,
            ballBonus: 2
        ),
        species: PokemonSpecies(id: 25, name: "Pikachu", generation: 1, baseHP: 35, catchRate: 190, type1: "electric", type2: nil),
        generation: .gen9
    )
}
