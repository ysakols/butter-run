import SwiftUI

struct MetricGridView: View {
    let viewModel: ActiveRunViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        if dynamicTypeSize >= .accessibility1 {
            return [GridItem(.flexible())]
        }
        return [GridItem(.flexible()), GridItem(.flexible())]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            metricTile(
                value: viewModel.formattedDuration,
                label: "Time",
                icon: "clock"
            )
            .accessibilityLabel("Time: \(viewModel.formattedDuration)")

            metricTile(
                value: viewModel.formattedDistance,
                label: "Distance",
                icon: "figure.run"
            )
            .accessibilityLabel("Distance: \(viewModel.formattedDistance)")

            metricTile(
                value: viewModel.formattedPace,
                label: "Pace",
                icon: "speedometer"
            )
            .accessibilityLabel("Pace: \(viewModel.formattedPace)")

            metricTile(
                value: viewModel.formattedButterRate,
                label: "pats/min",
                icon: "flame"
            )
            .accessibilityLabel("Butter rate: \(viewModel.formattedButterRate) pats per minute")
        }
    }

    private func metricTile(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(ButterTheme.gold.opacity(0.7))
                Text(label)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
            }

            Text(value)
                .font(.system(.title, design: .monospaced, weight: .bold))
                .foregroundStyle(ButterTheme.textPrimary)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.5)
                .animation(reduceMotion ? nil : .default, value: value)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ButterTheme.surfaceBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
