import Foundation
import SwiftData

class AchievementService {
    // Achievement thresholds derived from ButterCalculator constants (34 cal/pat)
    private enum Thresholds {
        static let patTsp = 1.0                        // 1 pat = 1 tsp = 34 cal
        static let teaspoonTsp = 1.0                   // 1 tsp (same as 1 pat)
        static let tablespoonTsp = 3.0                 // 1 tbsp = 3 tsp
        static let stickTsp = 24.0                     // 1 stick = 810 cal / 34 cal ≈ 23.8, rounded to 24
        static let poundTsp = 3240.0 / 34.0            // 1 lb = 3240 cal / 34 cal ≈ 95.3 tsp
        static let perfectZeroTolerance = 0.5          // ±0.5 tsp for Butter Zero
        static let marathonMiles = 26.2
        static let sculptorRunCount = 50
        static let streakRunCount = 5
        static let streakDays = -7
        static let butterFingersCount = 10
    }

    /// Check and award achievements after a run completes.
    /// Returns newly awarded achievement types.
    @discardableResult
    func checkAchievements(for run: Run, allRuns: [Run], context: ModelContext) -> [AchievementType] {
        let existingDescriptor = FetchDescriptor<Achievement>()
        let existing = (try? context.fetch(existingDescriptor)) ?? []
        let unlockedTypes = Set(existing.compactMap { $0.type })

        var newAwards: [AchievementType] = []

        func award(_ type: AchievementType) {
            guard !unlockedTypes.contains(type), !newAwards.contains(type) else { return }
            let achievement = Achievement(type: type)
            context.insert(achievement)
            newAwards.append(type)
        }

        // Single-run butter burn achievements
        if run.totalButterBurnedTsp > 0 {
            award(.patOnTheBack)
        }
        if run.totalButterBurnedTsp >= Thresholds.teaspoonTsp {
            award(.teaspoonToast)
        }
        if run.totalButterBurnedTsp >= Thresholds.tablespoonTsp {
            award(.tablespoonTriumph)
        }
        if run.totalButterBurnedTsp >= Thresholds.stickTsp {
            award(.stickSlayer)
        }

        // Butter Zero: finish within tolerance
        if run.isButterZeroChallenge && abs(run.netButterTsp) <= Thresholds.perfectZeroTolerance {
            award(.perfectZero)
        }

        // Cumulative achievements
        let totalButterTsp = allRuns.reduce(0.0) { $0 + $1.totalButterBurnedTsp }
        if totalButterTsp >= Thresholds.poundTsp {
            award(.poundPounder)
        }

        if allRuns.count >= Thresholds.sculptorRunCount {
            award(.butterSculptor)
        }

        let totalMiles = allRuns.reduce(0.0) { $0 + $1.distanceMiles }
        if totalMiles >= Thresholds.marathonMiles {
            award(.marathonMelt)
        }

        // Streak: 5 runs in one week
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: Thresholds.streakDays, to: Date()) ?? Date()
        let runsThisWeek = allRuns.filter { $0.startDate >= oneWeekAgo }
        if runsThisWeek.count >= Thresholds.streakRunCount {
            award(.fiveRunStreak)
        }

        // Per-run behavior achievements
        if run.butterEntries.count >= Thresholds.butterFingersCount {
            award(.butterFingers)
        }

        if !newAwards.isEmpty {
            try? context.save()
        }

        return newAwards
    }
}
