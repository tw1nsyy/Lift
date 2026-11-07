import SwiftUI
import SwiftData
import Charts

enum ChartRange: String, CaseIterable, Identifiable {
    case month = "1M", quarter = "3M", half = "6M", all = "All"
    var id: String { rawValue }

    func filter(_ sessions: [ExerciseSession]) -> [ExerciseSession] {
        let days: Int
        switch self {
        case .month: days = 30
        case .quarter: days = 90
        case .half: days = 180
        case .all: return sessions
        }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        return sessions.filter { $0.date >= cutoff }
    }
}

struct ChartPoint: Identifiable {
    let id: UUID
    let date: Date
    let value: Double
}

struct ProgressTabView: View {
    @Environment(AppRouter.self) private var router
    @Query(filter: #Predicate<Workout> { $0.isFinished == true }, sort: \Workout.startedAt)
    private var workouts: [Workout]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var records: [PersonalRecord]

    @State private var selectedID: UUID?
    @State private var metric: ChartMetric = .oneRM
    @State private var range: ChartRange = .all

    private struct Tracked: Identifiable {
        let exercise: Exercise
        let sessions: [ExerciseSession]
        var id: UUID { exercise.id }
    }

    private var tracked: [Tracked] {
        exercises.compactMap { ex -> Tracked? in
            let s = StatsService.sessions(for: ex, in: workouts)
            return s.isEmpty ? nil : Tracked(exercise: ex, sessions: s)
        }
        .sorted { ($0.sessions.last?.date ?? .distantPast) > ($1.sessions.last?.date ?? .distantPast) }
    }

    var body: some View {
        let data = tracked
        let wanted = selectedID ?? router.progressExerciseID
        let current = data.first { $0.exercise.id == wanted } ?? data.first

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Progress")
                        .font(.lift(30, .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if data.isEmpty {
                        EmptyStateView(icon: "chart.line.uptrend.xyaxis", title: "No progress yet",
                                       message: "Finish your first workout and your results will be charted here, per exercise.",
                                       actionTitle: "Start Workout") {
                            router.tab = .workout
                        }
                        .card()
                    } else {
                        exerciseChips(data, current: current)
                        if let current {
                            ExerciseProgressContent(exercise: current.exercise, sessions: current.sessions,
                                                    records: records.filter { $0.exerciseID == current.exercise.id },
                                                    metric: $metric, range: $range)
                                .id(current.exercise.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func exerciseChips(_ data: [Tracked], current: Tracked?) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(data) { item in
                    let isOn = item.exercise.id == current?.exercise.id
                    Button {
                        Haptics.tap()
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedID = item.exercise.id
                            router.progressExerciseID = nil
                        }
                    } label: {
                        Text(item.exercise.name)
                            .font(.lift(14, .bold))
                            .foregroundStyle(isOn ? Theme.background : Theme.textPrimary)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(isOn ? Theme.textPrimary : Theme.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ExerciseProgressContent: View {
    let exercise: Exercise
    let sessions: [ExerciseSession]
    let records: [PersonalRecord]
    @Binding var metric: ChartMetric
    @Binding var range: ChartRange

    @Environment(\.weightUnit) private var unit
    @State private var selectedDate: Date?

    private var summary: ExerciseSummary { ExerciseSummary(sessions: sessions) }

    private func display(_ kg: Double) -> Double { metric.isWeightBased ? unit.display(kg) : kg }

    private var points: [ChartPoint] {
        range.filter(sessions).map { ChartPoint(id: $0.id, date: $0.date, value: display($0.value(metric))) }
    }

    private var headline: Double { display(sessions.last?.value(metric) ?? 0) }
    private var unitLabel: String { metric.isWeightBased ? unit.label : "reps" }
    private var trend: Trend { StatsService.trend(values: sessions.map { $0.value(metric) }) }

    private var selectedPoint: ChartPoint? {
        guard let d = selectedDate else { return nil }
        return points.min { abs($0.date.timeIntervalSince(d)) < abs($1.date.timeIntervalSince(d)) }
    }

    private var yDomain: ClosedRange<Double> {
        let vals = points.map(\.value)
        guard let lo = vals.min(), let hi = vals.max() else { return 0...1 }
        let pad = hi == lo ? max(hi * 0.1, 1) : (hi - lo) * 0.25
        return max(0, lo - pad)...(hi + pad)
    }

    var body: some View {
        VStack(spacing: 16) {
            headerCard
            metricPicker
            chartCard
            statsGrid
            recordsCard
            sessionsCard
            Text("1RM is an estimate calculated with the Epley formula: weight × (1 + reps ÷ 30). It is not a verified max lift.")
                .font(.lift(11, .medium)).foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.name).font(.lift(15, .semibold)).foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatNumber(headline))
                    .font(.lift(56, .bold))
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text(unitLabel).font(.lift(18, .semibold)).foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 4)
                DeltaBadge(trend: trend)
            }
            Text(metric.title + " · last session" + (sessions.count >= 2 ? " vs previous" : ""))
                .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
        }
        .card()
        .animation(.easeInOut(duration: 0.25), value: metric)
    }

    private var metricPicker: some View {
        HStack(spacing: 6) {
            ForEach(ChartMetric.allCases) { m in
                Button {
                    Haptics.tap()
                    withAnimation(.easeInOut(duration: 0.3)) { metric = m; selectedDate = nil }
                } label: {
                    Text(m.rawValue)
                        .font(.lift(13, .bold))
                        .foregroundStyle(metric == m ? Theme.background : Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(metric == m ? Theme.textPrimary : Theme.card, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(metric.title).font(.lift(15, .bold))
                Spacer()
                Picker("Range", selection: $range) {
                    ForEach(ChartRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            if points.isEmpty {
                Text("No sessions in this period.")
                    .font(.lift(13, .medium)).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart {
                    ForEach(points) { p in
                        AreaMark(x: .value("Date", p.date), y: .value(metric.rawValue, p.value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.28), Theme.accent.opacity(0)],
                                                            startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Date", p.date), y: .value(metric.rawValue, p.value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Theme.accent)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        PointMark(x: .value("Date", p.date), y: .value(metric.rawValue, p.value))
                            .foregroundStyle(Theme.accent)
                            .symbolSize(36)
                    }
                    if let sel = selectedPoint {
                        RuleMark(x: .value("Date", sel.date))
                            .foregroundStyle(Theme.textSecondary.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .annotation(position: .top, spacing: 4,
                                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                                VStack(spacing: 2) {
                                    Text("\(formatNumber(sel.value)) \(unitLabel)").font(.lift(13, .bold))
                                    Text(sel.date.formatted(.dateTime.month(.abbreviated).day()))
                                        .font(.lift(11, .medium)).foregroundStyle(Theme.textSecondary)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Theme.cardHigh, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                    }
                }
                .chartYScale(domain: yDomain)
                .chartXSelection(value: $selectedDate)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Theme.hairline)
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Theme.hairline)
                        AxisValueLabel().foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(height: 240)
                .animation(.easeInOut(duration: 0.35), value: metric)

                if points.count == 1 {
                    Text("Log more sessions to see a trend.")
                        .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .card()
    }

    // MARK: Stats

    private var statsGrid: some View {
        let change = summary.changeSinceFirst(.oneRM)
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(title: "Current 1RM (est.)", value: unit.format(summary.currentE1RMKg, withUnit: false), unit: unit.label, icon: "bolt.fill")
            StatTile(title: "Best set",
                     value: summary.bestSet.map { "\(unit.format($0.weightKg, withUnit: false))×\($0.reps)" } ?? "—",
                     unit: unit.label, icon: "star.fill")
            StatTile(title: "Max weight", value: unit.format(summary.maxWeightKg, withUnit: false), unit: unit.label, icon: "scalemass.fill")
            StatTile(title: "Total volume", value: unit.formatVolume(summary.totalVolumeKg), unit: unit.label, icon: "chart.bar.fill")
            StatTile(title: "Max reps", value: "\(summary.maxReps)", unit: "reps", icon: "repeat")
            StatTile(title: "1RM change", value: change.map { String(format: "%+.1f%%", $0) } ?? "—",
                     icon: "arrow.up.right",
                     tint: (change ?? 0) > 0 ? Theme.accent : Theme.textPrimary)
        }
    }

    private var recordsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal records").font(.lift(18, .bold))
            ForEach(RecordType.allCases) { type in
                let best = records.filter { $0.type == type }.max { $0.value < $1.value }
                HStack(spacing: 10) {
                    Image(systemName: type.icon).foregroundStyle(Theme.accent).frame(width: 22)
                    Text(type.rawValue).font(.lift(14, .semibold))
                    Spacer()
                    if let best {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(type.formatted(best.value, unit: unit)).font(.lift(15, .bold))
                            Text(best.date.formatted(.dateTime.month(.abbreviated).day().year()))
                                .font(.lift(11, .medium)).foregroundStyle(Theme.textSecondary)
                        }
                    } else {
                        Text("—").foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .card()
    }

    private var sessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent sessions").font(.lift(18, .bold))
            ForEach(sessions.reversed().prefix(8)) { s in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(.lift(14, .semibold))
                        Text(s.sets.map { "\(unit.format($0.weightKg, withUnit: false))×\($0.reps)" }.joined(separator: "  "))
                            .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                    }
                    Spacer()
                    Text("\(unit.formatVolume(s.volumeKg)) \(unit.label)")
                        .font(.lift(13, .bold))
                }
            }
        }
        .card()
    }
}
