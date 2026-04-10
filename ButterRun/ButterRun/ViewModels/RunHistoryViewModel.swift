import Foundation
import SwiftData

@Observable
class RunHistoryViewModel {
    var allTimeButterTsp: Double = 0
    var allTimeDistanceMeters: Double = 0
    var allTimeRuns: Int = 0

    func load(runs: [Run]) {
        allTimeRuns = runs.count
        allTimeButterTsp = runs.reduce(0) { $0 + $1.totalButterBurnedTsp }
        allTimeDistanceMeters = runs.reduce(0) { $0 + $1.distanceMeters }
    }
}
