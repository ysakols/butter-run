import Foundation
import SwiftData

@Model
class Split {
    var index: Int
    var distanceMeters: Double
    var durationSeconds: Double
    var paceSecondsPerKm: Double
    var butterBurnedTsp: Double
    var elevationGainMeters: Double
    var isPartial: Bool
    var run: Run?

    init(
        index: Int,
        distanceMeters: Double,
        durationSeconds: Double,
        paceSecondsPerKm: Double,
        butterBurnedTsp: Double,
        elevationGainMeters: Double = 0,
        isPartial: Bool = false
    ) {
        self.index = index
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.paceSecondsPerKm = paceSecondsPerKm
        self.butterBurnedTsp = butterBurnedTsp
        self.elevationGainMeters = elevationGainMeters
        self.isPartial = isPartial
    }

    var formattedPace: String {
        let totalSeconds = Int(paceSecondsPerKm)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
