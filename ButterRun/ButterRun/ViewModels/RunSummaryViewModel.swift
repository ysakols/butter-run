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
        String(format: "%.1f tsp", run.totalButterBurnedTsp)
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
        let net = run.netButterTsp
        let sign = net >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", net)) tsp"
    }

    var butterZeroScore: Int? {
        guard run.isButterZeroChallenge else { return nil }
        return run.butterZeroScore
    }

    @MainActor
    func generateShareImage() -> UIImage? {
        ShareImageRenderer.render(run: run, usesMiles: usesMiles)
    }
}
