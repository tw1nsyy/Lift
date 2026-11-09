import SwiftUI
import SwiftData

/// Works out training weights from a one-rep max (inverse Epley).
struct OneRMCalculatorView: View {
    @Bindable var exercise: Exercise
    var initialReps: Int = 8
    /// When opened from a workout: receives the chosen weight (kg) and reps.
    var onApply: ((Double, Int) -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var unit
    @Query(filter: #Predicate<Workout> { $0.isFinished == true }, sort: \Workout.startedAt)
    private var workouts: [Workout]

    @State private var oneRMText = ""
    @State private var targetReps = 8
    @State private var loaded = false

    private let repRows = [1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20]
    private let percentRows = [100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 50]

    private var oneRMKg: Double { unit.toKg(max(0, parseDecimal(oneRMText))) }
    private var hasMax: Bool { oneRMKg > 0 }

    private var historyKg: Double {
        ExerciseSummary(sessions: StatsService.sessions(for: exercise, in: workouts)).bestE1RMKg
    }

    /// Plate step in display units: 2.5 kg or 5 lb.
    private var step: Double { unit == .kg ? 2.5 : 5 }

    private func rounded(_ kg: Double) -> Double {
        let d = unit.display(kg)
        return unit.toKg((d / step).rounded() * step)
    }

    private func weightText(_ kg: Double) -> String { hasMax ? unit.format(rounded(kg)) : "—" }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                maxCard
                targetCard
                table(title: tr("By reps")) {
                    ForEach(repRows, id: \.self) { r in
                        calcRow(tr("REPS") + " " + "\(r)",
                                "\(Int((Formulas.percentOfMax(reps: r) * 100).rounded()))%",
                                weightText(Formulas.weightForReps(oneRM: oneRMKg, reps: r)))
                    }
                }
                table(title: tr("By percentage")) {
                    ForEach(percentRows, id: \.self) { p in
                        calcRow("\(p)%",
                                trf("About %d reps", Formulas.repsForPercent(Double(p) / 100)),
                                weightText(oneRMKg * Double(p) / 100))
                    }
                }
                Text(trf("Weights are rounded to the nearest %@. The calculation uses the Epley formula, so treat it as a starting point, not a guarantee.",
                         unit.format(unit.toKg(step))))
                    .font(.lift(11, .medium)).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .navigationTitle(tr(exercise.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button(tr("Done")) { dismiss() }.fontWeight(.semibold) }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            targetReps = min(max(initialReps, 1), 30)
            let start = exercise.manualOneRMKg > 0 ? exercise.manualOneRMKg : historyKg
            if start > 0 { oneRMText = formatNumber(unit.display(start)) }
        }
    }

    // MARK: Cards

    private var maxCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("My one-rep max")).font(.lift(18, .bold))
            HStack(spacing: 8) {
                TextField("0", text: $oneRMText)
                    .keyboardType(.decimalPad)
                    .font(.lift(28, .bold))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.cardHigh, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(unit.label).font(.lift(18, .semibold)).foregroundStyle(Theme.textSecondary)
            }
            if historyKg > 0 {
                HStack {
                    Text(trf("From history (estimated): %@", unit.format(historyKg)))
                        .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Button(tr("Use")) { oneRMText = formatNumber(unit.display(historyKg)) }
                        .buttonStyle(SoftButtonStyle())
                }
            }
            HStack {
                Button {
                    exercise.manualOneRMKg = oneRMKg
                    try? context.save()
                    Haptics.success()
                } label: { Label(tr("Save as my max"), systemImage: "checkmark.circle") }
                    .buttonStyle(SoftButtonStyle(tint: Theme.accent))
                    .disabled(!hasMax)
                if exercise.manualOneRMKg > 0 && abs(exercise.manualOneRMKg - oneRMKg) < 0.001 {
                    Text(tr("Saved")).font(.lift(12, .semibold)).foregroundStyle(Theme.accent)
                }
            }
        }
        .card()
    }

    private var targetCard: some View {
        let w = Formulas.weightForReps(oneRM: oneRMKg, reps: targetReps)
        return VStack(alignment: .leading, spacing: 12) {
            Text(tr("Weight for target reps")).font(.lift(18, .bold))
            Stepper(value: $targetReps, in: 1...30) {
                Text(trf("Target reps: %d", targetReps)).font(.lift(15, .semibold))
            }
            if hasMax {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formatNumber(unit.display(rounded(w))))
                        .font(.lift(54, .bold))
                        .contentTransition(.numericText())
                    Text(unit.label).font(.lift(18, .semibold)).foregroundStyle(Theme.textSecondary)
                    Text("× \(targetReps)").font(.lift(22, .bold)).foregroundStyle(Theme.accent)
                }
                .animation(.easeInOut(duration: 0.2), value: targetReps)
                Text(trf("%d%% of your max", Int((Formulas.percentOfMax(reps: targetReps) * 100).rounded())))
                    .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
                if let onApply {
                    Button {
                        onApply(rounded(w), targetReps)
                        Haptics.success()
                        dismiss()
                    } label: { Text(tr("Apply to my sets")) }
                        .buttonStyle(PrimaryButtonStyle())
                }
            } else {
                Text(tr("Enter your one-rep max to see the weights."))
                    .font(.lift(13, .medium)).foregroundStyle(Theme.textSecondary)
            }
        }
        .card()
    }

    private func table<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.lift(18, .bold))
            content()
        }
        .card()
    }

    private func calcRow(_ a: String, _ b: String, _ c: String) -> some View {
        HStack {
            Text(a).font(.lift(14, .semibold)).frame(maxWidth: .infinity, alignment: .leading)
            Text(b).font(.lift(13, .medium)).foregroundStyle(Theme.textSecondary).frame(maxWidth: .infinity, alignment: .center)
            Text(c).font(.lift(15, .bold)).frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
