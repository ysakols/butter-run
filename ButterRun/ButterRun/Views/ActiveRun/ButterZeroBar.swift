import SwiftUI

struct ButterZeroBar: View {
    let burnedTsp: Double
    let eatenTsp: Double

    private var netTsp: Double {
        eatenTsp - burnedTsp
    }

    private var isAtZero: Bool {
        abs(netTsp) < 0.3
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Butter Zero")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(netLabel)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(netColor)
            }

            GeometryReader { geo in
                let width = geo.size.width
                let center = width / 2.0

                // Calculate offset: clamp between -5 and +5 tsp for display
                let clamped = min(5.0, max(-5.0, netTsp))
                let offset = (clamped / 5.0) * (width / 2.0)

                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(.white.opacity(0.1))
                        .frame(height: 8)

                    // Fill from center
                    Capsule()
                        .fill(netColor)
                        .frame(
                            width: abs(offset),
                            height: 8
                        )
                        .offset(x: offset >= 0 ? center : center + offset)

                    // Center marker (zero line)
                    Circle()
                        .fill(isAtZero ? ButterTheme.success : .white)
                        .frame(width: 14, height: 14)
                        .offset(x: center - 7)
                        .shadow(color: isAtZero ? ButterTheme.success.opacity(0.6) : .clear, radius: 6)

                    // Indicator dot
                    Circle()
                        .fill(netColor)
                        .frame(width: 10, height: 10)
                        .offset(x: center + offset - 5)
                        .animation(.spring(response: 0.3), value: netTsp)
                }
            }
            .frame(height: 14)

            HStack {
                Text("deficit")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(ButterTheme.deficit.opacity(0.6))
                Spacer()
                Text("surplus")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(ButterTheme.success.opacity(0.6))
            }
        }
        .padding(16)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private var netLabel: String {
        let sign = netTsp >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", netTsp)) tsp"
    }

    private var netColor: Color {
        if isAtZero { return ButterTheme.success }
        return netTsp > 0 ? ButterTheme.success : ButterTheme.deficit
    }
}
