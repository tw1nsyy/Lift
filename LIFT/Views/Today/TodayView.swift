import SwiftUI
import SwiftData
import Charts

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.weightUnit) private var unit
    @Environment(AppRouter.self) private var router
    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<Workout> { $0.isFinished == true }, sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    @Query(filter: #Predicate<Workout> { $0.isFinished == false }) private var active: [Workout]
    @Query(sort: \PersonalRecord.date, order: .reverse) private var records: [PersonalRecord]
    @Query(sort: \WorkoutTemplate.createdAt) private var templates: [WorkoutTemplate]

    @State private var displayedMonth = Date()
    @State private var selectedDay: Date?

    private var calendar: Calendar { Lang.calendar }
    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    startButton
                    if !plannedToday.isEmpty { planCard }
                    if workouts.contains(where: { $0.isDemo }) { demoBanner }
                    statGrid
                    muscleVolumeCard
                    leaderboardCard
                    calendarCard
                    lastWorkoutCard
                    recordsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .tabBarClearance()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: Header

    private var greeting: String {
        let h = calendar.component(.hour, from: Date())
        let part = h < 12 ? tr("Good morning") : (h < 18 ? tr("Good afternoon") : tr("Good evening"))
        let name = (profile?.name ?? "").trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? part : "\(part), \(name)"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date().f(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.lift(13, .semibold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.textSecondary)
            Text(greeting).font(.lift(30, .bold)).minimumScaleFactor(0.7).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var startButton: some View {
        Button {
            Haptics.tap()
            WorkoutService.begin(context: context, router: router)
        } label: {
            Label(active.isEmpty ? tr("Start Workout") : tr("Resume Workout"),
                  systemImage: active.isEmpty ? "play.fill" : "arrow.right")
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    // MARK: Weekly plan

    private var plannedToday: [WorkoutTemplate] {
        let wd = calendar.component(.weekday, from: Date())
        return templates.filter { $0.isPlanned(weekday: wd) }
    }

    private var doneToday: Bool {
        workouts.contains { calendar.isDateInToday($0.startedAt) && !$0.isDemo }
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(tr("Today's plan"), systemImage: "calendar.badge.clock").font(.lift(17, .bold))
                Spacer()
                if doneToday {
                    Label(tr("Done"), systemImage: "checkmark.circle.fill")
                        .font(.lift(12, .bold)).foregroundStyle(Theme.accent)
                }
            }
            ForEach(plannedToday) { t in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr(t.name)).font(.lift(15, .semibold))
                        Text("\(countText(t.items.count, .exercise)) · \(countText(t.totalSets, .set))")
                            .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Button(tr("Start")) {
                        WorkoutService.begin(template: t, context: context, router: router)
                    }
                    .buttonStyle(SoftButtonStyle())
                    .disabled(!active.isEmpty)
                }
            }
        }
        .card()
    }

    // MARK: Muscle volume

    private var muscleVolumeCard: some View {
        let data = StatsService.muscleVolume(workouts: workouts)
        let total = data.reduce(0) { $0 + $1.volumeKg }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tr("Volume by muscle")).font(.lift(20, .bold))
                Spacer()
                Text(tr("7 days")).font(.lift(12, .semibold)).foregroundStyle(Theme.textSecondary)
            }
            if total <= 0 {
                Text(tr("Finish a workout to see how your volume is split between muscle groups."))
                    .font(.lift(13, .medium)).foregroundStyle(Theme.textSecondary)
            } else {
                Chart(data, id: \.muscle) { item in
                    BarMark(x: .value("Volume", unit.display(item.volumeKg)),
                            y: .value("Muscle", item.muscle.title))
                        .foregroundStyle(Theme.accent)
                        .cornerRadius(6)
                        .annotation(position: .trailing) {
                            if item.volumeKg > 0 {
                                Text(unit.formatVolume(item.volumeKg))
                                    .font(.lift(11, .bold)).foregroundStyle(Theme.textSecondary)
                            }
                        }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { _ in AxisValueLabel().foregroundStyle(Theme.textPrimary) }
                }
                .frame(height: 210)
            }
        }
        .card()
    }

    private var leaderboardCard: some View {
        NavigationLink { LeaderboardView() } label: {
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 40)
                    .background(Theme.cardHigh, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Leaderboard")).font(.lift(17, .bold))
                    Text(tr("Compare with friends")).font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .foregroundStyle(Theme.textPrimary)
            .card()
        }
        .buttonStyle(.plain)
    }

    private var demoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles").foregroundStyle(Theme.accent)
            Text(tr("You're seeing demo data. It disappears automatically when you finish your first workout."))
                .font(.lift(12, .medium))
                .foregroundStyle(Theme.textSecondary)
            Button(tr("Remove")) {
                withAnimation { WorkoutService.deleteDemoData(context: context) }
            }
            .buttonStyle(SoftButtonStyle())
        }
        .card(padding: 12)
    }

    // MARK: Stats

    private var weekCount: Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return workouts.filter { interval.contains($0.startedAt) }.count
    }

    private var recentPRCount: Int {
        let cutoff = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return records.filter { !$0.isBaseline && $0.date >= cutoff }.count
    }

    private var statGrid: some View {
        let totalVolume = workouts.reduce(0) { $0 + $1.totalVolumeKg }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(title: tr("This week"), value: "\(weekCount)", unit: "/ \(profile?.weeklyGoal ?? 3)", icon: "flame.fill",
                     tint: weekCount >= (profile?.weeklyGoal ?? 3) ? Theme.accent : Theme.textPrimary)
            StatTile(title: tr("Workouts"), value: "\(workouts.count)", icon: "checkmark.circle.fill")
            StatTile(title: tr("Total volume"), value: unit.formatVolume(totalVolume), unit: unit.label, icon: "scalemass.fill")
            StatTile(title: tr("New PRs · 30 days"), value: "\(recentPRCount)", icon: "trophy.fill",
                     tint: recentPRCount > 0 ? Theme.accent : Theme.textPrimary)
        }
    }

    // MARK: Calendar

    private func workoutsOn(_ day: Date) -> [Workout] {
        workouts.filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
    }

    private var monthDays: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let first = interval.start
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        var days: [Date?] = Array(repeating: nil, count: leading)
        for i in 0..<count { days.append(calendar.date(byAdding: .day, value: i, to: first)) }
        return days
    }

    private var weekdaySymbols: [String] {
        let s = calendar.veryShortStandaloneWeekdaySymbols
        let f = calendar.firstWeekday - 1
        return Array(s[f...]) + Array(s[..<f])
    }

    private var calendarCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text(displayedMonth.f(.dateTime.month(.wide).year())).font(.lift(17, .bold))
                Spacer()
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(SoftButtonStyle())
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(SoftButtonStyle())
            }
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                    Text(s).font(.lift(11, .semibold)).foregroundStyle(Theme.textSecondary).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                    if let day { dayCell(day) } else { Color.clear.frame(height: 34) }
                }
            }
            if let sel = selectedDay {
                let items = workoutsOn(sel)
                Divider().overlay(Theme.hairline)
                if items.isEmpty {
                    Text(trf("No workouts on %@", sel.f(.dateTime.month(.abbreviated).day())))
                        .font(.lift(13, .medium)).foregroundStyle(Theme.textSecondary)
                } else {
                    ForEach(items) { w in
                        NavigationLink { WorkoutDetailView(workout: w) } label: {
                            HStack {
                                Text(tr(w.name)).font(.lift(15, .semibold))
                                Spacer()
                                Text("\(countText(w.completedSets.count, .set)) · \(unit.formatVolume(w.totalVolumeKg)) \(unit.label)")
                                    .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
                                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .card()
    }

    private func dayCell(_ day: Date) -> some View {
        let has = !workoutsOn(day).isEmpty
        let isToday = calendar.isDateInToday(day)
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        return Button {
            Haptics.tap()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDay = isSelected ? nil : day
            }
        } label: {
            ZStack {
                if has { Circle().fill(Theme.accent) }
                else if isToday { Circle().stroke(Theme.textSecondary, lineWidth: 1) }
                if isSelected { Circle().stroke(Theme.textPrimary, lineWidth: 2) }
                Text("\(calendar.component(.day, from: day))")
                    .font(.lift(13, .semibold))
                    .foregroundStyle(has ? Color.black : Theme.textPrimary)
            }
            .frame(height: 34)
        }
        .buttonStyle(.plain)
    }

    private func shiftMonth(_ delta: Int) {
        Haptics.tap()
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
            selectedDay = nil
        }
    }

    // MARK: Last workout

    private var lastWorkoutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Last workout")).font(.lift(20, .bold))
            if let w = workouts.first {
                NavigationLink { WorkoutDetailView(workout: w) } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(tr(w.name)).font(.lift(17, .bold))
                            Spacer()
                            Text(relativeString(w.startedAt))
                                .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
                        }
                        HStack(spacing: 16) {
                            miniStat("\(w.completedSets.count)", tr("sets"))
                            miniStat(unit.formatVolume(w.totalVolumeKg), unit.label)
                            miniStat(durationString(w.duration), tr("time"))
                        }
                        Text(w.sortedExercises.map { tr($0.exercise?.name ?? $0.exerciseName) }.joined(separator: " · "))
                            .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary).lineLimit(2)
                    }
                    .foregroundStyle(Theme.textPrimary)
                }
                .buttonStyle(.plain)
            } else {
                EmptyStateView(icon: "figure.strengthtraining.traditional", title: tr("No workouts yet"),
                               message: tr("Finish your first workout and it will show up here."))
            }
        }
        .card()
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.lift(20, .bold))
            Text(label).font(.lift(11, .medium)).foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: Records

    private var topLifts: [(name: String, value: Double)] {
        var best: [UUID: (name: String, value: Double)] = [:]
        for r in records where r.type == .oneRM {
            if (best[r.exerciseID]?.value ?? 0) < r.value { best[r.exerciseID] = (r.exerciseName, r.value) }
        }
        return best.values.sorted { $0.value > $1.value }.prefix(4).map { (name: $0.name, value: $0.value) }
    }

    private var recordsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Personal records")).font(.lift(20, .bold))
            if topLifts.isEmpty {
                EmptyStateView(icon: "trophy", title: tr("No records yet"),
                               message: tr("Your best lifts will appear here after you finish a workout."))
            } else {
                ForEach(topLifts, id: \.name) { lift in
                    HStack {
                        Text(tr(lift.name)).font(.lift(15, .semibold))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(unit.format(lift.value)).font(.lift(17, .bold))
                            Text(tr("est. 1RM")).font(.lift(11, .medium)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                let recent = records.filter { !$0.isBaseline }.prefix(3)
                if !recent.isEmpty {
                    Divider().overlay(Theme.hairline)
                    Text(tr("Latest")).font(.lift(12, .semibold)).foregroundStyle(Theme.textSecondary)
                    ForEach(Array(recent)) { r in
                        HStack(spacing: 8) {
                            Image(systemName: "trophy.fill").foregroundStyle(Theme.accent).font(.system(size: 12))
                            Text("\(tr(r.exerciseName)) · \(r.type.title)").font(.lift(13, .medium))
                            Spacer()
                            Text(r.type.formatted(r.value, unit: unit)).font(.lift(13, .bold))
                        }
                    }
                }
                Text(tr("1RM is estimated with the Epley formula, not a verified max lift."))
                    .font(.lift(11, .medium)).foregroundStyle(Theme.textSecondary)
            }
        }
        .card()
    }
}
