import SwiftUI
import SwiftData
import CoreLocation

struct HomeView: View {
    @EnvironmentObject private var stravaAuth: StravaAuthService
    @Query(sort: \Run.startDate, order: .reverse) private var runs: [Run]
    @Query private var profiles: [UserProfile]
    @State private var viewModel = HomeViewModel()
    @State private var showActiveRun = false
    @State private var isButterZero = false
    @State private var isChurnEnabled = false
    @State private var showChurnSetup = false
    @State private var churnConfig: ChurnConfiguration?
    @State private var showLocationPermission = false
    @State private var locationManager = CLLocationManager()
    @State private var butterTrivia = ButterFacts.random

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
                        weeklyPats: viewModel.weeklyButterPats,
                        totalRuns: viewModel.totalRuns,
                        lastRunSummary: viewModel.lastRunSummary
                    )
                    .padding(.horizontal)

                    Spacer()

                    // Butter Zero toggle
                    VStack(spacing: 12) {
                        Toggle(isOn: $isButterZero) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("Butter Zero")
                                        .font(.system(.body, design: .rounded, weight: .semibold))
                                        .foregroundStyle(ButterTheme.textPrimary)
                                    InfoButton(title: "Butter Zero", bodyText: "Eat butter during your run and try to match what you burn. Track as + or − pats from net zero.")
                                }
                                Text("Eat butter mid-run. Try to net zero.")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(ButterTheme.textSecondary)
                            }
                        }
                        .tint(ButterTheme.gold)
                        .accessibilityLabel("Butter Zero mode")

                        Toggle(isOn: $isChurnEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("Churn Tracker")
                                        .font(.system(.body, design: .rounded, weight: .semibold))
                                        .foregroundStyle(ButterTheme.textPrimary)
                                    InfoButton(title: "Churn Tracker", bodyText: "Carry cream in a bag. Bouncing churns it into butter in ~6-10 km.")
                                }
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
                        checkLocationAndStart()
                    }
                    .padding(.bottom, 8)
                    .accessibilityLabel(isChurnEnabled ? "Set up churn tracker" : "Start run")

                    // Butter trivia (selected once per view appearance via butterTrivia state)
                    Text(butterTrivia)
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
                .environmentObject(stravaAuth)
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
            .sheet(isPresented: $showLocationPermission) {
                LocationPermissionView(
                    onAllow: {
                        locationManager.requestWhenInUseAuthorization()
                        showLocationPermission = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            if isChurnEnabled {
                                showChurnSetup = true
                            } else {
                                showActiveRun = true
                            }
                        }
                    },
                    onDeny: {
                        showLocationPermission = false
                    }
                )
            }
        }
        .onAppear {
            viewModel.load(runs: runs, usesMiles: profile?.usesMiles ?? true)
        }
    }

    private func checkLocationAndStart() {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            showLocationPermission = true
        } else if isChurnEnabled {
            showChurnSetup = true
        } else {
            showActiveRun = true
        }
    }
}

struct WeeklyButterCard: View {
    let weeklyPats: Double
    let totalRuns: Int
    let lastRunSummary: String?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("This Week")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(ButterTheme.textSecondary)
                Spacer()
                ButterPatView(size: 32, style: .solid)
                    .accessibilityHidden(true)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.1f", weeklyPats))
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(ButterTheme.gold)
                HStack(spacing: 4) {
                    Text("pats")
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .foregroundStyle(ButterTheme.textSecondary)
                    InfoButton(title: "What's a pat?", bodyText: "≈ 1 tsp of butter (~34 cals). A fun way to track energy burned.")
                }
                Spacer()
            }

            if weeklyPats < 0.01 && totalRuns == 0 {
                HStack {
                    Text("Get out there and burn some butter!")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
                        .italic()
                    Spacer()
                }
            } else if let summary = lastRunSummary {
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
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(ButterTheme.surfaceBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
