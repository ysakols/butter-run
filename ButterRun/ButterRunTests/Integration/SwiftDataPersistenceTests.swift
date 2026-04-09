import XCTest
import SwiftData
@testable import ButterRun

final class SwiftDataPersistenceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    @MainActor
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Run.self, Split.self, ButterEntry.self, UserProfile.self, Achievement.self, RunDraft.self,
            configurations: config
        )
        context = ModelContext(container)
    }

    func test_saveAndFetchRun() throws {
        let run = Run(startDate: Date(timeIntervalSince1970: 1000000))
        run.distanceMeters = 5000
        run.totalButterBurnedTsp = 3.5
        context.insert(run)
        try context.save()

        let descriptor = FetchDescriptor<Run>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.distanceMeters, 5000)
        XCTAssertEqual(fetched.first?.totalButterBurnedTsp, 3.5)
    }

    func test_cascadeDeleteSplits() throws {
        let run = Run(startDate: .now)
        let split = Split(index: 0, distanceMeters: 1609, durationSeconds: 480, paceSecondsPerKm: 298, butterBurnedTsp: 3.0)
        run.splits = [split]
        context.insert(run)
        try context.save()

        context.delete(run)
        try context.save()

        let splits = try context.fetch(FetchDescriptor<Split>())
        XCTAssertEqual(splits.count, 0)
    }

    func test_cascadeDeleteButterEntries() throws {
        let run = Run(startDate: .now, isButterZeroChallenge: true)
        let entry = ButterEntry(serving: .teaspoon)
        run.butterEntries = [entry]
        context.insert(run)
        try context.save()

        context.delete(run)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<ButterEntry>())
        XCTAssertEqual(entries.count, 0)
    }

    func test_runDraftSaveAndLoad() throws {
        let draft = RunDraft(
            startDate: .now,
            elapsedSeconds: 300,
            distanceMeters: 1500,
            butterBurnedTsp: 2.5
        )
        context.insert(draft)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<RunDraft>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.elapsedSeconds, 300)
        XCTAssertEqual(fetched.first?.butterBurnedTsp, 2.5)
    }

    func test_deleteAllData() throws {
        context.insert(Run(startDate: .now))
        context.insert(UserProfile(displayName: "Test", weightKg: 70))
        context.insert(Achievement(type: .teaspoonToast))
        try context.save()

        try context.delete(model: Run.self)
        try context.delete(model: UserProfile.self)
        try context.delete(model: Achievement.self)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Run>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<UserProfile>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Achievement>()).count, 0)
    }

    func test_runChurnResultPersistence() throws {
        let run = Run(startDate: .now)
        let result = ChurnResult(creamType: "heavy", creamCups: 1.0, finalStage: 3, finalProgress: 0.65, totalAgitation: 500.0)
        run.churnResultData = try JSONEncoder().encode(result)
        context.insert(run)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Run>())
        let decoded = fetched.first?.churnResult
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.finalStage, 3)
        XCTAssertEqual(decoded?.creamType, "heavy")
    }

    func test_manualEntryFlag() throws {
        let run = Run(startDate: .now)
        run.isManualEntry = true
        context.insert(run)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Run>())
        XCTAssertTrue(fetched.first?.isManualEntry ?? false)
    }
}
