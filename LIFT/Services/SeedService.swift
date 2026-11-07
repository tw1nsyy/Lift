import Foundation
import SwiftData

enum SeedService {
    private struct LibraryItem {
        let name: String
        let muscle: MuscleGroup
        let equipment: Equipment
        let technique: String
    }

    private static let library: [LibraryItem] = [
        // Chest
        .init(name: "Bench Press", muscle: .chest, equipment: .barbell, technique: "Lie flat, eyes under the bar. Pull shoulder blades together, lower the bar to mid-chest with elbows ~45° from the torso, then press up and slightly back. Keep feet planted and glutes on the bench."),
        .init(name: "Incline Bench Press", muscle: .chest, equipment: .barbell, technique: "Set the bench to 30–45°. Lower the bar to the upper chest under control and press back up. Keep wrists stacked over elbows and avoid flaring the elbows."),
        .init(name: "Dumbbell Fly", muscle: .chest, equipment: .dumbbell, technique: "With a slight bend in the elbows, open the arms in a wide arc until you feel a stretch across the chest, then squeeze the dumbbells back together above the chest."),
        .init(name: "Chest Press", muscle: .chest, equipment: .machine, technique: "Adjust the seat so the handles are at mid-chest height. Press forward without locking the elbows and return slowly, keeping shoulder blades pinned back."),
        .init(name: "Cable Fly", muscle: .chest, equipment: .cable, technique: "Stand between the pulleys with a slight forward lean. Sweep the handles together in a hugging arc, squeeze at the centre, and return with control."),
        // Back
        .init(name: "Lat Pulldown", muscle: .back, equipment: .cable, technique: "Grip slightly wider than shoulders. Lean back a little, drive the elbows down toward the ribs and pull the bar to the upper chest. Control the way up."),
        .init(name: "Pull Ups", muscle: .back, equipment: .bodyweight, technique: "Start from a dead hang. Pull the chest toward the bar by driving the elbows down, chin over the bar, then lower fully under control."),
        .init(name: "Seated Cable Row", muscle: .back, equipment: .cable, technique: "Sit tall with a slight knee bend. Pull the handle to the lower ribs, squeezing the shoulder blades together, without rocking the torso."),
        .init(name: "Barbell Row", muscle: .back, equipment: .barbell, technique: "Hinge at the hips with a flat back, bar hanging below the knees. Row the bar to the lower ribs, pause briefly, and lower without losing the hinge angle."),
        .init(name: "Deadlift", muscle: .back, equipment: .barbell, technique: "Bar over mid-foot, hips back, flat back. Brace, push the floor away and stand tall with the bar close to the legs. Lower by hinging at the hips first."),
        // Shoulders
        .init(name: "Shoulder Press", muscle: .shoulders, equipment: .dumbbell, technique: "Press the weights overhead from shoulder height until the arms are almost straight. Brace the core and avoid arching the lower back."),
        .init(name: "Lateral Raises", muscle: .shoulders, equipment: .dumbbell, technique: "With a slight elbow bend, raise the arms out to the sides to shoulder height, leading with the elbows. Lower slowly; avoid swinging."),
        .init(name: "Rear Delt Fly", muscle: .shoulders, equipment: .dumbbell, technique: "Hinge forward with a flat back. Open the arms out to the sides, squeezing the rear shoulders, and lower under control."),
        .init(name: "Face Pull", muscle: .shoulders, equipment: .cable, technique: "Set the cable at upper-chest height with a rope. Pull toward the face, elbows high and wide, rotating the hands outward at the end."),
        // Arms
        .init(name: "Barbell Curl", muscle: .arms, equipment: .barbell, technique: "Stand tall, elbows pinned to the sides. Curl the bar up without swinging the torso and lower it fully under control."),
        .init(name: "Hammer Curl", muscle: .arms, equipment: .dumbbell, technique: "Hold the dumbbells with a neutral grip (palms facing in). Curl up keeping the elbows still, and lower slowly."),
        .init(name: "Triceps Pushdown", muscle: .arms, equipment: .cable, technique: "Elbows tucked at the sides. Push the handle down until the arms are straight, squeeze the triceps, then return until the forearms are just past parallel."),
        .init(name: "Skull Crushers", muscle: .arms, equipment: .barbell, technique: "Lying on a bench, lower the bar toward the forehead by bending only at the elbows, then extend back up. Keep the upper arms still."),
        .init(name: "Dips", muscle: .arms, equipment: .bodyweight, technique: "Support yourself on parallel bars, lean slightly forward, lower until the upper arms are about parallel to the floor, then press up."),
        // Legs
        .init(name: "Squat", muscle: .legs, equipment: .barbell, technique: "Bar on the upper back, feet shoulder-width. Brace, sit down and back until thighs are at least parallel, knees tracking over the toes, then drive up."),
        .init(name: "Leg Press", muscle: .legs, equipment: .machine, technique: "Feet shoulder-width on the platform. Lower until the knees reach about 90° without the lower back lifting off the seat, then press without locking out."),
        .init(name: "Leg Extension", muscle: .legs, equipment: .machine, technique: "Align the knee with the machine pivot. Extend the legs fully, squeeze the quads for a moment, and lower slowly."),
        .init(name: "Romanian Deadlift", muscle: .legs, equipment: .barbell, technique: "Soft knees, push the hips back with the bar sliding down the thighs until you feel a hamstring stretch, then drive the hips forward."),
        .init(name: "Leg Curl", muscle: .legs, equipment: .machine, technique: "Align the knees with the pivot. Curl the pad toward the glutes, squeeze, and return slowly without letting the hips rise."),
        .init(name: "Calf Raises", muscle: .legs, equipment: .machine, technique: "Lower the heels for a full stretch, then rise onto the balls of the feet as high as possible and pause at the top."),
        // Added for the Upper A / Upper B program
        .init(name: "Incline Dumbbell Press", muscle: .chest, equipment: .dumbbell, technique: "Set the bench to about 30°. Press the dumbbells up and slightly together, lower until the elbows are just below the bench line, keeping the shoulder blades pinned back."),
        .init(name: "Pec Deck Fly", muscle: .chest, equipment: .machine, technique: "Set the seat so the handles are at chest height. Bring the arms together in a wide arc, squeeze the chest, and return slowly without letting the weight stack touch down."),
        .init(name: "Reverse Pec Deck", muscle: .shoulders, equipment: .machine, technique: "Sit facing the pad with the handles at shoulder height. Open the arms out to the sides, leading with the elbows, squeeze the rear shoulders, and return under control."),
        .init(name: "Overhead Triceps Extension", muscle: .arms, equipment: .dumbbell, technique: "Hold one dumbbell (or a cable rope) overhead with the elbows pointing forward. Lower it behind the head by bending only at the elbows, then extend fully."),
        .init(name: "Chest Supported Row", muscle: .back, equipment: .machine, technique: "Lie chest-down on an incline pad. Row the handles toward the lower ribs, squeezing the shoulder blades, and lower until the arms are fully stretched."),
        .init(name: "Incline Dumbbell Curl", muscle: .arms, equipment: .dumbbell, technique: "Sit on a bench at 45–60° with the arms hanging back. Curl without swinging the shoulders forward, squeeze at the top, and lower to a full stretch."),
        .init(name: "Reverse Curl", muscle: .arms, equipment: .barbell, technique: "Use an overhand grip on a barbell or EZ-bar. Keep the elbows at your sides and curl up with the wrists straight, then lower slowly."),
        // Core
        .init(name: "Plank", muscle: .core, equipment: .bodyweight, technique: "Forearms on the floor, body in a straight line from head to heels. Brace the abs and glutes and breathe steadily."),
        .init(name: "Cable Crunch", muscle: .core, equipment: .cable, technique: "Kneel facing the cable with the rope at your head. Curl the ribcage toward the pelvis, keeping the hips still, then return slowly.")
    ]

