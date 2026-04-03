import Foundation
import Combine
import SwiftData

@Observable
class ActiveRunViewModel {
    // MARK: - Run State
    enum RunState {
        case idle
        case running
        case paused
        case finished
    }

    var state: RunState = .idle
    var elapsedSeconds: Double = 0
    var distanceMeters: Double = 0
    var currentSpeedMph: Double = 0
    var averageSpeedMph: Double = 0
    var butterBurnedTsp: Double = 0
    var butterEatenTsp: Double = 0
    var isButterZeroChallenge: Bool = false
    var butterEntries: [ButterEntry] = []

    // MARK: - Services
    private let locationService = LocationService()
    private let motionService = MotionService()
    private let voiceService = VoiceFeedbackService()
    private var splitTracker: SplitTracker?

    private var timer: Timer?
    private var startDate: Date?
    private var pausedDuration: TimeInterval = 0
    private var lastPauseDate: Date?
    private var cancellables = Set<AnyCancellable>()

    var weightKg: Double = 70.0
    var usesMiles: Bool = true
    var splitDistanceMeters: Double = 1609.344

    // MARK: - Computed Properties

    var netButterTsp: Double {
        butterEatenTsp - butterBurnedTsp
    }

    var butterZeroScore: Int {
        ButterCalculator.butterZeroScore(netTsp: netButterTsp)
    }

    var formattedDuration: String {
        ButterFormatters.duration(elapsedSeconds)
    }

    var formattedDistance: String {
        ButterFormatters.distance(meters: distanceMeters, usesMiles: usesMiles)
    }

    var formattedPace: String {
        guard distanceMeters > 0, elapsedSeconds > 0 else { return "--:--" }
        let secondsPerKm = elapsedSeconds / (distanceMeters / 1000.0)
        return ButterFormatters.pace(secondsPerKm: secondsPerKm, usesMiles: usesMiles)
    }

    var formattedButter: String {
        String(format: "%.1f", butterBurnedTsp)
    }

    var butterRate: Double {
        guard elapsedSeconds > 60 else { return 0 }
        return butterBurnedTsp / (elapsedSeconds / 60.0)
    }

    // MARK: - Actions

    func configure(profile: UserProfile) {
        weightKg = profile.weightKg
        usesMiles = profile.usesMiles
        splitDistanceMeters = profile.splitDistanceMeters
        voiceService.isEnabled = profile.voiceFeedbackEnabled
    }

    func startRun() {
        state = .running
        startDate = .now
        elapsedSeconds = 0
        distanceMeters = 0
        butterBurnedTsp = 0
        butterEatenTsp = 0
        butterEntries = []
        pausedDuration = 0

        splitTracker = SplitTracker(splitDistanceMeters: splitDistanceMeters, weightKg: weightKg)
        splitTracker?.start()
        voiceService.reset()

        locationService.startTracking()
        motionService.startTracking()
        startTimer()

        // Subscribe to location updates
        locationService.locationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMetrics()
            }
            .store(in: &cancellables)
    }

    func pauseRun() {
        state = .paused
        lastPauseDate = .now
        locationService.pauseTracking()
        timer?.invalidate()
    }

    func resumeRun() {
        state = .running
        if let pauseDate = lastPauseDate {
            pausedDuration += Date.now.timeIntervalSince(pauseDate)
        }
        locationService.resumeTracking()
        startTimer()
    }

    func stopRun() -> Run {
        state = .finished
        timer?.invalidate()
        locationService.stopTracking()
        motionService.stopTracking()
        cancellables.removeAll()

        voiceService.announceRunEnd(
            totalButterTsp: butterBurnedTsp,
            netButter: isButterZeroChallenge ? netButterTsp : nil,
            isButterZero: isButterZeroChallenge
        )

        // Build the Run model
        let run = Run(startDate: startDate ?? .now, isButterZeroChallenge: isButterZeroChallenge)
        run.endDate = .now
        run.distanceMeters = distanceMeters
        run.durationSeconds = elapsedSeconds
        run.totalCaloriesBurned = butterBurnedTsp * ButterCalculator.caloriesPerTeaspoon
        run.totalButterBurnedTsp = butterBurnedTsp
        run.totalButterEatenTsp = butterEatenTsp
        run.netButterTsp = netButterTsp
        run.elevationGainMeters = locationService.elevationGainMeters
        run.elevationLossMeters = locationService.elevationLossMeters
        run.averageCadence = motionService.currentCadence > 0 ? motionService.currentCadence : nil
        run.routePolyline = locationService.encodeRoute()

        // Calculate average pace
        if distanceMeters > 0 {
            run.averagePaceSecondsPerKm = elapsedSeconds / (distanceMeters / 1000.0)
        }

        // Attach splits
        var allSplits = splitTracker?.completedSplits ?? []
        if let finalSplit = splitTracker?.finalSplit(
            totalDistanceMeters: distanceMeters,
            elapsedSeconds: elapsedSeconds,
            elevationGainMeters: locationService.elevationGainMeters,
            currentSpeedMph: currentSpeedMph
        ) {
            allSplits.append(finalSplit)
        }
        run.splits = allSplits

        // Attach butter entries
        run.butterEntries = butterEntries

        return run
    }

    func eatButter(serving: ButterServing, customTsp: Double = 0) {
        let entry = ButterEntry(serving: serving, customTeaspoons: customTsp)
        butterEntries.append(entry)
        butterEatenTsp += entry.teaspoonEquivalent
    }

    // MARK: - Private

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard state == .running, let start = startDate else { return }
        elapsedSeconds = Date.now.timeIntervalSince(start) - pausedDuration
        updateMetrics()
    }

    private func updateMetrics() {
        distanceMeters = locationService.totalDistanceMeters
        currentSpeedMph = ButterCalculator.metersPerSecondToMph(locationService.currentSpeedMps)

        if elapsedSeconds > 0 && distanceMeters > 0 {
            averageSpeedMph = ButterCalculator.metersPerSecondToMph(distanceMeters / elapsedSeconds)
        }

        // Recalculate total butter burned
        let durationMinutes = elapsedSeconds / 60.0
        let avgMet = ButterCalculator.metValue(forSpeedMph: averageSpeedMph)
        let calories = ButterCalculator.caloriesBurned(
            weightKg: weightKg,
            met: avgMet,
            durationMinutes: durationMinutes
        )
        butterBurnedTsp = ButterCalculator.caloriesToButterTsp(calories)

        // Update split tracker
        splitTracker?.update(
            totalDistanceMeters: distanceMeters,
            elapsedSeconds: elapsedSeconds,
            elevationGainMeters: locationService.elevationGainMeters,
            currentSpeedMph: currentSpeedMph
        )

        // Voice milestones
        voiceService.checkMilestones(
            butterTsp: butterBurnedTsp,
            distanceMiles: distanceMeters / 1609.344,
            pace: formattedPace,
            isButterZero: isButterZeroChallenge,
            netButter: netButterTsp
        )
    }
}
