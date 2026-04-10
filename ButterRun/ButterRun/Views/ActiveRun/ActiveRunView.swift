import SwiftUI
import SwiftData
import CoreLocation

struct ActiveRunView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @EnvironmentObject private var stravaAuth: StravaAuthService

    let isButterZeroChallenge: Bool
    let isChurnEnabled: Bool
    let churnConfig: ChurnConfiguration?
    let profile: UserProfile

    @State private var viewModel = ActiveRunViewModel()
    @State private var showEatButterSheet = false
    @State private var completedRun: Run?
    @State private var showSummary = false
    @State private var showMap = false
    @State private var showUndoToast = false
    @State private var showSaveError = false
    @State private var countdownValue: Int = 3
    @State private var isCountingDown = true
    @State private var countdownTask: Task<Void, Never>?
    @ScaledMetric(relativeTo: .largeTitle) private var heroFontSize: CGFloat = 56
    @State private var showLocationDeniedAlert = false

    var body: some View {
        ZStack {
            ButterTheme.background.ignoresSafeArea()

            // Countdown overlay
            if isCountingDown {
                countdownOverlay
                    .transition(.opacity)
                    .zIndex(100)
            }

            VStack(spacing: 0) {
                // GPS signal banners
                if viewModel.gpsSignalState == .weak {
                    BannerView(type: .warn, icon: "location.slash", text: "GPS signal weak — distance may be inaccurate")
                } else if viewModel.gpsSignalState == .lost {
                    BannerView(type: .error, icon: "location.slash.fill", text: "GPS signal lost")
                }

                // Auto-pause banner
                if viewModel.isAutoPaused {
                    BannerView(type: .pause, icon: "pause.circle", text: "Auto-paused")
                        .accessibilityLabel("Run auto-paused due to low speed")
                }

                // Hero metric
                butterHeroSection
                    .padding(.top, 40)

                // Contextual strip (BZ + churn combined)
                if isButterZeroChallenge || isChurnEnabled {
                    ContextualStrip(
                        isButterZero: isButterZeroChallenge,
                        isChurnEnabled: isChurnEnabled,
                        burnedTsp: viewModel.butterBurnedTsp,
                        eatenTsp: viewModel.butterEatenTsp,
                        churnProgress: viewModel.churnProgress,
                        churnStage: viewModel.churnStage
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                Spacer()

                // Metric grid or map
                if showMap {
                    RunMapView(
                        routeCoordinates: viewModel.routeCoordinates,
                        isLive: viewModel.state == .running
                    )
                    .frame(height: 200)
                    .padding(.horizontal, 16)
                } else {
                    MetricGridView(viewModel: viewModel)
                        .padding(.horizontal, 16)
                }

                // Map toggle
                HStack {
                    Spacer()
                    Button {
                        showMap.toggle()
                    } label: {
                        Image(systemName: showMap ? "square.grid.2x2" : "map")
                            .font(.body)
                            .foregroundStyle(ButterTheme.textSecondary)
                            .frame(minWidth: 44, minHeight: 44)
                            .background(ButterTheme.surface, in: Circle())
                    }
                    .accessibilityLabel(showMap ? "Show metrics" : "Show map")
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()

                // Undo toast
                if showUndoToast {
                    ToastView(
                        text: "Added \(ButterFormatters.pats(viewModel.butterEntries.last?.teaspoonEquivalent ?? 1.0))",
                        actionLabel: "Undo",
                        onAction: {
                            _ = viewModel.undoLastButterEntry()
                            withAnimation { showUndoToast = false }
                        },
                        isPresented: $showUndoToast
                    )
                    .id(viewModel.butterEntries.count)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.opacity)
                }

                // Controls
                controlsSection
                    .padding(.bottom, 50)
            }
        }
        .onAppear {
            viewModel.configure(profile: profile)
            viewModel.isButterZeroChallenge = isButterZeroChallenge
            let draftService = RunDraftService(context: modelContext)
            viewModel.setDraftService(draftService)

            let status = CLLocationManager().authorizationStatus
            if status == .denied || status == .restricted {
                showLocationDeniedAlert = true
            }

            startCountdown()
        }
        .onDisappear {
            countdownTask?.cancel()
        }
        .sheet(isPresented: $showEatButterSheet) {
            EatButterSheet { serving, customTsp in
                viewModel.eatButter(serving: serving, customTsp: customTsp)
                showUndoToast = true
            }
            .presentationDetents([.medium])
        }
        .alert("Location Access Required", isPresented: $showLocationDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("ButterRun needs location access to track your run. Please enable it in Settings.")
        }
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your data could not be saved. Please try again.")
        }
        .fullScreenCover(isPresented: $showSummary) {
            if let run = completedRun {
                RunSummaryView(
                    run: run,
                    usesMiles: profile.usesMiles,
                    onDismiss: { dismiss() },
                    healthKitEnabled: profile.healthKitEnabled,
                    pauseResumeEvents: viewModel.workoutPauseResumeEvents
                )
                .environmentObject(stravaAuth)
            }
        }
    }

    // MARK: - Subviews

    private var butterHeroSection: some View {
        VStack(spacing: 4) {
            ButterPatView(size: 36, style: .solid)
                .accessibilityHidden(true)

            Text(viewModel.formattedButter)
                .font(.system(size: heroFontSize, weight: .black, design: .rounded))
                .foregroundStyle(ButterTheme.gold)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .default, value: viewModel.formattedButter)
                .minimumScaleFactor(0.5)

            Text("pats burned")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.formattedButter) pats of butter burned")
    }

    private var controlsSection: some View {
        HStack(spacing: 32) {
            // Eat butter button (Butter Zero mode)
            if isButterZeroChallenge {
                Button {
                    showEatButterSheet = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                        Text("Eat")
                            .font(.system(.caption, design: .rounded))
                    }
                    .foregroundStyle(ButterTheme.gold)
                    .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Eat butter")
            }

            // Pause / Resume
            Button {
                if viewModel.state == .running {
                    viewModel.pauseRun()
                } else {
                    viewModel.resumeRun()
                }
            } label: {
                Circle()
                    .fill(viewModel.state == .running ? ButterTheme.surfaceBorder : ButterTheme.success)
                    .frame(width: 70, height: 70)
                    .overlay {
                        Image(systemName: viewModel.state == .running ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
            }
            .accessibilityLabel(viewModel.state == .running ? "Pause run" : "Resume run")

            // Stop (long-press)
            LongPressStopButton {
                finishRun()
            }
        }
    }

    // MARK: - Countdown

    private var countdownOverlay: some View {
        ZStack {
            ButterTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                if countdownValue > 0 {
                    Text("\(countdownValue)")
                        .font(.system(size: 96, weight: .black, design: .rounded))
                        .foregroundStyle(ButterTheme.gold)
                        .contentTransition(.numericText())
                } else {
                    Text("Go!")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(ButterTheme.gold)
                }

                Text(countdownValue > 0 ? "Get ready..." : "")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
            }
        }
        .accessibilityLabel(countdownValue > 0 ? "Starting in \(countdownValue)" : "Go")
    }

    private func startCountdown() {
        countdownValue = 3
        isCountingDown = true

        // Skip countdown during UI testing
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--skip-countdown") {
            isCountingDown = false
            beginRun()
            return
        }
        #endif

        countdownTask = Task {
            do {
                try await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { withAnimation { countdownValue = 2 } }

                try await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { withAnimation { countdownValue = 1 } }

                try await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { withAnimation { countdownValue = 0 } }

                try await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation { isCountingDown = false }
                    beginRun()
                }
            } catch {
                // Task was cancelled
            }
        }
    }

    private func beginRun() {
        viewModel.startRun()
        if isChurnEnabled, let config = churnConfig {
            viewModel.startChurn(configuration: config)
        }
    }

    // MARK: - Actions

    private func finishRun() {
        guard completedRun == nil else { return }
        let run = viewModel.stopRun()
        modelContext.insert(run)
        do {
            try modelContext.save()
        } catch {
            showSaveError = true
        }
        // Delete draft on successful finish
        let draftService = RunDraftService(context: modelContext)
        draftService.deleteDraft()
        completedRun = run
        showSummary = true
    }

}
