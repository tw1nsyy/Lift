import SwiftUI
import SwiftData

/// One exercise with an editable personal one-rep max.
struct MaxRow: View {
    @Bindable var exercise: Exercise
    var historyKg: Double = 0

    @Environment(\.weightUnit) private var unit
    @State private var text = ""

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tr(exercise.name)).font(.lift(15, .semibold))
                if historyKg > 0 {
                    Text(trf("From history (estimated): %@", unit.format(historyKg)))
                        .font(.lift(11, .medium)).foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 8)
            TextField("—", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.lift(17, .bold))
                .frame(width: 80)
                .padding(.vertical, 8).padding(.horizontal, 10)
                .background(Theme.cardHigh, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(unit.label).font(.lift(13, .semibold)).foregroundStyle(Theme.textSecondary)
        }
        .onAppear {
            text = exercise.manualOneRMKg > 0 ? formatNumber(unit.display(exercise.manualOneRMKg)) : ""
        }
        .onChange(of: text) { _, new in
            exercise.manualOneRMKg = unit.toKg(max(0, parseDecimal(new)))
        }
    }
}

/// All exercises with their saved one-rep maxes.
struct MyMaxesView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(filter: #Predicate<Workout> { $0.isFinished == true }, sort: \Workout.startedAt)
    private var workouts: [Workout]

    @State private var search = ""
    @State private var onlySet = false

    private var rows: [Exercise] {
        exercises.filter { ex in
            (!onlySet || ex.manualOneRMKg > 0)
            && (search.isEmpty || ex.name.localizedCaseInsensitiveContains(search) || tr(ex.name).localizedCaseInsensitiveContains(search))
        }
    }

    private func historyKg(_ ex: Exercise) -> Double {
        StatsService.sessions(for: ex, in: workouts).map { $0.e1RMKg }.max() ?? 0
    }

    var body: some View {
        List {
            Section {
                Text(tr("Enter the heaviest single you can do (or your best estimate). LIFT uses it to calculate working weights in your programs."))
                    .font(.lift(13, .medium)).foregroundStyle(Theme.textSecondary)
                Picker(tr("Show"), selection: $onlySet) {
                    Text(tr("All")).tag(false)
                    Text(tr("Set")).tag(true)
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Theme.card)

            Section {
                ForEach(rows) { ex in
                    MaxRow(exercise: ex, historyKg: historyKg(ex))
                }
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .tabBarClearance()
        .navigationTitle(tr("My one-rep maxes"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: tr("Search exercises"))
        .scrollDismissesKeyboard(.interactively)
    }
}
