import Foundation
import SwiftData

struct SetSnapshot: Hashable {
    let weightKg: Double
    let reps: Int
    var e1RMKg: Double { Formulas.epley1RM(weight: weightKg, reps: reps) }
}

enum Trend {
    case up(Double), down(Double), flat, insufficient
}

struct ExerciseSession: Identifiable {
    let id: UUID            // workout id
    let date: Date
    let sets: [SetSnapshot]

    var maxWeightKg: Double { sets.map(\.weightKg).max() ?? 0 }
    var e1RMKg: Double { sets.map(\.e1RMKg).max() ?? 0 }
    var volumeKg: Double { sets.reduce(0) { $0 + Formulas.volume(weight: $1.weightKg, reps: $1.reps) } }
    var maxReps: Int { sets.map(\.reps).max() ?? 0 }
    var bestSet: SetSnapshot? { sets.max { $0.e1RMKg < $1.e1RMKg } }

    func value(_ metric: ChartMetric) -> Double {
        switch metric {
        case .oneRM: e1RMKg
        case .maxWeight: maxWeightKg
        case .volume: volumeKg
        case .reps: Double(maxReps)
        }
    }
}

struct ExerciseSummary {
    let sessions: [ExerciseSession]

    var currentE1RMKg: Double { sessions.last?.e1RMKg ?? 0 }
    var bestE1RMKg: Double { sessions.map(\.e1RMKg).max() ?? 0 }
    var maxWeightKg: Double { sessions.map(\.maxWeightKg).max() ?? 0 }
    var totalVolumeKg: Double { sessions.reduce(0) { $0 + $1.volumeKg } }
    var maxReps: Int { sessions.map(\.maxReps).max() ?? 0 }
    var bestSet: SetSnapshot? { sessions.compactMap(\.bestSet).max { $0.e1RMKg < $1.e1RMKg } }

    /// Change of the metric between the first and the latest session (nil if < 2 sessions).
    func changeSinceFirst(_ metric: ChartMetric) -> Double? {
        guard sessions.count >= 2, let first = sessions.first?.value(metric), let last = sessions.last?.value(metric), first > 0 else { return nil }
        return (last - first) / first * 100
    }
}

enum StatsService {
    // MARK: Fetching

    static func finishedWorkouts(_ context: ModelContext) -> [Workout] {
        let d = FetchDescriptor<Workout>(predicate: #Predicate { $0.isFinished == true },
                                         sortBy: [SortDescriptor(\.startedAt)])
        return (try? context.fetch(d)) ?? []
    }

