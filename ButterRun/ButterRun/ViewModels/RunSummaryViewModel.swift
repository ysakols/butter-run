import Foundation
import SwiftUI

@Observable
class RunSummaryViewModel {
    let run: Run
    let usesMiles: Bool

    init(run: Run, usesMiles: Bool) {
        self.run = run
        self.usesMiles = usesMiles
    }

    var butterBurned: String {
        ButterFormatters.pats(run.totalButterBurnedTsp)
    }

    var butterDescription: String {
        ButterCalculator.butterDescription(tsp: run.totalButterBurnedTsp)
    }

    var distance: String {
        ButterFormatters.distance(meters: run.distanceMeters, usesMiles: usesMiles)
    }

    var duration: String {
        run.formattedDuration
    }

    var avgPace: String {
        ButterFormatters.pace(secondsPerKm: run.averagePaceSecondsPerKm, usesMiles: usesMiles)
    }

    var netButter: String? {
        guard run.isButterZeroChallenge else { return nil }
        return ButterFormatters.netPats(run.netButterTsp)
    }

    @MainActor
    func generateShareImage() -> UIImage? {
        ShareImageRenderer.render(run: run, usesMiles: usesMiles)
    }
}
