import SwiftUI
import SwiftData
import AVFoundation

private let fallbackURL = URL(string: "https://example.com")!

struct SettingsView: View {
    @Query private var profiles: [UserProfile]
    @Query private var runs: [Run]
    @Environment(\.modelContext) private var modelContext

    private var profile: UserProfile? { profiles.first }

    @State private var displayName: String = ""
    @State private var weightKg: Double = 70.0
    @State private var previousWeightKg: Double = 70.0
    @State private var weightDisplay: Double = 154.0
    @State private var weightUnitSetting: String = "lbs"
    @State private var usesMiles: Bool = true
    @State private var voiceFeedback: Bool = true
    @State private var autoPause: Bool = true
    @State private var healthKit: Bool = false
    @State private var loaded = false
    @State private var showDeleteConfirmation = false
    @State private var showRecalcConfirmation = false
    @State private var weightDebounceTask: Task<Void, Never>?
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @EnvironmentObject private var stravaAuth: StravaAuthService
    @State private var autoShareToStrava: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $displayName)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(ButterTheme.textPrimary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Weight")
                                .foregroundStyle(ButterTheme.textPrimary)
                            InfoButton(title: "Why weight?", bodyText: "Heavier runners burn more per mile. Include pack weight for accuracy.")
                            Spacer()
                            TextField("0", value: $weightDisplay, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .keyboardType(.decimalPad)
                            Picker("", selection: $weightUnitSetting) {
                                Text("lbs").tag("lbs")
                                Text("kg").tag("kg")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 100)
                        }
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
                    HStack {
                        Toggle("Voice Feedback", isOn: $voiceFeedback)
                            .tint(ButterTheme.gold)
                        if voiceFeedback {
                            Button {
                                previewVoice()
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(ButterTheme.gold)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel("Preview voice feedback")
                        }
                    }
                    Toggle("Auto-Pause", isOn: $autoPause)
                        .tint(ButterTheme.gold)
                }
                .listRowBackground(ButterTheme.surface)

                Section("Integrations") {
                    // Apple Health
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Health")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(ButterTheme.textPrimary)
                            Text("Sync workouts & calories")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(ButterTheme.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $healthKit)
                            .tint(ButterTheme.gold)
                            .labelsHidden()
                    }

                    // Garmin
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Garmin")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(ButterTheme.textPrimary)
                            Text("Coming Soon")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(ButterTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .opacity(0.5)
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
                    Text("Strava")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    infoRow("1 pat butter", "34 calories")
                    infoRow("1 tbsp butter", "102 calories")
                    infoRow("1 stick butter", "810 calories")
                    infoRow("1 lb butter", "3,240 calories")
                } header: {
                    butterMathHeader
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

                    Link("National Eating Disorders Association", destination: URL(string: "https://www.nationaleatingdisorders.org") ?? fallbackURL)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(ButterTheme.gold)
                }
                .listRowBackground(ButterTheme.surface)

                Section("About") {
                    HStack {
                        Text("Version")
                            .foregroundStyle(ButterTheme.textPrimary)
                        Spacer()
                        Text(Bundle.main.appVersion)
                            .foregroundStyle(ButterTheme.textSecondary)
                    }

                    Link("Privacy Policy", destination: URL(string: "https://github.com/ysakols/butter-run/blob/main/PRIVACY_POLICY.md") ?? fallbackURL)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(ButterTheme.gold)

                    Link("Terms of Service", destination: URL(string: "https://github.com/ysakols/butter-run/blob/main/TERMS_OF_SERVICE.md") ?? fallbackURL)
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
            .onChange(of: weightDisplay) { _, _ in
                // Convert display value to kg for internal tracking
                if weightUnitSetting == "lbs" {
                    weightKg = weightDisplay / 2.20462
                } else {
                    weightKg = weightDisplay
                }
                saveProfile()
                // Debounce recalculation prompt to avoid firing on every keystroke
                weightDebounceTask?.cancel()
                if loaded && !runs.isEmpty {
                    weightDebounceTask = Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        guard !Task.isCancelled else { return }
                        if abs(weightKg - previousWeightKg) > 0.1 {
                            showRecalcConfirmation = true
                        }
                    }
                }
            }
            .onChange(of: weightUnitSetting) { oldUnit, newUnit in
                if oldUnit == "kg" && newUnit == "lbs" {
                    weightDisplay = weightDisplay * 2.20462
                } else if oldUnit == "lbs" && newUnit == "kg" {
                    weightDisplay = weightDisplay / 2.20462
                }
                saveProfile()
            }
            .onChange(of: usesMiles) { _, _ in saveProfile() }
            .onChange(of: voiceFeedback) { _, _ in saveProfile() }
            .onChange(of: autoPause) { _, _ in saveProfile() }
            .onChange(of: healthKit) { _, enabled in
                if enabled {
                    Task {
                        let service = HealthKitService()
                        let authorized = await service.requestAuthorization()
                        if authorized {
                            saveProfile()
                        } else {
                            healthKit = false
                        }
                    }
                } else {
                    saveProfile()
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

    private var butterMathHeader: some View {
        HStack(spacing: 4) {
            Text("Butter Math")
            InfoButton(title: "What's a pat?", bodyText: "≈ 1 tsp of butter (~34 cals). A fun way to track energy burned.")
        }
    }

    private func loadProfile() {
        guard !loaded, let p = profile else { return }
        displayName = p.displayName
        weightKg = p.weightKg
        previousWeightKg = p.weightKg
        weightUnitSetting = p.weightUnit
        if weightUnitSetting == "lbs" {
            weightDisplay = p.weightKg * 2.20462
        } else {
            weightDisplay = p.weightKg
        }
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
        if weightUnitSetting == "lbs" {
            p.weightKg = max(1.0, weightDisplay / 2.20462)
        } else {
            p.weightKg = max(1.0, weightDisplay)
        }
        weightKg = p.weightKg
        p.weightUnit = weightUnitSetting
        p.preferredUnit = usesMiles ? "miles" : "kilometers"
        p.splitDistance = usesMiles ? "mile" : "kilometer"
        p.voiceFeedbackEnabled = voiceFeedback
        p.autoPauseEnabled = autoPause
        p.healthKitEnabled = healthKit
        p.autoShareToStrava = autoShareToStrava
    }

    private func previewVoice() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: "Half a pat of butter burned. Keep going!")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = 0.8
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(utterance)
    }

    private func deleteAllData() {
        stravaAuth.disconnect()
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
