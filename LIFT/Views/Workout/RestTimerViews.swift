import SwiftUI
import SwiftData

struct RestRing: View {
    let progress: Double
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle().stroke(Theme.cardHigh, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)
        }
    }
}

/// Compact, non-blocking timer bar shown at the bottom of the active workout.
struct RestTimerBar: View {
    @Environment(RestTimerManager.self) private var timer
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RestRing(progress: timer.progress, lineWidth: 4)
                .frame(width: 38, height: 38)
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timer.status == .paused ? tr("Rest · paused") : tr("Rest"))
                        .font(.lift(11, .semibold)).foregroundStyle(Theme.textSecondary)
                    Text(countdownString(timer.remaining))
                        .font(.lift(24, .bold)).monospacedDigit().foregroundStyle(Theme.textPrimary)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button {
                timer.status == .paused ? timer.resume() : timer.pause()
            } label: {
                Image(systemName: timer.status == .paused ? "play.fill" : "pause.fill")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(SoftButtonStyle())
            Button(tr("Skip")) { timer.skip() }
                .buttonStyle(SoftButtonStyle())
        }
        .padding(12)
        .background(Theme.cardHigh, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline, lineWidth: 0.5))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

/// Full timer with a large ring and duration presets.
struct RestTimerSheet: View {
    @Environment(RestTimerManager.self) private var timer
    @Query private var profiles: [UserProfile]

    private let presets = [30, 60, 90, 120, 180]
    private var profile: UserProfile? { profiles.first }
    private var selected: Int { profile?.defaultRestSeconds ?? 90 }

    var body: some View {
        VStack(spacing: 24) {
            Text(tr("Rest timer")).font(.lift(18, .bold)).padding(.top, 20)

            ZStack {
                RestRing(progress: timer.isActive ? timer.progress : 1, lineWidth: 14)
                VStack(spacing: 4) {
                    Text(countdownString(timer.isActive ? timer.remaining : Double(selected)))
                        .font(.lift(58, .bold)).monospacedDigit()
                    Text(timer.status == .paused ? tr("Paused") : (timer.isActive ? tr("Resting") : tr("Ready")))
                        .font(.lift(14, .semibold)).foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 250, height: 250)

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { s in
                    Button {
                        Haptics.tap()
                        profile?.defaultRestSeconds = s
                        if timer.isActive { timer.start(seconds: s) }
                    } label: {
                        Text(s >= 60 ? "\(s / 60):\(String(format: "%02d", s % 60))" : trf("%ds", s))
                            .font(.lift(14, .bold))
                            .foregroundStyle(selected == s ? Theme.background : Theme.textPrimary)
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(selected == s ? Theme.textPrimary : Theme.cardHigh, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                if timer.isActive {
                    Button {
                        timer.status == .paused ? timer.resume() : timer.pause()
                    } label: {
                        Label(timer.status == .paused ? tr("Resume") : tr("Pause"),
                              systemImage: timer.status == .paused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(SoftButtonStyle())
                    Button { timer.add(seconds: 30) } label: { Text(tr("+30s")) }
                        .buttonStyle(SoftButtonStyle())
                    Button { timer.skip() } label: { Label(tr("Skip"), systemImage: "forward.end.fill") }
                        .buttonStyle(SoftButtonStyle())
                } else {
                    Button {
                        applySettings()
                        timer.start(seconds: selected)
                    } label: { Label(tr("Start rest"), systemImage: "play.fill") }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .screenBackground()
    }

    private func applySettings() {
        timer.soundEnabled = profile?.soundEnabled ?? true
        timer.hapticsEnabled = profile?.hapticsEnabled ?? true
        timer.notificationsEnabled = profile?.restAlertsEnabled ?? true
    }
}
