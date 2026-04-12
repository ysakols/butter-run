import SwiftUI
import SwiftData

struct RunHistoryView: View {
    @Query(sort: \Run.startDate, order: .reverse) private var runs: [Run]
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(DeepLinkRouter.self) private var router
    @State private var viewModel = RunHistoryViewModel()
    @State private var showManualEntry = false
    @State private var runToDelete: Run?
    @State private var showDeleteConfirmation = false
    @State private var showSaveError = false
    @State private var visibleCount = 50
    @State private var navigationPath = NavigationPath()

    private var usesMiles: Bool { profiles.first?.usesMiles ?? true }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ButterTheme.background.ignoresSafeArea()

                if runs.isEmpty {
                    emptyState
                } else {
                    List {
                        // Summary header
                        Section {
                            VStack(spacing: 16) {
                                Text("All Time")
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .foregroundStyle(ButterTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                HStack(spacing: 0) {
                                    summaryItem(
                                        value: String(format: "%.1f", viewModel.allTimeButterTsp),
                                        unit: "pats",
                                        label: "Total Butter"
                                    )
                                    .frame(maxWidth: .infinity)
                                    Divider()
                                        .frame(height: 32)
                                    summaryItem(
                                        value: ButterFormatters.distance(
                                            meters: viewModel.allTimeDistanceMeters,
                                            usesMiles: usesMiles
                                        ),
                                        unit: "",
                                        label: "Total Distance"
                                    )
                                    .frame(maxWidth: .infinity)
                                    Divider()
                                        .frame(height: 32)
                                    summaryItem(
                                        value: "\(viewModel.allTimeRuns)",
                                        unit: "",
                                        label: "Runs"
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(ButterTheme.surface)
                        }

                        // Icon legend
                        Section {
                            HStack(spacing: 16) {
                                Label {
                                    Text("Butter Zero")
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(ButterTheme.textSecondary)
                                } icon: {
                                    Image(systemName: "scalemass.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(ButterTheme.gold)
                                }

                                Label {
                                    Text("Churn Tracker")
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(ButterTheme.textSecondary)
                                } icon: {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 12))
                                        .foregroundStyle(ButterTheme.gold)
                                }

                                Label {
                                    Text("Manual Entry")
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(ButterTheme.textSecondary)
                                } icon: {
                                    Text("M")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundStyle(ButterTheme.goldDim)
                                        .padding(.horizontal, 3)
                                        .padding(.vertical, 1)
                                        .background(ButterTheme.goldDim.opacity(0.2), in: Capsule())
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .listRowBackground(ButterTheme.surface)
                        }

                        // Run list
                        Section {
                            // Log Manual Run at top for easy access
                            Button {
                                showManualEntry = true
                            } label: {
                                Label("Log Manual Run", systemImage: "plus.circle")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                    .foregroundStyle(ButterTheme.gold)
                            }
                            .listRowBackground(ButterTheme.surface)

                            ForEach(runs.prefix(visibleCount), id: \.id) { run in
                                NavigationLink(value: run) {
                                    RunRowView(run: run, usesMiles: usesMiles)
                                }
                                .listRowBackground(ButterTheme.surface)
                            }
                            .onDelete { indexSet in
                                if let index = indexSet.first, index < visibleCount {
                                    runToDelete = runs[index]
                                    showDeleteConfirmation = true
                                }
                            }

                            if visibleCount < runs.count {
                                Button {
                                    visibleCount += 50
                                } label: {
                                    Text("Show More (\(runs.count - visibleCount) remaining)")
                                        .font(.system(.body, design: .rounded))
                                        .foregroundStyle(ButterTheme.gold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                }
                                .listRowBackground(ButterTheme.surface)
                            }
                        } header: {
                            Text("All Runs")
                                .padding(.top, 8)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: Run.self) { run in
                RunDetailView(run: run, usesMiles: usesMiles)
            }
            .onChange(of: router.pending, initial: true) { _, newValue in
                handleDeepLink(newValue)
            }
            .onChange(of: runs.count) {
                handleDeepLink(router.pending)
            }
            .sheet(isPresented: $showManualEntry) {
                ManualRunEntryView()
            }
            .confirmationDialog(
                "Delete this run?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let run = runToDelete {
                        modelContext.delete(run)
                        do {
                            try modelContext.save()
                        } catch {
                            showSaveError = true
                        }
                    }
                    runToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    runToDelete = nil
                }
            } message: {
                Text("This cannot be undone.")
            }
        }
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your data could not be saved. Please try again.")
        }
        .onAppear {
            viewModel.load(runs: runs)
        }
        .onChange(of: runs.count) {
            viewModel.load(runs: runs)
        }
    }

    private func handleDeepLink(_ destination: DeepLinkDestination?) {
        guard case .run(let id) = destination else { return }
        if let run = runs.first(where: { $0.id == id }) {
            navigationPath = NavigationPath()
            navigationPath.append(run)
            Task { @MainActor in
                _ = router.consume()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ButterPatView(size: 60, style: .solid)
                .opacity(0.4)
                .accessibilityHidden(true)
            Text("No runs yet")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(ButterTheme.textPrimary)
            Text("Tap the Run tab to start!")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)
        }
    }

    private func summaryItem(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(ButterTheme.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
                }
            }
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)
        }
    }
}

struct RunRowView: View {
    let run: Run
    let usesMiles: Bool

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(run.startDate, format: .dateTime.month().day().year())
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(ButterTheme.textPrimary)

                    // Run type badges
                    if run.isButterZeroChallenge {
                        Image(systemName: "scalemass.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ButterTheme.gold)
                            .accessibilityLabel("Butter Zero run")
                    }
                    if run.churnResult != nil {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ButterTheme.gold)
                            .accessibilityLabel("Churn Tracker run")
                    }
                    if run.isManualEntry {
                        Text("Manual")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(ButterTheme.goldDim)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ButterTheme.goldDim.opacity(0.2), in: Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Text(ButterFormatters.distance(meters: run.distanceMeters, usesMiles: usesMiles))
                    Text("\u{00B7}")
                    Text(run.formattedDuration)
                }
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", run.totalButterBurnedTsp))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(ButterTheme.gold)
                Text("pats")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
                Text("\(Int(round(run.totalButterBurnedTsp * ButterCalculator.caloriesPerTeaspoon))) cal")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
