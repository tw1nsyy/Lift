import SwiftUI
import SwiftData

struct LeaderboardCategory: Identifiable {
    enum Kind { case count, volume, strength }
    let id: String
    let title: String
    let kind: Kind
    let value: (PlayerStats) -> Double?

    static func build(for players: [PlayerEntry]) -> [LeaderboardCategory] {
        var out: [LeaderboardCategory] = []
        out.append(LeaderboardCategory(id: "weekWorkouts", title: tr("Workouts this week"), kind: .count) { Double($0.weekWorkouts) })
        out.append(LeaderboardCategory(id: "weekVolume", title: tr("Volume this week"), kind: .volume) { $0.weekVolumeKg })
        out.append(LeaderboardCategory(id: "total", title: tr("Big 3 total"), kind: .strength) { s in
            let names = ["Bench Press", "Squat", "Deadlift"]
            let parts = names.compactMap { s.lifts?[$0] }
            return parts.count == 3 ? parts.reduce(0, +) : nil
        })
        out.append(LeaderboardCategory(id: "totalVolume", title: tr("Total volume"), kind: .volume) { $0.totalVolumeKg })
        out.append(LeaderboardCategory(id: "workouts", title: tr("All workouts"), kind: .count) { Double($0.workouts) })

        var counts: [String: Int] = [:]
        for p in players {
            for key in (p.stats.lifts ?? [:]).keys { counts[key, default: 0] += 1 }
        }
        let keys = counts.keys.sorted { a, b in
            let ca = counts[a] ?? 0, cb = counts[b] ?? 0
            return ca != cb ? ca > cb : a < b
        }
        for key in keys {
            out.append(LeaderboardCategory(id: "lift:" + key, title: tr(key), kind: .strength) { $0.lifts?[key] })
        }
        return out
    }
}

