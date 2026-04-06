import Foundation
import SwiftData

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

    // V3 fields
    var weightUnit: String = "kg"  // "kg" or "lbs"

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
