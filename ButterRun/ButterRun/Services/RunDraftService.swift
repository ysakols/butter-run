import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.butterrun", category: "RunDraftService")

class RunDraftService {
    private let container: ModelContainer
    /// Persistent context for draft saves. Must only be accessed from the main thread.
    private var persistentContext: ModelContext?

    init(container: ModelContainer) {
        self.container = container
    }

    /// Save a draft checkpoint. Uses a persistent ModelContext (main-thread only).
    func saveDraft(
        startDate: Date,
        elapsedSeconds: Double,
        pausedDuration: Double,
        distanceMeters: Double,
        butterBurnedTsp: Double,
        butterEatenTsp: Double,
        isButterZeroChallenge: Bool,
        routeData: Data?,
        butterEntriesData: Data?
    ) {
        if persistentContext == nil {
            persistentContext = ModelContext(container)
        }
        guard let context = persistentContext else { return }

        // Delete any existing draft first (only one at a time)
        let descriptor = FetchDescriptor<RunDraft>()
        if let existing = try? context.fetch(descriptor) {
            for draft in existing {
                context.delete(draft)
            }
        }

        let draft = RunDraft(
            startDate: startDate,
            elapsedSeconds: elapsedSeconds,
            pausedDuration: pausedDuration,
            distanceMeters: distanceMeters,
            butterBurnedTsp: butterBurnedTsp,
            butterEatenTsp: butterEatenTsp,
            isButterZeroChallenge: isButterZeroChallenge,
            routePointsData: routeData,
            butterEntriesData: butterEntriesData
        )

        context.insert(draft)
        do {
            try context.save()
        } catch {
            logger.error("Failed to save run draft: \(error, privacy: .public)")
        }
    }

    /// Load an existing draft (on main context for UI).
    func loadDraft(context: ModelContext) -> RunDraft? {
        do {
            let descriptor = FetchDescriptor<RunDraft>()
            return try context.fetch(descriptor).first
        } catch {
            logger.error("Failed to load run draft: \(error, privacy: .public)")
            return nil
        }
    }

    /// Delete all drafts.
    func deleteDraft(context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<RunDraft>()
            let drafts = try context.fetch(descriptor)
            for draft in drafts {
                context.delete(draft)
            }
            try context.save()
        } catch {
            logger.error("Failed to delete run draft: \(error, privacy: .public)")
        }
    }

    /// Auto-purge drafts older than 48 hours.
    func purgeStale(context: ModelContext) {
        let cutoff = Date().addingTimeInterval(-48 * 60 * 60)
        do {
            let descriptor = FetchDescriptor<RunDraft>()
            let drafts = try context.fetch(descriptor)
            for draft in drafts where draft.lastCheckpoint < cutoff {
                context.delete(draft)
            }
            try context.save()
        } catch {
            logger.error("Failed to purge stale drafts: \(error, privacy: .public)")
        }
    }
}
