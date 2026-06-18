import SwiftUI

struct LevelWheelControls: View {
    @Binding var level: Int
    var onChange: () -> Void = {}

    @State private var tensDigit: Int
    @State private var onesDigit: Int

    private let wheelWidth: CGFloat = 72
    private let wheelHeight: CGFloat = 168

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
        HStack(spacing: 0) {
            Picker("Tens", selection: $tensDigit) {
                ForEach(0...10, id: \.self) { digit in
                    Text(tensLabel(digit))
                        .font(.title)
                        .tag(digit)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: wheelWidth, height: wheelHeight)
            .clipped()

            Picker("Ones", selection: $onesDigit) {
                ForEach(0...9, id: \.self) { digit in
                    Text("\(digit)")
                        .font(.title)
                        .tag(digit)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: wheelWidth, height: wheelHeight)
            .clipped()
            .disabled(tensDigit == 10)
        }
        .frame(maxWidth: .infinity)
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

struct LevelPickerButton: View {
    enum Style {
        case compact
        case full
        case headerInline
    }

    @Binding var level: Int
    var style: Style = .compact
    var onChange: () -> Void = {}

    @State private var showLevelPicker = false

    var body: some View {
        Button {
            showLevelPicker = true
        } label: {
            labelContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Level \(level)")
        .accessibilityHint("Opens level picker")
        .sheet(isPresented: $showLevelPicker) {
            NavigationStack {
                LevelWheelControls(level: $level, onChange: onChange)
                    .padding(.top, 8)
                    .navigationTitle("Level")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showLevelPicker = false }
                        }
                    }
            }
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var labelContent: some View {
        switch style {
        case .headerInline:
            VStack(alignment: .leading, spacing: 2) {
                Text("Level")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text("\(level)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())

        case .compact:
            VStack(spacing: 2) {
                Text("Level")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text("\(level)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())

        case .full:
            VStack(spacing: 4) {
                Text("Level")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text("\(level)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .offset(x: 2, y: 2)
            }
        }
    }
}

/// Inline level wheels for forms and previews.
struct LevelWheelPicker: View {
    @Binding var level: Int
    var onChange: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            Text("Level: \(level)")
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            LevelWheelControls(level: $level, onChange: onChange)
        }
    }
}

#Preview("Button") {
    @Previewable @State var level = 72
    LevelPickerButton(level: $level)
        .frame(width: 80, height: 130)
        .padding()
}

#Preview("Inline") {
    @Previewable @State var level = 72
    Form {
        Section {
            LevelWheelPicker(level: $level)
        }
    }
}
