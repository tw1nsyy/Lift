import Foundation
import SwiftData
import SwiftUI

// MARK: - Enums

enum MuscleGroup: String, CaseIterable, Identifiable, Codable {
    case chest = "Chest", back = "Back", shoulders = "Shoulders", arms = "Arms", legs = "Legs", core = "Core"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .chest: "figure.strengthtraining.traditional"
        case .back: "figure.rowing"
        case .shoulders: "figure.arms.open"
        case .arms: "dumbbell.fill"
        case .legs: "figure.run"
        case .core: "figure.core.training"
        }
    }
}

enum Equipment: String, CaseIterable, Identifiable, Codable {
    case barbell = "Barbell", dumbbell = "Dumbbell", machine = "Machine", cable = "Cable", bodyweight = "Bodyweight"
    var id: String { rawValue }
}

enum ThemeMode: String, CaseIterable, Identifiable {
    case dark = "Dark", light = "Light", system = "System"
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: ColorScheme.dark
        case .light: ColorScheme.light
        case .system: nil
        }
    }
}

enum RecordType: String, CaseIterable, Identifiable {
    case maxWeight = "Max Weight"
    case oneRM = "Best 1RM (est.)"
    case maxReps = "Most Reps"
    case sessionVolume = "Session Volume"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .maxWeight: "scalemass.fill"
        case .oneRM: "bolt.fill"
        case .maxReps: "repeat"
        case .sessionVolume: "chart.bar.fill"
        }
    }
    func formatted(_ value: Double, unit: WeightUnit) -> String {
        switch self {
        case .maxReps: return "\(Int(value)) reps"
        case .sessionVolume: return "\(unit.formatVolume(value)) \(unit.label)"
        default: return unit.format(value)
        }
    }
}

enum ChartMetric: String, CaseIterable, Identifiable {
    case oneRM = "1RM", maxWeight = "Max Weight", volume = "Volume", reps = "Reps"
    var id: String { rawValue }
    var isWeightBased: Bool { self != .reps }
    var title: String {
        switch self {
        case .oneRM: "Estimated 1RM"
        case .maxWeight: "Max working weight"
        case .volume: "Volume per session"
        case .reps: "Max reps in a set"
        }
    }
}

// MARK: - Models

@Model
final class UserProfile {
    var name: String
    var unitRaw: String
    var themeRaw: String
    var defaultRestSeconds: Int
    var autoStartRest: Bool
    var soundEnabled: Bool
    var hapticsEnabled: Bool
    var restAlertsEnabled: Bool
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var weeklyGoal: Int
    var createdAt: Date
    var didSeedDemo: Bool
    var didOnboard: Bool = false
    /// Weight added when the app suggests a progression (kg).
    var progressionStepKg: Double = 2.0

    init(name: String = "") {
        self.name = name
        self.unitRaw = WeightUnit.kg.rawValue
        self.themeRaw = ThemeMode.dark.rawValue
        self.defaultRestSeconds = 90
        self.autoStartRest = true
        self.soundEnabled = true
        self.hapticsEnabled = true
        self.restAlertsEnabled = true
        self.reminderEnabled = false
        self.reminderHour = 18
        self.reminderMinute = 0
        self.weeklyGoal = 3
        self.createdAt = Date()
        self.didSeedDemo = false
    }

    var unit: WeightUnit {
        get { WeightUnit(rawValue: unitRaw) ?? .kg }
        set { unitRaw = newValue.rawValue }
    }
    var theme: ThemeMode {
        get { ThemeMode(rawValue: themeRaw) ?? .dark }
        set { themeRaw = newValue.rawValue }
    }
}

@Model
final class Exercise {
    var id: UUID
    var name: String
    var muscleRaw: String
    var equipmentRaw: String
    var technique: String
    var isFavorite: Bool
    var isCustom: Bool

    init(name: String, muscle: MuscleGroup, equipment: Equipment, technique: String = "", isCustom: Bool = false) {
        self.id = UUID()
        self.name = name
        self.muscleRaw = muscle.rawValue
        self.equipmentRaw = equipment.rawValue
        self.technique = technique
        self.isFavorite = false
        self.isCustom = isCustom
    }

    var muscle: MuscleGroup {
        get { MuscleGroup(rawValue: muscleRaw) ?? .chest }
        set { muscleRaw = newValue.rawValue }
    }
    var equipment: Equipment {
        get { Equipment(rawValue: equipmentRaw) ?? .barbell }
        set { equipmentRaw = newValue.rawValue }
    }
}

