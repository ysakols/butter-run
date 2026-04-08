import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.butterrun", category: "RunDraftService")

/// Thread safety: all methods must be called from the main thread.
/// ModelContext is not thread-safe; callers are responsible for main-thread dispatch.
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
        dispatchPrecondition(condition: .onQueue(.main))
        if persistentContext == nil {
            persistentContext = ModelContext(container)
        }
        guard let context = persistentContext else { return }

        // Delete any existing draft first (only one at a time)
        try? context.delete(model: RunDraft.self)

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
        dispatchPrecondition(condition: .onQueue(.main))
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
        dispatchPrecondition(condition: .onQueue(.main))
        do {
            try context.delete(model: RunDraft.self)
            try context.save()
        } catch {
            logger.error("Failed to delete run draft: \(error, privacy: .public)")
        }
    }

    /// Auto-purge drafts older than 48 hours.
    func purgeStale(context: ModelContext) {
        dispatchPrecondition(condition: .onQueue(.main))
        let cutoff = Date().addingTimeInterval(-48 * 60 * 60)
        do {
            try context.delete(model: RunDraft.self, where: #Predicate<RunDraft> {
                $0.lastCheckpoint < cutoff
            })
            try context.save()
        } catch {
            logger.error("Failed to purge stale drafts: \(error, privacy: .public)")
        }
    }
}
