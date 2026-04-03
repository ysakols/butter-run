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
                    Toggle("HealthKit", isOn: $healthKit)
                        .tint(ButterTheme.gold)
                }
                .listRowBackground(ButterTheme.surface)

                Section("Butter Math") {
                    infoRow("1 tsp butter", "34 calories")
                    infoRow("1 tbsp butter", "102 calories")
                    infoRow("1 stick butter", "810 calories")
                    infoRow("1 lb butter", "3,240 calories")
                }
                .listRowBackground(ButterTheme.surface)

                Section {
                    Text("Calorie estimates are approximate and for entertainment purposes. Actual calories burned depend on many factors including metabolism, body composition, terrain, and weather.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
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
            .onChange(of: healthKit) { _, newValue in
                saveProfile()
                if newValue {
                    Task {
                        let service = HealthKitService()
                        _ = await service.requestAuthorization()
                    }
                }
            }
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
        loaded = true
    }

    private func saveProfile() {
        guard loaded, let p = profile else { return }
        p.displayName = displayName
        p.weightKg = weightKg
        p.preferredUnit = usesMiles ? "miles" : "kilometers"
        p.splitDistance = usesMiles ? "mile" : "kilometer"
        p.voiceFeedbackEnabled = voiceFeedback
        p.autoPauseEnabled = autoPause
        p.healthKitEnabled = healthKit
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
        for run in runs {
            let durationMinutes = run.durationSeconds / 60.0
            let speedMps = run.distanceMeters > 0 ? run.distanceMeters / run.durationSeconds : 0
            let speedMph = ButterCalculator.metersPerSecondToMph(speedMps)
            let met = ButterCalculator.metValue(forSpeedMph: speedMph)
            let calories = ButterCalculator.caloriesBurned(
                weightKg: weightKg,
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
