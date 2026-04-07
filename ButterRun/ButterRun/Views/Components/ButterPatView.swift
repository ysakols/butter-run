import SwiftUI

struct ButterPatView: View {
    enum Style {
        case solid
        case melting
    }

    let size: CGFloat
    let style: Style

    init(size: CGFloat = 80, style: Style = .solid) {
        self.size = size
        self.style = style
    }

    private var showKnifeMark: Bool { size >= 48 }

    var body: some View {
        VStack(spacing: 0) {
            // Main butter body
            ZStack {
                // Body with gradient
                RoundedRectangle(cornerRadius: size * 0.08)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "FFF9E0"),
                                Color(hex: "F3BA60"),
                                Color(hex: "D4940A")
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size, height: size * 0.58)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.08)
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                    )

                // Top highlight
                RoundedRectangle(cornerRadius: size * 0.05)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.5), Color.white.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.9, height: size * 0.24)
                    .offset(y: -(size * 0.12))

                // Knife mark
                if showKnifeMark {
                    KnifeMarkShape()
                        .stroke(Color(hex: "C4943F").opacity(0.5), style: StrokeStyle(lineWidth: size * 0.02, lineCap: .round))
                        .frame(width: size * 0.55, height: size * 0.15)
                        .offset(y: -(size * 0.08))
                }
            }

            // Melt puddle (melting style only)
            if style == .melting {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "F3BA60").opacity(0.35), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.4
                        )
                    )
                    .frame(width: size * 0.85, height: size * 0.15)
                    .offset(y: -2)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct KnifeMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.2))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY - rect.height * 0.2),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}
