import SwiftUI
import SwiftData

@main
struct LIFTApp: App {
    private let container: ModelContainer
    @State private var router = AppRouter()
    @State private var restTimer = RestTimerManager()
    @State private var leaderboard = LeaderboardStore()

    init() {
        do {
            container = try ModelContainer(for:
                UserProfile.self, Exercise.self, Workout.self, WorkoutExercise.self,
                WorkoutSet.self, PersonalRecord.self, WorkoutTemplate.self, TemplateItem.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .modelContainer(container)
                .environment(router)
                .environment(restTimer)
                .environment(leaderboard)
        }
    }
}
