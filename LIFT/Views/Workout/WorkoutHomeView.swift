import SwiftUI
import SwiftData

struct WorkoutHomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(sort: \WorkoutTemplate.createdAt) private var templates: [WorkoutTemplate]
    @Query(filter: #Predicate<Workout> { $0.isFinished == true }, sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    @Query(filter: #Predicate<Workout> { $0.isFinished == false }) private var active: [Workout]

    @State private var workoutName = ""
    @State private var editingTemplate: WorkoutTemplate?
    @State private var editingIsNew = false
    @State private var templateToDelete: WorkoutTemplate?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(tr("Workout"))
                        .font(.lift(30, .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    startCard
                    quickActions
                    templatesSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .tabBarClearance()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editingTemplate) { t in
                TemplateEditorView(template: t, isNew: editingIsNew)
            }
            .confirmationDialog(tr("Delete program?"), isPresented: Binding(get: { templateToDelete != nil },
                                                                       set: { if !$0 { templateToDelete = nil } }),
                                titleVisibility: .visible) {
                Button(tr("Delete"), role: .destructive) {
                    if let t = templateToDelete { context.delete(t); try? context.save() }
                    templateToDelete = nil
                }
                Button(tr("Cancel"), role: .cancel) { templateToDelete = nil }
            } message: {
                Text(tr("Past workouts are not affected."))
            }
        }
    }

    // MARK: Start

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let a = active.first {
                HStack {
                    Image(systemName: "bolt.heart.fill").foregroundStyle(Theme.accent)
                    Text(tr("Workout in progress")).font(.lift(17, .bold))
                }
                Text("\(tr(a.name)) · \(trf("%d sets done", a.completedSets.count))")
                    .font(.lift(13, .medium)).foregroundStyle(Theme.textSecondary)
                Button {
                    router.presentedWorkout = a
                } label: { Label(tr("Resume Workout"), systemImage: "arrow.right") }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                Text(tr("New workout")).font(.lift(17, .bold))
                TextField(WorkoutService.defaultName(), text: $workoutName)
                    .font(.lift(16, .semibold))
                    .padding(12)
                    .background(Theme.cardHigh, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Button {
                    Haptics.tap()
                    let name = workoutName.trimmingCharacters(in: .whitespaces)
                    WorkoutService.begin(name: name.isEmpty ? nil : name, context: context, router: router)
                    workoutName = ""
                } label: { Label(tr("Start Empty Workout"), systemImage: "play.fill") }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .card()
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            NavigationLink { ExerciseLibraryView() } label: {
                quickTile(icon: "books.vertical.fill", title: tr("Exercise Library"))
            }
            .buttonStyle(.plain)

            Button {
                if let last = workouts.first {
                    WorkoutService.repeatWorkout(last, context: context, router: router)
                }
            } label: {
                quickTile(icon: "arrow.counterclockwise", title: tr("Repeat Last"))
            }
            .buttonStyle(.plain)
            .disabled(workouts.isEmpty)
            .opacity(workouts.isEmpty ? 0.45 : 1)
        }
    }

    private func quickTile(icon: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.accent)
            Text(title).font(.lift(15, .bold)).foregroundStyle(Theme.textPrimary)
        }
        .card()
    }

    // MARK: Templates

    private var templatesSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text(tr("Programs")).font(.lift(20, .bold))
                Spacer()
                Button {
                    let t = WorkoutTemplate(name: "")
                    context.insert(t)
                    editingIsNew = true
                    editingTemplate = t
                } label: { Label(tr("New"), systemImage: "plus") }
                    .buttonStyle(SoftButtonStyle())
            }
            if templates.isEmpty {
                EmptyStateView(icon: "list.bullet.rectangle", title: tr("No programs yet"),
                               message: tr("Save your favourite routines as programs and start them in one tap."))
                    .card()
            }
            ForEach(templates) { t in
                templateCard(t)
            }
        }
    }

    private func templateCard(_ t: WorkoutTemplate) -> some View {
        let names = t.sortedItems.compactMap { $0.exercise.map { tr($0.name) } }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr(t.name)).font(.lift(18, .bold))
                    Text("\(countText(names.count, .exercise)) · \(countText(t.totalSets, .set))")
                        .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Menu {
                    Button { editingIsNew = false; editingTemplate = t } label: { Label(tr("Edit"), systemImage: "pencil") }
                    Button(role: .destructive) { templateToDelete = t } label: { Label(tr("Delete"), systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 32, height: 32)
                        .background(Theme.cardHigh, in: Circle())
                }
                .foregroundStyle(Theme.textPrimary)
            }
            Text(names.joined(separator: " · "))
                .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary).lineLimit(2)
            if t.weekdayMask != 0 {
                let days = (1...7).filter { t.isPlanned(weekday: $0) }.map { Lang.calendar.shortWeekdaySymbols[$0 - 1] }
                Label(days.joined(separator: ", "), systemImage: "calendar")
                    .font(.lift(12, .semibold)).foregroundStyle(Theme.accent)
            }
            Button {
                Haptics.tap()
                WorkoutService.begin(template: t, context: context, router: router)
            } label: {
                Label(active.isEmpty ? tr("Start") : tr("Finish current workout first"), systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SoftButtonStyle())
            .disabled(!active.isEmpty || names.isEmpty)
        }
        .card()
    }
}

