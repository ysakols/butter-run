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
        weeklyButterPats = weekRuns.reduce(0) { $0 + $1.totalButterBurnedTsp }

        // NEW: Weekly stats
        weeklyRuns = weekRuns.count
        weeklyDistanceMeters = weekRuns.reduce(0) { $0 + $1.distanceMeters }
        weeklyDurationSeconds = weekRuns.reduce(0) { $0 + $1.durationSeconds }

        if let last = runs.sorted(by: { $0.startDate > $1.startDate }).first {
            let butter = String(format: "%.1f pats", last.totalButterBurnedTsp)
            let distance = ButterFormatters.distance(meters: last.distanceMeters, usesMiles: usesMiles)
            lastRunSummary = "\(butter) • \(distance) • \(last.formattedDuration)"
        }
    }
}
