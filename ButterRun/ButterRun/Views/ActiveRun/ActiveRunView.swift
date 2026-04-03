import SwiftUI
import SwiftData

struct ActiveRunView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let isButterZeroChallenge: Bool
    let profile: UserProfile

    @State private var viewModel = ActiveRunViewModel()
    @State private var showEatButterSheet = false
    @State private var showStopConfirmation = false
    @State private var completedRun: Run?
    @State private var showSummary = false

    var body: some View {
        ZStack {
            ButterTheme.activeRunBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top: Butter burned (hero metric)
                butterHeroSection
                    .padding(.top, 60)

                // Butter Zero bar (if applicable)
                if isButterZeroChallenge {
                    ButterZeroBar(
                        burnedTsp: viewModel.butterBurnedTsp,
                        eatenTsp: viewModel.butterEatenTsp
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }

                Spacer()

                // Metric grid
                MetricGridView(viewModel: viewModel)
                    .padding(.horizontal, 16)

                Spacer()

                // Controls
                controlsSection
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            viewModel.configure(profile: profile)
            viewModel.isButterZeroChallenge = isButterZeroChallenge
            viewModel.startRun()
        }
        .sheet(isPresented: $showEatButterSheet) {
            EatButterSheet { serving, customTsp in
                viewModel.eatButter(serving: serving, customTsp: customTsp)
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
    }

    // MARK: - Subviews

    private var butterHeroSection: some View {
        VStack(spacing: 4) {
            Text("🧈")
                .font(.system(size: 36))

            Text(viewModel.formattedButter)
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundStyle(ButterTheme.primary)
                .contentTransition(.numericText())
                .animation(.default, value: viewModel.formattedButter)

            Text("teaspoons melted")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
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
                    .foregroundStyle(ButterTheme.primary)
                }
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
                .foregroundStyle(.red.opacity(0.8))
            }
        }
    }

    private func finishRun() {
        let run = viewModel.stopRun()
        modelContext.insert(run)
        completedRun = run
        showSummary = true
    }
}
