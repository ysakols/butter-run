import Foundation
import Observation
import CoreMotion
import Combine

struct ChurnConfiguration: Codable {
    let creamType: String  // "heavy" or "whipping"
    let creamCups: Double
    let isRoomTemp: Bool

    var effectivenessMultiplier: Double {
        switch creamType {
        case "heavy": return 1.0
        case "whipping": return 0.7
        default: return 0.5
        }
    }

    /// Heavy cream: ~21 lbs of milk per lb butter. 1 cup heavy cream ~= 0.4 cups butter.
    /// We scale the agitation threshold by amount: more cream = more agitation needed.
    var agitationThreshold: Double {
        let baseThreshold = 800.0  // Total agitation units for 1 cup heavy cream
        return baseThreshold * creamCups / effectivenessMultiplier
    }

    var isRoomTempWarning: Bool {
        isRoomTemp
    }

    /// Room temp cream caps at Whipped stage
    var maxProgress: Double {
        isRoomTemp ? 0.55 : 1.0
    }
}

@Observable
class ButterChurnEstimator {
    private let motionManager = CMMotionManager()
    private let sampleRate: TimeInterval = 1.0 / 20.0  // 20Hz
    private let windowSize = 20  // 1-second window at 20Hz
    private let motionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.butterrun.churn-motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    private(set) var currentStage: ChurnStage = .liquid
    private(set) var progress: Double = 0.0
    private(set) var isActive = false

    private var configuration: ChurnConfiguration?
    private var totalAgitation: Double = 0
    private var sampleBuffer: [(x: Double, y: Double, z: Double)] = []
    private var previousStage: ChurnStage = .liquid
    private let lock = NSLock()
    /// Incremented on each start() to invalidate stale async blocks from prior sessions.
    private var generation: Int = 0

    let stageAdvancedPublisher = PassthroughSubject<ChurnStage, Never>()

    // MARK: - Pure Algorithm (testable without CoreMotion)

    /// Compute RMS of acceleration magnitude over a window of samples
    static func agitationRMS(samples: [(x: Double, y: Double, z: Double)]) -> Double {
        guard !samples.isEmpty else { return 0 }

        let sumSquares = samples.reduce(0.0) { sum, s in
            let magnitude = sqrt(s.x * s.x + s.y * s.y + s.z * s.z)
            return sum + magnitude * magnitude
        }

        return sqrt(sumSquares / Double(samples.count))
    }

    // MARK: - Lifecycle

    func start(configuration: ChurnConfiguration) {
        lock.lock()
        generation += 1
        self.configuration = configuration
        self.totalAgitation = 0
        self.progress = 0
        self.currentStage = .liquid
        self.previousStage = .liquid
        self.sampleBuffer = []
        self.isActive = true
        lock.unlock()

        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = sampleRate
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
            guard let motion = motion, error == nil else { return }

            let accel = motion.userAcceleration
            self?.processSample(x: accel.x, y: accel.y, z: accel.z)
        }
    }

    func pause() {
        motionManager.stopDeviceMotionUpdates()
    }

    func resume() {
        lock.lock()
        let active = isActive
        lock.unlock()
        guard active, motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = sampleRate
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
            guard let motion = motion, error == nil else { return }
            let accel = motion.userAcceleration
            self?.processSample(x: accel.x, y: accel.y, z: accel.z)
        }
    }

    func stop() -> ChurnResult? {
        motionManager.stopDeviceMotionUpdates()

        lock.lock()
        isActive = false
        let config = configuration
        let agitation = totalAgitation
        lock.unlock()

        guard let config else { return nil }

        // Derive progress and stage from the locked agitation total rather than
        // reading the async-updated observable properties, which may be stale.
        let prog = min(agitation / config.agitationThreshold, config.maxProgress)
        let stage = ChurnStage.stage(forProgress: prog)

        return ChurnResult(
            creamType: config.creamType,
            creamCups: config.creamCups,
            finalStage: stage.rawValue,
            finalProgress: prog,
            totalAgitation: agitation
        )
    }

    // MARK: - Sample Processing

    func processSample(x: Double, y: Double, z: Double) {
        lock.lock()
        defer { lock.unlock() }

        sampleBuffer.append((x: x, y: y, z: z))
        guard sampleBuffer.count >= windowSize else { return }

        let rms = Self.agitationRMS(samples: sampleBuffer)
        sampleBuffer.removeAll()

        guard let config = configuration else { return }

        // Accumulate agitation
        totalAgitation += rms * config.effectivenessMultiplier

        // Calculate progress
        let rawProgress = totalAgitation / config.agitationThreshold
        let clampedProgress = min(rawProgress, config.maxProgress)

        // Determine stage
        let newStage = ChurnStage.stage(forProgress: clampedProgress)
        let stageChanged = newStage != previousStage
        previousStage = newStage
        let gen = generation

        // Update observable properties and publish stage changes on main thread.
        // Check generation to prevent stale async blocks from overwriting a fresh start().
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let currentGen = self.generation
            self.lock.unlock()
            guard currentGen == gen else { return }
            self.progress = clampedProgress
            self.currentStage = newStage
            if stageChanged {
                self.stageAdvancedPublisher.send(newStage)
            }
        }
    }
}
