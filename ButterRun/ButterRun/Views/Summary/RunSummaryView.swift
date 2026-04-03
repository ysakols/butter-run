import SwiftUI

struct RunSummaryView: View {
    let run: Run
    let usesMiles: Bool
    let onDismiss: () -> Void

    @State private var viewModel: RunSummaryViewModel?
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var meltProgress: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero: Melting butter animation
                    VStack(spacing: 8) {
                        ButterStickView(meltPercentage: meltProgress)
                            .frame(width: 60, height: 120)
                            .onAppear {
                                withAnimation(.easeOut(duration: 2.0)) {
                                    // Melt proportional to burn (1 stick = 24 tsp max for visual)
                                    meltProgress = min(1.0, run.totalButterBurnedTsp / 24.0)
                                }
                            }

                        Text(String(format: "%.1f tsp", run.totalButterBurnedTsp))
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(ButterTheme.primary)

                        Text(ButterCalculator.butterDescription(tsp: run.totalButterBurnedTsp))
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(ButterTheme.textSecondary)
                    }
                    .padding(.top, 24)

                    // Butter Zero score
                    if run.isButterZeroChallenge {
                        butterZeroSection
                    }

                    // Stats grid
                    statsGrid

                    // Splits
                    if !run.splits.isEmpty {
                        splitsSection
                    }

                    // Share button
                    Button {
                        generateAndShare()
                    } label: {
                        Label("Share My Churn", systemImage: "square.and.arrow.up")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ButterTheme.primary, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .background(ButterTheme.background.ignoresSafeArea())
            .navigationTitle("Run Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = shareImage {
                    ShareSheetView(image: image)
                }
            }
        }
    }

    private var butterZeroSection: some View {
        VStack(spacing: 8) {
            let score = run.butterZeroScore
            Text("\(score)")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(score >= 80 ? ButterTheme.success : ButterTheme.accent)

            Text("Butter Zero Score")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(ButterTheme.textSecondary)

            let net = run.netButterTsp
            let sign = net >= 0 ? "+" : ""
            Text("Net: \(sign)\(String(format: "%.1f", net)) tsp")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 12) {
            statCard(
                value: ButterFormatters.distance(meters: run.distanceMeters, usesMiles: usesMiles),
                label: "Distance"
            )
            statCard(
                value: run.formattedDuration,
                label: "Duration"
            )
            statCard(
                value: ButterFormatters.pace(secondsPerKm: run.averagePaceSecondsPerKm, usesMiles: usesMiles),
                label: "Avg Pace"
            )
            statCard(
                value: String(format: "%.0f", run.totalCaloriesBurned),
                label: "Calories"
            )
            if run.elevationGainMeters > 0 {
                statCard(
                    value: String(format: "%.0f m", run.elevationGainMeters),
                    label: "Elevation"
                )
            }
            if let cadence = run.averageCadence, cadence > 0 {
                statCard(
                    value: String(format: "%.0f spm", cadence),
                    label: "Cadence"
                )
            }
        }
        .padding(.horizontal)
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(ButterTheme.textPrimary)
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private var splitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Splits")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(ButterTheme.textPrimary)
                .padding(.horizontal)

            ForEach(run.splits.sorted(by: { $0.index < $1.index }), id: \.index) { split in
                SplitRowView(split: split, usesMiles: usesMiles, index: split.index)
            }
        }
    }

    @MainActor
    private func generateAndShare() {
        shareImage = ShareImageRenderer.render(run: run, usesMiles: usesMiles)
        showShareSheet = true
    }
}

struct SplitRowView: View {
    let split: Split
    let usesMiles: Bool
    let index: Int

    var body: some View {
        HStack {
            Text(split.isPartial ? "Final" : "\(index + 1)")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(ButterTheme.textPrimary)
                .frame(width: 40)

            Spacer()

            Text(ButterFormatters.pace(secondsPerKm: split.paceSecondsPerKm, usesMiles: usesMiles))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(ButterTheme.textPrimary)

            Spacer()

            Text(String(format: "%.1f tsp", split.butterBurnedTsp))
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(ButterTheme.accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

struct ShareSheetView: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