    static func activeWorkout(_ context: ModelContext) -> Workout? {
        var d = FetchDescriptor<Workout>(predicate: #Predicate { $0.isFinished == false })
        d.fetchLimit = 1
        return (try? context.fetch(d))?.first
    }

    // MARK: Sessions & trends

    static func sessions(for exercise: Exercise, in workouts: [Workout]) -> [ExerciseSession] {
        let id = exercise.id
        return workouts
            .filter { $0.isFinished }
            .sorted { $0.startedAt < $1.startedAt }
            .compactMap { w -> ExerciseSession? in
                let sets = w.exercises
                    .filter { $0.exercise?.id == id }
                    .flatMap { $0.sets }
                    .filter { $0.isCompleted && !$0.isWarmup }
                    .sorted { $0.order < $1.order }
                guard !sets.isEmpty else { return nil }
                return ExerciseSession(id: w.id, date: w.startedAt,
                                       sets: sets.map { SetSnapshot(weightKg: $0.weightKg, reps: $0.reps) })
            }
    }

    /// Compares the latest value with the previous one. Needs at least two sessions.
    static func trend(values: [Double]) -> Trend {
        guard values.count >= 2 else { return .insufficient }
        let cur = values[values.count - 1], prev = values[values.count - 2]
        guard prev > 0 else { return .insufficient }
        if abs(cur - prev) < 0.0001 { return .flat }
        let pct = (cur - prev) / prev * 100
        return pct > 0 ? .up(pct) : .down(pct)
    }

    // MARK: Personal records

    /// Rebuilds all personal records from scratch from finished workouts, so edits/deletes stay consistent.
    static func rebuildRecords(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        for r in existing { context.delete(r) }

        var best: [String: Double] = [:]
        for w in finishedWorkouts(context) {
            var grouped: [UUID: (name: String, sets: [WorkoutSet])] = [:]
            for we in w.exercises {
                guard let ex = we.exercise else { continue }
                let done = we.sets.filter { $0.isCompleted && !$0.isWarmup }
                guard !done.isEmpty else { continue }
                var entry = grouped[ex.id] ?? (name: ex.name, sets: [])
                entry.sets += done
                grouped[ex.id] = entry
            }
            for (exID, entry) in grouped {
                let values: [(RecordType, Double)] = [
                    (.maxWeight, entry.sets.map { $0.weightKg }.max() ?? 0),
                    (.oneRM, entry.sets.map { Formulas.epley1RM(weight: $0.weightKg, reps: $0.reps) }.max() ?? 0),
                    (.maxReps, Double(entry.sets.map { $0.reps }.max() ?? 0)),
                    (.sessionVolume, entry.sets.reduce(0) { $0 + Formulas.volume(weight: $1.weightKg, reps: $1.reps) })
                ]
                for (type, v) in values where v > 0 {
                    let key = "\(exID.uuidString)-\(type.rawValue)"
                    let prev = best[key]
                    if prev == nil || v > (prev ?? 0) + 0.0001 {
                        best[key] = v
                        context.insert(PersonalRecord(exerciseID: exID, exerciseName: entry.name, type: type,
                                                      value: v, date: w.startedAt, workoutID: w.id,
                                                      isBaseline: prev == nil))
                    }
                }
            }
        }
        try? context.save()
    }

    /// Checks whether a just-completed set beats everything done before (history + earlier sets today).
    static func liveRecord(for set: WorkoutSet, in entry: WorkoutExercise, history: [Workout]) -> (type: RecordType, valueKg: Double)? {
        guard let ex = entry.exercise, !set.isWarmup else { return nil }
        let past = sessions(for: ex, in: history)
        guard !past.isEmpty else { return nil }     // no history → nothing to beat, no fake PR
        let others = entry.sets.filter { $0.isCompleted && !$0.isWarmup && $0.id != set.id }
        let bestWeight = max(past.map(\.maxWeightKg).max() ?? 0, others.map { $0.weightKg }.max() ?? 0)
        let bestE1RM = max(past.map(\.e1RMKg).max() ?? 0,
                           others.map { Formulas.epley1RM(weight: $0.weightKg, reps: $0.reps) }.max() ?? 0)
        let e1 = Formulas.epley1RM(weight: set.weightKg, reps: set.reps)
        if e1 > bestE1RM + 0.0001 { return (.oneRM, e1) }
        if set.weightKg > bestWeight + 0.0001 { return (.maxWeight, set.weightKg) }
        return nil
    }
}

// MARK: - Progression & muscle volume

struct ProgressionSuggestion {
    let weightKg: Double
    let reps: Int
    let reason: String
}

extension StatsService {
    /// Double progression: if every working set reached 8+ reps, add weight; otherwise add a rep at the same weight.
    static func suggestion(for exercise: Exercise, last: ExerciseSession, stepKg: Double, unit: WeightUnit) -> ProgressionSuggestion? {
        guard exercise.equipment != .bodyweight, !last.sets.isEmpty else { return nil }
        let topWeight = last.maxWeightKg
        guard topWeight > 0 else { return nil }
        let working = last.sets.filter { $0.weightKg >= topWeight * 0.9 }
        let minReps = working.map(\.reps).min() ?? 0
        let ref = "\(working.count)×\(minReps) at \(unit.format(topWeight))"
        if minReps >= 8 {
            let next = topWeight + stepKg
            return ProgressionSuggestion(weightKg: next, reps: 8,
                                         reason: "You hit \(ref). Add \(unit.format(stepKg)) and aim for 8 reps.")
        }
        return ProgressionSuggestion(weightKg: topWeight, reps: minReps + 1,
                                     reason: "Last time \(ref). Same weight, aim for \(minReps + 1) reps.")
    }

    /// Working volume per muscle group (kg) for workouts started in the last `days` days.
    static func muscleVolume(workouts: [Workout], days: Int = 7) -> [(muscle: MuscleGroup, volumeKg: Double)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        var totals: [MuscleGroup: Double] = [:]
        for w in workouts where w.isFinished && w.startedAt >= cutoff {
            for we in w.exercises {
                guard let m = we.exercise?.muscle else { continue }
                let v = we.sets.filter { $0.isCompleted && !$0.isWarmup }
                    .reduce(0) { $0 + Formulas.volume(weight: $1.weightKg, reps: $1.reps) }
                totals[m, default: 0] += v
            }
        }
        return MuscleGroup.allCases.map { (muscle: $0, volumeKg: totals[$0] ?? 0) }
    }
}
