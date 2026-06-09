import SwiftUI

struct ResultsCardView: View {
    let result: CatchResult?
    let generation: PokemonGeneration

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Catch Rate")
                .font(.headline)

            if let result {
                Text(formattedPercent(result.probabilityPercent))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        statLabel("Est. HP")
                        Text("\(result.currentHP) / \(result.maxHP)").monospacedDigit()
                    }

                    GridRow {
                        statLabel("Species rate")
                        Text("\(result.speciesCatchRate)").monospacedDigit()
                    }

                    if generation.formulaFamily == .gen1 {
                        GridRow {
                            statLabel("HP factor")
                            Text("\(result.hpFactor)").monospacedDigit()
                        }
                    } else {
                        GridRow {
                            statLabel("Modified rate")
                            Text("\(result.effectiveCatchRate)").monospacedDigit()
                        }
                    }

                    if let ballBonus = result.ballBonus, ballBonus != 1 {
                        GridRow {
                            statLabel("Ball bonus")
                            Text(formattedBonus(ballBonus)).monospacedDigit()
                        }
                    }

                    GridRow {
                        statLabel(generation.formulaFamily == .gen1 ? "Wobbles on fail" : "Est. wobbles")
                        Text("\(result.wobbleCount)").monospacedDigit()
                    }
                }
                .font(.subheadline)

                Text("HP estimated at level with median wild IV (\(HPEstimator.medianIV)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if result.isAtHPCap {
                    Label("HP is at the effective cap for this ball.", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            } else {
                Text("Select a Pokémon to calculate.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func statLabel(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
    }

    private func formattedPercent(_ value: Double) -> String {
        String(format: "%.2f%%", value)
    }

    private func formattedBonus(_ value: Double) -> String {
        String(format: "%.2fx", value)
    }
}

#Preview {
    ResultsCardView(
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
        generation: .gen3
    )
    .padding()
}
