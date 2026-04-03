import XCTest
import SwiftData
@testable import ButterRun

final class RunDraftServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var service: RunDraftService!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Run.self, Split.self, ButterEntry.self, UserProfile.self, Achievement.self, RunDraft.self,
            configurations: config
        )
        context = ModelContext(container)
        service = RunDraftService(container: container)
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

        // Need a fresh context to see background writes
        let freshContext = ModelContext(container)
        let drafts = try freshContext.fetch(FetchDescriptor<RunDraft>())
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

        let freshContext = ModelContext(container)
        let draft = service.loadDraft(context: freshContext)
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

        let freshContext = ModelContext(container)
        service.deleteDraft(context: freshContext)

        let drafts = try freshContext.fetch(FetchDescriptor<RunDraft>())
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

        let freshContext = ModelContext(container)
        let drafts = try freshContext.fetch(FetchDescriptor<RunDraft>())
        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts.first?.elapsedSeconds, 200)
    }

    func test_purgeStale_removes48hOldDrafts() throws {
        // Insert a draft with old checkpoint
        let draft = RunDraft(startDate: .now, elapsedSeconds: 100)
        draft.lastCheckpoint = Date().addingTimeInterval(-49 * 60 * 60) // 49 hours ago
        context.insert(draft)
        try context.save()

        service.purgeStale(context: context)

        let drafts = try context.fetch(FetchDescriptor<RunDraft>())
        XCTAssertEqual(drafts.count, 0)
    }

    func test_purgeStale_keepsRecentDrafts() throws {
        let draft = RunDraft(startDate: .now, elapsedSeconds: 100)
        draft.lastCheckpoint = Date() // Fresh
        context.insert(draft)
        try context.save()

        service.purgeStale(context: context)

        let drafts = try context.fetch(FetchDescriptor<RunDraft>())
        XCTAssertEqual(drafts.count, 1)
    }
}
