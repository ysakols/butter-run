import Foundation
import SwiftData

/// The singleton user profile storing personal settings and body metrics.
///
/// Enforced as a singleton in ``ContentView`` — duplicate profiles are deleted on app launch.
/// ``preferredUnit`` uses plural forms ("miles" / "kilometers") for display labeling, while
/// ``splitDistance`` uses singular forms ("mile" / "kilometer") to name split segments.
/// ``weightKg`` is used by ``ButterCalculator`` for calorie expenditure estimation.
@Model
class UserProfile {
    var id: UUID
    var displayName: String
    var weightKg: Double
    var preferredUnit: String
    var voiceFeedbackEnabled: Bool
    var splitDistance: String
    var createdAt: Date

    // V2 fields
    var autoPauseEnabled: Bool = true
    var healthKitEnabled: Bool = false

    init(
        displayName: String,
        weightKg: Double,
        preferredUnit: String = "miles",
        voiceFeedbackEnabled: Bool = true,
        splitDistance: String = "mile"
    ) {
        self.id = UUID()
        self.displayName = displayName
        self.weightKg = weightKg
        self.preferredUnit = preferredUnit
        self.voiceFeedbackEnabled = voiceFeedbackEnabled
        self.splitDistance = splitDistance
        self.createdAt = .now
        self.autoPauseEnabled = true
        self.healthKitEnabled = false
    }

    var usesMiles: Bool {
        preferredUnit == "miles"
    }

    var splitDistanceMeters: Double {
        splitDistance == "mile" ? 1609.344 : 1000.0
    }
}
