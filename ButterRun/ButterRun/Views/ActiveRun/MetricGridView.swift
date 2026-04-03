import SwiftUI

struct MetricGridView: View {
    let viewModel: ActiveRunViewModel

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 16) {
            metricTile(
                value: viewModel.formattedDuration,
                label: "Time",
                icon: "clock"
            )

            metricTile(
                value: viewModel.formattedDistance,
                label: "Distance",
                icon: "figure.run"
            )

            metricTile(
                value: viewModel.formattedPace,
                label: "Pace",
                icon: "speedometer"
            )

            metricTile(
                value: String(format: "%.2f", viewModel.butterRate),
                label: "tsp/min",
                icon: "flame"
            )
        }
    }

    private func metricTile(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(ButterTheme.primary.opacity(0.7))
                Text(label)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.default, value: value)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
