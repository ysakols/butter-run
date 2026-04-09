import SwiftUI

/// Combined Butter Zero balance + Churn progress strip for the active run screen.
struct ContextualStrip: View {
    let isButterZero: Bool
    let isChurnEnabled: Bool
    let burnedTsp: Double
    let eatenTsp: Double
    let churnProgress: Double
    let churnStage: ChurnStage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var netTsp: Double { eatenTsp - burnedTsp }
    private var isNearZero: Bool { abs(netTsp) < 0.3 }

    var body: some View {
        VStack(spacing: isButterZero && isChurnEnabled ? 12 : 0) {
            // Butter Zero section
            if isButterZero {
                VStack(spacing: 8) {
                    HStack {
                        Text("Butter Zero")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(ButterTheme.textSecondary)
                        InfoButton(title: "Butter Zero", bodyText: "Eat butter during your run and try to match what you burn. Track as + or − pats from net zero.")

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: netTsp >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption2)
                                .foregroundStyle(netColor)

                            Text(netLabel)
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(netColor)
                        }
                    }

                    ButterZeroScale(netPats: netTsp, showLabels: false)
                }
                .padding(12)
                .background(ButterTheme.goldLight, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ButterTheme.surfaceBorder, lineWidth: 1))
            }

            // Churn Tracker section
            if isChurnEnabled {
                VStack(spacing: 10) {
                    HStack {
                        Text("Churn Tracker")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(ButterTheme.textSecondary)

                        Spacer()

                        Text(churnStage.name)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(ButterTheme.gold)
                    }

                    // Stage markers and progress bar
                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            let width = geo.size.width
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(ButterTheme.surfaceBorder)
                                    .frame(height: 8)
                                Capsule()
                                    .fill(ButterTheme.gold)
                                    .frame(width: width * min(1, churnProgress), height: 8)
                                    .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: churnProgress)
                            }
                        }
                        .frame(height: 8)

                        // Stage labels along the bar
                        HStack {
                            Text("Liquid")
                            Spacer()
                            Text("Foamy")
                            Spacer()
                            Text("Whipped")
                            Spacer()
                            Text("Butter")
                        }
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
                    }
                }
                .padding(12)
                .background(ButterTheme.goldLight, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ButterTheme.surfaceBorder, lineWidth: 1))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(composedAccessibilityLabel)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var netLabel: String {
        let sign = netTsp >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", netTsp)) pats"
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