    static func seedIfNeeded(context: ModelContext) {
        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        let profile: UserProfile
        if let p = profiles.first {
            profile = p
        } else {
            profile = UserProfile()
            context.insert(profile)
        }

        // Insert any library exercise that does not exist yet (also covers app updates).
        let existing = Set(((try? context.fetch(FetchDescriptor<Exercise>())) ?? []).map { $0.name })
        for item in library where !existing.contains(item.name) {
            context.insert(Exercise(name: item.name, muscle: item.muscle, equipment: item.equipment, technique: item.technique))
        }
        try? context.save()

        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []

        if !profile.didSeedDemo {
            insertDemoTemplates(exercises: exercises, context: context)
            insertDemoWorkouts(exercises: exercises, context: context)
            profile.didSeedDemo = true
            try? context.save()
            StatsService.rebuildRecords(context)
        }

        if !profile.seededUpperProgram {
            insertUpperProgram(exercises: exercises, context: context)
            profile.seededUpperProgram = true
            try? context.save()
        }
    }

    // MARK: Upper A / Upper B program (name, sets, reps min, reps max, rest seconds)

    private static func insertUpperProgram(exercises: [Exercise], context: ModelContext) {
        func ex(_ n: String) -> Exercise? { exercises.first { $0.name == n } }
        let plans: [(String, [(String, Int, Int, Int, Int)])] = [
            ("Upper A — Chest, Shoulders, Triceps", [
                ("Bench Press", 3, 6, 8, 180),
                ("Incline Dumbbell Press", 3, 8, 12, 120),
                ("Pec Deck Fly", 2, 12, 15, 90),
                ("Shoulder Press", 3, 6, 10, 180),
                ("Lateral Raises", 4, 12, 20, 90),
                ("Reverse Pec Deck", 3, 12, 20, 90),
                ("Triceps Pushdown", 3, 10, 15, 90),
                ("Overhead Triceps Extension", 2, 10, 15, 90)]),
            ("Upper B — Back, Shoulders, Biceps", [
                ("Lat Pulldown", 3, 8, 12, 120),
                ("Chest Supported Row", 3, 8, 12, 120),
                ("Seated Cable Row", 3, 8, 12, 120),
                ("Shoulder Press", 3, 8, 10, 180),
                ("Lateral Raises", 4, 12, 20, 90),
                ("Reverse Pec Deck", 3, 12, 20, 90),
                ("Barbell Curl", 3, 8, 12, 90),
                ("Incline Dumbbell Curl", 2, 10, 15, 90),
                ("Reverse Curl", 2, 10, 15, 90)])
        ]
        for (name, items) in plans {
            let t = WorkoutTemplate(name: name)
            context.insert(t)
            for (i, item) in items.enumerated() {
                guard let e = ex(item.0) else { continue }
                let ti = TemplateItem(order: i, exercise: e, sets: item.1, reps: item.2)
                ti.repsMax = item.3
                ti.restSeconds = item.4
                context.insert(ti)
                ti.template = t
            }
        }
    }

