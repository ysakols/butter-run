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
    private var splitStartButterBurned: Double = 0
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
        splitStartButterBurned = 0
    }

    /// Call this every time distance or metrics update.
    /// `butterBurnedTsp` is the VM's running total, used to derive per-split butter burn.
    func update(
        totalDistanceMeters: Double,
        elapsedSeconds: Double,
        elevationGainMeters: Double,
        currentSpeedMph: Double,
        butterBurnedTsp: Double = 0
    ) {
        // Check if we crossed one or more split boundaries
        while totalDistanceMeters >= nextSplitBoundary {
            let splitDuration = elapsedSeconds - splitStartElapsedSeconds

            let splitDistance = splitDistanceMeters
            let paceSecondsPerKm = splitDuration / (splitDistance / 1000.0)
            let splitElevation = elevationGainMeters - splitStartElevationGain

            // Use the VM's accumulated butter burn for this split interval
            let splitButterTsp = butterBurnedTsp - splitStartButterBurned

            let split = Split(
                index: currentSplitIndex,
                distanceMeters: splitDistance,
                durationSeconds: splitDuration,
                paceSecondsPerKm: paceSecondsPerKm,
                butterBurnedTsp: splitButterTsp,
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
            splitStartButterBurned = butterBurnedTsp
        }
    }

    /// Generate a final partial split when the run ends.
    func finalSplit(
        totalDistanceMeters: Double,
        elapsedSeconds: Double,
        elevationGainMeters: Double,
        currentSpeedMph: Double,
        butterBurnedTsp: Double = 0
    ) -> Split? {
        let remaining = totalDistanceMeters - splitStartDistance
        guard remaining > 10 else { return nil } // ignore tiny remainders

        let splitDuration = elapsedSeconds - splitStartElapsedSeconds
        let paceSecondsPerKm = remaining > 0 ? splitDuration / (remaining / 1000.0) : 0
        let splitButterTsp = butterBurnedTsp - splitStartButterBurned

        return Split(
            index: currentSplitIndex,
            distanceMeters: remaining,
            durationSeconds: splitDuration,
            paceSecondsPerKm: paceSecondsPerKm,
            butterBurnedTsp: splitButterTsp,
            elevationGainMeters: elevationGainMeters - splitStartElevationGain,
            isPartial: true
        )
    }
}
