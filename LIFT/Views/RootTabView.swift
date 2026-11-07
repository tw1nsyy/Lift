import SwiftUI
import SwiftData

enum AppTab: String, CaseIterable, Identifiable {
    case today = "Today", workout = "Workout", progress = "Progress", history = "History", profile = "Profile"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .today: "sun.max.fill"
        case .workout: "dumbbell.fill"
        case .progress: "chart.line.uptrend.xyaxis"
        case .history: "clock.arrow.circlepath"
        case .profile: "person.crop.circle.fill"
        }
    }
}

struct RootTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppRouter.self) private var router
    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<Workout> { $0.isFinished == false }) private var activeWorkouts: [Workout]

    private var unit: WeightUnit { profiles.first?.unit ?? .kg }

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.tab) {
            TodayView().tag(AppTab.today).toolbar(.hidden, for: .tabBar)
            WorkoutHomeView().tag(AppTab.workout).toolbar(.hidden, for: .tabBar)
            ProgressTabView().tag(AppTab.progress).toolbar(.hidden, for: .tabBar)
            HistoryView().tag(AppTab.history).toolbar(.hidden, for: .tabBar)
            ProfileView().tag(AppTab.profile).toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if let active = activeWorkouts.first, router.presentedWorkout == nil {
                    ActiveWorkoutBar(workout: active) { router.presentedWorkout = active }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                CustomTabBar(selection: $router.tab)
            }
            .background(
                LinearGradient(colors: [Theme.background.opacity(0), Theme.background], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: activeWorkouts.count)
        .fullScreenCover(item: $router.presentedWorkout) { workout in
            ActiveWorkoutView(workout: workout)
                .environment(\.weightUnit, unit)
                .preferredColorScheme(profiles.first?.theme.colorScheme)
        }
        .environment(\.weightUnit, unit)
        .preferredColorScheme(profiles.first?.theme.colorScheme)
        .tint(Theme.accent)
        .overlay {
            if let p = profiles.first, !p.didOnboard {
                OnboardingView(profile: p).transition(.opacity).zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: profiles.first?.didOnboard)
        .task { SeedService.seedIfNeeded(context: context) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { try? context.save() }
        }
    }
}

struct CustomTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 19, weight: .semibold))
                            .symbolEffect(.bounce, value: selection == tab)
                        Text(tab.rawValue).font(.lift(10, .semibold))
                    }
                    .foregroundStyle(selection == tab ? Theme.textPrimary : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if selection == tab {
                            Capsule().fill(Theme.cardHigh).matchedGeometryEffect(id: "tab-bg", in: namespace)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Theme.card, in: Capsule())
        .overlay(Capsule().stroke(Theme.hairline, lineWidth: 0.5))
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .padding(.top, 6)
    }
}

struct ActiveWorkoutBar: View {
    let workout: Workout
    let onResume: () -> Void

    var body: some View {
        Button(action: onResume) {
            HStack(spacing: 12) {
                Circle().fill(Theme.accent).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.name).font(.lift(15, .bold)).foregroundStyle(Theme.textPrimary)
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text(elapsedString(from: workout.startedAt, to: ctx.date))
                            .font(.lift(12, .medium))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Text("Resume")
                    .font(.lift(14, .bold))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.textPrimary, in: Capsule())
            }
            .padding(12)
            .background(Theme.cardHigh, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
}
