import SwiftUI

struct AchievementUnlockOverlay: View {
    let achievements: [AchievementType]
    let onDismiss: () -> Void

    @State private var currentIndex = 0
    @State private var showContent = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var current: AchievementType? {
        guard currentIndex < achievements.count else { return nil }
        return achievements[currentIndex]
    }

    var body: some View {
        ZStack {
            // Cream overlay background
            ButterTheme.background
                .ignoresSafeArea()
                .opacity(0.97)

            if let achievement = current {
                VStack(spacing: 24) {
                    Spacer()

                    // Achievement emoji (large)
                    Text(achievement.emoji)
                        .font(.system(size: 72))
                        .scaleEffect(showContent ? 1.0 : 0.3)
                        .opacity(showContent ? 1 : 0)

                    // Title
                    Text("Achievement Unlocked!")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(ButterTheme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .opacity(showContent ? 1 : 0)

                    // Achievement name
                    Text(achievement.displayName)
                        .font(.system(.title, design: .rounded, weight: .black))
                        .foregroundStyle(ButterTheme.gold)
                        .opacity(showContent ? 1 : 0)

                    // Description
                    Text(achievement.description)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .opacity(showContent ? 1 : 0)

                    Spacer()

                    // Button
                    Button {
                        if currentIndex < achievements.count - 1 {
                            withAnimation(reduceMotion ? nil : .spring(response: 0.4)) {
                                showContent = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.05 : 0.3)) {
                                currentIndex += 1
                                withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7)) {
                                    showContent = true
                                }
                            }
                        } else {
                            onDismiss()
                        }
                    } label: {
                        Text(currentIndex < achievements.count - 1 ? "Next" : "Awesome!")
                            .font(ButterTypography.buttonText)
                            .foregroundStyle(ButterTheme.onPrimaryAction)
                            .frame(maxWidth: .infinity)
                            .frame(height: ButterSpacing.buttonHeight)
                            .background(ButterTheme.gold, in: RoundedRectangle(cornerRadius: ButterSpacing.buttonCornerRadius))
                    }
                    .accessibilityLabel(currentIndex < achievements.count - 1 ? "Next achievement" : "Dismiss")
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
                }
            }
        }
        .onAppear {
            guard !achievements.isEmpty else {
                DispatchQueue.main.async { onDismiss() }
                return
            }
            withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                showContent = true
            }
            if let achievement = current {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Achievement unlocked: \(achievement.displayName)"
                )
            }
        }
    }
}
