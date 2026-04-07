import SwiftUI
import SwiftData

// MARK: - Schema Versioning

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [
        Run.self,
        UserProfile.self,
        Split.self,
        ButterEntry.self,
        Achievement.self
    ]
}

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] = [
        Run.self,
        UserProfile.self,
        Split.self,
        ButterEntry.self,
        Achievement.self,
        RunDraft.self
    ]
}

enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] = [
        Run.self,
        UserProfile.self,
        Split.self,
        ButterEntry.self,
        Achievement.self,
        RunDraft.self
    ]
}

enum ButterRunMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    static var stages: [MigrationStage] = [
        .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
        .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self)
    ]
}

// MARK: - App

@main
struct ButterRunApp: App {
    @StateObject private var stravaAuth = StravaAuthService()
    let container: ModelContainer
    let containerError: Error?

    init() {
        #if DEBUG
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--reset-state")
        #else
        let isUITesting = false
        #endif

        do {
            let schema = Schema([
                Run.self,
                Split.self,
                ButterEntry.self,
                UserProfile.self,
                Achievement.self,
                RunDraft.self,
            ])
            let config: ModelConfiguration
            if isUITesting {
                config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            } else {
                config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            }
            container = try ModelContainer(
                for: schema,
                migrationPlan: isUITesting ? nil : ButterRunMigrationPlan.self,
                configurations: [config]
            )
            containerError = nil
        } catch {
            // Fallback: create an in-memory container so the app can launch
            containerError = error
            do {
                container = try ModelContainer(
                    for: Schema([Run.self, Split.self, ButterEntry.self, UserProfile.self, Achievement.self, RunDraft.self]),
                    configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
                )
            } catch {
                fatalError("Failed to create even an in-memory ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let error = containerError {
                    DatabaseErrorView(error: error)
                } else {
                    ContentView()
                        .environmentObject(stravaAuth)
                }
            }
            .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}

struct DatabaseErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Database Error")
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text("Butter Run couldn't load your data. Try deleting and reinstalling the app.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    #if DEBUG
    private let skipOnboarding = ProcessInfo.processInfo.arguments.contains("--skip-onboarding")
    #else
    private let skipOnboarding = false
    #endif
    @AppStorage("tosAcceptedVersion") private var tosAcceptedVersion: String = ""

    /// Increment this when the ToS changes materially to re-trigger acceptance.
    private static let currentTosVersion = "2026-04-07"

    var body: some View {
        Group {
            if profiles.isEmpty && !skipOnboarding {
                OnboardingWalkthroughView()
            } else if tosAcceptedVersion != Self.currentTosVersion {
                TermsAcceptanceView {
                    tosAcceptedVersion = Self.currentTosVersion
                }
            } else {
                CrashRecoveryWrapper {
                    MainTabView()
                }
            }
        }
        .onAppear {
            // UI testing: create a default profile when skipping onboarding
            if skipOnboarding && profiles.isEmpty {
                let profile = UserProfile(
                    displayName: "Test Runner",
                    weightKg: 70.0,
                    preferredUnit: "miles",
                    voiceFeedbackEnabled: false,
                    splitDistance: "mile"
                )
                modelContext.insert(profile)
            }

            // Enforce UserProfile singleton — delete duplicates if any
            if profiles.count > 1 {
                for extra in profiles.dropFirst() {
                    modelContext.delete(extra)
                }
            }

            // Purge stale drafts on launch
            let service = RunDraftService(container: modelContext.container)
            service.purgeStale(context: modelContext)
        }
    }
}

/// Shared snapshot type used to encode/decode butter entries in run drafts.
/// Used by both ActiveRunViewModel (encoder) and CrashRecoveryWrapper (decoder).
struct DraftEntrySnapshot: Codable {
    let servingRaw: String
    let tsp: Double
    let timestamp: Date
}

/// Checks for an unfinished run draft on app launch
struct CrashRecoveryWrapper<Content: View>: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showRecoveryPrompt = false
    @State private var recoveredDraft: RunDraft?
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .onAppear(perform: checkForDraft)
            .alert("Unfinished Run", isPresented: $showRecoveryPrompt) {
                Button("Save Run") {
                    saveAsManualRun()
                }
                Button("Discard", role: .destructive) {
                    discardDraft()
                }
            } message: {
                if let draft = recoveredDraft {
                    let duration = ButterFormatters.duration(draft.elapsedSeconds)
                    Text("You had an unfinished run from \(draft.startDate.formatted(date: .abbreviated, time: .shortened)) (\(duration)). Would you like to save it?")
                } else {
                    Text("You had an unfinished run that cannot be resumed.")
                }
            }
    }

