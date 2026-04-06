import Foundation
import SwiftData

/// A temporary snapshot of an in-progress run, saved to SwiftData every 30 seconds for crash recovery.
///
/// If the app terminates unexpectedly during a run, ``CrashRecoveryWrapper`` detects the draft on
/// next launch and offers to discard or save it as a manual run. Route coordinates are stored in
/// ``routePointsData`` as a JSON-encoded array of `[lat, lng]` pairs. Butter consumption events
/// are stored in ``butterEntriesData`` as JSON-encoded `EntrySnapshot` objects. Drafts older than
/// 48 hours are automatically purged on app launch.
@Model
class RunDraft {
    var id: UUID
    var startDate: Date
    var elapsedSeconds: Double
    var pausedDuration: Double
    var distanceMeters: Double
    var butterBurnedTsp: Double
    var butterEatenTsp: Double
    var isButterZeroChallenge: Bool
    var routePointsData: Data?
    var butterEntriesData: Data?
    var lastCheckpoint: Date

    init(
        startDate: Date,
        elapsedSeconds: Double = 0,
        pausedDuration: Double = 0,
        distanceMeters: Double = 0,
        butterBurnedTsp: Double = 0,
        butterEatenTsp: Double = 0,
        isButterZeroChallenge: Bool = false,
        routePointsData: Data? = nil,
        butterEntriesData: Data? = nil
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.elapsedSeconds = elapsedSeconds
        self.pausedDuration = pausedDuration
        self.distanceMeters = distanceMeters
        self.butterBurnedTsp = butterBurnedTsp
        self.butterEatenTsp = butterEatenTsp
        self.isButterZeroChallenge = isButterZeroChallenge
        self.routePointsData = routePointsData
        self.butterEntriesData = butterEntriesData
        self.lastCheckpoint = Date()
    }
}
