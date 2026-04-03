import SwiftUI
import MapKit

struct RunDetailView: View {
    let run: Run
    let usesMiles: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Butter hero
                VStack(spacing: 4) {
                    Text("🧈")
                        .font(.system(size: 36))
                    Text(String(format: "%.1f tsp", run.totalButterBurnedTsp))
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(ButterTheme.primary)
                    Text(ButterCalculator.butterDescription(tsp: run.totalButterBurnedTsp))
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
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

                // Butter Zero
                if run.isButterZeroChallenge {
                    HStack {
                        VStack(spacing: 2) {
                            Text("Butter Zero Score")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(ButterTheme.textSecondary)
                            Text("\(run.butterZeroScore)")
                                .font(.system(.title, design: .rounded, weight: .black))
                                .foregroundStyle(run.butterZeroScore >= 80 ? ButterTheme.success : ButterTheme.accent)
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text("Net Butter")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(ButterTheme.textSecondary)
                            let sign = run.netButterTsp >= 0 ? "+" : ""
                            Text("\(sign)\(String(format: "%.1f", run.netButterTsp)) tsp")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                        }
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
                        detailStat(String(format: "%.0f m", run.elevationGainMeters), "Elev. Gain")
                    }
                }
                .padding(.horizontal)

                // Splits
                if !run.splits.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Splits")
                            .font(.system(.headline, design: .rounded, weight: .bold))
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
                            .padding(.horizontal)

                        ForEach(run.butterEntries, id: \.id) { entry in
                            HStack {
                                Text(entry.servingType.emoji)
                                Text(entry.servingType.displayName)
                                    .font(.system(.body, design: .rounded))
                                Spacer()
                                Text(String(format: "%.1f tsp", entry.teaspoonEquivalent))
                                    .font(.system(.body, design: .rounded, weight: .medium))
                                    .foregroundStyle(ButterTheme.accent)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding(.bottom, 32)
        }
        .background(ButterTheme.background.ignoresSafeArea())
        .navigationTitle(run.startDate.formatted(.dateTime.month().day()))
        .navigationBarTitleDisplayMode(.inline)
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
    }
}

struct RouteMapView: View {
    let coordinates: [CLLocationCoordinate2D]

    var body: some View {
        Map {
            MapPolyline(coordinates: coordinates)
                .stroke(ButterTheme.primary, lineWidth: 4)
        }
        .mapStyle(.standard)
    }
}