@Model
final class Workout {
    var id: UUID
    var name: String
    var startedAt: Date
    var endedAt: Date?
    var isFinished: Bool
    var isDemo: Bool
    var note: String

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise] = []

    init(name: String, startedAt: Date = Date(), endedAt: Date? = nil, isFinished: Bool = false, isDemo: Bool = false) {
        self.id = UUID()
        self.name = name
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.isFinished = isFinished
        self.isDemo = isDemo
        self.note = ""
    }

    var sortedExercises: [WorkoutExercise] { exercises.sorted { $0.order < $1.order } }
    var allSets: [WorkoutSet] { exercises.flatMap { $0.sets } }
    /// Completed working sets (warm-ups excluded).
    var completedSets: [WorkoutSet] { allSets.filter { $0.isCompleted && !$0.isWarmup } }
    /// Total volume = Σ weight × reps over completed sets (kg).
    var totalVolumeKg: Double { completedSets.reduce(0) { $0 + Formulas.volume(weight: $1.weightKg, reps: $1.reps) } }
    var duration: TimeInterval { (endedAt ?? Date()).timeIntervalSince(startedAt) }
}

@Model
final class WorkoutExercise {
    var id: UUID
    var order: Int
    var exerciseName: String
    var exercise: Exercise?
    var workout: Workout?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.workoutExercise)
    var sets: [WorkoutSet] = []

    init(order: Int, exercise: Exercise) {
        self.id = UUID()
        self.order = order
        self.exercise = exercise
        self.exerciseName = exercise.name
    }

    var sortedSets: [WorkoutSet] { sets.sorted { $0.order < $1.order } }
}

@Model
final class WorkoutSet {
    var id: UUID
    var order: Int
    var weightKg: Double
    var reps: Int
    var isCompleted: Bool
    var completedAt: Date?
    var isWarmup: Bool = false
    var workoutExercise: WorkoutExercise?

    init(order: Int, weightKg: Double, reps: Int, isCompleted: Bool = false) {
        self.id = UUID()
        self.order = order
        self.weightKg = weightKg
        self.reps = reps
        self.isCompleted = isCompleted
        self.completedAt = isCompleted ? Date() : nil
    }
}

@Model
final class PersonalRecord {
    var id: UUID
    var exerciseID: UUID
    var exerciseName: String
    var typeRaw: String
    var value: Double
    var date: Date
    var workoutID: UUID
    /// First-ever value for this exercise/type. Not shown as a "new record".
    var isBaseline: Bool

    init(exerciseID: UUID, exerciseName: String, type: RecordType, value: Double, date: Date, workoutID: UUID, isBaseline: Bool) {
        self.id = UUID()
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.typeRaw = type.rawValue
        self.value = value
        self.date = date
        self.workoutID = workoutID
        self.isBaseline = isBaseline
    }

    var type: RecordType { RecordType(rawValue: typeRaw) ?? .maxWeight }
}

@Model
final class WorkoutTemplate {
    var id: UUID
    var name: String
    var createdAt: Date
    var isDemo: Bool
    /// Bitmask of planned weekdays: bit (weekday - 1), Calendar weekday 1 = Sunday.
    var weekdayMask: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \TemplateItem.template)
    var items: [TemplateItem] = []

    init(name: String, isDemo: Bool = false) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.isDemo = isDemo
    }

    var sortedItems: [TemplateItem] { items.sorted { $0.order < $1.order } }
    var totalSets: Int { items.reduce(0) { $0 + $1.sets } }

    func isPlanned(weekday: Int) -> Bool { weekdayMask & (1 << (weekday - 1)) != 0 }
    func setPlanned(weekday: Int, _ on: Bool) {
        if on { weekdayMask |= (1 << (weekday - 1)) } else { weekdayMask &= ~(1 << (weekday - 1)) }
    }
}

@Model
final class TemplateItem {
    var id: UUID
    var order: Int
    var sets: Int
    var reps: Int
    var weightKg: Double
    var exercise: Exercise?
    var template: WorkoutTemplate?

    init(order: Int, exercise: Exercise, sets: Int = 3, reps: Int = 10, weightKg: Double = 0) {
        self.id = UUID()
        self.order = order
        self.exercise = exercise
        self.sets = sets
        self.reps = reps
        self.weightKg = weightKg
    }
}
