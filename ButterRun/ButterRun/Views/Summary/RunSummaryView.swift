import SwiftUI
import SwiftData

struct RunSummaryView: View {
    let run: Run
    let usesMiles: Bool
    let onDismiss: () -> Void
    var healthKitEnabled: Bool = false
    var pauseResumeEvents: [(pauseDate: Date, resumeDate: Date)] = []

    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var isGeneratingShare = false
    @State private var meltProgress: Double = 0
    @State private var shareMode: ShareCardMode = .story
    @State private var newAchievements: [AchievementType] = []
    @State private var showAchievementOverlay = false
    @EnvironmentObject private var stravaAuth: StravaAuthService
    @State private var stravaUploading = false
    @State private var stravaUploaded = false
    @State private var stravaError: String?
    @State private var healthKitSynced = false
    @State private var healthKitSyncing = false
    @State private var healthKitError: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext

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

                        Text(ButterFormatters.pats(run.totalButterBurnedTsp))
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

                    // Net pats (Butter Zero challenge)
                    if run.isButterZeroChallenge {
                        netPatsSection
                    }

                    // Churn result
                    if let churn = run.churnResult {
                        churnResultSection(churn)
                    }

                    // Stats grid
                    statsGrid

                    // Achievements unlocked
                    if !newAchievements.isEmpty {
                        Button {
                            showAchievementOverlay = true
                        } label: {
                            VStack(spacing: 8) {
                                Text("Achievements Unlocked")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(ButterTheme.textPrimary)

                                ForEach(newAchievements, id: \.self) { achievement in
                                    HStack(spacing: 12) {
                                        Text(achievement.emoji)
                                            .font(.system(size: 28))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(achievement.displayName)
                                                .font(.system(.body, design: .rounded, weight: .bold))
                                                .foregroundStyle(ButterTheme.textPrimary)
                                            Text(achievement.description)
                                                .font(.system(.caption, design: .rounded))
                                                .foregroundStyle(ButterTheme.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(ButterTheme.textSecondary)
                                    }
                                    .padding(12)
                                    .background(ButterTheme.goldLight, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

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
                        ZStack {
                            Label("Share My Run", systemImage: "square.and.arrow.up")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .opacity(isGeneratingShare ? 0 : 1)

                            if isGeneratingShare {
                                ProgressView()
                                    .tint(ButterTheme.onPrimaryAction)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ButterTheme.gold, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(ButterTheme.onPrimaryAction)
                    }
                    .disabled(isGeneratingShare)
                    .padding(.horizontal)
                    .accessibilityLabel("Share run results")

                    // HealthKit status
                    if run.healthKitSynced || healthKitSynced {
                        healthKitSyncedBadge
                    } else if let error = healthKitError {
                        Text(error)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(ButterTheme.deficit)
                            .padding(.horizontal)
                    }

                    // Strava upload
                    if stravaAuth.isAuthenticated && run.stravaActivityId == nil {
                        stravaUploadSection
                    } else if run.stravaActivityId != nil || stravaUploaded {
                        stravaUploadedBadge
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
                    let deepLink = DeepLinkRouter.url(forRunID: run.id)
                    ShareSheetView(items: [image, deepLink], isPresented: $showShareSheet)
                }
            }
            .onAppear {
                let service = AchievementService()
                let descriptor = FetchDescriptor<Run>()
                let allRunsList = (try? modelContext.fetch(descriptor)) ?? []
                let awards = service.checkAchievements(for: run, allRuns: allRunsList, context: modelContext)
                if !awards.isEmpty {
                    newAchievements = awards
                }

                // Auto-sync to HealthKit if enabled
                if healthKitEnabled && !run.healthKitSynced {
                    syncToHealthKit()
                }
            }
            .overlay {
                if showAchievementOverlay {
                    AchievementUnlockOverlay(achievements: newAchievements) {
                        showAchievementOverlay = false
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    private var netPatsSection: some View {
        VStack(spacing: 12) {
            Text(ButterFormatters.netPats(run.netButterTsp))
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(ButterTheme.gold)

            ButterZeroScale(netPats: run.netButterTsp)
                .padding(.horizontal, 8)

            Text("Net Pats")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(ButterTheme.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Net pats: \(ButterFormatters.netPats(run.netButterTsp))")
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

    private var healthKitSyncedBadge: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(ButterTheme.success.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ButterTheme.success)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Saved to Apple Health")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(ButterTheme.success)
                Text("Workout synced to the Health app")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(ButterTheme.success.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ButterTheme.success.opacity(0.2), lineWidth: 1))
        .padding(.horizontal)
    }

    private var stravaUploadedBadge: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(ButterTheme.success.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ButterTheme.success)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Uploaded to Strava")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(ButterTheme.success)
                Text("Activity is live on your Strava profile")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(ButterTheme.success.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ButterTheme.success.opacity(0.2), lineWidth: 1))
        .padding(.horizontal)
    }

    private var stravaUploadSection: some View {
        let stravaOrange = Color(red: 0.99, green: 0.32, blue: 0.15)

        return VStack(spacing: 0) {
                Button {
                    uploadToStrava()
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white.opacity(0.15))
                                .frame(width: 32, height: 32)

                            if stravaUploading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(stravaUploading ? "Uploading..." : "Upload to Strava")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            Text("Share this run on your profile")
                                .font(.system(.caption2, design: .rounded))
                                .opacity(0.8)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .opacity(0.6)
                    }
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(stravaOrange, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(stravaUploading)

            // Error message
            if let error = stravaError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text(error)
                        .font(.system(.caption2, design: .rounded))
                }
                .foregroundStyle(ButterTheme.deficit)
                .padding(.top, 8)
            }
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(stravaUploaded ? "Uploaded to Strava" : "Upload to Strava")
    }

    private func syncToHealthKit() {
        guard !healthKitSyncing else { return }
        healthKitSyncing = true
        Task {
            let service = HealthKitService()
            let success = await service.saveWorkout(run: run, pauseResumeEvents: pauseResumeEvents)
            await MainActor.run {
                healthKitSyncing = false
                if success {
                    run.healthKitSynced = true
                    do {
                        try modelContext.save()
                        healthKitSynced = true
                    } catch {
                        healthKitError = "Workout saved to Health but failed to update local state."
                    }
                } else {
                    healthKitError = "Could not save to Apple Health. Check permissions in Settings."
                }
            }
        }
    }

    private func uploadToStrava() {
        stravaUploading = true
        stravaError = nil
        Task {
            var activityId: Int64?
            do {
                activityId = try await StravaUploadService.shared.uploadRun(run: run, authService: stravaAuth)
            } catch {
                // Don't expose raw error details (may contain tokens/URLs) — use generic message
            }
            await MainActor.run {
                if let activityId {
                    run.stravaActivityId = activityId
                    try? modelContext.save()
                    stravaUploaded = true
                } else {
                    stravaError = "Upload failed. Check your connection and try again."
                }
                stravaUploading = false
            }
        }
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

    private func generateAndShare() {
        guard !isGeneratingShare else { return }
        isGeneratingShare = true
        Task {
            shareImage = await ShareImageRenderer.render(run: run, usesMiles: usesMiles, mode: shareMode)
            showShareSheet = shareImage != nil
            isGeneratingShare = false
        }
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

            Text(ButterFormatters.pats(split.butterBurnedTsp))
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(ButterTheme.gold)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            isPresented = false
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
