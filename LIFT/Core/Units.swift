import SwiftUI

enum WeightUnit: String, CaseIterable, Identifiable, Codable {
    case kg, lb
    var id: String { rawValue }
    var label: String { rawValue }

    private var factor: Double { self == .kg ? 1 : 2.2046226218 }

    /// Converts kilograms (internal storage) to the display unit.
    func display(_ kg: Double) -> Double { kg * factor }
    /// Converts a value in the display unit back to kilograms.
    func toKg(_ value: Double) -> Double { value / factor }

    func format(_ kg: Double, withUnit: Bool = true) -> String {
        let s = formatNumber(display(kg))
        return withUnit ? "\(s) \(label)" : s
    }

    /// Compact formatting for large totals (e.g. 12.4k).
    func formatVolume(_ kg: Double) -> String {
        let v = display(kg)
        if v >= 100_000 { return String(format: "%.0fk", v / 1000) }
        if v >= 10_000 { return String(format: "%.1fk", v / 1000) }
        return formatNumber(v)
    }
}

/// Up to one decimal, trailing ".0" removed.
func formatNumber(_ value: Double) -> String {
    let r = (value * 10).rounded() / 10
    if r == r.rounded() { return String(format: "%.0f", r) }
    return String(format: "%.1f", r)
}

private struct WeightUnitKey: EnvironmentKey {
    static let defaultValue: WeightUnit = .kg
}

extension EnvironmentValues {
    var weightUnit: WeightUnit {
        get { self[WeightUnitKey.self] }
        set { self[WeightUnitKey.self] = newValue }
    }
}

enum Formulas {
    /// Epley estimate: 1RM = weight × (1 + reps / 30). An estimate, not a verified max.
    static func epley1RM(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        return weight * (1 + Double(reps) / 30)
    }

    static func volume(weight: Double, reps: Int) -> Double {
        weight * Double(max(reps, 0))
    }
}

// MARK: - Time formatting

func elapsedString(from start: Date, to end: Date) -> String {
    let s = max(0, Int(end.timeIntervalSince(start)))
    let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
}

func durationString(_ t: TimeInterval) -> String {
    let minutes = max(0, Int(t / 60))
    if minutes >= 60 { return "\(minutes / 60) h \(String(format: "%02d", minutes % 60)) min" }
    return "\(max(minutes, 1)) min"
}

func countdownString(_ t: TimeInterval) -> String {
    let s = max(0, Int(ceil(t)))
    return String(format: "%d:%02d", s / 60, s % 60)
}

func parseDecimal(_ text: String) -> Double {
    Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0
}
