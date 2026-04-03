import SwiftUI
import SwiftData

struct RunHistoryView: View {
    @Query(sort: \Run.startDate, order: .reverse) private var runs: [Run]
    @Query private var profiles: [UserProfile]
    @State private var viewModel = RunHistoryViewModel()

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
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("History")
        }
        .onAppear {
            viewModel.load(runs: runs)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🧈")
                .font(.system(size: 60))
            Text("No runs yet")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(ButterTheme.textPrimary)
            Text("Hit that Churn button to melt some butter!")
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
                Text(run.startDate, format: .dateTime.month().day().year())
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(ButterTheme.textPrimary)

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
                    .foregroundStyle(ButterTheme.primary)
                Text("tsp 🧈")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}
