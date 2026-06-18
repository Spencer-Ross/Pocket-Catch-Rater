import SwiftUI

struct SelectionGridCell: View {
    let title: String
    let subtitle: String?
    var imageURL: URL? = nil
    var systemImage: (name: String, color: Color)? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if let imageURL {
                    RemoteSpriteImage(url: imageURL, size: 36)
                        .frame(maxWidth: .infinity)
                } else if let systemImage {
                    Image(systemName: systemImage.name)
                        .font(.title2)
                        .foregroundStyle(systemImage.color)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: imageURL != nil || systemImage != nil ? 84 : 52, alignment: .top)
            .background(isSelected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

struct BallSelectionGrid: View {
    let balls: [CatchBall]
    @Binding var selection: CatchBall
    @Binding var standardBallAppearance: StandardBall
    var onCustomizeStandardBall: () -> Void = {}
    var onChange: () -> Void = {}

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(balls) { ball in
                if ball == .poke {
                    StandardBallGridCell(
                        isSelected: selection == .poke,
                        appearance: standardBallAppearance,
                        onSelect: {
                            selection = .poke
                            onChange()
                        },
                        onCustomize: {
                            selection = .poke
                            onChange()
                            onCustomizeStandardBall()
                        }
                    )
                } else {
                    SelectionGridCell(
                        title: ball.displayName,
                        subtitle: nil,
                        imageURL: ball.spriteURL,
                        isSelected: selection == ball
                    ) {
                        selection = ball
                        onChange()
                    }
                }
            }
        }
    }
}

private struct StandardBallGridCell: View {
    let isSelected: Bool
    let appearance: StandardBall
    let onSelect: () -> Void
    let onCustomize: () -> Void

    private var subtitle: String? {
        guard isSelected, appearance != .poke else { return "Hold to change style" }
        return appearance.displayName
    }

    private var imageURL: URL? {
        isSelected ? appearance.spriteURL : StandardBall.poke.spriteURL
    }

    var body: some View {
        cellContent
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture(perform: onSelect)
            .onLongPressGesture(minimumDuration: 0.45, perform: onCustomize)
    }

    private var cellContent: some View {
        VStack(spacing: 6) {
            RemoteSpriteImage(url: imageURL, size: 36)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text("Poké Ball")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .top)
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        }
        .accessibilityLabel("Poké Ball")
        .accessibilityHint("Double tap to select. Touch and hold to change style.")
    }
}

struct StatusSelectionGrid: View {
    @Binding var selection: StatusCondition
    var onChange: () -> Void = {}

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(StatusCondition.allCases) { status in
                SelectionGridCell(
                    title: status.displayName,
                    subtitle: status.symbolName,
                    systemImage: (status.iconSystemName, statusColor(for: status)),
                    isSelected: selection == status
                ) {
                    selection = status
                    onChange()
                }
            }
        }
        .padding(.vertical, 4)
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

private extension StatusCondition {
    var symbolName: String {
        switch self {
        case .none: "—"
        case .poison: "PSN"
        case .burn: "BRN"
        case .paralysis: "PAR"
        case .sleep: "SLP"
        case .freeze: "FRZ"
        }
    }
}
