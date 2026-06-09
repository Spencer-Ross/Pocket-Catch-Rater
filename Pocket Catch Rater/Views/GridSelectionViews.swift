import SwiftUI

struct PaginatedSelectionGrid<Item: Identifiable & Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    var rowsPerPage: Int = 4
    let title: (Item) -> String
    var subtitle: ((Item) -> String)? = nil
    var imageURL: ((Item) -> URL?)? = nil
    var systemImage: ((Item) -> (name: String, color: Color)?)? = nil
    var onChange: () -> Void = {}

    @State private var currentPage = 0

    private var gridHeight: CGFloat {
        let rowHeight: CGFloat = imageURL != nil || systemImage != nil ? 92 : 62
        return CGFloat(rowsPerPage) * rowHeight + CGFloat(max(rowsPerPage - 1, 0)) * 10 + 8
    }

    var body: some View {
        GeometryReader { geometry in
            let columnCount = resolvedColumnCount(for: geometry.size.width)
            let itemsPerPage = columnCount * rowsPerPage
            let pages = items.chunked(into: itemsPerPage)
            let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: columnCount)

            VStack(spacing: 8) {
                if pages.isEmpty {
                    EmptyView()
                } else if pages.count == 1 {
                    gridPage(pages[0], columns: gridColumns)
                } else {
                    TabView(selection: $currentPage) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { pageIndex, pageItems in
                            gridPage(pageItems, columns: gridColumns)
                                .tag(pageIndex)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .frame(height: gridHeight)

                    Text("Page \(currentPage + 1) of \(pages.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: gridHeight + (items.count > rowsPerPage * 3 ? 24 : 0))
        .onChange(of: items.count) { _, _ in
            currentPage = 0
        }
    }

    private func resolvedColumnCount(for width: CGFloat) -> Int {
        if width >= 390 { return 4 }
        if width >= 320 { return 3 }
        return 2
    }

    @ViewBuilder
    private func gridPage(_ pageItems: [Item], columns: [GridItem]) -> some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(pageItems) { item in
                SelectionGridCell(
                    title: title(item),
                    subtitle: subtitle?(item),
                    imageURL: imageURL?(item),
                    systemImage: systemImage?(item),
                    isSelected: selection.id == item.id
                ) {
                    selection = item
                    onChange()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

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

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }
        var result: [[Element]] = []
        result.reserveCapacity((count + size - 1) / size)

        var index = startIndex
        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(Array(self[index..<end]))
            index = end
        }
        return result
    }
}

struct BallSelectionGrid: View {
    let balls: [CatchBall]
    @Binding var selection: CatchBall
    var onChange: () -> Void = {}

    var body: some View {
        PaginatedSelectionGrid(
            items: balls,
            selection: $selection,
            rowsPerPage: 4,
            title: { $0.displayName },
            imageURL: { $0.spriteURL },
            onChange: onChange
        )
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
