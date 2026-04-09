import XCTest
import SwiftData
@testable import ButterRun

final class RunDraftServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var service: RunDraftService!

    @MainActor
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Run.self, Split.self, ButterEntry.self, UserProfile.self, Achievement.self, RunDraft.self,
            configurations: config
        )
        context = ModelContext(container)
        service = RunDraftService(context: context)
    }

    func test_saveDraft_createsRecord() throws {
        service.saveDraft(
            startDate: .now,
            elapsedSeconds: 120,
            pausedDuration: 0,
            distanceMeters: 500,
            butterBurnedTsp: 1.0,
            butterEatenTsp: 0,
            isButterZeroChallenge: false,
            routeData: nil,
            butterEntriesData: nil
        )

        let drafts = try context.fetch(FetchDescriptor<RunDraft>())
        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts.first?.elapsedSeconds, 120)
    }

    func test_loadDraft_afterSave() {
        service.saveDraft(
            startDate: .now,
            elapsedSeconds: 300,
            pausedDuration: 10,
            distanceMeters: 2000,
            butterBurnedTsp: 5.0,
            butterEatenTsp: 2.0,
            isButterZeroChallenge: true,
            routeData: nil,
            butterEntriesData: nil
        )

        let draft = service.loadDraft()
        XCTAssertNotNil(draft)
        XCTAssertEqual(draft?.elapsedSeconds, 300)
        XCTAssertTrue(draft?.isButterZeroChallenge ?? false)
    }

    func test_deleteDraft_removesRecord() throws {
        service.saveDraft(
            startDate: .now,
            elapsedSeconds: 60,
            pausedDuration: 0,
            distanceMeters: 100,
            butterBurnedTsp: 0.5,
            butterEatenTsp: 0,
            isButterZeroChallenge: false,
            routeData: nil,
            butterEntriesData: nil
        )

        service.deleteDraft()

        let drafts = try context.fetch(FetchDescriptor<RunDraft>())
        XCTAssertEqual(drafts.count, 0)
    }

    func test_saveDraft_overwritesPrevious() throws {
        service.saveDraft(
            startDate: .now, elapsedSeconds: 100, pausedDuration: 0,
            distanceMeters: 500, butterBurnedTsp: 1.0, butterEatenTsp: 0,
            isButterZeroChallenge: false, routeData: nil, butterEntriesData: nil
        )

        service.saveDraft(
            startDate: .now, elapsedSeconds: 200, pausedDuration: 0,
            distanceMeters: 1000, butterBurnedTsp: 2.0, butterEatenTsp: 0,
            isButterZeroChallenge: false, routeData: nil, butterEntriesData: nil
        )

        let drafts = try context.fetch(FetchDescriptor<RunDraft>())
        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts.first?.elapsedSeconds, 200)
    }

    func test_purgeStale_removes48hOldDrafts() throws {
        // Insert a draft with old checkpoint
        let draft = RunDraft(startDate: .now, elapsedSeconds: 100)
        draft.lastCheckpoint = Date().addingTimeInterval(-49 * 60 * 60) // 49 hours ago
        context.insert(draft)
        try context.save()

        service.purgeStale()

        let drafts = try context.fetch(FetchDescriptor<RunDraft>())
        XCTAssertEqual(drafts.count, 0)
    }

    func test_purgeStale_keepsRecentDrafts() throws {
        let draft = RunDraft(startDate: .now, elapsedSeconds: 100)
        draft.lastCheckpoint = Date() // Fresh
        context.insert(draft)
        try context.save()

        service.purgeStale()

        let drafts = try context.fetch(FetchDescriptor<RunDraft>())
        XCTAssertEqual(drafts.count, 1)
    }

    func test_purgeStale_selectiveDelete_keepsRecentRemovesOld() throws {
        // Insert a stale draft (49 hours old)
        let oldDraft = RunDraft(startDate: .now, elapsedSeconds: 50)
        oldDraft.lastCheckpoint = Date().addingTimeInterval(-49 * 60 * 60)
        context.insert(oldDraft)

        // Insert a recent draft
        let newDraft = RunDraft(startDate: .now, elapsedSeconds: 200)
        newDraft.lastCheckpoint = Date()
        context.insert(newDraft)
        try context.save()

        let beforeCount = try context.fetch(FetchDescriptor<RunDraft>()).count
        XCTAssertEqual(beforeCount, 2)

        service.purgeStale()

        let remaining = try context.fetch(FetchDescriptor<RunDraft>())
        XCTAssertEqual(remaining.count, 1, "Only the recent draft should survive purge")
        XCTAssertEqual(remaining.first?.elapsedSeconds, 200)
    }

    func test_batchDelete_removesAllDrafts() throws {
        // Insert multiple drafts directly
        context.insert(RunDraft(startDate: .now, elapsedSeconds: 10))
        context.insert(RunDraft(startDate: .now, elapsedSeconds: 20))
        context.insert(RunDraft(startDate: .now, elapsedSeconds: 30))
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<RunDraft>()).count, 3)

        service.deleteDraft()

        XCTAssertEqual(try context.fetch(FetchDescriptor<RunDraft>()).count, 0)
    }
}
