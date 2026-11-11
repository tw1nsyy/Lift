import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.weightUnit) private var unit
    @Environment(AppRouter.self) private var router
    @Query(filter: #Predicate<Workout> { $0.isFinished == true }, sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    @Query private var records: [PersonalRecord]

    @State private var workoutToDelete: Workout?

    private var sections: [(title: String, items: [Workout])] {
        var result: [(title: String, items: [Workout])] = []
        let cal = Lang.calendar
        for w in workouts {
            let title = w.startedAt.f(.dateTime.month(.wide).year())
            if let last = result.last, cal.isDate(last.items[0].startedAt, equalTo: w.startedAt, toGranularity: .month) {
                result[result.count - 1].items.append(w)
            } else {
                result.append((title: title, items: [w]))
            }
        }
        return result
    }

    private func prCount(_ w: Workout) -> Int {
        records.filter { $0.workoutID == w.id && !$0.isBaseline }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    ScrollView {
                        VStack(spacing: 16) {
                            Text(tr("History")).font(.lift(30, .bold)).frame(maxWidth: .infinity, alignment: .leading)
                            EmptyStateView(icon: "clock.arrow.circlepath", title: tr("No workouts yet"),
                                           message: tr("Completed workouts will be listed here so you can review or repeat them."),
                                           actionTitle: tr("Start Workout")) { router.tab = .workout }
                                .card()
                        }
                        .padding(16)
                    }
                } else {
                    List {
                        Text(tr("History")).font(.lift(30, .bold))
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                        ForEach(sections, id: \.title) { section in
                            Section {
                                ForEach(section.items) { w in
                                    row(w)
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) { workoutToDelete = w } label: {
                                                Label(tr("Delete"), systemImage: "trash")
                                            }
                                        }
                                }
                            } header: {
                                Text(section.title).font(.lift(13, .bold)).foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .screenBackground()
            .tabBarClearance()
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(tr("Delete workout?"), isPresented: Binding(get: { workoutToDelete != nil },
                                                                       set: { if !$0 { workoutToDelete = nil } }),
                                titleVisibility: .visible) {
                Button(tr("Delete"), role: .destructive) {
                    if let w = workoutToDelete { withAnimation { WorkoutService.delete(w, context: context) } }
                    workoutToDelete = nil
                }
                Button(tr("Cancel"), role: .cancel) { workoutToDelete = nil }
            } message: {
                Text(tr("Progress and records will be recalculated."))
            }
        }
    }

    private func row(_ w: Workout) -> some View {
        ZStack {
            NavigationLink { WorkoutDetailView(workout: w) } label: { EmptyView() }.opacity(0)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr(w.name)).font(.lift(17, .bold))
                        Text(w.startedAt.f(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                            .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    if prCount(w) > 0 {
                        Label(trf("%d PR", prCount(w)), systemImage: "trophy.fill")
                            .font(.lift(12, .bold)).foregroundStyle(Theme.accent)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Theme.accent.opacity(0.15), in: Capsule())
                    }
                }
                HStack(spacing: 18) {
                    stat(durationString(w.duration), tr("time"))
                    stat("\(w.completedSets.count)", tr("sets"))
                    stat(unit.formatVolume(w.totalVolumeKg), unit.label)
                }
                Text(w.sortedExercises.map { tr($0.exercise?.name ?? $0.exerciseName) }.joined(separator: " · "))
                    .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary).lineLimit(2)
            }
            .card()
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.lift(16, .bold))
            Text(label).font(.lift(11, .medium)).foregroundStyle(Theme.textSecondary)
        }
    }
}

// MARK: - Detail

struct WorkoutDetailView: View {
    @Bindable var workout: Workout

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var unit
    @Environment(AppRouter.self) private var router
    @Query private var records: [PersonalRecord]

