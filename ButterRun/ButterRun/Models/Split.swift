import Foundation
import SwiftData

/// A distance-based segment of a ``Run``, created each time the runner crosses a split boundary
/// (e.g. every mile or kilometer, configured via ``UserProfile/splitDistance``).
///
/// Splits use zero-based ``index`` values (split 0 is the first segment). Pace is always stored
/// in seconds-per-kilometer (``paceSecondsPerKm``) regardless of the user's display preference.
/// The final split of a run is marked with ``isPartial`` when the remaining distance is less than
/// a full split unit. Splits are cascade-deleted with their parent ``Run``.
@Model
class Split {
    var id: UUID = UUID()
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
