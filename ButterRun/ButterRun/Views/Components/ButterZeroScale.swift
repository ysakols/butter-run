import SwiftUI

struct ButterZeroScale: View {
    let netPats: Double
    let maxAbsNetPats: Double
    let showLabels: Bool
    let showDetail: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(netPats: Double, maxAbsNetPats: Double = 5.0, showLabels: Bool = true, showDetail: Bool = false) {
        self.netPats = netPats
        self.maxAbsNetPats = max(abs(netPats) * 1.25, max(maxAbsNetPats, 2.0))
        self.showLabels = showLabels
        self.showDetail = showDetail
    }

    private var dotColor: Color {
        let absNet = abs(netPats)
        if absNet < 0.5 { return ButterTheme.gold }
        if absNet < 2.0 { return ButterTheme.success }
        if absNet < 4.0 { return ButterTheme.goldDim }
        return ButterTheme.deficit
    }

    private var valueColor: Color {
        let absNet = abs(netPats)
        if absNet < 0.5 { return ButterTheme.gold }
        if netPats > 0 { return ButterTheme.success }
        return ButterTheme.deficit
    }

    var body: some View {
        VStack(spacing: 4) {
            // Track with dot
            GeometryReader { geo in
                let width = geo.size.width
                let center = width / 2
                let clampedNet = max(-maxAbsNetPats, min(maxAbsNetPats, netPats))
                let dotX = center + (clampedNet / maxAbsNetPats) * (width / 2 - 8)

                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.gray.opacity(0.12))
                        .frame(height: 6)

                    // Fill from center
                    if abs(netPats) > 0.05 {
                        let fillStart = netPats > 0 ? center : dotX
                        let fillWidth = abs(dotX - center)
                        Capsule()
                            .fill(dotColor.opacity(0.3))
                            .frame(width: fillWidth, height: 6)
                            .offset(x: fillStart)
                    }

                    // Center marker (thin line)
                    Rectangle()
                        .fill(ButterTheme.textSecondary.opacity(0.3))
                        .frame(width: 1, height: 10)
                        .offset(x: center - 0.5)

                    // Dot
                    Circle()
                        .fill(dotColor)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                        .offset(x: dotX - 6)
                        .animation(reduceMotion ? nil : .spring(response: 0.3), value: netPats)
                }
            }
            .frame(height: 12)

            // Labels
            if showLabels {
                HStack {
                    Text("\u{2212} pats")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
                    Spacer()
                    Text("net zero")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
                    Spacer()
                    Text("+ pats")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Butter Zero balance: \(ButterFormatters.netPats(netPats))")
    }
}
