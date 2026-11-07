import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context
    @State private var page = 0

    private let restOptions = [30, 60, 90, 120, 180]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcome.tag(0)
                    about.tag(1)
                    goals.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(i == page ? Theme.textPrimary : Theme.cardHigh)
                            .frame(width: i == page ? 22 : 8, height: 8)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
                    }
                }
                .padding(.bottom, 16)

                Button(page == 2 ? "Get Started" : "Continue") {
                    hideKeyboard()
                    Haptics.tap()
                    if page == 2 {
                        profile.didOnboard = true
                        try? context.save()
                    } else {
                        withAnimation { page += 1 }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private func hero(_ icon: String, _ title: String, _ text: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(Theme.accent)
                .padding(.bottom, 8)
            Text(title).font(.lift(32, .bold)).multilineTextAlignment(.center)
            Text(text)
                .font(.lift(16, .medium)).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private var welcome: some View {
        hero("dumbbell.fill", "Welcome to LIFT",
             "Log every set, watch every lift grow. Everything stays on your phone, no account needed.")
    }

    private var about: some View {
        VStack(spacing: 22) {
            Spacer()
            feature("square.and.pencil", "Fast logging", "Weights and reps are prefilled from your last session.")
            feature("chart.line.uptrend.xyaxis", "Real progress", "Per-exercise charts for estimated 1RM, weight, volume and reps.")
            feature("lightbulb.fill", "Smart suggestions", "Hit your reps on every set and LIFT suggests when to add weight.")
            feature("trophy.fill", "Personal records", "New records are detected automatically, never invented.")
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private func feature(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 44, height: 44)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.lift(17, .bold))
                Text(text).font(.lift(13, .medium)).foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var goals: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Set up your profile").font(.lift(30, .bold)).padding(.top, 40)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your name").font(.lift(13, .semibold)).foregroundStyle(Theme.textSecondary)
                    TextField("Optional", text: $profile.name)
                        .font(.lift(18, .semibold))
                        .padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Weight unit").font(.lift(13, .semibold)).foregroundStyle(Theme.textSecondary)
                    Picker("Unit", selection: Binding(get: { profile.unit }, set: { profile.unit = $0 })) {
                        ForEach(WeightUnit.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Workouts per week").font(.lift(13, .semibold)).foregroundStyle(Theme.textSecondary)
                    Stepper(value: $profile.weeklyGoal, in: 1...7) {
                        Text("\(profile.weeklyGoal) per week").font(.lift(18, .bold))
                    }
                    .padding(14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Default rest between sets").font(.lift(13, .semibold)).foregroundStyle(Theme.textSecondary)
                    HStack(spacing: 8) {
                        ForEach(restOptions, id: \.self) { s in
                            let on = profile.defaultRestSeconds == s
                            Button { profile.defaultRestSeconds = s } label: {
                                Text("\(s)s")
                                    .font(.lift(14, .bold))
                                    .foregroundStyle(on ? Theme.background : Theme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(on ? Theme.textPrimary : Theme.card, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