    // MARK: Demo templates

    private static func insertDemoTemplates(exercises: [Exercise], context: ModelContext) {
        guard ((try? context.fetchCount(FetchDescriptor<WorkoutTemplate>())) ?? 0) == 0 else { return }
        func ex(_ n: String) -> Exercise? { exercises.first { $0.name == n } }
        let plans: [(String, [(String, Int, Int)])] = [
            ("Push Day", [("Bench Press", 4, 8), ("Incline Bench Press", 3, 10), ("Shoulder Press", 3, 10), ("Lateral Raises", 3, 15), ("Triceps Pushdown", 3, 12)]),
            ("Pull Day", [("Barbell Row", 4, 8), ("Lat Pulldown", 3, 10), ("Seated Cable Row", 3, 10), ("Face Pull", 3, 15), ("Barbell Curl", 3, 10)]),
            ("Leg Day", [("Squat", 4, 6), ("Romanian Deadlift", 3, 8), ("Leg Press", 3, 12), ("Leg Curl", 3, 12), ("Calf Raises", 4, 15)]),
            ("Full Body", [("Squat", 3, 8), ("Bench Press", 3, 8), ("Barbell Row", 3, 8), ("Shoulder Press", 3, 10), ("Hammer Curl", 3, 12)])
        ]
        for (name, items) in plans {
            let t = WorkoutTemplate(name: name, isDemo: true)
            context.insert(t)
            for (i, item) in items.enumerated() {
                guard let e = ex(item.0) else { continue }
                let ti = TemplateItem(order: i, exercise: e, sets: item.1, reps: item.2)
                context.insert(ti)
                ti.template = t
            }
        }
    }

