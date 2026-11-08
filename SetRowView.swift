import SwiftUI
import SwiftData

struct SetRowView: View {
    @Bindable var item: WorkoutSet
    let index: Int
    var prev: SetSnapshot? = nil
    var showsPrev = true
    var showsCheck = true
    var onToggle: (WorkoutSet) -> Void = { _ in }

    @Environment(\.weightUnit) private var unit
    @State private var weightText = ""
    @State private var repsText = ""

    var body: some View {
        HStack(spacing: 8) {
            Text(item.isWarmup ? "W" : "\(index)")
                .font(.lift(15, .bold))
                .foregroundStyle(item.isWarmup ? Color.orange : Theme.textSecondary)
                .frame(width: 24)
            if showsPrev {
                Text(prevText)
                    .font(.lift(12, .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 62)
            }
            field($weightText, placeholder: "0", keyboard: .decimalPad)
            field($repsText, placeholder: "0", keyboard: .numberPad)
            if showsCheck {
                Button {
                    toggle()
                } label: {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(item.isCompleted ? Theme.accent : Theme.textSecondary)
                        .symbolEffect(.bounce, value: item.isCompleted)
                }
                .buttonStyle(.plain)
                .frame(width: 36)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(item.isCompleted && showsCheck ? Theme.accent.opacity(0.12) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: item.isCompleted)
        .onAppear {
            weightText = item.weightKg > 0 ? formatNumber(unit.display(item.weightKg)) : ""
            repsText = item.reps > 0 ? "\(item.reps)" : ""
        }
        .onChange(of: item.weightKg) { _, new in
            // Keep the field in sync when the value is changed programmatically (e.g. "Apply suggestion").
            if abs(unit.toKg(parseDecimal(weightText)) - new) > 0.001 {
                weightText = new > 0 ? formatNumber(unit.display(new)) : ""
            }
        }
        .onChange(of: item.reps) { _, new in
            if (Int(repsText) ?? 0) != new { repsText = new > 0 ? "\(new)" : "" }
        }
        .onChange(of: weightText) { _, new in
            item.weightKg = unit.toKg(max(0, parseDecimal(new)))
        }
        .onChange(of: repsText) { _, new in
            item.reps = max(0, Int(new.filter(\.isNumber)) ?? 0)
        }
    }

    private var prevText: String {
        guard let prev else { return "—" }
        return "\(unit.format(prev.weightKg, withUnit: false))×\(prev.reps)"
    }

    private func field(_ text: Binding<String>, placeholder: String, keyboard: UIKeyboardType) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .font(.lift(17, .bold))
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(Theme.cardHigh, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func toggle() {
        if !item.isCompleted && item.reps <= 0 {
            Haptics.warning()
            return
        }
        Haptics.tap()
        item.isCompleted.toggle()
        item.completedAt = item.isCompleted ? Date() : nil
        onToggle(item)
    }
}
