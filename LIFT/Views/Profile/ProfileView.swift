import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        NavigationStack {
            if let profile = profiles.first {
                ProfileForm(profile: profile)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).screenBackground()
            }
        }
    }
}

private struct ProfileForm: View {
    @Bindable var profile: UserProfile

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Workout> { $0.isFinished == true }) private var workouts: [Workout]
    @Query private var records: [PersonalRecord]

    @AppStorage(Lang.key) private var language: String = "ru"
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var exportFailed = false
    @State private var confirmReset = false
    @State private var notificationsDenied = false

    private let restOptions = [30, 60, 90, 120, 180]

    private var realWorkouts: [Workout] { workouts.filter { !$0.isDemo } }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Text(String((profile.name.first ?? "L")).uppercased())
                        .font(.lift(24, .bold))
                        .frame(width: 56, height: 56)
                        .background(Theme.cardHigh, in: Circle())
                    TextField(tr("Your name"), text: $profile.name)
                        .font(.lift(20, .bold))
                }
            }
            .listRowBackground(Theme.card)

            Section(tr("Language")) {
                Picker(tr("Language"), selection: $language) {
                    ForEach(AppLanguage.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Theme.card)

            Section(tr("Units")) {
                Picker(tr("Weight"), selection: Binding(get: { profile.unit }, set: { profile.unit = $0 })) {
                    ForEach(WeightUnit.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Theme.card)

            Section(tr("Tools")) {
                NavigationLink { MyMaxesView() } label: { Label(tr("My one-rep maxes"), systemImage: "scalemass") }
                NavigationLink { ScienceView() } label: { Label(tr("Scientific basis"), systemImage: "book") }
            }
            .listRowBackground(Theme.card)

            Section(tr("Training stats")) {
                statRow(tr("Workouts"), "\(realWorkouts.count)")
                statRow(tr("Total sets"), "\(realWorkouts.reduce(0) { $0 + $1.completedSets.count })")
                statRow(tr("Total volume"), "\(profile.unit.formatVolume(realWorkouts.reduce(0) { $0 + $1.totalVolumeKg })) \(profile.unit.label)")
                statRow(tr("Personal records"), "\(records.filter { !$0.isBaseline }.count)")
                Stepper(value: $profile.weeklyGoal, in: 1...7) {
                    HStack { Text(tr("Weekly goal")); Spacer(); Text(trf("%d per week", profile.weeklyGoal)).foregroundStyle(Theme.textSecondary) }
                }
            }
            .listRowBackground(Theme.card)

            Section(tr("Progression")) {
                Stepper(value: stepBinding, in: 0.5...10, step: 0.5) {
                    HStack {
                        Text(tr("Suggested step"))
                        Spacer()
                        Text(profile.unit.format(profile.progressionStepKg)).foregroundStyle(Theme.textSecondary)
                    }
                }
                Text(tr("When you reach the top of the target rep range on every working set (8 reps if none is set), LIFT suggests adding this much weight next time."))
                    .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
            }
            .listRowBackground(Theme.card)

            Section(tr("Rest timer")) {
                Picker(tr("Default rest"), selection: $profile.defaultRestSeconds) {
                    ForEach(restOptions, id: \.self) { Text(trf("%d s", $0)).tag($0) }
                }
                Toggle(tr("Start automatically after a set"), isOn: $profile.autoStartRest)
                Toggle(tr("Sound when finished"), isOn: $profile.soundEnabled)
                Toggle(tr("Vibration when finished"), isOn: $profile.hapticsEnabled)
            }
            .listRowBackground(Theme.card)

            Section(tr("Notifications")) {
                Toggle(tr("Rest timer alerts"), isOn: Binding(get: { profile.restAlertsEnabled }, set: { on in
                    if on { requestAuth { granted in profile.restAlertsEnabled = granted } }
                    else { profile.restAlertsEnabled = false }
                }))
                Toggle(tr("Daily workout reminder"), isOn: Binding(get: { profile.reminderEnabled }, set: { on in
                    if on {
                        requestAuth { granted in
                            profile.reminderEnabled = granted
                            if granted { NotificationService.scheduleDailyReminder(hour: profile.reminderHour, minute: profile.reminderMinute) }
                        }
                    } else {
                        profile.reminderEnabled = false
                        NotificationService.cancelReminder()
                    }
                }))
                if profile.reminderEnabled {
                    DatePicker(tr("Reminder time"), selection: reminderTime, displayedComponents: .hourAndMinute)
                }
                if notificationsDenied {
                    Text(tr("Notifications are turned off for LIFT in iOS Settings."))
                        .font(.lift(12, .medium)).foregroundStyle(Theme.danger)
                }
            }
            .listRowBackground(Theme.card)

            Section(tr("Appearance")) {
                Picker(tr("Theme"), selection: Binding(get: { profile.theme }, set: { profile.theme = $0 })) {
                    ForEach(ThemeMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Theme.card)

            Section {
                NavigationLink { LeaderboardView() } label: { Label(tr("Leaderboard"), systemImage: "trophy.fill") }
            }
            .listRowBackground(Theme.card)

            Section(tr("Data")) {
                Button { export() } label: { Label(tr("Export workout history (CSV)"), systemImage: "square.and.arrow.up") }
                if workouts.contains(where: { $0.isDemo }) {
                    Button { WorkoutService.deleteDemoData(context: context) } label: {
                        Label(tr("Remove demo data"), systemImage: "sparkles")
                    }
                }
                Button(role: .destructive) { confirmReset = true } label: {
                    Label(tr("Delete all workout data"), systemImage: "trash")
                }
            }
            .listRowBackground(Theme.card)

            Section(tr("About")) {
                statRow(tr("Version"), "1.0")
                Text(tr("All data is stored on this device. No account or internet connection required. 1RM values use the Epley formula and are estimates."))
                    .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .tabBarClearance()
        .navigationTitle(tr("Profile"))
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showShare) {
            if let exportURL { ShareSheet(items: [exportURL]) }
        }
        .alert(tr("Export failed"), isPresented: $exportFailed) {
            Button(tr("OK"), role: .cancel) {}
        } message: { Text(tr("Could not create the export file.")) }
        .confirmationDialog(tr("Delete all workout data?"), isPresented: $confirmReset, titleVisibility: .visible) {
            Button(tr("Delete Everything"), role: .destructive) { WorkoutService.deleteAllWorkoutData(context: context) }
            Button(tr("Cancel"), role: .cancel) {}
        } message: {
            Text(tr("This permanently removes all workouts, progress and records. Exercises and programs are kept."))
        }
        .onChange(of: profile.defaultRestSeconds) { _, _ in try? context.save() }
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).font(.lift(15, .bold)).foregroundStyle(Theme.textSecondary)
        }
    }

    private var stepBinding: Binding<Double> {
        Binding(
            get: { (profile.unit.display(profile.progressionStepKg) * 2).rounded() / 2 },
            set: { profile.progressionStepKg = profile.unit.toKg($0) })
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: profile.reminderHour, minute: profile.reminderMinute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                profile.reminderHour = c.hour ?? 18
                profile.reminderMinute = c.minute ?? 0
                if profile.reminderEnabled {
                    NotificationService.scheduleDailyReminder(hour: profile.reminderHour, minute: profile.reminderMinute)
                }
            })
    }

    private func requestAuth(_ completion: @escaping (Bool) -> Void) {
        NotificationService.requestAuthorization { granted in
            notificationsDenied = !granted
            completion(granted)
        }
    }

    private func export() {
        if let url = ExportService.exportCSV(context: context) {
            exportURL = url
            showShare = true
        } else {
            exportFailed = true
        }
    }
}
