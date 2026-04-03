import SwiftUI

/// A visual butter stick that "melts" based on a percentage (0.0 = full, 1.0 = fully melted).
struct ButterStickView: View {
    let meltPercentage: Double // 0.0 to 1.0

    private var clampedMelt: Double {
        min(1.0, max(0.0, meltPercentage))
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let meltHeight = height * clampedMelt

            ZStack(alignment: .bottom) {
                // Butter stick (remaining)
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "FFF176"),
                                ButterTheme.primary,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: height - meltHeight)
                    .frame(maxHeight: .infinity, alignment: .top)

                // Melted puddle
                if clampedMelt > 0.05 {
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ButterTheme.primary.opacity(0.6),
                                    ButterTheme.accent.opacity(0.4),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(
                            width: width * (0.8 + clampedMelt * 0.4),
                            height: min(meltHeight * 0.4, 30)
                        )
                }
            }
            .frame(width: width, height: height)
        }
    }
}

/// Shows a horizontal row of butter stick segments to visualize tablespoons burned.
struct ButterStickMeter: View {
    let tspBurned: Double
    let maxTsp: Double

    private var segments: Int {
        max(1, Int(ceil(maxTsp / 3.0))) // each segment = 1 tbsp (3 tsp)
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<segments, id: \.self) { i in
                let segmentStart = Double(i) * 3.0
                let segmentFill = min(1.0, max(0.0, (tspBurned - segmentStart) / 3.0))

                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        segmentFill >= 1.0
                            ? ButterTheme.accent
                            : segmentFill > 0
                                ? ButterTheme.primary.opacity(0.5)
                                : ButterTheme.primary.opacity(0.15)
                    )
                    .frame(height: 12)
            }
        }
    }
}
