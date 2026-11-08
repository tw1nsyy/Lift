import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case ru, en
    var id: String { rawValue }
    var title: String { self == .ru ? "Русский" : "English" }
    var locale: Locale { Locale(identifier: self == .ru ? "ru_RU" : "en_US") }
}

/// In-app language. Stored in UserDefaults so it is available before SwiftData loads. Russian by default.
enum Lang {
    static let key = "appLanguage"
    static var current: AppLanguage { AppLanguage(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .ru }
    static var locale: Locale { current.locale }
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = locale
        return c
    }
}

/// Translates an English UI string (the key) to the current language. Falls back to the key.
func tr(_ key: String) -> String {
    guard Lang.current == .ru else { return key }
    return RuStrings.table[key] ?? key
}

/// Translated format string with %d / %@ arguments.
func trf(_ key: String, _ args: CVarArg...) -> String {
    String(format: tr(key), locale: Lang.locale, arguments: args)
}

enum Noun {
    case exercise, set

    func form(_ n: Int) -> String {
        if Lang.current == .ru {
            let m10 = n % 10, m100 = n % 100
            let idx = (m10 == 1 && m100 != 11) ? 0 : ((2...4).contains(m10) && !(12...14).contains(m100) ? 1 : 2)
            switch self {
            case .exercise: return ["упражнение", "упражнения", "упражнений"][idx]
            case .set: return ["подход", "подхода", "подходов"][idx]
            }
        }
        switch self {
        case .exercise: return n == 1 ? "exercise" : "exercises"
        case .set: return n == 1 ? "set" : "sets"
        }
    }
}

func countText(_ n: Int, _ noun: Noun) -> String { "\(n) \(noun.form(n))" }

extension Date {
    /// Formats with the in-app language rather than the device locale.
    func f(_ style: Date.FormatStyle) -> String { formatted(style.locale(Lang.locale)) }
}

func relativeString(_ date: Date) -> String {
    let f = RelativeDateTimeFormatter()
    f.locale = Lang.locale
    f.unitsStyle = .full
    return f.localizedString(for: date, relativeTo: Date())
}
