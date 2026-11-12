import SwiftUI
import SwiftData

enum AppTab: String, CaseIterable, Identifiable {
    case today = "Today", workout = "Workout", progress = "Progress", history = "History", profile = "Profile"
    var id: String { rawValue }
    var title: String { tr(rawValue) }
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
    @Environment(LeaderboardStore.self) private var leaderboard
    @AppStorage(Lang.key) private var language: String = "ru"
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
        .id(language)
        .overlay(alignment: .bottom) {
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
                .environment(\.locale, Lang.locale)
                .preferredColorScheme(profiles.first?.theme.colorScheme)
        }
        .environment(\.weightUnit, unit)
        .environment(\.locale, Lang.locale)
        .preferredColorScheme(profiles.first?.theme.colorScheme)
        .tint(Theme.accent)
        .overlay {
            if let p = profiles.first, !p.didOnboard {
                OnboardingView(profile: p).transition(.opacity).zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: profiles.first?.didOnboard)
        .task {
            SeedService.seedIfNeeded(context: context)
            await leaderboard.sync(context: context)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                try? context.save()
            } else {
                Task { await leaderboard.sync(context: context) }
            }
        }
    }
}

struct CustomTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                TabBarButton(tab: tab, isSelected: selection == tab, namespace: namespace) {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = tab }
                }
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

struct TabBarButton: View {
    let tab: AppTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    private var tint: Color {
        if isSelected { return Theme.textPrimary }
        return Theme.textSecondary
    }

    var body: some View {
        Button(action: action) {
            content
        }
        .buttonStyle(.plain)
    }

    private var content: some View {
        VStack(spacing: 4) {
            Image(systemName: tab.icon)
                .font(.system(size: 19, weight: .semibold))
                .symbolEffect(.bounce, value: isSelected)
            Text(tab.title)
                .font(.lift(10, .semibold))
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(highlight)
    }

    @ViewBuilder
    private var highlight: some View {
        if isSelected {
            Capsule()
                .fill(Theme.cardHigh)
                .matchedGeometryEffect(id: "tab-bg", in: namespace)
        }
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
                    Text(tr(workout.name)).font(.lift(15, .bold)).foregroundStyle(Theme.textPrimary)
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text(elapsedString(from: workout.startedAt, to: ctx.date))
                            .font(.lift(12, .medium))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Text(tr("Resume"))
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
