import SwiftUI
import SwiftData

struct ActiveRunView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isButterZeroChallenge: Bool
    let isChurnEnabled: Bool
    let churnConfig: ChurnConfiguration?
    let profile: UserProfile

    @State private var viewModel = ActiveRunViewModel()
    @State private var showEatButterSheet = false
    @State private var showStopConfirmation = false
    @State private var completedRun: Run?
    @State private var showSummary = false
    @State private var showMap = false
    @State private var showUndoToast = false
    @State private var undoTimer: Timer?

    var body: some View {
        ZStack {
            ButterTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // GPS signal banners
                if viewModel.gpsSignalState == .weak {
                    gpsBanner
                } else if viewModel.gpsSignalState == .lost {
                    gpsLostBanner
                }

                // Auto-pause banner
                if viewModel.isAutoPaused {
                    autoPauseBanner
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
                        churnStage: viewModel.churnStage,
                        onQuickEat: {
                            viewModel.eatButter(serving: .teaspoon)
                            showUndoToast = true
                            startUndoTimer()
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                Spacer()

                // Metric grid or map
                if showMap {
                    // Map placeholder — will show route when RunMapView is available
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ButterTheme.surface)
                        .frame(height: 200)
                        .overlay {
                            Text("Map")
                                .foregroundStyle(ButterTheme.textSecondary)
                        }
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
                    undoToastView
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Controls
                controlsSection
                    .padding(.bottom, 50)
            }
        }
        .onAppear {
            viewModel.configure(profile: profile)
            viewModel.isButterZeroChallenge = isButterZeroChallenge
            let draftService = RunDraftService(container: modelContext.container)
            viewModel.setDraftService(draftService)
            viewModel.startRun()
            if isChurnEnabled, let config = churnConfig {
                viewModel.startChurn(configuration: config)
            }
        }
        .sheet(isPresented: $showEatButterSheet) {
            EatButterSheet { serving, customTsp in
                viewModel.eatButter(serving: serving, customTsp: customTsp)
                showUndoToast = true
                startUndoTimer()
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog("End run?", isPresented: $showStopConfirmation) {
            Button("Finish Run", role: .destructive) {
                finishRun()
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showSummary) {
            if let run = completedRun {
                RunSummaryView(
                    run: run,
                    usesMiles: profile.usesMiles,
                    onDismiss: { dismiss() }
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    private var gpsBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.slash")
                .font(.caption)
            Text("GPS signal weak — distance paused")
                .font(.system(.caption, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(ButterTheme.deficit.opacity(0.8))
        .accessibilityLabel("GPS signal weak, distance tracking paused")
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: "GPS signal weak, distance tracking paused")
        }
    }

    private var gpsLostBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.slash.fill")
                .font(.caption)
            Text("GPS signal lost")
                .font(.system(.caption, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(ButterTheme.deficit)
        .accessibilityLabel("GPS signal lost")
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: "GPS signal lost")
        }
    }

    private var autoPauseBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "pause.circle")
                .font(.caption)
            Text("Auto-paused")
                .font(.system(.caption, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(ButterTheme.goldDim.opacity(0.8))
        .accessibilityLabel("Run auto-paused due to low speed")
    }

    private var butterHeroSection: some View {
        VStack(spacing: 4) {
            Image("butter-pat")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

            Text(viewModel.formattedButter)
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(ButterTheme.gold)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .default, value: viewModel.formattedButter)
                .minimumScaleFactor(0.5)

            Text("teaspoons melted")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.formattedButter) teaspoons of butter melted")
    }

    private var undoToastView: some View {
        HStack {
            Text("Added 1 tsp")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(ButterTheme.textPrimary)
            Spacer()
            Button("Undo") {
                _ = viewModel.undoLastButterEntry()
                withAnimation { showUndoToast = false }
            }
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(ButterTheme.gold)
        }
        .padding(12)
        .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.12), lineWidth: 1))
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
                    .fill(viewModel.state == .running ? .white.opacity(0.2) : ButterTheme.success)
                    .frame(width: 70, height: 70)
                    .overlay {
                        Image(systemName: viewModel.state == .running ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
            }
            .accessibilityLabel(viewModel.state == .running ? "Pause run" : "Resume run")

            // Stop
            Button {
                showStopConfirmation = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 28))
                    Text("Stop")
                        .font(.system(.caption, design: .rounded))
                }
                .foregroundStyle(ButterTheme.deficit)
                .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Stop run")
        }
    }

    // MARK: - Actions

    private func finishRun() {
        let run = viewModel.stopRun()
        modelContext.insert(run)
        // Delete draft on successful finish
        let draftService = RunDraftService(container: modelContext.container)
        draftService.deleteDraft(context: modelContext)
        completedRun = run
        showSummary = true
    }

    private func startUndoTimer() {
        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation { showUndoToast = false }
            }
        }
    }
}
