import SwiftUI

struct HPBarSlider: View {
    @Binding var hpPercent: Double

    private var barColor: Color {
        if hpPercent > 50 { return .green }
        if hpPercent > 20 { return .yellow }
        return .red
    }

    private var fillGradient: LinearGradient {
        LinearGradient(
            colors: [
                barColor.opacity(0.95),
                barColor.opacity(0.72),
                barColor.opacity(0.88),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("HP Remaining")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(hpPercent))%")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }

            GeometryReader { geometry in
                let width = geometry.size.width
                let fillWidth = max(0, width * hpPercent / 100)

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.18))

                    Capsule(style: .continuous)
                        .fill(fillGradient)
                        .frame(width: fillWidth)
                        .shadow(color: barColor.opacity(0.35), radius: 4, y: 1)

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.38),
                                    Color.white.opacity(0.12),
                                    Color.clear,
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: fillWidth)
                        .blendMode(.screen)
                        .allowsHitTesting(false)

                    Capsule(style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular, in: .capsule)
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.65),
                                            Color.white.opacity(0.18),
                                            Color.white.opacity(0.05),
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        }
                        .allowsHitTesting(false)

                    if fillWidth > 6 {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.55))
                            .frame(width: 2, height: 18)
                            .offset(x: max(0, fillWidth - 2))
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 32)
                .contentShape(Capsule(style: .continuous))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            hpPercent = Self.hpPercent(from: value.location.x, width: width)
                        }
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("HP Remaining")
                .accessibilityValue("\(Int(hpPercent)) percent")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        hpPercent = min(100, hpPercent + 1)
                    case .decrement:
                        hpPercent = max(1, hpPercent - 1)
                    @unknown default:
                        break
                    }
                }
            }
            .frame(height: 32)
        }
        .animation(.easeOut(duration: 0.15), value: hpPercent)
    }

    private static func hpPercent(from x: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return 1 }
        let raw = Double(x / width * 100)
        return min(100, max(1, raw.rounded()))
    }
}

#Preview {
    @Previewable @State var hp = 45.0
    HPBarSlider(hpPercent: $hp)
        .padding()
}
