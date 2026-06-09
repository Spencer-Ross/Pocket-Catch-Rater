import SwiftUI

struct LevelWheelPicker: View {
    @Binding var level: Int
    var onChange: () -> Void = {}

    @State private var tensDigit: Int
    @State private var onesDigit: Int

    private let wheelWidth: CGFloat = 54
    private let wheelHeight: CGFloat = 104

    init(level: Binding<Int>, onChange: @escaping () -> Void = {}) {
        _level = level
        self.onChange = onChange

        let clamped = min(100, max(1, level.wrappedValue))
        let tens = clamped == 100 ? 10 : clamped / 10
        let ones = clamped == 100 ? 0 : clamped % 10
        _tensDigit = State(initialValue: tens)
        _onesDigit = State(initialValue: ones)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("Level: \(level)")
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            HStack(spacing: 0) {
                Picker("Tens", selection: $tensDigit) {
                    ForEach(0...10, id: \.self) { digit in
                        Text(tensLabel(digit))
                            .font(.title3)
                            .tag(digit)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: wheelWidth, height: wheelHeight)
                .clipped()

                Picker("Ones", selection: $onesDigit) {
                    ForEach(0...9, id: \.self) { digit in
                        Text("\(digit)")
                            .font(.title3)
                            .tag(digit)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: wheelWidth, height: wheelHeight)
                .clipped()
                .disabled(tensDigit == 10)
            }
            .fixedSize()
        }
        .onChange(of: tensDigit) { _, newTens in
            if newTens == 10 {
                onesDigit = 0
            } else if newTens == 0 && onesDigit == 0 {
                onesDigit = 1
            }
            applyLevel()
        }
        .onChange(of: onesDigit) { _, _ in
            applyLevel()
        }
        .onChange(of: level) { _, newLevel in
            syncFromLevel(newLevel)
        }
    }

    private func tensLabel(_ digit: Int) -> String {
        digit == 10 ? "10×" : "\(digit)"
    }

    private func applyLevel() {
        let computed: Int
        if tensDigit == 10 {
            computed = 100
        } else if tensDigit == 0 {
            computed = max(1, onesDigit)
        } else {
            computed = tensDigit * 10 + onesDigit
        }

        if level != computed {
            level = computed
            onChange()
        }
    }

    private func syncFromLevel(_ newLevel: Int) {
        let clamped = min(100, max(1, newLevel))
        let newTens = clamped == 100 ? 10 : clamped / 10
        let newOnes = clamped == 100 ? 0 : clamped % 10

        if tensDigit != newTens {
            tensDigit = newTens
        }
        if onesDigit != newOnes {
            onesDigit = newOnes
        }
    }
}

#Preview {
    @Previewable @State var level = 72
    Form {
        Section {
            LevelWheelPicker(level: $level)
        }
    }
}
