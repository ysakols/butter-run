import SwiftUI
import SwiftData

// MARK: - Schema Versioning
//
// NOTE: All versions reference the current model types rather than version-specific
// nested types. This is sufficient because all migrations are lightweight (adding
// optional fields or new models with defaults). SwiftData detects schema changes by
// comparing the on-disk SQLite columns against the current model, not the Swift types.
// If a future migration requires custom data transformation, the affected version(s)
// must define nested model types capturing the "from" schema shape.

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

enum SchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)
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
    static var schemas: [any VersionedSchema.Type] = [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self]
    static var stages: [MigrationStage] = [
        .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
        .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
        .lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self)
    ]
}

// MARK: - App

@main
struct ButterRunApp: App {
    @StateObject private var stravaAuth = StravaAuthService()
    let container: ModelContainer
    let containerError: Error?

    init() {
        // Install lightweight crash handlers before anything else
        CrashReportService.install()

        #if DEBUG
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--reset-state")
        #else
        let isUITesting = false
        #endif

        // Reset UserDefaults during UI testing so @AppStorage values
        // (e.g. tosAcceptedVersion) don't leak between test runs or
        // block tests on fresh simulators with the ToS acceptance screen.
        if isUITesting {
            if let bundleId = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
            }
        }

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
    private let skipTos = ProcessInfo.processInfo.arguments.contains("--skip-tos")
    #else
    private let skipOnboarding = false
    private let skipTos = false
    #endif
    @AppStorage("tosAcceptedVersion") private var tosAcceptedVersion: String = ""

    // Crash report state
    @State private var showCrashReportAlert = false
    @State private var showCrashMailComposer = false
    @State private var pendingCrashReport: String?
    @State private var showCopiedToast = false

    /// Increment this when the ToS changes materially to re-trigger acceptance.
    private static let currentTosVersion = "2026-04-07-v2"

    var body: some View {
        Group {
            if !skipTos && tosAcceptedVersion != Self.currentTosVersion {
                LegalAcceptanceView {
                    tosAcceptedVersion = Self.currentTosVersion
                }
            } else if profiles.isEmpty && !skipOnboarding {
                OnboardingWalkthroughView()
            } else {
                CrashRecoveryWrapper {
                    MainTabView()
                }
                .alert("Crash Report", isPresented: $showCrashReportAlert) {
                    if CrashReportMailView.canSendMail {
                        Button("Send Report") {
                            showCrashMailComposer = true
                        }
                    } else {
                        Button("Copy to Clipboard") {
                            if let report = pendingCrashReport {
                                UIPasteboard.general.string = report
                                showCopiedToast = true
                            }
                            CrashReportService.deletePendingReport()
                            pendingCrashReport = nil
                        }
                    }
                    Button("Dismiss", role: .cancel) {
                        CrashReportService.deletePendingReport()
                        pendingCrashReport = nil
                    }
                } message: {
                    if CrashReportMailView.canSendMail {
                        Text("Butter Run encountered an issue last time. Would you like to send a report?")
                    } else {
                        Text("Butter Run encountered an issue last time. Would you like to copy the report to your clipboard?")
                    }
                }
                .sheet(isPresented: $showCrashMailComposer) {
                    if let report = pendingCrashReport {
                        CrashReportMailView(reportText: report) {
                            CrashReportService.deletePendingReport()
                            pendingCrashReport = nil
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    if showCopiedToast {
                        ToastView(
                            text: "Crash report copied to clipboard",
                            autoDismissSeconds: 2.5,
                            isPresented: $showCopiedToast
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, ButterSpacing.tabBarHeight + 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .onAppear {
            // UI testing: auto-accept ToS when skipping
            if skipTos && tosAcceptedVersion != Self.currentTosVersion {
                tosAcceptedVersion = Self.currentTosVersion
            }

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
            let service = RunDraftService(context: modelContext)
            service.purgeStale()

            // Check for a crash report from a previous session (guard against re-trigger)
            if pendingCrashReport == nil, let report = CrashReportService.pendingReport() {
                pendingCrashReport = report
                showCrashReportAlert = true
            }
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
        let service = RunDraftService(context: modelContext)
        if let draft = service.loadDraft() {
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
        let service = RunDraftService(context: modelContext)
        service.deleteDraft()
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

// MARK: - Legal Acceptance Flow

/// Two-step acceptance: user must scroll through and accept both ToS and Privacy Policy
/// before any data is collected or onboarding begins.
struct LegalAcceptanceView: View {
    let onAccept: () -> Void
    @State private var tosAccepted = false
    @State private var privacyAccepted = false

    var body: some View {
        if !tosAccepted {
            ScrollableDocumentView(
                title: "Terms of Service",
                icon: "doc.text",
                text: LegalText.termsOfService,
                buttonLabel: "I Accept the Terms of Service",
                stepLabel: "Step 1 of 2"
            ) {
                tosAccepted = true
            }
            .id("tos") // Force fresh view identity so @State resets between steps
        } else if !privacyAccepted {
            ScrollableDocumentView(
                title: "Privacy Policy",
                icon: "hand.raised",
                text: LegalText.privacyPolicy,
                buttonLabel: "I Accept the Privacy Policy",
                stepLabel: "Step 2 of 2"
            ) {
                privacyAccepted = true
                // Log consent locally
                UserDefaults.standard.set(Date().ISO8601Format(), forKey: "tosConsentTimestamp")
                UserDefaults.standard.set(Bundle.main.appVersion, forKey: "tosConsentAppVersion")
                onAccept()
            }
            .id("privacy") // Distinct identity ensures hasScrolledToBottom resets
        }
    }
}

/// A scrollable full-text document view. The accept button only becomes enabled
/// once the user has scrolled near the bottom of the document.
struct ScrollableDocumentView: View {
    let title: String
    let icon: String
    let text: String
    let buttonLabel: String
    let stepLabel: String
    let onAccept: () -> Void

    @State private var hasScrolledToBottom = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(ButterTheme.gold)
                    Text(title)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(ButterTheme.textPrimary)
                }
                Text(stepLabel)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Scrollable document text
            GeometryReader { outerGeo in
                ScrollView {
                    Text(text)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(ButterTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)

                    // Invisible marker at the bottom to detect scroll position
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ScrollBottomPreferenceKey.self, value: geo.frame(in: .named("scroll")).maxY)
                    }
                    .frame(height: 1)
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollBottomPreferenceKey.self) { maxY in
                    if maxY < outerGeo.size.height + 100 {
                        hasScrolledToBottom = true
                    }
                }
            }
            .background(ButterTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)

            // Accept button
            VStack(spacing: 6) {
                if !hasScrolledToBottom {
                    Text("Please scroll to the bottom to continue")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
                }

                Button(action: onAccept) {
                    Text(buttonLabel)
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(ButterTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            hasScrolledToBottom ? ButterTheme.gold : ButterTheme.gold.opacity(0.3),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                }
                .disabled(!hasScrolledToBottom)
                .padding(.horizontal, 16)
            }
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(ButterTheme.background.ignoresSafeArea())
        .preferredColorScheme(.light)
    }
}

private struct ScrollBottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

