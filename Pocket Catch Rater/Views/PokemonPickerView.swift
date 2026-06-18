import SwiftUI

struct PokemonPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let dataStore: PokemonDataStore
    let gameGeneration: PokemonGeneration
    @Binding var selectedSpecies: PokemonSpecies?

    @State private var searchText = ""
    @State private var species: [PokemonSpecies] = []
    @State private var isLoading = false
    @State private var loadingSpeciesID: Int?
    @State private var isScrolling = false

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
                                    isSelected: selectedSpecies?.id == entry.id,
                                    isLoadingDetails: loadingSpeciesID == entry.id,
                                    isScrolling: isScrolling
                                ) {
                                    Task { await selectSpecies(entry) }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onScrollPhaseChange { _, phase in
                        isScrolling = phase != .idle
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
            .task(id: gameGeneration.rawValue) {
                await loadSpecies()
            }
            .onChange(of: searchText) { _, _ in
                reloadSpeciesFromCache()
            }
            .onChange(of: dataStore.syncState) { _, _ in
                reloadSpeciesFromCache()
            }
        }
    }

    private func loadSpecies() async {
        reloadSpeciesFromCache()

        if !species.isEmpty {
            await dataStore.ensureGameData(for: gameGeneration)
            reloadSpeciesFromCache()
            return
        }

        isLoading = true
        await dataStore.ensureGameData(for: gameGeneration)
        reloadSpeciesFromCache()
        isLoading = false
    }

    private func reloadSpeciesFromCache() {
        species = (try? dataStore.search(name: searchText, in: gameGeneration)) ?? []
    }

    private func selectSpecies(_ entry: PokemonSpecies) async {
        guard loadingSpeciesID == nil else { return }

        if entry.hasCompleteDetails {
            selectedSpecies = entry
            dismiss()
            return
        }

        loadingSpeciesID = entry.id
        defer { loadingSpeciesID = nil }

        do {
            let detailed = try await dataStore.ensureSpeciesDetails(for: entry.id)
            selectedSpecies = detailed
            dismiss()
        } catch {
            // Keep picker open so the user can retry or pick another species.
        }
    }
}

private struct PokemonGridCell: View {
    let species: PokemonSpecies
    let isSelected: Bool
    var isLoadingDetails = false
    var isScrolling = false
    let action: () -> Void

    /// Finger movement above this cancels the tap so scrolling can take over.
    private let scrollTapThreshold: CGFloat = 20

    var body: some View {
        cellContent
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .onLongPressGesture(minimumDuration: 0, maximumDistance: scrollTapThreshold) {
                guard !isLoadingDetails, !isScrolling else { return }
                action()
            }
    }

    private var cellContent: some View {
        VStack(spacing: 6) {
            ZStack {
                RemoteSpriteImage(url: species.spriteURL, size: 48)
                    .frame(maxWidth: .infinity)

                if isLoadingDetails {
                    ProgressView()
                        .controlSize(.small)
                }
            }

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

            if species.hasDetails {
                Text("C \(species.catchRate)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
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
