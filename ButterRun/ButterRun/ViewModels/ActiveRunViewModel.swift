import Foundation
import Combine
import SwiftData
import AVFoundation
import UIKit

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

    // Churn tracker
    var isChurnEnabled: Bool = false
    var churnProgress: Double = 0
    var churnStage: ChurnStage = .liquid

    // GPS
    var gpsSignalState: GPSSignalState = .strong

    // Auto-pause
    var isAutoPaused: Bool = false

    // MARK: - Services (injected via protocols)
    private let locationService: LocationTracking
    private let motionService: MotionTracking
    private let voiceService: VoiceFeedback
    private let hapticService: HapticFeedback
    private let autoPauseService: AutoPauseService
    private let churnEstimator: ButterChurnEstimator

    private var splitTracker: SplitTracker?
    private var draftService: RunDraftService?

    // Undo toast
    var showUndoToast: Bool = false

    private var timer: Timer?
    private var startDate: Date?
    private var pausedDuration: TimeInterval = 0
    private var lastPauseDate: Date?
    private var lastDraftSave: Date?
    private var lastLocationUpdate: Date?
    private var previousSplitCount: Int = 0
    private var cancellables = Set<AnyCancellable>()

    var weightKg: Double = 70.0
    var usesMiles: Bool = true
    var splitDistanceMeters: Double = 1609.344

    // MARK: - Init with dependency injection

    init(
        location: LocationTracking = LocationService(),
        motion: MotionTracking = MotionService(),
        voice: VoiceFeedback = VoiceFeedbackService(),
        haptic: HapticFeedback = HapticService(),
        autoPause: AutoPauseService = AutoPauseService(),
        churnEstimator: ButterChurnEstimator = ButterChurnEstimator()
    ) {
        self.locationService = location
        self.motionService = motion
        self.voiceService = voice
        self.hapticService = haptic
        self.autoPauseService = autoPause
        self.churnEstimator = churnEstimator
    }

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

    var butterRate: Double? {
        guard elapsedSeconds > 60 else { return nil }
        return butterBurnedTsp / (elapsedSeconds / 60.0)
    }

    var formattedButterRate: String {
        guard let rate = butterRate else { return "--" }
        return String(format: "%.2f/min", rate)
    }

    // MARK: - Actions

    func configure(profile: UserProfile) {
        weightKg = max(1.0, profile.weightKg)
        usesMiles = profile.usesMiles
        splitDistanceMeters = profile.splitDistanceMeters
        var voice = voiceService
        voice.isEnabled = profile.voiceFeedbackEnabled
        autoPauseService.isEnabled = profile.autoPauseEnabled
    }

    func setDraftService(_ service: RunDraftService) {
        self.draftService = service
    }

    func startRun() {
        guard state == .idle else { return }

        // Clear any previous subscriptions
        cancellables.removeAll()

        // AVAudioSession keep-alive for background execution
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)

        state = .running
        startDate = .now
        elapsedSeconds = 0
        distanceMeters = 0
        butterBurnedTsp = 0
        butterEatenTsp = 0
        butterEntries = []
        pausedDuration = 0
        isAutoPaused = false
        gpsSignalState = .strong
        lastDraftSave = .now
        lastLocationUpdate = nil
        previousSplitCount = 0
        showUndoToast = false

        splitTracker = SplitTracker(splitDistanceMeters: max(1.0, splitDistanceMeters), weightKg: weightKg)
        splitTracker?.start()

        var voice = voiceService
        voice.isEnabled = voiceService.isEnabled
        voiceService.reset()
        autoPauseService.reset()

        locationService.startTracking()
        motionService.startTracking()
        startTimer()

        // Subscribe to location updates — this is the primary metrics driver
        locationService.locationPublisher
            .receive(on: DispatchQueue.main)
            .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                self?.lastLocationUpdate = Date()
                self?.updateMetrics()
            }
            .store(in: &cancellables)

        // Subscribe to auto-pause events
        autoPauseService.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleAutoPauseEvent(event)
            }
            .store(in: &cancellables)

        // Subscribe to churn stage changes
        churnEstimator.stageAdvancedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stage in
                self?.hapticService.churnStageAdvanced()
                self?.voiceService.announceChurnStage(stage.name)
                UIAccessibility.post(notification: .announcement, argument: "Churn stage: \(stage.name)")
            }
            .store(in: &cancellables)
    }

    func startChurn(configuration: ChurnConfiguration) {
        isChurnEnabled = true
        churnEstimator.start(configuration: configuration)
    }

    func pauseRun() {
        guard state == .running else { return }
        state = .paused
        lastPauseDate = .now
        locationService.pauseTracking()
        timer?.invalidate()
    }

    func resumeRun() {
        guard state == .paused else { return }
        state = .running
        isAutoPaused = false
        if let pauseDate = lastPauseDate {
            pausedDuration += Date.now.timeIntervalSince(pauseDate)
        }
        locationService.resumeTracking()
        startTimer()
    }

    private var finishedRun: Run?

    func stopRun() -> Run {
        // Idempotent: return existing run if already finished
        if state == .finished, let existing = finishedRun { return existing }

        state = .finished
        timer?.invalidate()
        locationService.stopTracking()
        motionService.stopTracking()
        cancellables.removeAll()

        hapticService.runFinished()
        UIAccessibility.post(notification: .announcement, argument: "Run complete")

        voiceService.announceRunEnd(
            totalButterTsp: butterBurnedTsp,
            netButter: isButterZeroChallenge ? netButterTsp : nil,
            isButterZero: isButterZeroChallenge
        )

        // Deactivate background audio session after voice announcement queued
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }

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

        if distanceMeters > 0 {
            run.averagePaceSecondsPerKm = elapsedSeconds / (distanceMeters / 1000.0)
        }

        // Attach churn result
        if isChurnEnabled {
            if let result = churnEstimator.stop() {
                run.churnResultData = try? JSONEncoder().encode(result)
            }
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
        run.butterEntries = butterEntries

        finishedRun = run
        return run
    }

    func eatButter(serving: ButterServing, customTsp: Double = 0) {
        let entry = ButterEntry(serving: serving, customTeaspoons: customTsp)
        butterEntries.append(entry)
        butterEatenTsp += entry.teaspoonEquivalent

        // Show undo toast
        showUndoToast = true
        UIAccessibility.post(notification: .announcement, argument: "Added \(String(format: "%.1f", entry.teaspoonEquivalent)) teaspoons. Double-tap Undo to reverse.")

        // Check Butter Zero crossing
        if isButterZeroChallenge && abs(netButterTsp) < 0.3 {
            hapticService.butterZeroCrossing()
            UIAccessibility.post(notification: .announcement, argument: "Butter Zero reached")
        }
    }

    /// Undo the most recent butter entry
    func undoLastButterEntry() -> Bool {
        guard let last = butterEntries.last else { return false }
        butterEatenTsp = max(0, butterEatenTsp - last.teaspoonEquivalent)
        butterEntries.removeLast()
        showUndoToast = false
        UIAccessibility.post(notification: .announcement, argument: "Butter entry undone")
        return true
    }

    // MARK: - Private

    private func startTimer() {
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard state == .running, let start = startDate else { return }
        elapsedSeconds = Date.now.timeIntervalSince(start) - pausedDuration

        // Only call updateMetrics as fallback when no location update in last 2 seconds
        if let lastLoc = lastLocationUpdate, Date().timeIntervalSince(lastLoc) < 2 {
            // Location publisher is driving metrics — just update elapsed time display
        } else {
            updateMetrics()
        }

        checkDraftSave()
    }

    private func updateMetrics() {
        distanceMeters = locationService.totalDistanceMeters
        currentSpeedMph = ButterCalculator.metersPerSecondToMph(locationService.currentSpeedMps)

        // GPS signal state
        gpsSignalState = locationService.gpsSignalState

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

        // Capture split count BEFORE update to detect new completions
        let countBefore = splitTracker?.completedSplits.count ?? 0

        // Update split tracker
        splitTracker?.update(
            totalDistanceMeters: distanceMeters,
            elapsedSeconds: elapsedSeconds,
            elevationGainMeters: locationService.elevationGainMeters,
            currentSpeedMph: currentSpeedMph
        )

        // Check if a new split was completed
        let countAfter = splitTracker?.completedSplits.count ?? 0
        if countAfter > countBefore {
            hapticService.splitCompleted()
            let splitNum = countAfter
            let announcement = "Split \(splitNum) complete. Pace: \(formattedPace)"
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }

        // Update churn progress
        if isChurnEnabled {
            churnProgress = churnEstimator.progress
            churnStage = churnEstimator.currentStage
        }

        // Feed auto-pause
        autoPauseService.updateSpeed(locationService.currentSpeedMps)

        // Voice milestones
        voiceService.checkMilestones(
            butterTsp: butterBurnedTsp,
            distanceMiles: distanceMeters / 1609.344,
            pace: formattedPace,
            isButterZero: isButterZeroChallenge,
            netButter: netButterTsp
        )
    }

    private func handleAutoPauseEvent(_ event: AutoPauseEvent) {
        switch event {
        case .autoPaused:
            isAutoPaused = true
            pauseRun()
            voiceService.announceAutoPause(paused: true)
            UIAccessibility.post(notification: .announcement, argument: "Run auto-paused")
        case .autoResumed:
            isAutoPaused = false
            resumeRun()
            voiceService.announceAutoPause(paused: false)
            UIAccessibility.post(notification: .announcement, argument: "Run resumed")
        }
    }

    /// Checkpoint draft every 30 seconds
    private func checkDraftSave() {
        guard let lastSave = lastDraftSave,
              Date().timeIntervalSince(lastSave) >= 30 else { return }

        lastDraftSave = Date()

        // Encode butter entries for draft
        let entriesData: Data? = {
            struct EntrySnapshot: Codable {
                let servingRaw: String
                let tsp: Double
                let timestamp: Date
            }
            let snapshots = butterEntries.map {
                EntrySnapshot(servingRaw: $0.servingTypeRaw, tsp: $0.teaspoonEquivalent, timestamp: $0.timestamp)
            }
            return try? JSONEncoder().encode(snapshots)
        }()

        // Encode route on background queue to avoid blocking main thread
        let locationSvc = locationService
        let draftSvc = draftService
        let start = startDate ?? .now
        let elapsed = elapsedSeconds
        let paused = pausedDuration
        let distance = distanceMeters
        let burned = butterBurnedTsp
        let eaten = butterEatenTsp
        let isBZ = isButterZeroChallenge

        DispatchQueue.global(qos: .utility).async {
            let routeData = locationSvc.encodeRoute()
            draftSvc?.saveDraft(
                startDate: start,
                elapsedSeconds: elapsed,
                pausedDuration: paused,
                distanceMeters: distance,
                butterBurnedTsp: burned,
                butterEatenTsp: eaten,
                isButterZeroChallenge: isBZ,
                routeData: routeData,
                butterEntriesData: entriesData
            )
        }
    }
}
