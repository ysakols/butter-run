import SwiftUI

struct RunSummaryView: View {
    let run: Run
    let usesMiles: Bool
    let onDismiss: () -> Void

    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var meltProgress: Double = 0
    @State private var shareMode: ShareCardMode = .story
    @StateObject private var stravaAuth = StravaAuthService()
    @State private var stravaUploading = false
    @State private var stravaUploaded = false
    @State private var stravaError: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero: Melting butter animation
                    VStack(spacing: 8) {
                        ButterStickView(meltPercentage: meltProgress)
                            .frame(width: 60, height: 120)
                            .onAppear {
                                if reduceMotion {
                                    meltProgress = min(1.0, run.totalButterBurnedTsp / 24.0)
                                } else {
                                    withAnimation(.easeOut(duration: 2.0)) {
                                        meltProgress = min(1.0, run.totalButterBurnedTsp / 24.0)
                                    }
                                }
                            }

                        Text(String(format: "%.1f tsp", run.totalButterBurnedTsp))
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(ButterTheme.gold)

                        Text(ButterCalculator.butterDescription(tsp: run.totalButterBurnedTsp))
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(ButterTheme.textSecondary)
                    }
                    .padding(.top, 24)

                    // Route map thumbnail
                    RunMapThumbnail(routeData: run.routePolyline)
                        .padding(.horizontal)

                    // Butter Zero score
                    if run.isButterZeroChallenge {
                        butterZeroSection
                    }

                    // Churn result
                    if let churn = run.churnResult {
                        churnResultSection(churn)
                    }

                    // Stats grid
                    statsGrid

                    // Splits
                    if !run.splits.isEmpty {
                        splitsSection
                    }

                    // Calorie disclaimer
                    Text("Estimates are approximate, based on pace and body weight.")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
                        .padding(.horizontal)

                    // Share mode picker
                    Picker("Share Format", selection: $shareMode) {
                        Text("Story (9:16)").tag(ShareCardMode.story)
                        Text("Square (1:1)").tag(ShareCardMode.square)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Share button
                    Button {
                        generateAndShare()
                    } label: {
                        Label("Share My Churn", systemImage: "square.and.arrow.up")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ButterTheme.gold, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(ButterTheme.background)
                    }
                    .padding(.horizontal)
                    .accessibilityLabel("Share run results")

                    // Strava upload
                    if stravaAuth.isAuthenticated && !stravaUploaded {
                        Button {
                            stravaUploading = true
                            stravaError = nil
                            Task {
                                do {
                                    _ = try await StravaUploadService.shared.uploadRun(run: run, authService: stravaAuth)
                                    stravaUploaded = true
                                } catch {
                                    stravaError = error.localizedDescription
                                }
                                stravaUploading = false
                            }
                        } label: {
                            HStack {
                                if stravaUploading {
                                    ProgressView()
                                        .tint(ButterTheme.background)
                                }
                                Text("Upload to Strava")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 0.99, green: 0.32, blue: 0.15), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                        }
                        .disabled(stravaUploading)
                        .padding(.horizontal)
                    }

                    if stravaUploaded {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ButterTheme.success)
                            Text("Uploaded to Strava")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .foregroundStyle(ButterTheme.success)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ButterTheme.success.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    if let error = stravaError {
                        Text(error)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(ButterTheme.deficit)
                            .padding(.horizontal)
                    }
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
                        .foregroundStyle(ButterTheme.gold)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = shareImage {
                    ShareSheetView(image: image, isPresented: $showShareSheet)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var butterZeroSection: some View {
        VStack(spacing: 8) {
            let score = run.butterZeroScore
            Text("\(score)")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(score >= 80 ? ButterTheme.success : ButterTheme.goldDim)

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Butter Zero Score: \(run.butterZeroScore)")
    }

    private func churnResultSection(_ churn: ChurnResult) -> some View {
        VStack(spacing: 8) {
            let stage = ChurnStage(rawValue: churn.finalStage) ?? .liquid
            Text(stage.name)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(ButterTheme.gold)

            Text("Churn Result")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(ButterTheme.textSecondary)

            Text("\(Int(churn.finalProgress * 100))% complete")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)

            if churn.finalStage >= ChurnStage.butter.rawValue {
                Text("You made butter!")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(ButterTheme.gold)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Churn result: \(ChurnStage(rawValue: churn.finalStage)?.name ?? "Unknown"), \(Int(churn.finalProgress * 100)) percent complete")
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
                let elevValue = usesMiles
                    ? String(format: "%.0f ft", run.elevationGainMeters * 3.28084)
                    : String(format: "%.0f m", run.elevationGainMeters)
                statCard(
                    value: elevValue,
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
        .accessibilityElement(children: .combine)
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
        shareImage = ShareImageRenderer.render(run: run, usesMiles: usesMiles, mode: shareMode)
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
                .foregroundStyle(ButterTheme.gold)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

struct ShareSheetView: UIViewControllerRepresentable {
    let image: UIImage
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            isPresented = false
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
