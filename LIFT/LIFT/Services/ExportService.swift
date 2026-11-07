import Foundation
import SwiftData

enum ExportService {
    /// Writes all real (non-demo) finished workouts to a CSV file and returns its URL.
    static func exportCSV(context: ModelContext) -> URL? {
        let workouts = StatsService.finishedWorkouts(context).filter { !$0.isDemo }
        let iso = ISO8601DateFormatter()
        var lines = ["date,workout,exercise,set,weight_kg,weight_lb,reps,warmup,volume_kg,estimated_1rm_kg"]

        func esc(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }

        for w in workouts {
            for we in w.sortedExercises {
                for s in we.sortedSets where s.isCompleted {
                    let e1 = Formulas.epley1RM(weight: s.weightKg, reps: s.reps)
                    let row: [String] = [
                        iso.string(from: w.startedAt),
                        esc(w.name),
                        esc(we.exercise?.name ?? we.exerciseName),
                        String(s.order + 1),
                        String(format: "%.2f", s.weightKg),
                        String(format: "%.2f", WeightUnit.lb.display(s.weightKg)),
                        String(s.reps),
                        s.isWarmup ? "1" : "0",
                        String(format: "%.2f", s.isWarmup ? 0 : Formulas.volume(weight: s.weightKg, reps: s.reps)),
                        String(format: "%.2f", s.isWarmup ? 0 : e1)
                    ]
                    lines.append(row.joined(separator: ","))
                }
            }
        }

        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LIFT-export-\(f.string(from: Date())).csv")
        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
