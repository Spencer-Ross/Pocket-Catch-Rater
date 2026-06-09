import SwiftUI

struct PokemonPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let dataStore: PokemonDataStore
    let gameGeneration: PokemonGeneration
    @Binding var selectedSpecies: PokemonSpecies?

    @State private var searchText = ""
    @State private var species: [PokemonSpecies] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && species.isEmpty {
                    ProgressView("Loading \(gameGeneration.displayName) Pokémon…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if species.isEmpty {
                    ContentUnavailableView(
                        "No Pokémon Yet",
                        systemImage: "arrow.trianglehead.2.clockwise",
                        description: Text("Sync \(gameGeneration.displayName) in Settings, or wait for the download to finish.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10),
                            ],
                            spacing: 10
                        ) {
                            ForEach(species) { entry in
                                PokemonGridCell(
                                    species: entry,
                                    isSelected: selectedSpecies?.id == entry.id
                                ) {
                                    selectedSpecies = entry
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("\(gameGeneration.displayName) Pokémon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "Search Pokémon")
            .safeAreaInset(edge: .bottom) {
                if !species.isEmpty {
                    Text("\(species.count) Pokémon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.bar)
                }
            }
            .task(id: taskID) {
                await loadSpecies()
            }
        }
    }

    private var taskID: String {
        "\(gameGeneration.rawValue)-\(searchText)"
    }

    private func loadSpecies() async {
        isLoading = true
        await dataStore.ensureGameData(for: gameGeneration)
        species = (try? dataStore.search(name: searchText, in: gameGeneration)) ?? []
        isLoading = false
    }
}

private struct PokemonGridCell: View {
    let species: PokemonSpecies
    let isSelected: Bool
    let action: () -> Void

    private let tapThreshold: CGFloat = 12

    var body: some View {
        cellContent
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let distance = hypot(value.translation.width, value.translation.height)
                        guard distance < tapThreshold else { return }
                        action()
                    }
            )
    }

    private var cellContent: some View {
        VStack(spacing: 6) {
            RemoteSpriteImage(url: species.spriteURL, size: 48)
                .frame(maxWidth: .infinity)

            Text("#\(species.id)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Text(species.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text("C \(species.catchRate)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .top)
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        }
    }
}

#Preview {
    @Previewable @State var selected: PokemonSpecies?
    let database = try! PokemonDatabase(inMemory: true)
    let repository = PokemonRepository(database: database)
    let store = PokemonDataStore(repository: repository)

    return PokemonPickerView(
        dataStore: store,
        gameGeneration: .gen1,
        selectedSpecies: $selected
    )
}