    // MARK: Demo workouts (deterministic, removed after the first real workout)

    private struct Lift {
        let name: String
        let startKg: Double
        let stepKg: Double
        let reps: Int
    }

    private static func insertDemoWorkouts(exercises: [Exercise], context: ModelContext) {
        func ex(_ n: String) -> Exercise? { exercises.first { $0.name == n } }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let push: [Lift] = [.init(name: "Bench Press", startKg: 60, stepKg: 2.5, reps: 8),
                            .init(name: "Incline Bench Press", startKg: 45, stepKg: 2.5, reps: 10),
                            .init(name: "Shoulder Press", startKg: 20, stepKg: 1, reps: 10),
                            .init(name: "Triceps Pushdown", startKg: 25, stepKg: 2.5, reps: 12)]
        let pull: [Lift] = [.init(name: "Barbell Row", startKg: 50, stepKg: 2.5, reps: 8),
                            .init(name: "Lat Pulldown", startKg: 45, stepKg: 2.5, reps: 10),
                            .init(name: "Seated Cable Row", startKg: 40, stepKg: 2.5, reps: 10),
                            .init(name: "Barbell Curl", startKg: 25, stepKg: 2.5, reps: 10)]
        let legs: [Lift] = [.init(name: "Squat", startKg: 70, stepKg: 5, reps: 6),
                            .init(name: "Romanian Deadlift", startKg: 60, stepKg: 5, reps: 8),
                            .init(name: "Leg Press", startKg: 120, stepKg: 10, reps: 12),
                            .init(name: "Calf Raises", startKg: 60, stepKg: 5, reps: 15)]

        // (name, lifts, daysAgo for weeks 0...5 (oldest → newest), start hour)
        let plan: [(String, [Lift], [Int], Int)] = [
            ("Push Day", push, [40, 33, 26, 19, 12, 5], 18),
            ("Pull Day", pull, [38, 31, 24, 17, 10, 3], 18),
            ("Leg Day", legs, [36, 29, 22, 15, 8, 1], 17)
        ]
        let repBump = [0, 0, 1, 0, 1, 0]

        for (name, lifts, days, hour) in plan {
            for week in 0..<6 {
                guard let day = cal.date(byAdding: .day, value: -days[week], to: today),
                      let start = cal.date(bySettingHour: hour, minute: 30, second: 0, of: day) else { continue }
                let minutes = 52 + (week % 3) * 4
                let w = Workout(name: name, startedAt: start,
                                endedAt: start.addingTimeInterval(Double(minutes) * 60),
                                isFinished: true, isDemo: true)
                context.insert(w)
                for (i, lift) in lifts.enumerated() {
                    guard let e = ex(lift.name) else { continue }
                    let entry = WorkoutExercise(order: i, exercise: e)
                    context.insert(entry)
                    entry.workout = w
                    let weight = lift.startKg + lift.stepKg * Double(week)
                    let reps = lift.reps + repBump[week]
                    for s in 0..<3 {
                        let set = WorkoutSet(order: s, weightKg: weight, reps: s == 2 ? max(reps - 1, 1) : reps, isCompleted: true)
                        set.completedAt = start.addingTimeInterval(Double(i * 600 + s * 150))
                        context.insert(set)
                        set.workoutExercise = entry
                    }
                }
            }
        }
    }
}
