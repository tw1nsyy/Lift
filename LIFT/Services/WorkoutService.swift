import Foundation
import SwiftData
import Observation

@Observable
final class AppRouter {
    var tab: AppTab = .today
    var presentedWorkout: Workout?
    var progressExerciseID: UUID?
}

struct RecordDisplay: Identifiable {
    let id = UUID()
    let exerciseName: String
    let type: RecordType
    let valueKg: Double
}

enum WorkoutService {
    static func defaultName(_ date: Date = Date()) -> String {
        let h = Calendar.current.component(.hour, from: date)
        switch h {
        case 5..<12: return tr("Morning Workout")
        case 12..<17: return tr("Afternoon Workout")
        case 17..<22: return tr("Evening Workout")
        default: return tr("Night Workout")
        }
    }

    /// Starts a new workout (optionally from a template) or resumes the unfinished one.
    static func begin(name: String? = nil, template: WorkoutTemplate? = nil,
                      context: ModelContext, router: AppRouter) {
        if let active = StatsService.activeWorkout(context) {
            router.presentedWorkout = active
            return
        }
        let w = Workout(name: name ?? template?.name ?? defaultName())
        context.insert(w)
        if let template {
            let unit = ((try? context.fetch(FetchDescriptor<UserProfile>()))?.first)?.unit ?? .kg
            let finished = StatsService.finishedWorkouts(context)
            for item in template.sortedItems {
                guard let ex = item.exercise else { continue }
                let plan = LoadPlanner.plan(exercise: ex, repsMin: item.reps, repsMax: item.repsMax,
                                            model: template.progression, rir: template.rir,
                                            sessions: StatsService.sessions(for: ex, in: finished), unit: unit)
                addExercise(ex, to: w, context: context, setCount: item.sets, reps: item.reps, fallbackWeightKg: item.weightKg,
                            repsMax: item.repsMax, restSeconds: item.restSeconds,
                            plannedWeightKg: plan?.weightKg, plannedReps: plan?.reps, planNote: plan?.note ?? "")
            }
        }
        try? context.save()
        router.presentedWorkout = w
    }

    static func repeatWorkout(_ source: Workout, context: ModelContext, router: AppRouter) {
        if let active = StatsService.activeWorkout(context) {
            router.presentedWorkout = active
            return
        }
        let w = Workout(name: source.name)
        context.insert(w)
        for we in source.sortedExercises {
            guard let ex = we.exercise else { continue }
            addExercise(ex, to: w, context: context, setCount: max(we.sets.count, 1),
                        repsMin: we.repsMin, repsMax: we.repsMax, restSeconds: we.restSeconds)
        }
        try? context.save()
        router.presentedWorkout = w
    }

    /// Adds an exercise; sets are prefilled from the previous session of that exercise when available.
    static func addExercise(_ exercise: Exercise, to workout: Workout, context: ModelContext,
                            setCount: Int? = nil, reps: Int? = nil, fallbackWeightKg: Double = 0,
                            repsMin: Int = 0, repsMax: Int = 0, restSeconds: Int = 0,
                            plannedWeightKg: Double? = nil, plannedReps: Int? = nil, planNote: String = "") {
        let history = StatsService.finishedWorkouts(context)
        let last = StatsService.sessions(for: exercise, in: history).last?.sets ?? []
        let count = setCount ?? (last.isEmpty ? 3 : min(last.count, 8))
        let entry = WorkoutExercise(order: workout.exercises.count, exercise: exercise)
        context.insert(entry)
        entry.workout = workout
        entry.repsMin = repsMin > 0 ? repsMin : (reps ?? 0)
        entry.repsMax = repsMax
        entry.restSeconds = restSeconds
        entry.planNote = planNote
        for i in 0..<count {
            let ref: SetSnapshot? = last.isEmpty ? nil : last[min(i, last.count - 1)]
            let s = WorkoutSet(order: i, weightKg: plannedWeightKg ?? ref?.weightKg ?? fallbackWeightKg,
                             reps: plannedReps ?? ref?.reps ?? reps ?? 10)
            context.insert(s)
            s.workoutExercise = entry
        }
    }

    static func addSet(to entry: WorkoutExercise, context: ModelContext) {
        let last = entry.sortedSets.last
        let s = WorkoutSet(order: entry.sets.count, weightKg: last?.weightKg ?? 0, reps: last?.reps ?? 10)
        context.insert(s)
        s.workoutExercise = entry
    }

    /// Inserts a warm-up set at the top (about half of the first working weight, rounded to 2.5 kg).
    static func addWarmup(to entry: WorkoutExercise, context: ModelContext) {
        let first = entry.sortedSets.first { !$0.isWarmup }
        for s in entry.sets { s.order += 1 }
        let w = WorkoutSet(order: 0, weightKg: (((first?.weightKg ?? 0) * 0.5) / 2.5).rounded() * 2.5, reps: 8)
        w.isWarmup = true
        context.insert(w)
        w.workoutExercise = entry
    }

    static func removeSet(_ set: WorkoutSet, from entry: WorkoutExercise, context: ModelContext) {
        entry.sets.removeAll { $0.id == set.id }
        context.delete(set)
        for (i, s) in entry.sortedSets.enumerated() { s.order = i }
    }

    static func removeExercise(_ entry: WorkoutExercise, from workout: Workout, context: ModelContext) {
        workout.exercises.removeAll { $0.id == entry.id }
        context.delete(entry)
        for (i, e) in workout.sortedExercises.enumerated() { e.order = i }
    }

    /// Finalizes a workout: drops unfinished sets, removes demo data, rebuilds records. Returns new records.
    static func finish(_ workout: Workout, context: ModelContext) -> [RecordDisplay] {
        for entry in workout.exercises {
            let stale = entry.sets.filter { !$0.isCompleted }
            entry.sets.removeAll { !$0.isCompleted }
            stale.forEach { context.delete($0) }
            for (i, s) in entry.sortedSets.enumerated() { s.order = i }
        }
        let empty = workout.exercises.filter { $0.sets.isEmpty }
        workout.exercises.removeAll { $0.sets.isEmpty }
        empty.forEach { context.delete($0) }
        for (i, e) in workout.sortedExercises.enumerated() { e.order = i }

        workout.endedAt = Date()
        workout.isFinished = true

        if !workout.isDemo { deleteDemoData(context: context, rebuild: false) }
        try? context.save()
        StatsService.rebuildRecords(context)

        let wid = workout.id
        let d = FetchDescriptor<PersonalRecord>(predicate: #Predicate { $0.workoutID == wid && $0.isBaseline == false })
        let records = (try? context.fetch(d)) ?? []
        return records.map { RecordDisplay(exerciseName: $0.exerciseName, type: $0.type, valueKg: $0.value) }
    }

    static func discard(_ workout: Workout, context: ModelContext) {
        context.delete(workout)
        try? context.save()
    }

    static func delete(_ workout: Workout, context: ModelContext) {
        context.delete(workout)
        try? context.save()
        StatsService.rebuildRecords(context)
    }

    static func deleteDemoData(context: ModelContext, rebuild: Bool = true) {
        let d = FetchDescriptor<Workout>(predicate: #Predicate { $0.isDemo == true })
        for w in (try? context.fetch(d)) ?? [] { context.delete(w) }
        try? context.save()
        if rebuild { StatsService.rebuildRecords(context) }
    }

    static func deleteAllWorkoutData(context: ModelContext) {
        for w in (try? context.fetch(FetchDescriptor<Workout>())) ?? [] { context.delete(w) }
        try? context.save()
        StatsService.rebuildRecords(context)
    }
}
