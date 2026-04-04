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

enum ButterRunMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [SchemaV1.self, SchemaV2.self]
    static var stages: [MigrationStage] = [
        .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
    ]
}

// MARK: - App

@main
struct ButterRunApp: App {
    let container: ModelContainer
    let containerError: Error?

    init() {
        do {
            let schema = Schema([
                Run.self,
                Split.self,
                ButterEntry.self,
                UserProfile.self,
                Achievement.self,
                RunDraft.self,
            ])
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            container = try ModelContainer(
                for: schema,
                migrationPlan: ButterRunMigrationPlan.self,
                configurations: [config]
            )
            containerError = nil
        } catch {
            // Fallback: create an in-memory container so the app can launch
            containerError = error
            container = try! ModelContainer(
                for: Schema([Run.self, Split.self, ButterEntry.self, UserProfile.self, Achievement.self, RunDraft.self]),
                configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            if let error = containerError {
                DatabaseErrorView(error: error)
            } else {
                ContentView()
            }
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

    var body: some View {
        Group {
            if profiles.isEmpty {
                OnboardingView()
            } else {
                CrashRecoveryWrapper {
                    MainTabView()
                }
            }
        }
        .onAppear {
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

        // Decode and attach butter entries from draft
        if let entriesData = draft.butterEntriesData {
            struct EntrySnapshot: Codable {
                let servingRaw: String
                let tsp: Double
                let timestamp: Date
            }
            if let snapshots = try? JSONDecoder().decode([EntrySnapshot].self, from: entriesData) {
                let entries = snapshots.map { snapshot -> ButterEntry in
                    // Use .custom with the snapshot's exact tsp value to preserve
                    // the recorded amount regardless of serving enum changes
                    let entry = ButterEntry(serving: .custom, customTeaspoons: snapshot.tsp)
                    return entry
                }
                run.butterEntries = entries
            }
        }

        modelContext.insert(run)
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

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(ButterTheme.gold)
    }
}

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var weightKg: Double = 70.0
    @State private var displayName: String = ""
    @State private var useMiles: Bool = Locale.current.measurementSystem == .us
    @State private var weightError: String?

    private var isFormValid: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty && weightKg > 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image("butter-pat")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .accessibilityHidden(true)

                Text("Butter Run")
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .foregroundStyle(ButterTheme.gold)

                Text("Run it off. One pat at a time.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)

                VStack(spacing: 16) {
                    TextField("Your name", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .rounded))
                        .accessibilityLabel("Your name")

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Weight")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(ButterTheme.textPrimary)
                            Spacer()
                            TextField("kg", value: $weightKg, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .keyboardType(.decimalPad)
                                .accessibilityLabel("Weight in kilograms")
                                .onChange(of: weightKg) { _, newValue in
                                    if newValue <= 0 {
                                        weightError = "Weight must be greater than zero"
                                    } else {
                                        weightError = nil
                                    }
                                }
                            Text("kg")
                                .foregroundStyle(ButterTheme.textSecondary)
                        }

                        if let error = weightError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(ButterTheme.deficit)
                        }
                    }

                    Picker("Units", selection: $useMiles) {
                        Text("Miles").tag(true)
                        Text("Kilometers").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 32)

                Spacer()

                Button(action: createProfile) {
                    Text("Let's Churn")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(ButterTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ButterTheme.gold, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
                .disabled(!isFormValid)
                .opacity(isFormValid ? 1.0 : 0.5)

                Spacer().frame(height: 40)
            }
            .background(ButterTheme.background.ignoresSafeArea())
        }
        .preferredColorScheme(.dark)
    }

    private func createProfile() {
        guard weightKg > 0 else { return }
        let profile = UserProfile(
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            weightKg: weightKg,
            preferredUnit: useMiles ? "miles" : "kilometers",
            voiceFeedbackEnabled: true,
            splitDistance: useMiles ? "mile" : "kilometer"
        )
        modelContext.insert(profile)
    }
}
