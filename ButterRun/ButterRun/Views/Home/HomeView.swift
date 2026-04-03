import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Run.startDate, order: .reverse) private var runs: [Run]
    @Query private var profiles: [UserProfile]
    @State private var viewModel = HomeViewModel()
    @State private var showActiveRun = false
    @State private var isButterZero = false

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
                    Toggle(isOn: $isButterZero) {
                        HStack {
                            Text("🎯")
                            VStack(alignment: .leading) {
                                Text("Butter Zero Challenge")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                Text("Try to net zero calories")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(ButterTheme.textSecondary)
                            }
                        }
                    }
                    .tint(ButterTheme.primary)
                    .padding(.horizontal, 24)

                    // CHURN button
                    ChurnButton {
                        showActiveRun = true
                    }
                    .padding(.bottom, 8)

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
            .fullScreenCover(isPresented: $showActiveRun) {
                ActiveRunView(
                    isButterZeroChallenge: isButterZero,
                    profile: profile ?? UserProfile(displayName: "Runner", weightKg: 70)
                )
            }
        }
        .onAppear {
            viewModel.load(runs: runs)
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
            }

            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.1f", weeklyTsp))
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(ButterTheme.primary)
                Text("tsp")
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .foregroundStyle(ButterTheme.textSecondary)
                Spacer()
                Text("🧈")
                    .font(.system(size: 40))
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
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}
