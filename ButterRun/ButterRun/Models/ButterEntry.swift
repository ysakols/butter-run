import Foundation
import SwiftData

enum ButterServing: String, CaseIterable, Codable {
    case teaspoon = "teaspoon"
    case pat = "pat"
    case tablespoon = "tablespoon"
    case halfStick = "half_stick"
    case custom = "custom"

    var teaspoonEquivalent: Double {
        switch self {
        case .teaspoon: return 1.0
        case .pat: return 1.0
        case .tablespoon: return 3.0
        case .halfStick: return 12.0
        case .custom: return 0
        }
    }

    var displayName: String {
        switch self {
        case .teaspoon: return "1 pat"
        case .pat: return "1 pat"
        case .tablespoon: return "1 tbsp"
        case .halfStick: return "½ stick"
        case .custom: return "Custom"
        }
    }

    var emoji: String {
        switch self {
        case .teaspoon: return "🥄"
        case .pat: return "🧈"
        case .tablespoon: return "🥄"
        case .halfStick: return "🧱"
        case .custom: return "✏️"
        }
    }
}

@Model
class ButterEntry {
    var id: UUID
    var timestamp: Date
    var servingTypeRaw: String
    var teaspoonEquivalent: Double
    var run: Run?

    init(serving: ButterServing, customTeaspoons: Double = 0) {
        self.id = UUID()
        self.timestamp = .now
        self.servingTypeRaw = serving.rawValue
        self.teaspoonEquivalent = serving == .custom ? customTeaspoons : serving.teaspoonEquivalent
    }

    var servingType: ButterServing {
        ButterServing(rawValue: servingTypeRaw) ?? .custom
    }
}
