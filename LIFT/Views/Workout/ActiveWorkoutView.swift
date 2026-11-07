import SwiftUI
import SwiftData

struct WorkoutSummaryData {
    let name: String
    let duration: TimeInterval
    let volumeKg: Double
    let sets: Int
    let exercises: Int
    let records: [RecordDisplay]
}

struct ActiveWorkoutView: View {
    @Bindable var workout: Workout

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var unit
    @Environment(RestTimerManager.self) private var timer
    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<Workout> { $0.isFinished == true }, sort: \Workout.startedAt)
    private var history: [Workout]

    @State private var showPicker = false
    @State private var showTimerSheet = false
    @State private var confirmFinish = false
    @State private var confirmDiscard = false
    @State private var showNoSets = false
    @State private var toast: (title: String, subtitle: String)?
    @State private var summary: WorkoutSummaryData?

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let summary {
                WorkoutSummaryView(data: summary) { dismiss() }
                    .transition(.opacity)
            } else {
                content
            }
        }
        .preferredColorScheme(profile?.theme.colorScheme)
        .animation(.easeInOut(duration: 0.25), value: summary == nil)
    }

    // MARK: Content

    private var content: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: 14) {
                    if workout.exercises.isEmpty {
                        EmptyStateView(icon: "dumbbell", title: tr("Add your first exercise"),
                                       message: tr("Pick exercises from the library. Weights and reps are prefilled from your last session."))
                            .card()
                    }
                    ForEach(workout.sortedExercises) { entry in
                        ExerciseCardView(entry: entry, history: history,
                                         onSetToggled: setToggled,
                                         onRemove: {
                                             withAnimation { WorkoutService.removeExercise(entry, from: workout, context: context) }
                                         })
                    }
                    TextField(tr("Workout notes"), text: $workout.note, axis: .vertical)
                        .font(.lift(14, .medium))
                        .lineLimit(1...5)
                        .padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                    Button { showPicker = true } label: { Label(tr("Add Exercise"), systemImage: "plus") }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)

            if timer.isActive {
                RestTimerBar { showTimerSheet = true }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: timer.isActive)
        .overlay(alignment: .top) {
            if let toast {
                ToastView(title: toast.title, subtitle: toast.subtitle)
                    .padding(.top, 56)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                ExerciseLibraryView { picked in
                    withAnimation {
                        for ex in picked { WorkoutService.addExercise(ex, to: workout, context: context) }
                    }
                }
            }
            .environment(\.weightUnit, unit)
        }
        .sheet(isPresented: $showTimerSheet) {
            RestTimerSheet()
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.background)
        }
        .confirmationDialog(tr("Finish workout?"), isPresented: $confirmFinish, titleVisibility: .visible) {
            Button(tr("Finish & Save")) { finish() }
            Button(tr("Keep training"), role: .cancel) {}
        } message: {
            Text(trf("%d sets completed · %@ %@ volume. Unchecked sets will be discarded.", workout.completedSets.count, unit.formatVolume(workout.totalVolumeKg), unit.label))
        }
        .confirmationDialog(tr("Discard this workout?"), isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button(tr("Discard Workout"), role: .destructive) {
                timer.stop()
                WorkoutService.discard(workout, context: context)
                dismiss()
            }
            Button(tr("Cancel"), role: .cancel) {}
        } message: {
            Text(tr("All data from this session will be deleted."))
        }
        .alert(tr("No completed sets"), isPresented: $showNoSets) {
            Button(tr("Keep training"), role: .cancel) {}
            Button(tr("Discard"), role: .destructive) {
                timer.stop()
                WorkoutService.discard(workout, context: context)
                dismiss()
            }
        } message: {
            Text(tr("Check off at least one set to save this workout."))
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down").frame(width: 20, height: 20)
            }
            .buttonStyle(SoftButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                TextField(tr("Workout name"), text: $workout.name)
                    .font(.lift(18, .bold))
                    .submitLabel(.done)
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(elapsedString(from: workout.startedAt, to: ctx.date))
                        .font(.lift(12, .medium)).monospacedDigit().foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 4)

            Menu {
                Button { showTimerSheet = true } label: { Label(tr("Rest timer"), systemImage: "timer") }
                Button(role: .destructive) { confirmDiscard = true } label: { Label(tr("Discard workout"), systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis").frame(width: 20, height: 20)
            }
            .buttonStyle(SoftButtonStyle())

            Button(tr("Finish")) { attemptFinish() }
                .font(.lift(15, .bold))
                .foregroundStyle(Theme.background)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Theme.textPrimary, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Actions

    private func setToggled(_ set: WorkoutSet, _ entry: WorkoutExercise) {
        guard set.isCompleted else { return }

        if let rec = StatsService.liveRecord(for: set, in: entry, history: history) {
            Haptics.success()
            let name = tr(entry.exercise?.name ?? entry.exerciseName)
            let text = rec.type == .oneRM ? trf("est. 1RM %@", unit.format(rec.valueKg)) : trf("max weight %@", unit.format(rec.valueKg))
            showToast(tr("New personal record!"), "\(name) · \(text)")
        }
        if profile?.autoStartRest ?? true {
            timer.soundEnabled = profile?.soundEnabled ?? true
            timer.hapticsEnabled = profile?.hapticsEnabled ?? true
            timer.notificationsEnabled = profile?.restAlertsEnabled ?? true
            timer.start(seconds: entry.restSeconds > 0 ? entry.restSeconds : (profile?.defaultRestSeconds ?? 90))
        }
    }

    private func showToast(_ title: String, _ subtitle: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { toast = (title, subtitle) }
        Task {
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation(.easeOut(duration: 0.25)) { toast = nil }
        }
    }

    private func attemptFinish() {
        hideKeyboard()
        if workout.completedSets.isEmpty { showNoSets = true } else { confirmFinish = true }
    }

    private func finish() {
        timer.stop()
        let totalSets = workout.completedSets.count
        let volume = workout.totalVolumeKg
        let exCount = workout.exercises.filter { $0.sets.contains { $0.isCompleted } }.count
        let name = workout.name
        let start = workout.startedAt
        let records = WorkoutService.finish(workout, context: context)
        Haptics.success()
        summary = WorkoutSummaryData(name: name, duration: Date().timeIntervalSince(start),
                                     volumeKg: volume, sets: totalSets, exercises: exCount, records: records)
    }
}

// MARK: - Exercise card

struct ExerciseCardView: View {
    @Bindable var entry: WorkoutExercise
    let history: [Workout]
    let onSetToggled: (WorkoutSet, WorkoutExercise) -> Void
    let onRemove: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.weightUnit) private var unit
    @Query private var profiles: [UserProfile]

    private var targetText: String? {
        guard entry.repsMin > 0 else { return nil }
        let range = entry.repsMax > entry.repsMin ? "\(entry.repsMin)–\(entry.repsMax)" : "\(entry.repsMin)"
        var t = trf("Target: %@ reps", range)
        if entry.restSeconds > 0 { t += " · " + trf("rest %@", countdownString(Double(entry.restSeconds))) }
        return t
    }

    private var suggestion: ProgressionSuggestion? {
        guard let ex = entry.exercise, let prev = previous else { return nil }
        return StatsService.suggestion(for: ex, last: prev, stepKg: profiles.first?.progressionStepKg ?? 2.0, unit: unit,
                                       targetMin: entry.repsMin > 0 ? entry.repsMin : 8,
                                       targetMax: entry.repsMax > 0 ? entry.repsMax : 8)
    }

    private func workingIndex(of s: WorkoutSet) -> Int {
        entry.sortedSets.filter { !$0.isWarmup && $0.order <= s.order }.count
    }

    private func apply(_ sg: ProgressionSuggestion) {
        Haptics.tap()
        for s in entry.sets where !s.isCompleted && !s.isWarmup {
            s.weightKg = sg.weightKg
            s.reps = sg.reps
        }
    }

    private var previous: ExerciseSession? {
        guard let ex = entry.exercise else { return nil }
        return StatsService.sessions(for: ex, in: history).last
    }

    var body: some View {
        let prev = previous
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr(entry.exercise?.name ?? entry.exerciseName)).font(.lift(20, .bold))
                    HStack(spacing: 6) {
                        if let ex = entry.exercise {
                            Tag(text: ex.muscle.title)
                            Tag(text: ex.equipment.title)
                        }
                    }
                }
                Spacer()
                Menu {
                    Button { addSet() } label: { Label(tr("Add set"), systemImage: "plus") }
                    Button {
                        withAnimation { WorkoutService.addWarmup(to: entry, context: context) }
                    } label: { Label(tr("Add warm-up set"), systemImage: "flame") }
                    Button(role: .destructive, action: onRemove) { Label(tr("Remove exercise"), systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 32, height: 32)
                        .background(Theme.cardHigh, in: Circle())
                }
                .foregroundStyle(Theme.textPrimary)
            }

            if let t = targetText {
                Label(t, systemImage: "target")
                    .font(.lift(12, .semibold)).foregroundStyle(Theme.accent)
            }

            if let prev {
                Text(tr("Last time · ") + prev.sets.map { "\(unit.format($0.weightKg, withUnit: false))×\($0.reps)" }.joined(separator: "  "))
                    .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary).lineLimit(2)
            } else {
                Text(tr("No previous results yet")).font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
            }

            if let sg = suggestion, entry.sets.contains(where: { !$0.isCompleted && !$0.isWarmup }) {
                HStack(spacing: 10) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trf("Suggested: %@ × %d", unit.format(sg.weightKg), sg.reps)).font(.lift(13, .bold))
                        Text(sg.reason).font(.lift(11, .medium)).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 4)
                    Button(tr("Apply")) { apply(sg) }.buttonStyle(SoftButtonStyle(tint: Theme.accent))
                }
                .padding(10)
                .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack(spacing: 8) {
                Text(tr("SET")).frame(width: 24)
                Text(tr("PREV")).frame(width: 62)
                Text(unit.label.uppercased()).frame(maxWidth: .infinity)
                Text(tr("REPS")).frame(maxWidth: .infinity)
                Image(systemName: "checkmark").frame(width: 36)
            }
            .font(.lift(10, .bold))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 6)

            VStack(spacing: 6) {
                ForEach(entry.sortedSets) { s in
                    let wIdx = workingIndex(of: s)
                    SetRowView(item: s, index: wIdx,
                               prev: s.isWarmup ? nil : prev.flatMap { $0.sets.indices.contains(wIdx - 1) ? $0.sets[wIdx - 1] : nil },
                               onToggle: { onSetToggled($0, entry) })
                    .contextMenu {
                        Button { s.isWarmup.toggle() } label: {
                            Label(s.isWarmup ? tr("Mark as working set") : tr("Mark as warm-up"), systemImage: "flame")
                        }
                        Button(role: .destructive) {
                            withAnimation { WorkoutService.removeSet(s, from: entry, context: context) }
                        } label: { Label(tr("Delete set"), systemImage: "trash") }
                    }
                }
            }

            HStack(spacing: 10) {
                Button { addSet() } label: { Label(tr("Add Set"), systemImage: "plus") }
                    .buttonStyle(SoftButtonStyle())
                if entry.sets.count > 1 {
                    Button {
                        if let last = entry.sortedSets.last {
                            withAnimation { WorkoutService.removeSet(last, from: entry, context: context) }
                        }
                    } label: { Label(tr("Remove Last"), systemImage: "minus") }
                        .buttonStyle(SoftButtonStyle(tint: Theme.textSecondary))
                }
            }
        }
        .card()
    }

    private func addSet() {
        Haptics.tap()
        withAnimation { WorkoutService.addSet(to: entry, context: context) }
    }
}

