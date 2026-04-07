import Foundation
import SwiftData

enum AchievementType: String, CaseIterable, Codable {
    case patOnTheBack     // Complete first run (34 cal per pat)
    case teaspoonToast    // Burn 1 pat in a single run
    case tablespoonTriumph // Burn 1 tbsp
    case stickSlayer      // Burn 1 stick (810 cal)
    case poundPounder     // Burn 1 lb butter (3240 cal)
    case butterSculptor   // 50 runs completed
    case perfectZero      // Butter Zero within ±0.5 tsp
    case fiveRunStreak    // 5 runs in one week
    case marathonMelt     // Run 26.2 miles total
    case butterFingers    // Eat butter 10 times in one run

    var displayName: String {
        switch self {
        case .patOnTheBack: return "Pat on the Back"
        case .teaspoonToast: return "Teaspoon Toast"
        case .tablespoonTriumph: return "Tablespoon Triumph"
        case .stickSlayer: return "Stick Slayer"
        case .poundPounder: return "Pound Pounder"
        case .butterSculptor: return "Butter Sculptor"
        case .perfectZero: return "Perfect Zero"
        case .fiveRunStreak: return "Five Run Streak"
        case .marathonMelt: return "Marathon Melt"
        case .butterFingers: return "Butter Fingers"
        }
    }

    var description: String {
        switch self {
        case .patOnTheBack: return "Complete your first run"
        case .teaspoonToast: return "Burn 1 pat of butter in a single run"
        case .tablespoonTriumph: return "Burn a full tablespoon in one run"
        case .stickSlayer: return "Burn an entire stick of butter"
        case .poundPounder: return "Burn a full pound of butter (cumulative)"
        case .butterSculptor: return "Complete 50 runs"
        case .perfectZero: return "Finish a Butter Zero run within ±0.5 pats"
        case .fiveRunStreak: return "Run 5 times in one week"
        case .marathonMelt: return "Run 26.2 miles total"
        case .butterFingers: return "Eat butter 10 times in one run"
        }
    }

    var emoji: String {
        switch self {
        case .patOnTheBack: return "👏"
        case .teaspoonToast: return "🥄"
        case .tablespoonTriumph: return "🏆"
        case .stickSlayer: return "⚔️"
        case .poundPounder: return "💪"
        case .butterSculptor: return "🎨"
        case .perfectZero: return "🎯"
        case .fiveRunStreak: return "🔥"
        case .marathonMelt: return "🏅"
        case .butterFingers: return "🤲"
        }
    }
}

@Model
class Achievement {
    var id: UUID
    var typeRaw: String
    var unlockedAt: Date

    init(type: AchievementType) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.unlockedAt = .now
    }

    var type: AchievementType? {
        AchievementType(rawValue: typeRaw)
    }
}
