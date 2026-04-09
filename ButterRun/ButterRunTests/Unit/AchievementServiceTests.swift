import XCTest
import SwiftData
@testable import ButterRun

final class AchievementServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var service: AchievementService!

    @MainActor
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Run.self, Split.self, ButterEntry.self, UserProfile.self, Achievement.self, RunDraft.self,
            configurations: config
        )
        context = ModelContext(container)
        service = AchievementService()
    }

    func test_teaspoonToast_awarded() {
        let run = Run(startDate: .now)
        run.totalButterBurnedTsp = 1.5
        context.insert(run)

        let awards = service.checkAchievements(for: run, allRuns: [run], context: context)
        XCTAssertTrue(awards.contains(.teaspoonToast))
    }

    func test_tablespoonTriumph_awarded() {
        let run = Run(startDate: .now)
        run.totalButterBurnedTsp = 4.0
        context.insert(run)

        let awards = service.checkAchievements(for: run, allRuns: [run], context: context)
        XCTAssertTrue(awards.contains(.tablespoonTriumph))
    }

    func test_stickSlayer_awarded() {
        let run = Run(startDate: .now)
        run.totalButterBurnedTsp = 25.0
        context.insert(run)

        let awards = service.checkAchievements(for: run, allRuns: [run], context: context)
        XCTAssertTrue(awards.contains(.stickSlayer))
    }

    func test_perfectZero_awarded() {
        let run = Run(startDate: .now, isButterZeroChallenge: true)
        run.totalButterBurnedTsp = 5.0
        run.totalButterEatenTsp = 5.2
        run.netButterTsp = 0.2
        context.insert(run)

        let awards = service.checkAchievements(for: run, allRuns: [run], context: context)
        XCTAssertTrue(awards.contains(.perfectZero))
    }

    func test_perfectZero_notAwarded_whenNotBZ() {
        let run = Run(startDate: .now, isButterZeroChallenge: false)
        run.netButterTsp = 0.0
        context.insert(run)

        let awards = service.checkAchievements(for: run, allRuns: [run], context: context)
        XCTAssertFalse(awards.contains(.perfectZero))
    }

    func test_marathonMelt_cumulative() {
        var allRuns: [Run] = []
        for _ in 0..<5 {
            let run = Run(startDate: .now)
            run.distanceMeters = 10000 // ~6.2 miles each
            context.insert(run)
            allRuns.append(run)
        }
        // Total = 50km = ~31 miles > 26.2

        let awards = service.checkAchievements(for: allRuns.last!, allRuns: allRuns, context: context)
        XCTAssertTrue(awards.contains(.marathonMelt))
    }

    func test_noDuplicateAwards() {
        let run1 = Run(startDate: .now)
        run1.totalButterBurnedTsp = 2.0
        context.insert(run1)

        _ = service.checkAchievements(for: run1, allRuns: [run1], context: context)

        let run2 = Run(startDate: .now)
        run2.totalButterBurnedTsp = 3.0
        context.insert(run2)

        let awards2 = service.checkAchievements(for: run2, allRuns: [run1, run2], context: context)
        // teaspoonToast should NOT be awarded again
        XCTAssertFalse(awards2.contains(.teaspoonToast))
    }
}
