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
                    TextField("Your name", text: $profile.name)
                        .font(.lift(20, .bold))
                }
            }
            .listRowBackground(Theme.card)

            Section("Units") {
                Picker("Weight", selection: Binding(get: { profile.unit }, set: { profile.unit = $0 })) {
                    ForEach(WeightUnit.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Theme.card)

            Section("Training stats") {
                statRow("Workouts", "\(realWorkouts.count)")
                statRow("Total sets", "\(realWorkouts.reduce(0) { $0 + $1.completedSets.count })")
                statRow("Total volume", "\(profile.unit.formatVolume(realWorkouts.reduce(0) { $0 + $1.totalVolumeKg })) \(profile.unit.label)")
                statRow("Personal records", "\(records.filter { !$0.isBaseline }.count)")
                Stepper(value: $profile.weeklyGoal, in: 1...7) {
                    HStack { Text("Weekly goal"); Spacer(); Text("\(profile.weeklyGoal) workouts").foregroundStyle(Theme.textSecondary) }
                }
            }
            .listRowBackground(Theme.card)

            Section("Progression") {
                Stepper(value: stepBinding, in: 0.5...10, step: 0.5) {
                    HStack {
                        Text("Suggested step")
                        Spacer()
                        Text(profile.unit.format(profile.progressionStepKg)).foregroundStyle(Theme.textSecondary)
                    }
                }
                Text("When you hit 8+ reps on every working set, LIFT suggests adding this much weight next time.")
                    .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
            }
            .listRowBackground(Theme.card)

            Section("Rest timer") {
                Picker("Default rest", selection: $profile.defaultRestSeconds) {
                    ForEach(restOptions, id: \.self) { Text("\($0) s").tag($0) }
                }
                Toggle("Start automatically after a set", isOn: $profile.autoStartRest)
                Toggle("Sound when finished", isOn: $profile.soundEnabled)
                Toggle("Vibration when finished", isOn: $profile.hapticsEnabled)
            }
            .listRowBackground(Theme.card)

            Section("Notifications") {
                Toggle("Rest timer alerts", isOn: Binding(get: { profile.restAlertsEnabled }, set: { on in
                    if on { requestAuth { granted in profile.restAlertsEnabled = granted } }
                    else { profile.restAlertsEnabled = false }
                }))
                Toggle("Daily workout reminder", isOn: Binding(get: { profile.reminderEnabled }, set: { on in
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
                    DatePicker("Reminder time", selection: reminderTime, displayedComponents: .hourAndMinute)
                }
                if notificationsDenied {
                    Text("Notifications are turned off for LIFT in iOS Settings.")
                        .font(.lift(12, .medium)).foregroundStyle(Theme.danger)
                }
            }
            .listRowBackground(Theme.card)

            Section("Appearance") {
                Picker("Theme", selection: Binding(get: { profile.theme }, set: { profile.theme = $0 })) {
                    ForEach(ThemeMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Theme.card)

            Section("Data") {
                Button { export() } label: { Label("Export workout history (CSV)", systemImage: "square.and.arrow.up") }
                if workouts.contains(where: { $0.isDemo }) {
                    Button { WorkoutService.deleteDemoData(context: context) } label: {
                        Label("Remove demo data", systemImage: "sparkles")
                    }
                }
                Button(role: .destructive) { confirmReset = true } label: {
                    Label("Delete all workout data", systemImage: "trash")
                }
            }
            .listRowBackground(Theme.card)

            Section("About") {
                statRow("Version", "1.0")
                Text("All data is stored on this device. No account or internet connection required. 1RM values use the Epley formula and are estimates.")
                    .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Profile")
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showShare) {
            if let exportURL { ShareSheet(items: [exportURL]) }
        }
        .alert("Export failed", isPresented: $exportFailed) {
            Button("OK", role: .cancel) {}
        } message: { Text("Could not create the export file.") }
        .confirmationDialog("Delete all workout data?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) { WorkoutService.deleteAllWorkoutData(context: context) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes all workouts, progress and records. Exercises and programs are kept.")
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
