import XCTest
@testable import ButterRun

final class ChurnEstimatorTests: XCTestCase {

    // MARK: - Agitation RMS

    func test_agitationRMS_stillPhone() {
        let samples = Array(repeating: (x: 0.01, y: 0.01, z: 0.01), count: 20)
        let rms = ButterChurnEstimator.agitationRMS(samples: samples)
        XCTAssertEqual(rms, 0.0, accuracy: 0.05)
    }

    func test_agitationRMS_runningSimulation() {
        // Simulate ~0.8g oscillation in y-axis (running cadence)
        let samples: [(x: Double, y: Double, z: Double)] = (0..<20).map { i in
            let phase = Double(i) * .pi / 3.0  // ~3.3Hz at 20Hz sample rate
            return (x: 0.1, y: sin(phase) * 0.8, z: 0.1)
        }
        let rms = ButterChurnEstimator.agitationRMS(samples: samples)
        XCTAssertGreaterThan(rms, 0.3)
        XCTAssertLessThan(rms, 1.5)
    }

    func test_agitationRMS_vigorousShaking() {
        let samples: [(x: Double, y: Double, z: Double)] = (0..<20).map { i in
            let phase = Double(i) * .pi / 2.0
            return (x: sin(phase) * 2.0, y: cos(phase) * 2.0, z: sin(phase) * 1.5)
        }
        let rms = ButterChurnEstimator.agitationRMS(samples: samples)
        XCTAssertGreaterThan(rms, 1.5)
    }

    func test_agitationRMS_emptyArray() {
        XCTAssertEqual(ButterChurnEstimator.agitationRMS(samples: []), 0.0)
    }

    // MARK: - Churn Stages

    func test_stageForProgress_boundaries() {
        XCTAssertEqual(ChurnStage.stage(forProgress: 0.0), .liquid)
        XCTAssertEqual(ChurnStage.stage(forProgress: 0.08), .foamy)
        XCTAssertEqual(ChurnStage.stage(forProgress: 0.30), .whipped)
        XCTAssertEqual(ChurnStage.stage(forProgress: 0.55), .breaking)
        XCTAssertEqual(ChurnStage.stage(forProgress: 0.85), .butter)
    }

    func test_stageForProgress_midValues() {
        XCTAssertEqual(ChurnStage.stage(forProgress: 0.05), .liquid)
        XCTAssertEqual(ChurnStage.stage(forProgress: 0.15), .foamy)
        XCTAssertEqual(ChurnStage.stage(forProgress: 0.45), .whipped)
        XCTAssertEqual(ChurnStage.stage(forProgress: 0.70), .breaking)
        XCTAssertEqual(ChurnStage.stage(forProgress: 0.95), .butter)
    }

    // MARK: - Effectiveness Multiplier

    func test_effectivenessMultiplier_heavyCream() {
        let config = ChurnConfiguration(creamType: "heavy", creamCups: 1.0, isRoomTemp: false)
        XCTAssertEqual(config.effectivenessMultiplier, 1.0)
    }

    func test_effectivenessMultiplier_whippingCream() {
        let config = ChurnConfiguration(creamType: "whipping", creamCups: 1.0, isRoomTemp: false)
        XCTAssertEqual(config.effectivenessMultiplier, 0.7)
    }

    // MARK: - Room Temp

    func test_roomTempWarning() {
        let config = ChurnConfiguration(creamType: "heavy", creamCups: 1.0, isRoomTemp: true)
        XCTAssertTrue(config.isRoomTempWarning)
        XCTAssertEqual(config.maxProgress, 0.55)
    }

    func test_coldCream_fullProgress() {
        let config = ChurnConfiguration(creamType: "heavy", creamCups: 1.0, isRoomTemp: false)
        XCTAssertEqual(config.maxProgress, 1.0)
    }

    // MARK: - Progress Capping

    func test_progressNeverExceedsOne() {
        let stage = ChurnStage.stage(forProgress: 1.5)
        XCTAssertEqual(stage, .butter)
    }

    func test_progressNeverBelowZero() {
        let stage = ChurnStage.stage(forProgress: -0.5)
        XCTAssertEqual(stage, .liquid)
    }
}
