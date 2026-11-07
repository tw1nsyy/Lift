import XCTest
import SwiftData
@testable import LIFT

@MainActor
final class LIFTTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: UserProfile.self, Exercise.self, Workout.self, WorkoutExercise.self,
            WorkoutSet.self, PersonalRecord.self, WorkoutTemplate.self, TemplateItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private func addWorkout(_ context: ModelContext, exercise: Exercise, daysAgo: Int,
                            sets: [(Double, Int)], warmup: Bool = false) -> Workout {
        let start = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let w = Workout(name: "Test", startedAt: start, endedAt: start.addingTimeInterval(3600), isFinished: true)
        context.insert(w)
        let we = WorkoutExercise(order: 0, exercise: exercise)
        context.insert(we)
        we.workout = w
        for (i, s) in sets.enumerated() {
            let set = WorkoutSet(order: i, weightKg: s.0, reps: s.1, isCompleted: true)
            set.isWarmup = warmup
            context.insert(set)
            set.workoutExercise = we
        }
        return w
    }

    // MARK: Formulas & units

    func testEpley() {
        XCTAssertEqual(Formulas.epley1RM(weight: 100, reps: 5), 100 * (1 + 5.0 / 30), accuracy: 0.0001)
        XCTAssertEqual(Formulas.epley1RM(weight: 0, reps: 5), 0)
        XCTAssertEqual(Formulas.epley1RM(weight: 100, reps: 0), 0)
    }

    func testVolume() {
        XCTAssertEqual(Formulas.volume(weight: 80, reps: 8), 640)
    }

    func testUnitRoundTrip() {
        let kg = WeightUnit.lb.toKg(135)
        XCTAssertEqual(WeightUnit.lb.display(kg), 135, accuracy: 0.0001)
        XCTAssertEqual(WeightUnit.kg.format(82.5), "82.5 kg")
        XCTAssertEqual(WeightUnit.kg.format(80), "80 kg")
    }

    // MARK: Trend

    func testTrendNeedsTwoValues() {
        if case .insufficient = StatsService.trend(values: [100]) {} else { XCTFail("expected insufficient") }
    }

    func testTrendUpFlatDown() {
        if case .up(let p) = StatsService.trend(values: [100, 110]) { XCTAssertEqual(p, 10, accuracy: 0.001) } else { XCTFail() }
        if case .flat = StatsService.trend(values: [100, 100]) {} else { XCTFail() }
        if case .down = StatsService.trend(values: [100, 90]) {} else { XCTFail() }
    }

    // MARK: Records

    func testRecordsBaselineThenImprovement() throws {
        let context = try makeContext()
        let bench = Exercise(name: "Bench Press", muscle: .chest, equipment: .barbell)
        context.insert(bench)
        _ = addWorkout(context, exercise: bench, daysAgo: 10, sets: [(60, 8)])
        let second = addWorkout(context, exercise: bench, daysAgo: 3, sets: [(65, 8)])
        try context.save()

        StatsService.rebuildRecords(context)
        let records = try context.fetch(FetchDescriptor<PersonalRecord>())
        let fresh = records.filter { $0.workoutID == second.id && !$0.isBaseline }
        XCTAssertFalse(fresh.isEmpty)
        XCTAssertTrue(records.contains { $0.isBaseline })
        XCTAssertTrue(fresh.contains { $0.type == .maxWeight && $0.value == 65 })
    }

    func testDeletingWorkoutRebuildsRecords() throws {
        let context = try makeContext()
        let squat = Exercise(name: "Squat", muscle: .legs, equipment: .barbell)
        context.insert(squat)
        _ = addWorkout(context, exercise: squat, daysAgo: 10, sets: [(100, 5)])
        let best = addWorkout(context, exercise: squat, daysAgo: 2, sets: [(120, 5)])
        try context.save()
        StatsService.rebuildRecords(context)

        WorkoutService.delete(best, context: context)
        let records = try context.fetch(FetchDescriptor<PersonalRecord>())
        XCTAssertEqual(records.filter { $0.type == .maxWeight }.map(\.value).max(), 100)
        XCTAssertTrue(records.allSatisfy { $0.isBaseline })
    }

    func testWarmupSetsAreIgnored() throws {
        let context = try makeContext()
        let bench = Exercise(name: "Bench Press", muscle: .chest, equipment: .barbell)
        context.insert(bench)
        let w = addWorkout(context, exercise: bench, daysAgo: 1, sets: [(40, 10)], warmup: true)
        try context.save()
        XCTAssertEqual(w.totalVolumeKg, 0)
        XCTAssertTrue(StatsService.sessions(for: bench, in: [w]).isEmpty)
    }

    func testWorkoutVolumeOnlyCountsCompletedSets() throws {
        let context = try makeContext()
        let row = Exercise(name: "Barbell Row", muscle: .back, equipment: .barbell)
        context.insert(row)
        let w = addWorkout(context, exercise: row, daysAgo: 0, sets: [(50, 10), (50, 10)])
        w.exercises[0].sets[1].isCompleted = false
        XCTAssertEqual(w.totalVolumeKg, 500)
    }

    // MARK: Suggestions

    func testSuggestionAddsWeightWhenRepsReached() {
        let ex = Exercise(name: "Bench Press", muscle: .chest, equipment: .barbell)
        let session = ExerciseSession(id: UUID(), date: Date(), sets: [
            SetSnapshot(weightKg: 80, reps: 8), SetSnapshot(weightKg: 80, reps: 9), SetSnapshot(weightKg: 80, reps: 8)])
        let s = StatsService.suggestion(for: ex, last: session, stepKg: 2, unit: .kg)
        XCTAssertEqual(s?.weightKg, 82)
    }

    func testSuggestionKeepsWeightWhenRepsMissed() {
        let ex = Exercise(name: "Bench Press", muscle: .chest, equipment: .barbell)
        let session = ExerciseSession(id: UUID(), date: Date(), sets: [
            SetSnapshot(weightKg: 80, reps: 6), SetSnapshot(weightKg: 80, reps: 5)])
        let s = StatsService.suggestion(for: ex, last: session, stepKg: 2, unit: .kg)
        XCTAssertEqual(s?.weightKg, 80)
        XCTAssertEqual(s?.reps, 6)
    }

    func testNoSuggestionForBodyweight() {
        let ex = Exercise(name: "Pull Ups", muscle: .back, equipment: .bodyweight)
        let session = ExerciseSession(id: UUID(), date: Date(), sets: [SetSnapshot(weightKg: 0, reps: 10)])
        XCTAssertNil(StatsService.suggestion(for: ex, last: session, stepKg: 2, unit: .kg))
    }

    // MARK: Plan

    func testWeekdayMask() {
        let t = WorkoutTemplate(name: "Push")
        t.setPlanned(weekday: 2, true)
        XCTAssertTrue(t.isPlanned(weekday: 2))
        XCTAssertFalse(t.isPlanned(weekday: 3))
        t.setPlanned(weekday: 2, false)
        XCTAssertEqual(t.weekdayMask, 0)
    }
}