// MARK: - Template editor

struct TemplateEditorView: View {
    @Bindable var template: WorkoutTemplate
    let isNew: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var unit
    @State private var showPicker = false
    @State private var saved = false
    @State private var snapshot: Snapshot?
    @Query(filter: #Predicate<Workout> { $0.isFinished == true }, sort: \Workout.startedAt)
    private var workouts: [Workout]

    private struct Snapshot {
        struct Item { let exercise: Exercise?; let sets: Int; let reps: Int; let weightKg: Double; let repsMax: Int; let restSeconds: Int }
        let name: String
        let mask: Int
        let progression: String
        let rir: Int
        let items: [Item]
    }

    private var uniqueExercises: [Exercise] {
        var seen = Set<UUID>()
        return template.sortedItems.compactMap { $0.exercise }.filter { seen.insert($0.id).inserted }
    }

    private func historyKg(_ ex: Exercise) -> Double {
        StatsService.sessions(for: ex, in: workouts).map { $0.e1RMKg }.max() ?? 0
    }

    private var orderedWeekdays: [Int] {
        (0..<7).map { (Lang.calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section(tr("Name")) {
                    TextField(tr("Program name"), text: $template.name)
                        .font(.lift(17, .semibold))
                }
                .listRowBackground(Theme.card)

                Section(tr("Plan days")) {
                    HStack(spacing: 6) {
                        ForEach(orderedWeekdays, id: \.self) { d in
                            let on = template.isPlanned(weekday: d)
                            Button {
                                Haptics.tap()
                                template.setPlanned(weekday: d, !on)
                            } label: {
                                Text(Lang.calendar.shortWeekdaySymbols[d - 1].prefix(2))
                                    .font(.lift(12, .bold))
                                    .foregroundStyle(on ? Theme.background : Theme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(on ? Theme.textPrimary : Theme.cardHigh, in: Capsule())
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    Text(tr("Planned programs are suggested on the Today screen."))
                        .font(.lift(11, .medium)).foregroundStyle(Theme.textSecondary)
                }
                .listRowBackground(Theme.card)

                Section(tr("Load & progression")) {
                    Picker(tr("Progression model"), selection: Binding(get: { template.progression }, set: { template.progression = $0 })) {
                        ForEach(ProgressionModel.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    Text(template.progression.summary)
                        .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
                    Stepper(value: $template.rir, in: 0...4) {
                        Text(trf("Reps in reserve: %d", template.rir)).font(.lift(14, .medium))
                    }
                    Text(tr("Reps in reserve are how many more reps you could still do. 1–3 is a common range."))
                        .font(.lift(11, .medium)).foregroundStyle(Theme.textSecondary)
                    NavigationLink { ScienceView() } label: { Label(tr("Scientific basis"), systemImage: "book") }
                }
                .listRowBackground(Theme.card)

                Section(tr("Exercises")) {
                    ForEach(template.sortedItems) { item in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(item.exercise.map { tr($0.name) } ?? tr("Removed exercise")).font(.lift(16, .bold))
                            Stepper(value: Binding(get: { item.sets }, set: { item.sets = $0 }), in: 1...10) {
                                Text(trf("Sets: %d", item.sets)).font(.lift(14, .medium))
                            }
                            Stepper(value: Binding(get: { item.reps }, set: { item.reps = $0 }), in: 1...50) {
                                Text(trf("Reps: %d", item.reps)).font(.lift(14, .medium))
                            }
                            Stepper(value: Binding(get: { item.repsMax }, set: { item.repsMax = $0 }), in: 0...50) {
                                Text(item.repsMax == 0 ? tr("Max reps: —") : trf("Max reps: %d", item.repsMax)).font(.lift(14, .medium))
                            }
                            Stepper(value: Binding(get: { item.restSeconds }, set: { item.restSeconds = $0 }), in: 0...300, step: 15) {
                                Text(item.restSeconds == 0 ? tr("Rest: default") : trf("Rest: %@", countdownString(Double(item.restSeconds))))
                                    .font(.lift(14, .medium))
                            }
                            planPreview(item)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        let items = template.sortedItems
                        for i in offsets {
                            template.items.removeAll { $0.id == items[i].id }
                            context.delete(items[i])
                        }
                        for (i, it) in template.sortedItems.enumerated() { it.order = i }
                    }
                    .onMove { from, to in
                        var items = template.sortedItems
                        items.move(fromOffsets: from, toOffset: to)
                        for (i, it) in items.enumerated() { it.order = i }
                    }

                    Button { showPicker = true } label: { Label(tr("Add Exercise"), systemImage: "plus") }
                }
                .listRowBackground(Theme.card)

                Section(tr("My maxes")) {
                    if uniqueExercises.isEmpty {
                        Text(tr("No exercises in this program yet.")).font(.lift(13, .medium)).foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(uniqueExercises) { ex in
                        MaxRow(exercise: ex, historyKg: historyKg(ex))
                    }
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(isNew ? tr("New Program") : tr("Edit Program"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Cancel")) { cancel() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(tr("Save")) { save() }.fontWeight(.bold)
                }
                ToolbarItem(placement: .bottomBar) { EditButton() }
            }
            .sheet(isPresented: $showPicker) {
                NavigationStack {
                    ExerciseLibraryView { picked in
                        for ex in picked {
                            let item = TemplateItem(order: template.items.count, exercise: ex)
                            context.insert(item)
                            item.template = template
                        }
                    }
                }
            }
            .interactiveDismissDisabled()
            .onAppear {
                if snapshot == nil {
                    snapshot = Snapshot(name: template.name, mask: template.weekdayMask,
                                        progression: template.progressionRaw, rir: template.rir,
                                        items: template.sortedItems.map {
                                            .init(exercise: $0.exercise, sets: $0.sets, reps: $0.reps, weightKg: $0.weightKg,
                                                    repsMax: $0.repsMax, restSeconds: $0.restSeconds)
                                        })
                }
            }
        }
    }

    @ViewBuilder
    private func planPreview(_ item: TemplateItem) -> some View {
        if let ex = item.exercise {
            if let p = LoadPlanner.plan(exercise: ex, repsMin: item.reps, repsMax: item.repsMax,
                                        model: template.progression, rir: template.rir,
                                        sessions: StatsService.sessions(for: ex, in: workouts), unit: unit) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(trf("Today: %@ × %d", unit.format(p.weightKg), p.reps), systemImage: "scalemass.fill")
                        .font(.lift(13, .bold)).foregroundStyle(Theme.accent)
                    Text(p.note).font(.lift(11, .medium)).foregroundStyle(Theme.textSecondary)
                }
            } else {
                Text(tr("Set your 1RM below to see weights."))
                    .font(.lift(11, .medium)).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func save() {
        if template.name.trimmingCharacters(in: .whitespaces).isEmpty { template.name = tr("My Program") }
        try? context.save()
        saved = true
        dismiss()
    }

    private func cancel() {
        if isNew {
            context.delete(template)
        } else if let snap = snapshot {
            // Roll the program back to how it was when the editor opened.
            for it in template.items { context.delete(it) }
            template.items.removeAll()
            template.name = snap.name
            template.weekdayMask = snap.mask
            template.progressionRaw = snap.progression
            template.rir = snap.rir
            for (i, item) in snap.items.enumerated() {
                guard let ex = item.exercise else { continue }
                let restored = TemplateItem(order: i, exercise: ex, sets: item.sets, reps: item.reps, weightKg: item.weightKg)
                restored.repsMax = item.repsMax
                restored.restSeconds = item.restSeconds
                context.insert(restored)
                restored.template = template
            }
        }
        try? context.save()
        dismiss()
    }
}