// MARK: - Summary

struct WorkoutSummaryView: View {
    let data: WorkoutSummaryData
    let onDone: () -> Void
    @Environment(\.weightUnit) private var unit

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: data.records.isEmpty ? "checkmark.seal.fill" : "trophy.fill")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .padding(.top, 40)
                        .symbolEffect(.bounce, options: .nonRepeating)
                    Text(tr("Workout complete")).font(.lift(28, .bold))
                    Text(tr(data.name)).font(.lift(15, .medium)).foregroundStyle(Theme.textSecondary)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        StatTile(title: tr("Duration"), value: durationString(data.duration), icon: "clock.fill")
                        StatTile(title: tr("Volume"), value: unit.formatVolume(data.volumeKg), unit: unit.label, icon: "scalemass.fill")
                        StatTile(title: tr("Sets"), value: "\(data.sets)", icon: "checkmark.circle.fill")
                        StatTile(title: tr("Exercises"), value: "\(data.exercises)", icon: "dumbbell.fill")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(tr("New personal records")).font(.lift(18, .bold))
                        if data.records.isEmpty {
                            Text(tr("No new records this time. Consistency builds them."))
                                .font(.lift(13, .medium)).foregroundStyle(Theme.textSecondary)
                        } else {
                            ForEach(data.records) { r in
                                HStack(spacing: 10) {
                                    Image(systemName: "trophy.fill").foregroundStyle(Theme.accent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tr(r.exerciseName)).font(.lift(15, .semibold))
                                        Text(r.type.title).font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer()
                                    Text(r.type.formatted(r.valueKg, unit: unit)).font(.lift(16, .bold))
                                }
                            }
                            Text(tr("1RM values are estimates (Epley: weight × (1 + reps ÷ 30)), not verified max lifts."))
                                .font(.lift(11, .medium)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .card()
                }
                .padding(.horizontal, 16)
            }
            Button(tr("Done")) { onDone() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(16)
        }
    }
}
