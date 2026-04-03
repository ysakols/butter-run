import Foundation
import SwiftData

@Observable
class HomeViewModel {
    var weeklyButterTsp: Double = 0
    var totalRuns: Int = 0
    var lastRunSummary: String? = nil

    func load(runs: [Run], usesMiles: Bool = true) {
        totalRuns = runs.count

        // Weekly butter
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let weekRuns = runs.filter { $0.startDate >= oneWeekAgo }
        weeklyButterTsp = weekRuns.reduce(0) { $0 + $1.totalButterBurnedTsp }

        // Last run
        if let last = runs.sorted(by: { $0.startDate > $1.startDate }).first {
            let butter = String(format: "%.1f tsp", last.totalButterBurnedTsp)
            let distance = ButterFormatters.distance(meters: last.distanceMeters, usesMiles: usesMiles)
            lastRunSummary = "\(butter) • \(distance) • \(last.formattedDuration)"
        }
    }
}
