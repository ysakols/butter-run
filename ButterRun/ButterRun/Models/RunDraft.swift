import Foundation
import SwiftData

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
