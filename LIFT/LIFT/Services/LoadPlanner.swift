import Foundation

enum ProgressionModel: String, CaseIterable, Identifiable {
    case acsm, double, rir
    var id: String { rawValue }

    var title: String {
        switch self {
        case .acsm: return tr("2-for-2 rule (ACSM range)")
        case .double: return tr("Double progression")
        case .rir: return tr("% of 1RM with reserve reps")
        }
    }

    var summary: String {
        switch self {
        case .acsm: return tr("Hold the weight until you get 2+ reps over target in two sessions in a row, then add 2.5% (upper body) or 5% (legs).")
        case .double: return tr("Work inside a rep range. When every set reaches the top of the range, add weight and start from the bottom again.")
        case .rir: return tr("Weight is calculated from your 1RM (the higher of your saved max and your best estimate) for the target reps, leaving some reps in reserve.")
        }
    }
}

struct LoadPlan {
    let weightKg: Double
    let reps: Int
    let note: String
}

/// Works out the working weight for an exercise in a program from the lifter's one-rep max and history.
/// Rules follow published guidance (see ScienceView): the ACSM progression rule (increase 2-10% once you
/// can do 1-2 reps over the target), and repetitions-in-reserve based load selection.
enum LoadPlanner {
    /// Smallest sensible jump in display units: 2.5 kg (2 kg for dumbbells) or 5 lb.
    static func stepDisplay(for exercise: Exercise, unit: WeightUnit) -> Double {
        if unit == .lb { return 5 }
        return exercise.equipment == .dumbbell ? 2 : 2.5
    }

    static func roundKg(_ kg: Double, exercise: Exercise, unit: WeightUnit) -> Double {
        let step = stepDisplay(for: exercise, unit: unit)
        return unit.toKg((unit.display(kg) / step).rounded() * step)
    }

    /// The higher of the saved personal max and the best Epley estimate from the workout history (kg).
    static func oneRM(for exercise: Exercise, sessions: [ExerciseSession]) -> Double {
        max(exercise.manualOneRMKg, sessions.map { $0.e1RMKg }.max() ?? 0)
    }

    private static func lastSetReps(_ s: ExerciseSession) -> Int {
        let topW = s.maxWeightKg
        return s.sets.last(where: { $0.weightKg >= topW * 0.97 })?.reps ?? 0
    }

    static func plan(exercise: Exercise, repsMin: Int, repsMax: Int, model: ProgressionModel, rir: Int,
                     sessions: [ExerciseSession], unit: WeightUnit) -> LoadPlan? {
        let target = max(repsMin, 1)
        let top = max(repsMax, target)
        let reserve = max(rir, 0)
        let rm = oneRM(for: exercise, sessions: sessions)
        let stepKg = unit.toKg(stepDisplay(for: exercise, unit: unit))

        func fromMax() -> LoadPlan? {
            guard rm > 0 else { return nil }
            let w = roundKg(Formulas.weightForReps(oneRM: rm, reps: target + reserve), exercise: exercise, unit: unit)
            guard w > 0 else { return nil }
            let pct = Int((w / rm * 100).rounded())
            return LoadPlan(weightKg: w, reps: target, note: trf("%d%% of your 1RM, %d reps in reserve", pct, reserve))
        }

        guard let last = sessions.last else { return fromMax() }
        let w1 = last.maxWeightKg
        guard w1 > 0 else { return fromMax() }

        func hold() -> LoadPlan {
            LoadPlan(weightKg: w1, reps: target,
                     note: trf("Keep %@ until you get 2+ reps over target in two sessions in a row.", unit.format(w1)))
        }

        switch model {
        case .rir:
            return fromMax() ?? hold()

        case .double:
            guard let sg = StatsService.suggestion(for: exercise, last: last, stepKg: stepKg, unit: unit,
                                                   targetMin: target, targetMax: top) else { return fromMax() }
            return LoadPlan(weightKg: sg.weightKg, reps: sg.reps, note: sg.reason)

        case .acsm:
            let ok1 = lastSetReps(last) >= top + 2
            var ok0 = false
            if let prev = sessions.dropLast().last, abs(prev.maxWeightKg - w1) <= w1 * 0.02 {
                ok0 = lastSetReps(prev) >= top + 2
            }
            guard ok1 && ok0 else { return hold() }
            let pct = exercise.muscle == .legs ? 0.05 : 0.025
            var next = roundKg(w1 * (1 + pct), exercise: exercise, unit: unit)
            if next <= w1 + 0.0001 { next = w1 + stepKg }
            return LoadPlan(weightKg: next, reps: target,
                            note: trf("Two sessions in a row with 2+ reps over target: add %@ (ACSM range 2–10%%).", unit.format(next - w1)))
        }
    }
}
