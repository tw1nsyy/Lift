import Foundation
import SwiftData
import Observation

// MARK: - Shared data

/// What one player publishes to the group. Contains no workout dates, notes or health data.
struct PlayerStats: Codable, Equatable {
    var name: String
    var updatedAt: Double
    var workouts: Int
    var weekWorkouts: Int
    var weekVolumeKg: Double
    var totalVolumeKg: Double
    /// Best estimated 1RM (kg) per exercise name.
    var lifts: [String: Double]?
}

struct PlayerEntry: Identifiable {
    let id: String
    let stats: PlayerStats
    let isMe: Bool
}

// MARK: - Local settings

enum LeaderboardConfig {
    static let urlKey = "lbURL"
    static let groupKey = "lbGroup"
    static let enabledKey = "lbEnabled"
    static let playerKey = "lbPlayerID"
    static let nameKey = "lbName"

    static var url: String { UserDefaults.standard.string(forKey: urlKey) ?? "" }
    static var group: String { UserDefaults.standard.string(forKey: groupKey) ?? "" }
    static var enabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
    static var name: String { UserDefaults.standard.string(forKey: nameKey) ?? "" }
    static var isConfigured: Bool { !url.isEmpty && !group.isEmpty }

    /// Random id that identifies this phone inside the group.
    static var playerID: String {
        if let id = UserDefaults.standard.string(forKey: playerKey), !id.isEmpty { return id }
        let id = UUID().uuidString.lowercased()
        UserDefaults.standard.set(id, forKey: playerKey)
        return id
    }

    static func save(url: String, group: String, name: String) {
        let d = UserDefaults.standard
        d.set(url, forKey: urlKey)
        d.set(group, forKey: groupKey)
        d.set(name, forKey: nameKey)
        d.set(true, forKey: enabledKey)
    }

    static func clear() {
        let d = UserDefaults.standard
        d.removeObject(forKey: urlKey)
        d.removeObject(forKey: groupKey)
        d.set(false, forKey: enabledKey)
    }

    /// Accepts "abc.firebaseio.com/" or a full https URL and returns "https://host".
    static func normalizedURL(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.lowercased().hasPrefix("http") { s = "https://" + s }
        guard s.lowercased().hasPrefix("https://"),
              let u = URL(string: s), let host = u.host, host.contains(".") else { return nil }
        return "https://" + host
    }

    /// Lower-case letters, digits, "-" and "_"; at least 6 characters.
    static func normalizedGroup(_ raw: String) -> String? {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-_")
        let s = String(raw.lowercased().filter { allowed.contains($0) }.prefix(40))
        return s.count >= 6 ? s : nil
    }

    static func randomGroup() -> String {
        let chars = Array("abcdefghijkmnpqrstuvwxyz23456789")
        var out = "lift-"
        for _ in 0..<8 { out.append(chars.randomElement() ?? "x") }
        return out
    }

    // MARK: Invite code (database URL + group in one string)

