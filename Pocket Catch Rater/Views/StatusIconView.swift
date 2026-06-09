import SwiftUI

struct StatusIconView: View {
    let status: StatusCondition
    var size: CGFloat = 18

    var body: some View {
        Image(systemName: status.iconSystemName)
            .font(.system(size: size * 0.75, weight: .semibold))
            .foregroundStyle(statusColor)
            .frame(width: size, height: size)
    }

    private var statusColor: Color {
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
