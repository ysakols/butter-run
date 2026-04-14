import SwiftUI

struct OnboardingPage<Content: View>: View {
    let emoji: String
    let title: String
    let bodyText: String
    let content: Content

    init(emoji: String, title: String, body: String, @ViewBuilder content: () -> Content) {
        self.emoji = emoji
        self.title = title
        self.bodyText = body
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(emoji)
                .font(.system(size: 48))

            Text(title)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(ButterTheme.textPrimary)
                .padding(.top, 12)

            Text(bodyText)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 6)

            content
                .padding(.top, 16)
                .padding(.horizontal, 16)
        }
    }
}