    static func inviteCode(url: String, group: String) -> String {
        Data("\(url)|\(group)".utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decodeInvite(_ code: String) -> (url: String, group: String)? {
        var s = code.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        guard let data = Data(base64Encoded: s), let text = String(data: data, encoding: .utf8) else { return nil }
        let parts = text.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        return (String(parts[0]), String(parts[1]))
    }

    // MARK: Stats

    /// Firebase keys cannot contain . $ # [ ] /
    static func sanitizeKey(_ s: String) -> String {
        let bad: Set<Character> = [".", "$", "#", "[", "]", "/"]
        return String(s.map { bad.contains($0) ? " " : $0 })
    }

    /// Builds this player's public numbers from real (non-demo) finished workouts.
    static func myStats(workouts: [Workout], name: String, now: Date = Date()) -> PlayerStats {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone.current
        let week = cal.dateInterval(of: .weekOfYear, for: now)

        let real = workouts.filter { $0.isFinished && !$0.isDemo }
        var weekCount = 0
        var weekVolume = 0.0
        var totalVolume = 0.0
        var lifts: [String: Double] = [:]

        for w in real {
            totalVolume += w.totalVolumeKg
            if let week, week.contains(w.startedAt) {
                weekCount += 1
                weekVolume += w.totalVolumeKg
            }
            for we in w.exercises {
                let exName = we.exercise?.name ?? we.exerciseName
                var best = 0.0
                for s in we.sets where s.isCompleted && !s.isWarmup {
                    best = max(best, Formulas.epley1RM(weight: s.weightKg, reps: s.reps))
                }
                if best > 0 {
                    let key = sanitizeKey(exName)
                    lifts[key] = max(lifts[key] ?? 0, min(best, 999))
                }
            }
        }
        if lifts.count > 60 {
            let top = lifts.sorted { $0.value > $1.value }.prefix(60)
            lifts = Dictionary(uniqueKeysWithValues: top.map { ($0.key, $0.value) })
        }
        let rounded = lifts.mapValues { ($0 * 10).rounded() / 10 }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return PlayerStats(name: String((trimmed.isEmpty ? "Player" : trimmed).prefix(30)),
                           updatedAt: now.timeIntervalSince1970,
                           workouts: real.count,
                           weekWorkouts: weekCount,
                           weekVolumeKg: min(weekVolume.rounded(), 9_999_999),
                           totalVolumeKg: min(totalVolume.rounded(), 9_999_999),
                           lifts: rounded.isEmpty ? nil : rounded)
    }
}

// MARK: - Network (Firebase Realtime Database REST API)

enum LeaderboardError: Error {
    case notConfigured, rejected, unreachable

    var message: String {
        switch self {
        case .notConfigured: return tr("The database URL looks wrong.")
        case .rejected: return tr("The server rejected the request. Check the database rules.")
        case .unreachable: return tr("Could not reach the server. Check the database URL and your internet connection.")
        }
    }
}

private struct LossyPlayer: Decodable {
    let value: PlayerStats?
    init(from decoder: Decoder) throws {
        value = try? PlayerStats(from: decoder)
    }
}

enum LeaderboardAPI {
    static func endpoint(url: String, group: String, player: String?) -> URL? {
        var s = url + "/groups/" + group + "/players"
        if let player { s += "/" + player }
        return URL(string: s + ".json")
    }

    private static func send(_ req: URLRequest) async throws -> Data {
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw LeaderboardError.unreachable }
            if http.statusCode == 200 { return data }
            throw LeaderboardError.rejected
        } catch let e as LeaderboardError {
            throw e
        } catch {
            throw LeaderboardError.unreachable
        }
    }

    static func push(_ stats: PlayerStats, url: String, group: String, player: String) async throws {
        guard let u = endpoint(url: url, group: group, player: player) else { throw LeaderboardError.notConfigured }
        var req = URLRequest(url: u, timeoutInterval: 12)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(stats)
        _ = try await send(req)
    }

    static func fetch(url: String, group: String) async throws -> [String: PlayerStats] {
        guard let u = endpoint(url: url, group: group, player: nil) else { throw LeaderboardError.notConfigured }
        var req = URLRequest(url: u, timeoutInterval: 12)
        req.httpMethod = "GET"
        let data = try await send(req)
        let decoded = (try? JSONDecoder().decode([String: LossyPlayer].self, from: data)) ?? [:]
        var out: [String: PlayerStats] = [:]
        for (k, v) in decoded { if let s = v.value { out[k] = s } }
        return out
    }

    static func remove(url: String, group: String, player: String) async {
        guard let u = endpoint(url: url, group: group, player: player) else { return }
        var req = URLRequest(url: u, timeoutInterval: 12)
        req.httpMethod = "DELETE"
        _ = try? await send(req)
    }
}

// MARK: - Store

@Observable
final class LeaderboardStore {
    var players: [PlayerEntry] = []
    var isLoading = false
    var message: String?
    var lastUpdated: Date?

    @MainActor
    private func displayName(_ context: ModelContext) -> String {
        if !LeaderboardConfig.name.isEmpty { return LeaderboardConfig.name }
        let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first
        return profile?.name ?? ""
    }

    /// Publishes this player's numbers (if sharing is on) and loads the whole group.
    @MainActor
    func sync(context: ModelContext) async {
        guard LeaderboardConfig.isConfigured else { return }
        isLoading = true
        message = nil
        let url = LeaderboardConfig.url
        let group = LeaderboardConfig.group
        let me = LeaderboardConfig.playerID
        do {
            if LeaderboardConfig.enabled {
                let stats = LeaderboardConfig.myStats(workouts: StatsService.finishedWorkouts(context),
                                                      name: displayName(context))
                try await LeaderboardAPI.push(stats, url: url, group: group, player: me)
            }
            let all = try await LeaderboardAPI.fetch(url: url, group: group)
            players = all.map { PlayerEntry(id: $0.key, stats: $0.value, isMe: $0.key == me) }
            lastUpdated = Date()
        } catch let e as LeaderboardError {
            message = e.message
        } catch {
            message = LeaderboardError.unreachable.message
        }
        isLoading = false
    }

    /// Removes this player from the group and forgets the connection.
    @MainActor
    func leave() async {
        if LeaderboardConfig.isConfigured {
            await LeaderboardAPI.remove(url: LeaderboardConfig.url, group: LeaderboardConfig.group,
                                        player: LeaderboardConfig.playerID)
        }
        LeaderboardConfig.clear()
        players = []
        message = nil
    }
}
