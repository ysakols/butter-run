import SwiftUI

struct ChurnButton: View {
    let action: () -> Void

    @State private var isPressed = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer pulse ring
                Circle()
                    .fill(ButterTheme.primary.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseScale)

                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ButterTheme.primary, ButterTheme.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 130, height: 130)
                    .shadow(color: ButterTheme.primary.opacity(0.4), radius: 12, y: 6)

                // Label
                VStack(spacing: 4) {
                    Text("🧈")
                        .font(.system(size: 32))
                    Text("CHURN")
                        .font(.system(.title3, design: .rounded, weight: .black))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.08
            }
        }
    }
}
