import XCTest
@testable import ButterRun

final class RunHistoryViewModelTests: XCTestCase {

    func test_load_emptyArray() {
        let vm = RunHistoryViewModel()
        vm.load(runs: [])
        XCTAssertEqual(vm.allTimeRuns, 0)
        XCTAssertEqual(vm.allTimeButterTsp, 0)
        XCTAssertEqual(vm.allTimeDistanceMeters, 0)
    }

    func test_load_singleRun() {
        let vm = RunHistoryViewModel()
        let run = Run(startDate: .now, isButterZeroChallenge: false)
        run.totalButterBurnedTsp = 2.5
        run.distanceMeters = 5000

        vm.load(runs: [run])
        XCTAssertEqual(vm.allTimeRuns, 1)
        XCTAssertEqual(vm.allTimeButterTsp, 2.5, accuracy: 0.01)
        XCTAssertEqual(vm.allTimeDistanceMeters, 5000, accuracy: 0.01)
    }

    func test_load_multipleRuns_sumsTotals() {
        let vm = RunHistoryViewModel()
        let run1 = Run(startDate: .now, isButterZeroChallenge: false)
        run1.totalButterBurnedTsp = 2.0
        run1.distanceMeters = 3000

        let run2 = Run(startDate: .now, isButterZeroChallenge: true)
        run2.totalButterBurnedTsp = 3.5
        run2.distanceMeters = 7000

        vm.load(runs: [run1, run2])
        XCTAssertEqual(vm.allTimeRuns, 2)
        XCTAssertEqual(vm.allTimeButterTsp, 5.5, accuracy: 0.01)
        XCTAssertEqual(vm.allTimeDistanceMeters, 10000, accuracy: 0.01)
    }

    func test_load_replacesOldValues() {
        let vm = RunHistoryViewModel()
        let run1 = Run(startDate: .now, isButterZeroChallenge: false)
        run1.totalButterBurnedTsp = 10.0
        run1.distanceMeters = 20000

        vm.load(runs: [run1])
        XCTAssertEqual(vm.allTimeRuns, 1)

        // Reload with empty — should reset
        vm.load(runs: [])
        XCTAssertEqual(vm.allTimeRuns, 0)
        XCTAssertEqual(vm.allTimeButterTsp, 0)
        XCTAssertEqual(vm.allTimeDistanceMeters, 0)
    }
}
