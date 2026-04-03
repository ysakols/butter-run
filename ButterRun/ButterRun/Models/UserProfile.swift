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
    }

    var usesMiles: Bool {
        preferredUnit == "miles"
    }

    var splitDistanceMeters: Double {
        splitDistance == "mile" ? 1609.344 : 1000.0
    }
}
