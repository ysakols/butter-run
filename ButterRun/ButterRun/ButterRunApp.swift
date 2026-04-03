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
            let config = ModelConfiguration(schema: schema)
            container = try ModelContainer(
                for: schema,
                migrationPlan: ButterRunMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
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
                Button("Discard", role: .destructive) {
                    discardDraft()
                }
                Button("OK") {
                    // For now, just dismiss — resume could be added later
                    discardDraft()
                }
            } message: {
                if let draft = recoveredDraft {
                    let duration = ButterFormatters.duration(draft.elapsedSeconds)
                    Text("You have an unfinished run from \(draft.startDate.formatted(date: .abbreviated, time: .shortened)) (\(duration)). This draft will be discarded.")
                } else {
                    Text("You have an unfinished run.")
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
