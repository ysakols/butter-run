import Foundation
import SwiftData

@Observable
class HomeViewModel {
    var weeklyButterPats: Double = 0
    var totalRuns: Int = 0
    var lastRunSummary: String? = nil
    // NEW:
    var weeklyRuns: Int = 0
    var weeklyDistanceMeters: Double = 0
    var weeklyDurationSeconds: Double = 0

    func load(runs: [Run], usesMiles: Bool = true) {
        totalRuns = runs.count

        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let weekRuns = runs.filter { $0.startDate >= oneWeekAgo }
        let stats = weekRuns.reduce((pats: 0.0, dist: 0.0, dur: 0.0)) { acc, run in
            (acc.pats + run.totalButterBurnedTsp, acc.dist + run.distanceMeters, acc.dur + run.durationSeconds)
        }
        weeklyButterPats = stats.pats
        weeklyRuns = weekRuns.count
        weeklyDistanceMeters = stats.dist
        weeklyDurationSeconds = stats.dur

        if let last = runs.sorted(by: { $0.startDate > $1.startDate }).first {
            let butter = String(format: "%.1f pats", last.totalButterBurnedTsp)
            let distance = ButterFormatters.distance(meters: last.distanceMeters, usesMiles: usesMiles)
            lastRunSummary = "\(butter) • \(distance) • \(last.formattedDuration)"
        }
    }
}
