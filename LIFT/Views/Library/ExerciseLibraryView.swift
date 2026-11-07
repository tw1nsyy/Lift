import SwiftUI
import SwiftData

/// Browse mode (`onPick == nil`) shows the library with details.
/// Pick mode lets the user select several exercises and returns them via `onPick`.
struct ExerciseLibraryView: View {
    var onPick: (([Exercise]) -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var search = ""
    @State private var muscleFilter: MuscleGroup?
    @State private var favoritesOnly = false
    @State private var selection: [UUID] = []
    @State private var showAdd = false
    @State private var blockedDelete = false

    private var isPicking: Bool { onPick != nil }

    private var filtered: [Exercise] {
        exercises.filter { ex in
            (muscleFilter == nil || ex.muscle == muscleFilter)
            && (!favoritesOnly || ex.isFavorite)
            && (search.isEmpty || ex.name.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        List {
            Section {
                filterChips
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            ForEach(MuscleGroup.allCases) { group in
                let items = filtered.filter { $0.muscle == group }
                if !items.isEmpty {
                    Section(group.rawValue) {
                        ForEach(items) { ex in
                            row(ex)
                                .deleteDisabled(!ex.isCustom || isPicking)
                        }
                        .onDelete { offsets in delete(items, offsets) }
                    }
                    .listRowBackground(Theme.card)
                }
            }

            if filtered.isEmpty {
                EmptyStateView(icon: "magnifyingglass", title: "No exercises found",
                               message: favoritesOnly ? "Swipe an exercise to the right to add it to favourites."
                                                      : "Try another search or create your own exercise.",
                               actionTitle: "Create Exercise") { showAdd = true }
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle(isPicking ? "Add Exercises" : "Exercise Library")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Search exercises")
        .toolbar {
            if isPicking {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isPicking && !selection.isEmpty {
                Button {
                    let picked = selection.compactMap { id in exercises.first { $0.id == id } }
                    onPick?(picked)
                    dismiss()
                } label: { Text("Add \(selection.count) exercise\(selection.count == 1 ? "" : "s")") }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(16)
                    .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showAdd) { AddExerciseView() }
        .alert("Can't delete", isPresented: $blockedDelete) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This exercise is part of your workout history. Delete those workouts first.")
        }
    }

    // MARK: Pieces

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", isOn: muscleFilter == nil && !favoritesOnly) {
                    muscleFilter = nil; favoritesOnly = false
                }
                chip("★ Favorites", isOn: favoritesOnly) { favoritesOnly.toggle(); if favoritesOnly { muscleFilter = nil } }
                ForEach(MuscleGroup.allCases) { g in
                    chip(g.rawValue, isOn: muscleFilter == g) {
                        muscleFilter = (muscleFilter == g) ? nil : g
                        favoritesOnly = false
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.easeInOut(duration: 0.2)) { action() }
        } label: {
            Text(title)
                .font(.lift(13, .bold))
                .foregroundStyle(isOn ? Theme.background : Theme.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(isOn ? Theme.textPrimary : Theme.card, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func row(_ ex: Exercise) -> some View {
        if isPicking {
            Button {
                Haptics.tap()
                if let i = selection.firstIndex(of: ex.id) { selection.remove(at: i) } else { selection.append(ex.id) }
            } label: {
                HStack(spacing: 12) {
                    label(ex)
                    Image(systemName: selection.contains(ex.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(selection.contains(ex.id) ? Theme.accent : Theme.textSecondary)
                }
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink { ExerciseDetailView(exercise: ex) } label: { label(ex) }
                .swipeActions(edge: .leading) {
                    Button { ex.isFavorite.toggle(); try? context.save() } label: {
                        Label(ex.isFavorite ? "Unfavorite" : "Favorite", systemImage: ex.isFavorite ? "star.slash" : "star.fill")
                    }
                    .tint(.yellow)
                }
        }
    }

    private func label(_ ex: Exercise) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ex.muscle.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(Theme.cardHigh, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(ex.name).font(.lift(16, .semibold))
                    if ex.isFavorite { Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(.yellow) }
                }
                Text("\(ex.muscle.rawValue) · \(ex.equipment.rawValue)\(ex.isCustom ? " · Custom" : "")")
                    .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func delete(_ items: [Exercise], _ offsets: IndexSet) {
        for i in offsets {
            let ex = items[i]
            guard ex.isCustom else { continue }
            let all = (try? context.fetch(FetchDescriptor<WorkoutExercise>())) ?? []
            if all.contains(where: { $0.exercise?.id == ex.id }) {
                blockedDelete = true
            } else {
                context.delete(ex)
            }
        }
        try? context.save()
    }
}

// MARK: - Detail

struct ExerciseDetailView: View {
    @Bindable var exercise: Exercise
    @Environment(\.modelContext) private var context
    @Environment(\.weightUnit) private var unit
    @Environment(AppRouter.self) private var router
    @Query(filter: #Predicate<Workout> { $0.isFinished == true }, sort: \Workout.startedAt) private var workouts: [Workout]

    var body: some View {
        let sessions = StatsService.sessions(for: exercise, in: workouts)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Tag(text: exercise.muscle.rawValue)
                    Tag(text: exercise.equipment.rawValue)
                    if exercise.isCustom { Tag(text: "Custom") }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Technique").font(.lift(18, .bold))
                    Text(exercise.technique.isEmpty ? "No description added." : exercise.technique)
                        .font(.lift(15, .medium)).foregroundStyle(Theme.textSecondary)
                }
                .card()

                if sessions.isEmpty {
                    Text("You haven't logged this exercise yet.")
                        .font(.lift(13, .medium)).foregroundStyle(Theme.textSecondary)
                } else {
                    let summary = ExerciseSummary(sessions: sessions)
                    HStack(spacing: 12) {
                        StatTile(title: "Sessions", value: "\(sessions.count)")
                        StatTile(title: "Best 1RM (est.)", value: unit.format(summary.bestE1RMKg, withUnit: false), unit: unit.label)
                    }
                    Button {
                        router.progressExerciseID = exercise.id
                        router.tab = .progress
                    } label: { Label("View Progress", systemImage: "chart.line.uptrend.xyaxis") }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Haptics.tap()
                    exercise.isFavorite.toggle()
                    try? context.save()
                } label: {
                    Image(systemName: exercise.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(exercise.isFavorite ? Color.yellow : Theme.textPrimary)
                }
            }
        }
    }
}

// MARK: - Custom exercise

struct AddExerciseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var muscle: MuscleGroup = .chest
    @State private var equipment: Equipment = .barbell
    @State private var technique = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Cable Crossover", text: $name)
                }
                Section("Details") {
                    Picker("Muscle group", selection: $muscle) {
                        ForEach(MuscleGroup.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Equipment", selection: $equipment) {
                        ForEach(Equipment.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("Technique (optional)") {
                    TextField("How to perform it", text: $technique, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        context.insert(Exercise(name: trimmed, muscle: muscle, equipment: equipment,
                                                technique: technique, isCustom: true))
                        try? context.save()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
