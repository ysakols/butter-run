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

        // Pat on the Back: burn 1 pat (~1.06 tsp / 36 cal) in a single run
        if run.totalButterBurnedTsp >= 1.06 {
            award(.patOnTheBack)
        }

        // Pound Pounder: burn 1 lb butter (3240 cal / 34 cal per tsp ≈ 95.3 tsp) cumulative
        let totalButterTsp = allRuns.reduce(0.0) { $0 + $1.totalButterBurnedTsp }
        if totalButterTsp >= (3240.0 / 34.0) {
            award(.poundPounder)
        }

        // Butter Sculptor: complete 50 runs
        if allRuns.count >= 50 {
            award(.butterSculptor)
        }

        // Marathon Melt: 26.2 miles total (cumulative)
        let totalMiles = allRuns.reduce(0.0) { $0 + $1.distanceMiles }
        if totalMiles >= 26.2 {
            award(.marathonMelt)
        }

        // Five Run Streak: 5 runs in one week
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let runsThisWeek = allRuns.filter { $0.startDate >= oneWeekAgo }
        if runsThisWeek.count >= 5 {
            award(.fiveRunStreak)
        }

        // Butter Fingers: eat butter 10 times in one run
        if run.butterEntries.count >= 10 {
            award(.butterFingers)
        }

        if !newAwards.isEmpty {
            try? context.save()
        }

        return newAwards
    }
}