struct LeaderboardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.weightUnit) private var unit
    @Environment(LeaderboardStore.self) private var store
    @AppStorage(LeaderboardConfig.urlKey) private var url = ""
    @AppStorage(LeaderboardConfig.groupKey) private var group = ""

    @State private var selectedID = "weekWorkouts"
    @State private var showSetup = false
    @State private var showInvite = false

    private var configured: Bool { !url.isEmpty && !group.isEmpty }

    private var categories: [LeaderboardCategory] { LeaderboardCategory.build(for: store.players) }
    private var selected: LeaderboardCategory? {
        categories.first { $0.id == selectedID } ?? categories.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if configured {
                    groupCard
                    chips
                    if let cat = selected { board(cat) }
                    if let message = store.message {
                        Text(message).font(.lift(13, .medium)).foregroundStyle(Theme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text(tr("Results are not verified: it is a leaderboard for friends."))
                        .font(.lift(11, .medium)).foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    emptyCard
                }
            }
            .padding(16)
        }
        .refreshable { await store.sync(context: context) }
        .task { await store.sync(context: context) }
        .screenBackground()
        .tabBarClearance()
        .navigationTitle(tr("Leaderboard"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showSetup = true } label: { Image(systemName: "gearshape") }
            }
        }
        .sheet(isPresented: $showSetup) {
            NavigationStack { LeaderboardSetupView() }
        }
        .sheet(isPresented: $showInvite) {
            ShareSheet(items: [inviteMessage])
        }
    }

    private var inviteMessage: String {
        trf("Join my LIFT leaderboard! In the app open Today → Leaderboard → ⚙ → Join group and paste this invite code: %@",
            LeaderboardConfig.inviteCode(url: url, group: group))
    }

    // MARK: Pieces

    private var emptyCard: some View {
        VStack(spacing: 14) {
            EmptyStateView(icon: "trophy", title: tr("Leaderboard"),
                           message: tr("Compete with friends: workouts, volume and estimated 1RM. You need a free Firebase database, setup takes about 5 minutes."))
            Button { showSetup = true } label: { Text(tr("Set up leaderboard")) }
                .buttonStyle(PrimaryButtonStyle())
        }
        .card()
    }

    private var groupCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(trf("Group: %@", group)).font(.lift(15, .bold))
                if let updated = store.lastUpdated {
                    Text(trf("Updated %@", relativeString(updated)))
                        .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            if store.isLoading { ProgressView() }
            Button { showInvite = true } label: { Label(tr("Invite a friend"), systemImage: "person.badge.plus") }
                .buttonStyle(SoftButtonStyle(tint: Theme.accent))
        }
        .card(padding: 14)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories) { cat in
                    let on = cat.id == selected?.id
                    Button {
                        Haptics.tap()
                        withAnimation(.easeInOut(duration: 0.2)) { selectedID = cat.id }
                    } label: {
                        Text(cat.title)
                            .font(.lift(13, .bold))
                            .foregroundStyle(on ? Theme.background : Theme.textPrimary)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(on ? Theme.textPrimary : Theme.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func ranking(_ cat: LeaderboardCategory) -> [(entry: PlayerEntry, value: Double)] {
        var rows: [(entry: PlayerEntry, value: Double)] = []
        for p in store.players {
            guard let v = cat.value(p.stats) else { continue }
            if v > 0 || cat.kind == .count { rows.append((entry: p, value: v)) }
        }
        return rows.sorted { $0.value > $1.value }
    }

    private func valueText(_ cat: LeaderboardCategory, _ v: Double) -> String {
        switch cat.kind {
        case .count: return "\(Int(v))"
        case .volume: return "\(unit.formatVolume(v)) \(unit.label)"
        case .strength: return unit.format(v)
        }
    }

    private func medalColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(hex: 0xFFD24A)
        case 2: return Color(hex: 0xC9CED6)
        case 3: return Color(hex: 0xD08A52)
        default: return Theme.textSecondary
        }
    }

    private func board(_ cat: LeaderboardCategory) -> some View {
        let rows = ranking(cat)
        return VStack(alignment: .leading, spacing: 12) {
            Text(cat.title).font(.lift(18, .bold))
            if rows.isEmpty {
                Text(tr("No one has shared results yet."))
                    .font(.lift(13, .medium)).foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.entry.id) { idx, row in
                    HStack(spacing: 12) {
                        Text("\(idx + 1)")
                            .font(.lift(16, .bold))
                            .foregroundStyle(medalColor(idx + 1))
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.entry.stats.name).font(.lift(16, .semibold))
                            if row.entry.isMe {
                                Text(tr("You")).font(.lift(11, .bold)).foregroundStyle(Theme.accent)
                            }
                        }
                        Spacer()
                        Text(valueText(cat, row.value)).font(.lift(17, .bold))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .card()
    }
}

// MARK: - Setup

struct LeaderboardSetupView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(LeaderboardStore.self) private var store
    @Query private var profiles: [UserProfile]

    @AppStorage(LeaderboardConfig.urlKey) private var savedURL = ""
    @AppStorage(LeaderboardConfig.groupKey) private var savedGroup = ""
    @AppStorage(LeaderboardConfig.enabledKey) private var enabled = false

    @State private var mode = 0
    @State private var urlText = ""
    @State private var groupText = ""
    @State private var inviteText = ""
    @State private var nameText = ""
    @State private var errorText: String?
    @State private var busy = false
    @State private var confirmLeave = false

    private var connected: Bool { !savedURL.isEmpty && !savedGroup.isEmpty }

    var body: some View {
        List {
            if connected { connectedSection } else { connectSection }
            privacySection
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle(tr("Leaderboard"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button(tr("Done")) { dismiss() }.fontWeight(.semibold) }
        }
        .onAppear {
            if nameText.isEmpty { nameText = LeaderboardConfig.name.isEmpty ? (profiles.first?.name ?? "") : LeaderboardConfig.name }
            if groupText.isEmpty { groupText = LeaderboardConfig.randomGroup() }
        }
        .confirmationDialog(tr("Leave group"), isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(tr("Leave group"), role: .destructive) { Task { await store.leave() } }
            Button(tr("Cancel"), role: .cancel) {}
        } message: {
            Text(tr("Your results will be removed from the group."))
        }
    }

    // MARK: Sections

    private var connectedSection: some View {
        Section {
            Toggle(tr("Share my results"), isOn: $enabled)
            LabeledContent(tr("Group code"), value: savedGroup)
            VStack(alignment: .leading, spacing: 6) {
                Text(tr("Invite code")).font(.lift(12, .semibold)).foregroundStyle(Theme.textSecondary)
                Text(LeaderboardConfig.inviteCode(url: savedURL, group: savedGroup))
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
            }
            Button(tr("Leave group"), role: .destructive) { confirmLeave = true }
        }
        .listRowBackground(Theme.card)
    }

    private var connectSection: some View {
        Group {
            Section {
                Picker(tr("Mode"), selection: $mode) {
                    Text(tr("Create group")).tag(0)
                    Text(tr("Join group")).tag(1)
                }
                .pickerStyle(.segmented)
                TextField(tr("Your name"), text: $nameText)
            }
            .listRowBackground(Theme.card)

            Section {
                if mode == 0 {
                    TextField(tr("Database URL"), text: $urlText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    HStack {
                        TextField(tr("Group code"), text: $groupText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button(tr("Generate")) { groupText = LeaderboardConfig.randomGroup() }
                            .buttonStyle(.borderless)
                    }
                    Text(tr("Setup: 1) create a free project at console.firebase.google.com, 2) add a Realtime Database, 3) paste the rules from the leaderboard guide, 4) copy the database URL here."))
                        .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
                } else {
                    TextField(tr("Invite code"), text: $inviteText, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(2...5)
                    Text(tr("Paste the invite code from your friend."))
                        .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
                }
                if let errorText {
                    Text(errorText).font(.lift(13, .medium)).foregroundStyle(Theme.danger)
                }
                Button {
                    Task { await connect() }
                } label: {
                    Text(busy ? tr("Connecting…") : tr("Connect")).frame(maxWidth: .infinity)
                }
                .disabled(busy)
            }
            .listRowBackground(Theme.card)
        }
    }

    private var privacySection: some View {
        Section(tr("What is shared")) {
            Text(tr("Only your name, workout counts, volume and best estimated 1RM per exercise are shared. Demo data is never shared. Anyone who has your group code can see these numbers."))
                .font(.lift(12, .medium)).foregroundStyle(Theme.textSecondary)
        }
        .listRowBackground(Theme.card)
    }

    // MARK: Actions

    private func connect() async {
        errorText = nil
        let name = nameText.trimmingCharacters(in: .whitespaces)
        var finalURL = ""
        var finalGroup = ""
        if mode == 1 {
            guard let invite = LeaderboardConfig.decodeInvite(inviteText),
                  let u = LeaderboardConfig.normalizedURL(invite.url),
                  let g = LeaderboardConfig.normalizedGroup(invite.group) else {
                errorText = tr("The invite code is not valid.")
                return
            }
            finalURL = u
            finalGroup = g
        } else {
            guard let u = LeaderboardConfig.normalizedURL(urlText) else {
                errorText = tr("The database URL looks wrong.")
                return
            }
            guard let g = LeaderboardConfig.normalizedGroup(groupText) else {
                errorText = tr("The group code must have at least 6 letters or digits.")
                return
            }
            finalURL = u
            finalGroup = g
        }
        busy = true
        LeaderboardConfig.save(url: finalURL, group: finalGroup, name: name)
        await store.sync(context: context)
        busy = false
        if let message = store.message {
            LeaderboardConfig.clear()
            errorText = message
        } else {
            dismiss()
        }
    }
}
