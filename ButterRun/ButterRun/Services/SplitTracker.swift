import Foundation
import Combine

class SplitTracker: ObservableObject {
    @Published var currentSplitIndex: Int = 0
    @Published var completedSplits: [Split] = []

    let splitPublisher = PassthroughSubject<Split, Never>()

    private var splitDistanceMeters: Double
    private var nextSplitBoundary: Double
    private var splitStartTime: Date?
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
        splitStartTime = .now
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
            let splitDuration: Double
            if let startTime = splitStartTime {
                splitDuration = Date.now.timeIntervalSince(startTime)
            } else {
                splitDuration = elapsedSeconds
            }

            let splitDistance = splitDistanceMeters
            let paceSecondsPerKm = splitDuration / (splitDistance / 1000.0)
            let splitElevation = elevationGainMeters - splitStartElevationGain

            // Calculate butter burned for this split
            let durationMinutes = splitDuration / 60.0
            let butterTsp = ButterCalculator.butterBurned(
                weightKg: weightKg,
                speedMph: currentSpeedMph,
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
            splitStartTime = .now
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

        let splitDuration: Double
        if let startTime = splitStartTime {
            splitDuration = Date.now.timeIntervalSince(startTime)
        } else {
            splitDuration = 0
        }

        let paceSecondsPerKm = remaining > 0 ? splitDuration / (remaining / 1000.0) : 0
        let durationMinutes = splitDuration / 60.0
        let butterTsp = ButterCalculator.butterBurned(
            weightKg: weightKg,
            speedMph: currentSpeedMph,
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
