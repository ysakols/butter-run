import SwiftUI
import SwiftData

@main
struct ButterRunApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Run.self, UserProfile.self, Achievement.self])
    }
}

struct ContentView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        if profiles.isEmpty {
            OnboardingView()
        } else {
            MainTabView()
        }
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
        .tint(ButterTheme.primary)
    }
}

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var weightKg: Double = 70.0
    @State private var displayName: String = ""
    @State private var useMiles: Bool = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Text("🧈")
                    .font(.system(size: 80))

                Text("Butter Run")
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .foregroundStyle(ButterTheme.primary)

                Text("Track your runs in teaspoons of butter.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)

                VStack(spacing: 16) {
                    TextField("Your name", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .rounded))

                    HStack {
                        Text("Weight")
                            .font(.system(.body, design: .rounded))
                        Spacer()
                        TextField("kg", value: $weightKg, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .keyboardType(.decimalPad)
                        Text("kg")
                            .foregroundStyle(ButterTheme.textSecondary)
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
                    Text("Let's Churn!")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ButterTheme.primary, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
                .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer().frame(height: 40)
            }
            .background(ButterTheme.background)
        }
    }

    private func createProfile() {
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
