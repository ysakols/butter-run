import SwiftUI
import MapKit

struct RunDetailView: View {
    @Bindable var run: Run
    let usesMiles: Bool
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Butter hero
                VStack(spacing: 4) {
                    ButterPatView(size: 36, style: .solid)
                        .accessibilityHidden(true)
                    Text(ButterFormatters.pats(run.totalButterBurnedTsp))
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(ButterTheme.gold)
                    Text(ButterCalculator.butterDescription(tsp: run.totalButterBurnedTsp))
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
                    if run.isManualEntry {
                        Text("Manual Entry")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(ButterTheme.goldDim)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(ButterTheme.goldDim.opacity(0.2), in: Capsule())
                    }
                }
                .padding(.top, 8)

                // Route map
                if let polyline = run.routePolyline {
                    let coords = LocationService.decodeRoute(polyline)
                    if !coords.isEmpty {
                        RouteMapView(coordinates: coords)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                    }
                }

                // Net pats (Butter Zero challenge)
                if run.isButterZeroChallenge {
                    VStack(spacing: 8) {
                        Text(ButterFormatters.netPats(run.netButterTsp))
                            .font(.system(.title, design: .rounded, weight: .black))
                            .foregroundStyle(ButterTheme.gold)

                        ButterZeroScale(netPats: run.netButterTsp)
                            .padding(.horizontal, 8)

                        HStack(spacing: 4) {
                            Text("Net Pats")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(ButterTheme.textSecondary)
                            InfoButton(title: "Butter Zero", bodyText: "Eat butter during your run and try to match what you burn. Track as + or − pats from net zero.")
                        }
                    }
                    .padding(16)
                    .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Churn result
                if let churn = run.churnResult {
                    let stage = ChurnStage(rawValue: churn.finalStage) ?? .liquid
                    HStack {
                        VStack(spacing: 2) {
                            Text("Churn Result")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(ButterTheme.textSecondary)
                            Text(stage.name)
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(ButterTheme.gold)
                        }
                        Spacer()
                        Text("\(Int(churn.finalProgress * 100))%")
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(ButterTheme.gold)
                    }
                    .padding(16)
                    .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    detailStat(ButterFormatters.distance(meters: run.distanceMeters, usesMiles: usesMiles), "Distance")
                    detailStat(run.formattedDuration, "Duration")
                    detailStat(ButterFormatters.pace(secondsPerKm: run.averagePaceSecondsPerKm, usesMiles: usesMiles), "Avg Pace")
                    detailStat(String(format: "%.0f cal", run.totalCaloriesBurned), "Calories")
                    if run.elevationGainMeters > 0 {
                        let elevText = usesMiles
                            ? String(format: "%.0f ft", run.elevationGainMeters * 3.28084)
                            : String(format: "%.0f m", run.elevationGainMeters)
                        detailStat(elevText, "Elev. Gain")
                    }
                    if let cadence = run.averageCadence, cadence > 0 {
                        detailStat(String(format: "%.0f spm", cadence), "Cadence")
                    }
                }
                .padding(.horizontal)

                // Notes
                if let notes = run.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(ButterTheme.textSecondary)
                        Text(notes)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(ButterTheme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Splits
                if !run.splits.isEmpty {
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

                // Butter entries
                if !run.butterEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Butter Eaten")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(ButterTheme.textPrimary)
                            .padding(.horizontal)

                        ForEach(run.butterEntries, id: \.id) { entry in
                            HStack {
                                Text(entry.servingType.displayName)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(ButterTheme.textPrimary)
                                Spacer()
                                Text(ButterFormatters.pats(entry.teaspoonEquivalent))
                                    .font(.system(.body, design: .rounded, weight: .medium))
                                    .foregroundStyle(ButterTheme.gold)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Calorie disclaimer
                Text("Estimates are approximate and for entertainment purposes.")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
                    .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
        .background(ButterTheme.background.ignoresSafeArea())
        .navigationTitle(run.startDate.formatted(.dateTime.month().day()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    ShareLink(
                        item: DeepLinkRouter.url(forRunID: run.id),
                        message: Text("Check out my Butter Run!")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .foregroundStyle(ButterTheme.gold)

                    Button("Edit") {
                        showEdit = true
                    }
                    .foregroundStyle(ButterTheme.gold)
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            RunEditView(run: run, usesMiles: usesMiles)
        }
    }

    private func detailStat(_ value: String, _ label: String) -> some View {
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
}

struct RouteMapView: View {
    let coordinates: [CLLocationCoordinate2D]

    var body: some View {
        Map {
            MapPolyline(coordinates: coordinates)
                .stroke(ButterTheme.gold, lineWidth: 4)
        }
        .mapStyle(.standard)
    }
}
