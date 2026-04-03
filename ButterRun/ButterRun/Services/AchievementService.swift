import Foundation
import SwiftData

class AchievementService {
    /// Check and award achievements after a run completes.
    /// Returns newly awarded achievement types.
    @discardableResult
    func checkAchievements(for run: Run, allRuns: [Run], context: ModelContext) -> [AchievementType] {
        let existingDescriptor = FetchDescriptor<Achievement>()
        let existing = (try? context.fetch(existingDescriptor)) ?? []
        let unlockedTypes = Set(existing.compactMap { $0.type })

        var newAwards: [AchievementType] = []

        func award(_ type: AchievementType) {
            guard !unlockedTypes.contains(type) else { return }
            let achievement = Achievement(type: type)
            context.insert(achievement)
            newAwards.append(type)
        }

        // Teaspoon Toast: burn 1 tsp in a single run
        if run.totalButterBurnedTsp >= 1.0 {
            award(.teaspoonToast)
        }

        // Tablespoon Triumph: burn 3 tsp (1 tbsp) in a single run
        if run.totalButterBurnedTsp >= 3.0 {
            award(.tablespoonTriumph)
        }

        // Stick Slayer: burn 24 tsp (1 stick = 810 cal / 34 cal) in a single run
        if run.totalButterBurnedTsp >= 24.0 {
            award(.stickSlayer)
        }

        // Perfect Zero: Butter Zero within ±0.5 tsp
        if run.isButterZeroChallenge && abs(run.netButterTsp) <= 0.5 {
            award(.perfectZero)
        }

        // Marathon Melt: 26.2 miles total (cumulative)
        let totalMiles = allRuns.reduce(0.0) { $0 + $1.distanceMiles }
        if totalMiles >= 26.2 {
            award(.marathonMelt)
        }

        if !newAwards.isEmpty {
            try? context.save()
        }

        return newAwards
    }
}