    private func checkForDraft() {
        let service = RunDraftService(container: modelContext.container)
        if let draft = service.loadDraft(context: modelContext) {
            recoveredDraft = draft
            showRecoveryPrompt = true
        }
    }

    private func saveAsManualRun() {
        guard let draft = recoveredDraft else { return }

        let run = Run(startDate: draft.startDate, isButterZeroChallenge: draft.isButterZeroChallenge)
        run.endDate = draft.startDate.addingTimeInterval(draft.elapsedSeconds + draft.pausedDuration)
        run.distanceMeters = draft.distanceMeters
        run.durationSeconds = draft.elapsedSeconds
        run.totalButterBurnedTsp = draft.butterBurnedTsp
        run.totalButterEatenTsp = draft.butterEatenTsp
        run.netButterTsp = draft.butterEatenTsp - draft.butterBurnedTsp
        run.totalCaloriesBurned = draft.butterBurnedTsp * ButterCalculator.caloriesPerTeaspoon
        run.isManualEntry = true
        run.routePolyline = draft.routePointsData

        if draft.distanceMeters > 0 && draft.elapsedSeconds > 0 {
            run.averagePaceSecondsPerKm = draft.elapsedSeconds / (draft.distanceMeters / 1000.0)
        }

        // Decode and attach butter entries from draft, preserving original serving types and timestamps
        if let entriesData = draft.butterEntriesData {
            if let snapshots = try? JSONDecoder().decode([DraftEntrySnapshot].self, from: entriesData) {
                let entries = snapshots.map { snapshot -> ButterEntry in
                    let serving = ButterServing(rawValue: snapshot.servingRaw) ?? .custom
                    let entry = ButterEntry(serving: serving, customTeaspoons: serving == .custom ? snapshot.tsp : 0)
                    entry.timestamp = snapshot.timestamp
                    return entry
                }
                run.butterEntries = entries
            }
        }

        modelContext.insert(run)
        try? modelContext.save()
        discardDraft()
    }

    private func discardDraft() {
        let service = RunDraftService(container: modelContext.container)
        service.deleteDraft(context: modelContext)
        recoveredDraft = nil
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Run", systemImage: "figure.run")
                }

            RunHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            ChurnGuideView()
                .tabItem {
                    Label("Guide", systemImage: "book")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(ButterTheme.gold)
    }
}

// MARK: - Terms of Service Acceptance

struct TermsAcceptanceView: View {
    let onAccept: () -> Void

    private let tosURL = URL(string: "https://github.com/ysakols/butter-run/blob/main/TERMS_OF_SERVICE.md")!
    private let privacyURL = URL(string: "https://github.com/ysakols/butter-run/blob/main/PRIVACY_POLICY.md")!

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)

            Image("butter-pat")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .accessibilityHidden(true)

            Text("Terms of Service")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(ButterTheme.textPrimary)

            Text("Please review and accept our Terms of Service and Privacy Policy to continue using Butter Run.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Link(destination: tosURL) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Read Terms of Service")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(ButterTheme.gold)
                    .padding()
                    .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                }

                Link(destination: privacyURL) {
                    HStack {
                        Image(systemName: "hand.raised")
                        Text("Read Privacy Policy")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(ButterTheme.gold)
                    .padding()
                    .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 8) {
                Text("By tapping \"I Agree\" you confirm that you have read, understood, and agree to be bound by the Terms of Service and Privacy Policy.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button(action: onAccept) {
                    Text("I Agree")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(ButterTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ButterTheme.gold, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
            }

            Spacer().frame(height: 40)
        }
        .background(ButterTheme.background.ignoresSafeArea())
        .preferredColorScheme(.light)
    }
}
