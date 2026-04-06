import SwiftUI

struct OnboardingPage: View {
    let emoji: String
    let title: String
    let bodyText: String
    let pageIndex: Int
    let totalPages: Int
    let content: AnyView?

    init(emoji: String, title: String, body: String, pageIndex: Int, totalPages: Int, @ViewBuilder content: () -> some View = { EmptyView() }) {
        self.emoji = emoji
        self.title = title
        self.bodyText = body
        self.pageIndex = pageIndex
        self.totalPages = totalPages
        self.content = AnyView(content())
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

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

            if let content {
                content
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
            }

            Spacer()

            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<totalPages, id: \.self) { i in
                    if i == pageIndex {
                        Capsule()
                            .fill(ButterTheme.gold)
                            .frame(width: 20, height: 7)
                    } else {
                        Circle()
                            .fill(ButterTheme.textSecondary.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }
}
