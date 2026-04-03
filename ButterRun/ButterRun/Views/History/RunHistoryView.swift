import SwiftUI
import SwiftData

struct RunHistoryView: View {
    @Query(sort: \Run.startDate, order: .reverse) private var runs: [Run]
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = RunHistoryViewModel()
    @State private var showManualEntry = false
    @State private var runToDelete: Run?
    @State private var showDeleteConfirmation = false

    private var usesMiles: Bool { profiles.first?.usesMiles ?? true }

    var body: some View {
        NavigationStack {
            ZStack {
                ButterTheme.background.ignoresSafeArea()

                if runs.isEmpty {
                    emptyState
                } else {
                    List {
                        // Summary header
                        Section {
                            HStack(spacing: 24) {
                                summaryItem(
                                    value: String(format: "%.1f", viewModel.allTimeButterTsp),
                                    unit: "tsp",
                                    label: "Total Butter"
                                )
                                summaryItem(
                                    value: ButterFormatters.distance(
                                        meters: viewModel.allTimeDistanceMeters,
                                        usesMiles: usesMiles
                                    ),
                                    unit: "",
                                    label: "Total Distance"
                                )
                                summaryItem(
                                    value: "\(viewModel.allTimeRuns)",
                                    unit: "",
                                    label: "Runs"
                                )
                            }
                            .listRowBackground(ButterTheme.surface)
                        }

                        // Run list
                        Section("All Runs") {
                            ForEach(runs, id: \.id) { run in
                                NavigationLink {
                                    RunDetailView(run: run, usesMiles: usesMiles)
                                } label: {
                                    RunRowView(run: run, usesMiles: usesMiles)
                                }
                                .listRowBackground(ButterTheme.surface)
                            }
                            .onDelete { indexSet in
                                if let index = indexSet.first {
                                    runToDelete = runs[index]
                                    showDeleteConfirmation = true
                                }
                            }
                        }

                        // Manual entry button
                        Section {
                            Button {
                                showManualEntry = true
                            } label: {
                                Label("Log Manual Run", systemImage: "plus.circle")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                    .foregroundStyle(ButterTheme.gold)
                            }
                            .listRowBackground(ButterTheme.surface)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("History")
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
                        try? modelContext.save()
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
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.load(runs: runs)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image("butter-pat")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(run.startDate, format: .dateTime.month().day().year())
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(ButterTheme.textPrimary)
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
                    Text("•")
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
                Text("tsp")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}