    @State private var isEditing = false
    @State private var changed = false
    @State private var confirmDelete = false
    @State private var savedProgram = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    StatTile(title: tr("Duration"), value: durationString(workout.duration), icon: "clock.fill")
                    StatTile(title: tr("Volume"), value: unit.formatVolume(workout.totalVolumeKg), unit: unit.label, icon: "scalemass.fill")
                    StatTile(title: tr("Sets"), value: "\(workout.completedSets.count)", icon: "checkmark.circle.fill")
                    StatTile(title: tr("Exercises"), value: "\(workout.exercises.count)", icon: "dumbbell.fill")
                }

                if isEditing {
                    TextField(tr("Notes"), text: $workout.note, axis: .vertical)
                        .font(.lift(14, .medium))
                        .lineLimit(1...5)
                        .padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                        .onChange(of: workout.note) { _, _ in changed = true }
                } else if !workout.note.isEmpty {
                    Text(workout.note)
                        .font(.lift(14, .medium)).foregroundStyle(Theme.textSecondary)
                        .card()
                }

                ForEach(workout.sortedExercises) { entry in
                    exerciseCard(entry)
                }

                Button { saveAsProgram() } label: { Label(tr("Save as program"), systemImage: "square.and.arrow.down") }
                    .buttonStyle(SoftButtonStyle())
                    .frame(maxWidth: .infinity)

                Button {
                    WorkoutService.repeatWorkout(workout, context: context, router: router)
                } label: { Label(tr("Repeat Workout"), systemImage: "arrow.counterclockwise") }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 4)

                Button(role: .destructive) { confirmDelete = true } label: {
                    Label(tr("Delete Workout"), systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.danger))
            }
            .padding(16)
        }
        .screenBackground()
        .tabBarClearance()
        .navigationTitle(tr(workout.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? tr("Done") : tr("Edit")) {
                    if isEditing { commitEdits() }
                    withAnimation { isEditing.toggle() }
                }
                .fontWeight(.semibold)
            }
        }
        .onDisappear { if changed { commitEdits() } }
        .alert(tr("Program saved"), isPresented: $savedProgram) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(tr("You can find it in Workout → Programs."))
        }
        .confirmationDialog(tr("Delete workout?"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(tr("Delete"), role: .destructive) {
                WorkoutService.delete(workout, context: context)
                dismiss()
            }
            Button(tr("Cancel"), role: .cancel) {}
        } message: {
            Text(tr("Progress and records will be recalculated."))
        }
    }

    private func workingNumber(_ entry: WorkoutExercise, _ idx: Int) -> Int {
        entry.sortedSets.prefix(idx + 1).filter { !$0.isWarmup }.count
    }

    private func saveAsProgram() {
        let t = WorkoutTemplate(name: tr(workout.name))
        context.insert(t)
        for (i, we) in workout.sortedExercises.enumerated() {
            guard let ex = we.exercise else { continue }
            let working = we.sortedSets.filter { !$0.isWarmup }
            guard !working.isEmpty else { continue }
            let reps = working.map { $0.reps }
            let lo = reps.min() ?? 10, hi = reps.max() ?? 10
            let item = TemplateItem(order: i, exercise: ex, sets: working.count, reps: lo,
                                    weightKg: working.map { $0.weightKg }.max() ?? 0)
            item.repsMax = hi > lo ? hi : 0
            item.restSeconds = we.restSeconds
            context.insert(item)
            item.template = t
        }
        try? context.save()
        Haptics.success()
        savedProgram = true
    }

    private func commitEdits() {
        try? context.save()
        StatsService.rebuildRecords(context)
        changed = false
    }

    private func exerciseCard(_ entry: WorkoutExercise) -> some View {
        let exID = entry.exercise?.id
        let prs = records.filter { $0.workoutID == workout.id && $0.exerciseID == exID && !$0.isBaseline }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(tr(entry.exercise?.name ?? entry.exerciseName)).font(.lift(18, .bold))
                Spacer()
                if !prs.isEmpty {
                    Label(tr("PR"), systemImage: "trophy.fill")
                        .font(.lift(12, .bold)).foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Theme.accent.opacity(0.15), in: Capsule())
                }
            }
            if !prs.isEmpty {
                Text(prs.map { "\($0.type.title): \($0.type.formatted($0.value, unit: unit))" }.joined(separator: " · "))
                    .font(.lift(11, .medium)).foregroundStyle(Theme.accent)
            }
            ForEach(Array(entry.sortedSets.enumerated()), id: \.element.id) { idx, s in
                if isEditing {
                    SetRowView(item: s, index: workingNumber(entry, idx), showsPrev: false, showsCheck: false)
                        .onChange(of: s.weightKg) { _, _ in changed = true }
                        .onChange(of: s.reps) { _, _ in changed = true }
                        .contextMenu {
                            Button(role: .destructive) {
                                WorkoutService.removeSet(s, from: entry, context: context)
                                changed = true
                            } label: { Label(tr("Delete set"), systemImage: "trash") }
                        }
                } else {
                    HStack {
                        Text(s.isWarmup ? "W" : "\(workingNumber(entry, idx))")
                            .font(.lift(14, .bold))
                            .foregroundStyle(s.isWarmup ? Color.orange : Theme.textSecondary)
                            .frame(width: 24, alignment: .leading)
                        Text("\(unit.format(s.weightKg)) × \(s.reps)").font(.lift(15, .semibold))
                        Spacer()
                        let e1 = Formulas.epley1RM(weight: s.weightKg, reps: s.reps)
                        if e1 > 0 && !s.isWarmup {
                            Text("≈ \(unit.format(e1)) \(tr("1RM"))").font(.lift(11, .medium)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
        .card()
    }
}
