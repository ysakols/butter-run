import Foundation

enum PreviewData {
    static var sampleRun: Run {
        let run = Run(startDate: .now.addingTimeInterval(-1800), isButterZeroChallenge: true)
        run.endDate = .now
        run.distanceMeters = 5150
        run.durationSeconds = 1800
        run.averagePaceSecondsPerKm = 349
        run.bestPaceSecondsPerKm = 320
        run.totalCaloriesBurned = 343
        run.totalButterBurnedTsp = 10.1
        run.totalButterEatenTsp = 9.5
        run.netButterTsp = -0.6
        run.elevationGainMeters = 45
        run.elevationLossMeters = 42
        return run
    }

    static var sampleProfile: UserProfile {
        UserProfile(
            displayName: "Butter Runner",
            weightKg: 70,
            preferredUnit: "miles",
            voiceFeedbackEnabled: true
        )
    }
}
