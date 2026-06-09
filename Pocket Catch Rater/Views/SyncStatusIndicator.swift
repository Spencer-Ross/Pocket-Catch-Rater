import SwiftUI

struct SyncStatusIndicator: View {
    let state: SyncState

    @State private var showDetails = false

    var body: some View {
        if shouldShow {
            Button {
                showDetails = true
            } label: {
                indicatorLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .popover(isPresented: $showDetails, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(detailTitle)
                        .font(.headline)
                    Text(detailMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(minWidth: 220, alignment: .leading)
                .presentationCompactAdaptation(.popover)
            }
        }
    }

    private var shouldShow: Bool {
        switch state {
        case .idle, .ready(.api):
            return false
        case .syncing, .ready(.seedFallback), .failed:
            return true
        }
    }

    @ViewBuilder
    private var indicatorLabel: some View {
        switch state {
        case .syncing:
            ProgressView()
                .controlSize(.small)
        case .ready(.seedFallback):
            Image(systemName: "arrow.trianglehead.2.clockwise")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .symbolEffect(.rotate, options: .repeating)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)
        default:
            EmptyView()
        }
    }

    private var detailTitle: String {
        switch state {
        case .syncing(let generation, _, _):
            generation == 0 ? "Syncing All Data" : "Syncing Gen \(generation)"
        case .ready(.seedFallback):
            "Offline Mode"
        case .failed:
            "Sync Failed"
        default:
            "Sync Status"
        }
    }

    private var detailMessage: String {
        switch state {
        case .syncing(let generation, let completed, let total):
            if generation == 0 {
                if total > 0 {
                    "Downloading Pokémon data for all generations… \(completed)/\(total)"
                } else {
                    "Downloading Pokémon data for all generations…"
                }
            } else if total > 0 {
                "Downloading \(generation) species… \(completed)/\(total)"
            } else {
                "Downloading Gen \(generation) species…"
            }
        case .ready(.seedFallback):
            "Using offline Gen 1 seed while PokeAPI sync runs in the background."
        case .failed(let message):
            message
        default:
            ""
        }
    }

    private var accessibilityLabel: String {
        detailTitle + ". " + detailMessage
    }
}
