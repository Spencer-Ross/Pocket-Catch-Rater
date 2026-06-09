import SwiftUI

struct SettingsView: View {
    @Bindable var dataStore: PokemonDataStore

    var body: some View {
        List {
            Section("Sync") {
                Button {
                    Task { await dataStore.syncAllMissingData() }
                } label: {
                    HStack {
                        Text("Sync All Generations")
                        Spacer()
                        if case .syncing(let gen, _, _) = dataStore.syncState, gen == 0 {
                            ProgressView()
                        }
                    }
                }
                .disabled(dataStore.syncState.isSyncing)

                ForEach(PokemonGeneration.allCases) { generation in
                    Button {
                        Task { await dataStore.syncGameData(for: generation) }
                    } label: {
                        HStack {
                            Text("Sync \(generation.displayName)")
                            Spacer()
                            if case .syncing(let gen, _, _) = dataStore.syncState, gen == generation.rawValue {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(dataStore.syncState.isSyncing)
                }

                Button("Clear Cache & Re-sync Gen 1", role: .destructive) {
                    Task { await dataStore.clearCacheAndResync() }
                }
                .disabled(dataStore.syncState.isSyncing)
            }

            Section("Cache Stats") {
                if let stats = dataStore.cacheStats {
                    LabeledContent("Species cached", value: "\(stats.speciesCount)")
                    LabeledContent("Database size", value: formattedBytes(stats.databaseBytes))

                    ForEach(PokemonGeneration.allCases) { generation in
                        if let lastSync = stats.lastSync(for: generation.rawValue) {
                            LabeledContent("Last \(generation.displayName) sync", value: formattedLastSync(lastSync))
                        }
                    }
                } else {
                    Text("No cache data yet.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Status") {
                Text(syncStatusText)
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            dataStore.refreshCacheStats()
        }
    }

    private var syncStatusText: String {
        switch dataStore.syncState {
        case .idle:
            "Idle"
        case .syncing(let generation, let completed, let total):
            if generation == 0 {
                if total > 0 {
                    "Syncing all generations… \(completed)/\(total)"
                } else {
                    "Syncing all generations…"
                }
            } else if total > 0 {
                "Syncing Gen \(generation)… \(completed)/\(total)"
            } else {
                "Syncing Gen \(generation)…"
            }
        case .ready(let source):
            source == .api ? "Ready (API cache)" : "Ready (offline seed)"
        case .failed(let message):
            "Failed: \(message)"
        }
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func formattedLastSync(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) else { return iso }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
