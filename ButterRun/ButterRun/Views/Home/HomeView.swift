import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Run.startDate, order: .reverse) private var runs: [Run]
    @Query private var profiles: [UserProfile]
    @State private var viewModel = HomeViewModel()
    @State private var showActiveRun = false
    @State private var isButterZero = false
    @State private var isChurnEnabled = false
    @State private var showChurnSetup = false
    @State private var churnConfig: ChurnConfiguration?
    @State private var locationService = LocationService()

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ZStack {
                ButterTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Greeting
                    if let name = profile?.displayName {
                        Text("Hey, \(name)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(ButterTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }

                    // Weekly summary card
                    WeeklyButterCard(
                        weeklyTsp: viewModel.weeklyButterTsp,
                        totalRuns: viewModel.totalRuns,
                        lastRunSummary: viewModel.lastRunSummary
                    )
                    .padding(.horizontal)

                    Spacer()

                    // Butter Zero toggle
                    VStack(spacing: 12) {
                        Toggle(isOn: $isButterZero) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Butter Zero")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                    .foregroundStyle(ButterTheme.textPrimary)
                                Text("Eat butter mid-run. Try to net zero.")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(ButterTheme.textSecondary)
                            }
                        }
                        .tint(ButterTheme.gold)
                        .accessibilityLabel("Butter Zero mode")

                        Toggle(isOn: $isChurnEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Churn Tracker")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                    .foregroundStyle(ButterTheme.textPrimary)
                                Text("Track butter-churning progress with cream in your pack.")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(ButterTheme.textSecondary)
                            }
                        }
                        .tint(ButterTheme.gold)
                        .accessibilityLabel("Churn tracker mode")
                    }
                    .padding(.horizontal, 24)

                    // CHURN button
                    ChurnButton {
                        if isChurnEnabled {
                            showChurnSetup = true
                        } else {
                            showActiveRun = true
                        }
                    }
                    .padding(.bottom, 8)
                    .accessibilityLabel(isChurnEnabled ? "Set up churn tracker" : "Start run")

                    // Butter trivia
                    Text(ButterFacts.random)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 16)
                }
                .padding(.top)
            }
            .navigationTitle("")
            .fullScreenCover(isPresented: $showActiveRun, onDismiss: {
                churnConfig = nil
            }) {
                ActiveRunView(
                    isButterZeroChallenge: isButterZero,
                    isChurnEnabled: isChurnEnabled,
                    churnConfig: churnConfig,
                    profile: profile ?? UserProfile(displayName: "Runner", weightKg: 70)
                )
            }
            .sheet(isPresented: $showChurnSetup) {
                ChurnSetupSheet { config in
                    churnConfig = config
                    showChurnSetup = false
                    // Small delay to allow sheet dismissal before full screen cover
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showActiveRun = true
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.load(runs: runs, usesMiles: profile?.usesMiles ?? true)
            locationService.requestPermission()
        }
    }
}

struct WeeklyButterCard: View {
    let weeklyTsp: Double
    let totalRuns: Int
    let lastRunSummary: String?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("This Week")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(ButterTheme.textSecondary)
                Spacer()
                Image("butter-pat")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.1f", weeklyTsp))
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(ButterTheme.gold)
                Text("tsp")
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .foregroundStyle(ButterTheme.textSecondary)
                Spacer()
            }

            if let summary = lastRunSummary {
                HStack {
                    Text("Last run: \(summary)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
