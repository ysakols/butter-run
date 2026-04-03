import Foundation
import SwiftData

@Model
class Run {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var distanceMeters: Double
    var durationSeconds: Double
    var averagePaceSecondsPerKm: Double
    var bestPaceSecondsPerKm: Double
    var totalCaloriesBurned: Double
    var totalButterBurnedTsp: Double
    var totalButterEatenTsp: Double
    var netButterTsp: Double
    var elevationGainMeters: Double
    var elevationLossMeters: Double
    var averageCadence: Double?
    var routePolyline: Data?
    @Relationship(deleteRule: .cascade) var splits: [Split]
    @Relationship(deleteRule: .cascade) var butterEntries: [ButterEntry]
    var isButterZeroChallenge: Bool
    var notes: String?

    init(
        startDate: Date = .now,
        isButterZeroChallenge: Bool = false
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = nil
        self.distanceMeters = 0
        self.durationSeconds = 0
        self.averagePaceSecondsPerKm = 0
        self.bestPaceSecondsPerKm = 0
        self.totalCaloriesBurned = 0
        self.totalButterBurnedTsp = 0
        self.totalButterEatenTsp = 0
        self.netButterTsp = 0
        self.elevationGainMeters = 0
        self.elevationLossMeters = 0
        self.averageCadence = nil
        self.routePolyline = nil
        self.splits = []
        self.butterEntries = []
        self.isButterZeroChallenge = isButterZeroChallenge
        self.notes = nil
    }

    var butterZeroScore: Int {
        let score = 100.0 - abs(netButterTsp) * 20.0
        return max(0, min(100, Int(score)))
    }

    var distanceMiles: Double {
        distanceMeters / 1609.344
    }

    var distanceKm: Double {
        distanceMeters / 1000.0
    }

    var formattedDuration: String {
        let minutes = Int(durationSeconds) / 60
        let seconds = Int(durationSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
