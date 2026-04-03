import Foundation

struct ChurnResult: Codable {
    let creamType: String       // "heavy" or "whipping"
    let creamCups: Double
    let finalStage: Int         // 0-4
    let finalProgress: Double   // 0.0-1.0
    let totalAgitation: Double

    var stageName: String {
        ChurnStage(rawValue: finalStage)?.name ?? "Unknown"
    }
}

enum ChurnStage: Int, CaseIterable, Comparable {
    case liquid = 0
    case foamy = 1
    case whipped = 2
    case breaking = 3
    case butter = 4

    var name: String {
        switch self {
        case .liquid: return "Liquid"
        case .foamy: return "Foamy"
        case .whipped: return "Whipped"
        case .breaking: return "Breaking"
        case .butter: return "Butter"
        }
    }

    /// Progress threshold where this stage begins
    var threshold: Double {
        switch self {
        case .liquid: return 0.0
        case .foamy: return 0.08
        case .whipped: return 0.30
        case .breaking: return 0.55
        case .butter: return 0.85
        }
    }

    static func stage(forProgress progress: Double) -> ChurnStage {
        let clamped = max(0, min(1, progress))
        for stage in Self.allCases.reversed() {
            if clamped >= stage.threshold {
                return stage
            }
        }
        return .liquid
    }
}
