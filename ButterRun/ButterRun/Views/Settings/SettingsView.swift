import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var profiles: [UserProfile]
    @Query private var runs: [Run]
    @Environment(\.modelContext) private var modelContext

    private var profile: UserProfile? { profiles.first }

    @State private var displayName: String = ""
    @State private var weightKg: Double = 70.0
    @State private var previousWeightKg: Double = 70.0
    @State private var usesMiles: Bool = true
    @State private var voiceFeedback: Bool = true
    @State private var autoPause: Bool = true
    @State private var healthKit: Bool = false
    @State private var loaded = false
    @State private var showDeleteConfirmation = false
    @State private var showRecalcConfirmation = false
    @EnvironmentObject private var stravaAuth: StravaAuthService
    @State private var autoShareToStrava: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $displayName)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(ButterTheme.textPrimary)

                    HStack {
                        Text("Weight")
                            .foregroundStyle(ButterTheme.textPrimary)
                        Spacer()
                        TextField("kg", value: $weightKg, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .keyboardType(.decimalPad)
                        Text("kg")
                            .foregroundStyle(ButterTheme.textSecondary)
                    }
                }
                .listRowBackground(ButterTheme.surface)

                Section("Units") {
                    Picker("Distance", selection: $usesMiles) {
                        Text("Miles").tag(true)
                        Text("Kilometers").tag(false)
                    }
                }
                .listRowBackground(ButterTheme.surface)

                Section("Run Settings") {
                    Toggle("Voice Feedback", isOn: $voiceFeedback)
                        .tint(ButterTheme.gold)
                    Toggle("Auto-Pause", isOn: $autoPause)
                        .tint(ButterTheme.gold)
                    HStack {
                        Toggle("HealthKit", isOn: .constant(false))
                            .tint(ButterTheme.gold)
                            .disabled(true)
                        Text("Coming Soon")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(ButterTheme.textSecondary)
                    }
                }
                .listRowBackground(ButterTheme.surface)

                Section {
                    StravaIntegrationView(autoShareToStrava: $autoShareToStrava)
                        .onChange(of: autoShareToStrava) { _, _ in saveProfile() }
                        .onChange(of: stravaAuth.isAuthenticated) { _, connected in
                            if let p = profile {
                                p.stravaConnected = connected
                                if !connected {
                                    autoShareToStrava = false
                                    p.autoShareToStrava = false
                                }
                            }
                        }
                } header: {
                    Text("Integrations")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section("Butter Math") {
                    infoRow("1 tsp butter", "34 calories")
                    infoRow("1 tbsp butter", "102 calories")
                    infoRow("1 stick butter", "810 calories")
                    infoRow("1 lb butter", "3,240 calories")
                }
                .listRowBackground(ButterTheme.surface)

                Section {
                    Text("Estimates are approximate, based on pace and body weight. Actual calories burned depend on many factors including metabolism, body composition, terrain, and weather.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
                }
                .listRowBackground(ButterTheme.surface)

                Section("Health & Wellness Resources") {
                    Text("If you or someone you know is struggling with an eating disorder, please reach out for help.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)

                    Link("National Eating Disorders Association", destination: URL(string: "https://www.nationaleatingdisorders.org") ?? URL(string: "about:blank")!)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(ButterTheme.gold)
                }
                .listRowBackground(ButterTheme.surface)

                Section("About") {
                    HStack {
                        Text("Version")
                            .foregroundStyle(ButterTheme.textPrimary)
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(ButterTheme.textSecondary)
                    }

                    Link("Privacy Policy", destination: URL(string: "https://butterrun.app/privacy") ?? URL(string: "about:blank")!)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(ButterTheme.gold)
                }
                .listRowBackground(ButterTheme.surface)

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete All My Data")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                            Spacer()
                        }
                    }
                }
                .listRowBackground(ButterTheme.deficit.opacity(0.15))
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(ButterTheme.background.ignoresSafeArea())
            .onAppear { loadProfile() }
            .onChange(of: displayName) { _, _ in saveProfile() }
            .onChange(of: weightKg) { _, newWeight in
                saveProfile()
                if loaded && abs(newWeight - previousWeightKg) > 0.1 && !runs.isEmpty {
                    showRecalcConfirmation = true
                }
            }
            .onChange(of: usesMiles) { _, _ in saveProfile() }
            .onChange(of: voiceFeedback) { _, _ in saveProfile() }
            .onChange(of: autoPause) { _, _ in saveProfile() }

            .confirmationDialog(
                "Delete All Data?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your runs, achievements, and profile. This cannot be undone.")
            }
            .alert("Recalculate Past Runs?", isPresented: $showRecalcConfirmation) {
                Button("Recalculate") {
                    recalculateRuns()
                    previousWeightKg = weightKg
                }
                Button("Skip") {
                    previousWeightKg = weightKg
                }
            } message: {
                Text("Your weight changed. Would you like to recalculate butter burned for all past runs with your new weight?")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(ButterTheme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)
        }
    }

    private func loadProfile() {
        guard !loaded, let p = profile else { return }
        displayName = p.displayName
        weightKg = p.weightKg
        previousWeightKg = p.weightKg
        usesMiles = p.usesMiles
        voiceFeedback = p.voiceFeedbackEnabled
        autoPause = p.autoPauseEnabled
        healthKit = p.healthKitEnabled
        autoShareToStrava = p.autoShareToStrava
        loaded = true
    }

    private func saveProfile() {
        guard loaded, let p = profile else { return }
        p.displayName = displayName
        p.weightKg = max(1.0, weightKg)
        p.preferredUnit = usesMiles ? "miles" : "kilometers"
        p.splitDistance = usesMiles ? "mile" : "kilometer"
        p.voiceFeedbackEnabled = voiceFeedback
        p.autoPauseEnabled = autoPause
        p.healthKitEnabled = healthKit
        p.autoShareToStrava = autoShareToStrava
    }

    private func deleteAllData() {
        do {
            try modelContext.delete(model: Run.self)
            try modelContext.delete(model: Achievement.self)
            try modelContext.delete(model: RunDraft.self)
            try modelContext.delete(model: UserProfile.self)
            try modelContext.save()
        } catch {
            // Deletion failed; user can retry
        }
    }

    private func recalculateRuns() {
        let validatedWeight = max(1.0, weightKg)
        for run in runs {
            guard run.durationSeconds > 0 else { continue }
            let durationMinutes = run.durationSeconds / 60.0
            let speedMps = run.distanceMeters > 0 ? run.distanceMeters / run.durationSeconds : 0
            let speedMph = ButterCalculator.metersPerSecondToMph(speedMps)
            let met = ButterCalculator.metValue(forSpeedMph: speedMph)
            let calories = ButterCalculator.caloriesBurned(
                weightKg: validatedWeight,
                met: met,
                durationMinutes: durationMinutes
            )
            run.totalCaloriesBurned = calories
            run.totalButterBurnedTsp = ButterCalculator.caloriesToButterTsp(calories)
            run.netButterTsp = run.totalButterEatenTsp - run.totalButterBurnedTsp
        }
        try? modelContext.save()
    }
}
