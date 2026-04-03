import SwiftUI

struct ChurnButton: View {
    let action: () -> Void

    @State private var isPressed = false
    @State private var pulseScale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer pulse ring
                Circle()
                    .fill(ButterTheme.gold.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseScale)

                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ButterTheme.gold, ButterTheme.goldDim],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 130, height: 130)
                    .shadow(color: ButterTheme.gold.opacity(0.4), radius: 12, y: 6)

                // Label
                VStack(spacing: 4) {
                    Image("butter-pat")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .accessibilityHidden(true)
                    Text("CHURN")
                        .font(.system(.title3, design: .rounded, weight: .black))
                        .foregroundStyle(ButterTheme.background)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.08
            }
        }
        .accessibilityLabel("Start run")
    }
}
