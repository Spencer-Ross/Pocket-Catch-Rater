import SwiftUI

struct TurnWheelControls: View {
    @Binding var turn: Int
    var range: ClosedRange<Int> = 1...30
    var onChange: () -> Void = {}

    private let wheelWidth: CGFloat = 88
    private let wheelHeight: CGFloat = 168

    var body: some View {
        Picker("Turn", selection: $turn) {
            ForEach(Array(range), id: \.self) { value in
                Text("\(value)")
                    .font(.title)
                    .tag(value)
            }
        }
        .pickerStyle(.wheel)
        .frame(width: wheelWidth, height: wheelHeight)
        .frame(maxWidth: .infinity)
        .clipped()
        .onChange(of: turn) { _, _ in
            onChange()
        }
    }
}

struct TurnPickerButton: View {
    enum Style {
        case headerInline
    }

    @Binding var turn: Int
    var range: ClosedRange<Int> = 1...30
    var style: Style = .headerInline
    var onChange: () -> Void = {}

    @State private var showTurnPicker = false

    var body: some View {
        Button {
            showTurnPicker = true
        } label: {
            labelContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Turn \(turn)")
        .accessibilityHint("Opens turn picker")
        .sheet(isPresented: $showTurnPicker) {
            NavigationStack {
                TurnWheelControls(turn: $turn, range: range, onChange: onChange)
                    .padding(.top, 8)
                    .navigationTitle("Battle Turn")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showTurnPicker = false }
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
            VStack(alignment: .trailing, spacing: 2) {
                Text("Turn")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text("\(turn)")
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
        }
    }
}
