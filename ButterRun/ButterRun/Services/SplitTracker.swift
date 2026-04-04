import Foundation
import Combine

class SplitTracker: ObservableObject {
    @Published var currentSplitIndex: Int = 0
    @Published var completedSplits: [Split] = []

    let splitPublisher = PassthroughSubject<Split, Never>()

    private var splitDistanceMeters: Double
    private var nextSplitBoundary: Double
    private var splitStartElapsedSeconds: Double = 0
    private var splitStartDistance: Double = 0
    private var splitStartElevationGain: Double = 0
    private var weightKg: Double

    init(splitDistanceMeters: Double, weightKg: Double) {
        self.splitDistanceMeters = splitDistanceMeters
        self.weightKg = weightKg
        self.nextSplitBoundary = splitDistanceMeters
    }

    func start() {
        currentSplitIndex = 0
        completedSplits = []
        nextSplitBoundary = splitDistanceMeters
        splitStartElapsedSeconds = 0
        splitStartDistance = 0
        splitStartElevationGain = 0
    }

    /// Call this every time distance or metrics update.
    func update(
        totalDistanceMeters: Double,
        elapsedSeconds: Double,
        elevationGainMeters: Double,
        currentSpeedMph: Double
    ) {
        // Check if we crossed one or more split boundaries
        while totalDistanceMeters >= nextSplitBoundary {
            let splitDuration = elapsedSeconds - splitStartElapsedSeconds

            let splitDistance = splitDistanceMeters
            let paceSecondsPerKm = splitDuration / (splitDistance / 1000.0)
            let splitElevation = elevationGainMeters - splitStartElevationGain

            // Calculate butter burned for this split using the split's average speed
            let durationMinutes = splitDuration / 60.0
            let splitAvgSpeedMps = splitDuration > 0 ? splitDistance / splitDuration : 0
            let splitAvgSpeedMph = ButterCalculator.metersPerSecondToMph(splitAvgSpeedMps)
            let butterTsp = ButterCalculator.butterBurned(
                weightKg: weightKg,
                speedMph: splitAvgSpeedMph,
                durationMinutes: durationMinutes
            )

            let split = Split(
                index: currentSplitIndex,
                distanceMeters: splitDistance,
                durationSeconds: splitDuration,
                paceSecondsPerKm: paceSecondsPerKm,
                butterBurnedTsp: butterTsp,
                elevationGainMeters: splitElevation,
                isPartial: false
            )

            completedSplits.append(split)
            splitPublisher.send(split)

            currentSplitIndex += 1
            nextSplitBoundary += splitDistanceMeters
            splitStartElapsedSeconds = elapsedSeconds
            splitStartDistance = totalDistanceMeters
            splitStartElevationGain = elevationGainMeters
        }
    }

    /// Generate a final partial split when the run ends.
    func finalSplit(
        totalDistanceMeters: Double,
        elapsedSeconds: Double,
        elevationGainMeters: Double,
        currentSpeedMph: Double
    ) -> Split? {
        let remaining = totalDistanceMeters - splitStartDistance
        guard remaining > 10 else { return nil } // ignore tiny remainders

        let splitDuration = elapsedSeconds - splitStartElapsedSeconds

        let paceSecondsPerKm = remaining > 0 ? splitDuration / (remaining / 1000.0) : 0
        let durationMinutes = splitDuration / 60.0
        let splitAvgSpeedMps = splitDuration > 0 ? remaining / splitDuration : 0
        let splitAvgSpeedMph = ButterCalculator.metersPerSecondToMph(splitAvgSpeedMps)
        let butterTsp = ButterCalculator.butterBurned(
            weightKg: weightKg,
            speedMph: splitAvgSpeedMph,
            durationMinutes: durationMinutes
        )

        return Split(
            index: currentSplitIndex,
            distanceMeters: remaining,
            durationSeconds: splitDuration,
            paceSecondsPerKm: paceSecondsPerKm,
            butterBurnedTsp: butterTsp,
            elevationGainMeters: elevationGainMeters - splitStartElevationGain,
            isPartial: true
        )
    }
}
