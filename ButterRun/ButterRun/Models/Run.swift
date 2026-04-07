import Foundation
import SwiftData

/// A completed running session persisted via SwiftData.
///
/// Stores distance, duration, pace, calorie/butter metrics, elevation, route data (encoded as
/// a JSON array of `[lat, lng]` pairs in ``routePolyline``), split segments, and optional
/// butter-churn results (serialized as JSON in ``churnResultData``). The ``netButterTsp``
/// property represents `totalButterEatenTsp - totalButterBurnedTsp` (positive = surplus butter). Runs flagged with
/// ``isManualEntry`` were reconstructed from crash-recovery drafts rather than recorded live.
@Model
class Run {
    @Attribute(.spotlight) var id: UUID
    @Attribute(.spotlight) var startDate: Date
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

    // V2 fields
    var churnResultData: Data?
    var isManualEntry: Bool = false
    var targetDistanceMeters: Double?
    var targetDurationSeconds: Double?

    // V3 fields — Strava integration
    var stravaActivityId: Int64?

    // V3 fields — HealthKit integration
    var healthKitSynced: Bool = false

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
        self.churnResultData = nil
        self.isManualEntry = false
        self.targetDistanceMeters = nil
        self.targetDurationSeconds = nil
    }

    var distanceMiles: Double {
        distanceMeters / 1609.344
    }

    var distanceKm: Double {
        distanceMeters / 1000.0
    }

    var formattedDuration: String {
        let totalSeconds = Int(durationSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var churnResult: ChurnResult? {
        guard let data = churnResultData else { return nil }
        return try? JSONDecoder().decode(ChurnResult.self, from: data)
    }
}
