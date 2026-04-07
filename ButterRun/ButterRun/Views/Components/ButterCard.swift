import SwiftUI

struct ButterCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(ButterSpacing.cardPadding)
            .background(ButterTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: ButterSpacing.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: ButterSpacing.cardCornerRadius)
                    .strokeBorder(Color(hex: "F0E6D0").opacity(0.2), lineWidth: 1.5)
            )
    }
}
