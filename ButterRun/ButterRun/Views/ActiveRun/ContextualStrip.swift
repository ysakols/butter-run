import SwiftUI

/// Combined Butter Zero balance + Churn progress strip for the active run screen.
struct ContextualStrip: View {
    let isButterZero: Bool
    let isChurnEnabled: Bool
    let burnedTsp: Double
    let eatenTsp: Double
    let churnProgress: Double
    let churnStage: ChurnStage
    let onQuickEat: () -> Void

    private var netTsp: Double { eatenTsp - burnedTsp }
    private var isNearZero: Bool { abs(netTsp) < 0.3 }

    var body: some View {
        VStack(spacing: 8) {
            // Butter Zero row
            if isButterZero {
                HStack {
                    Text("BZ:")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(ButterTheme.textSecondary)

                    Image(systemName: netTsp >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                        .foregroundStyle(netColor)

                    Text(netLabel)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(netColor)

                    Spacer()

                    Button(action: onQuickEat) {
                        Text("Eat")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(ButterTheme.background)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(ButterTheme.gold, in: Capsule())
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Eat butter, quick add one teaspoon")
                }
            }

            // Churn progress row
            if isChurnEnabled {
                HStack(spacing: 8) {
                    Text("Churn:")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(ButterTheme.textSecondary)

                    GeometryReader { geo in
                        let width = geo.size.width
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.1))
                                .frame(height: 8)
                            Capsule()
                                .fill(ButterTheme.gold)
                                .frame(width: width * min(1, churnProgress), height: 8)
                                .animation(.easeOut(duration: 0.3), value: churnProgress)
                        }
                    }
                    .frame(height: 8)

                    Text(churnStage.name)
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(ButterTheme.gold)
                        .accessibilityLabel("Churn stage: \(churnStage.name)")
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(composedAccessibilityLabel)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var netLabel: String {
        let sign = netTsp >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", netTsp)) tsp"
    }

    private var netColor: Color {
        if isNearZero { return ButterTheme.success }
        return netTsp > 0 ? ButterTheme.success : ButterTheme.deficit
    }

    private var composedAccessibilityLabel: String {
        var parts: [String] = []
        if isButterZero {
            parts.append("Butter Zero balance: \(netLabel)")
        }
        if isChurnEnabled {
            parts.append("Churn stage: \(churnStage.name), \(Int(churnProgress * 100)) percent")
        }
        return parts.joined(separator: ". ")
    }
}
