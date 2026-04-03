import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext

    private var profile: UserProfile? { profiles.first }

    @State private var displayName: String = ""
    @State private var weightKg: Double = 70.0
    @State private var usesMiles: Bool = true
    @State private var voiceFeedback: Bool = true
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $displayName)
                        .font(.system(.body, design: .rounded))

                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("kg", value: $weightKg, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .keyboardType(.decimalPad)
                        Text("kg")
                            .foregroundStyle(ButterTheme.textSecondary)
                    }
                }

                Section("Units") {
                    Picker("Distance", selection: $usesMiles) {
                        Text("Miles").tag(true)
                        Text("Kilometers").tag(false)
                    }
                }

                Section("Run Settings") {
                    Toggle("Voice Feedback", isOn: $voiceFeedback)
                        .tint(ButterTheme.primary)
                }

                Section("Butter Math") {
                    infoRow("1 tsp butter", "34 calories")
                    infoRow("1 tbsp butter", "102 calories")
                    infoRow("1 stick butter", "810 calories")
                    infoRow("1 lb butter", "3,240 calories")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(ButterTheme.textSecondary)
                    }
                    HStack {
                        Text("")
                        Spacer()
                        Text("Made with 🧈")
                            .foregroundStyle(ButterTheme.textSecondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(ButterTheme.background.ignoresSafeArea())
            .onAppear { loadProfile() }
            .onChange(of: displayName) { _, _ in saveProfile() }
            .onChange(of: weightKg) { _, _ in saveProfile() }
            .onChange(of: usesMiles) { _, _ in saveProfile() }
            .onChange(of: voiceFeedback) { _, _ in saveProfile() }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.body, design: .rounded))
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
        usesMiles = p.usesMiles
        voiceFeedback = p.voiceFeedbackEnabled
        loaded = true
    }

    private func saveProfile() {
        guard loaded, let p = profile else { return }
        p.displayName = displayName
        p.weightKg = weightKg
        p.preferredUnit = usesMiles ? "miles" : "kilometers"
        p.splitDistance = usesMiles ? "mile" : "kilometer"
        p.voiceFeedbackEnabled = voiceFeedback
    }
}
