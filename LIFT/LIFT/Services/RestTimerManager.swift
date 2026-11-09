import SwiftUI
import AudioToolbox
import UIKit
import Observation

/// Wall-clock based rest timer: stays accurate when the app is backgrounded
/// and notifies through a local notification if enabled.
@Observable
final class RestTimerManager {
    enum Status { case idle, running, paused }

    private(set) var status: Status = .idle
    private(set) var remaining: TimeInterval = 0
    private(set) var total: TimeInterval = 90

    var soundEnabled = true
    var hapticsEnabled = true
    var notificationsEnabled = true

    @ObservationIgnored private var endDate: Date?
    @ObservationIgnored private var ticker: Timer?

    var isActive: Bool { status != .idle }
    var progress: Double { total > 0 ? max(0, min(1, remaining / total)) : 0 }

    func start(seconds: Int) {
        stopTicker()
        total = Double(seconds)
        remaining = total
        endDate = Date().addingTimeInterval(total)
        status = .running
        scheduleNotification()
        startTicker()
    }

    func pause() {
        guard status == .running, let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        stopTicker()
        NotificationService.cancelRest()
        status = .paused
    }

    func resume() {
        guard status == .paused else { return }
        endDate = Date().addingTimeInterval(remaining)
        status = .running
        scheduleNotification()
        startTicker()
    }

    func add(seconds: Int) {
        guard status != .idle else { return }
        total += Double(seconds)
        remaining += Double(seconds)
        if status == .running {
            endDate = endDate?.addingTimeInterval(Double(seconds))
            scheduleNotification()
        }
    }

    func skip() { reset() }
    func stop() { reset() }

    // MARK: Private

    private func scheduleNotification() {
        if notificationsEnabled { NotificationService.scheduleRestEnd(after: remaining) }
    }

    private func startTicker() {
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 { finish() }
    }

    private func finish() {
        reset()
        if hapticsEnabled { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        if soundEnabled { AudioServicesPlaySystemSound(1007) }
    }

    private func reset() {
        stopTicker()
        NotificationService.cancelRest()
        endDate = nil
        remaining = 0
        status = .idle
    }
}
