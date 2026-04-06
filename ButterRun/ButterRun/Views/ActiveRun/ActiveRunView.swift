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
    @State private var completedRun: Run?
    @State private var showSummary = false
    @State private var showMap = false
    @State private var showUndoToast = false
    @ScaledMetric(relativeTo: .largeTitle) private var heroFontSize: CGFloat = 56

    var body: some View {
        ZStack {
            ButterTheme.background.ignoresSafeArea()

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
                        text: "Added \(String(format: "%.1f", viewModel.butterEntries.last?.teaspoonEquivalent ?? 1.0)) pat",
                        actionLabel: "Undo",
                        onAction: {
                            _ = viewModel.undoLastButterEntry()
                            withAnimation { showUndoToast = false }
                        },
                        isPresented: $showUndoToast
                    )
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
            }
            .presentationDetents([.medium])
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

}
