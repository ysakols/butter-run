import SwiftUI

struct GoldButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Text(icon)
                }
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .frame(height: ButterSpacing.buttonHeight)
            .foregroundStyle(ButterTheme.onPrimaryAction)
            .background(ButterTheme.gold)
            .clipShape(RoundedRectangle(cornerRadius: ButterSpacing.buttonCornerRadius))
        }
    }
}

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let destructive: Bool
    let action: () -> Void

    init(_ title: String, icon: String? = nil, destructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.destructive = destructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Text(icon)
                }
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .frame(height: ButterSpacing.buttonHeight)
            .foregroundStyle(destructive ? ButterTheme.deficit : ButterTheme.textPrimary)
            .background(ButterTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: ButterSpacing.buttonCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: ButterSpacing.buttonCornerRadius)
                    .strokeBorder(destructive ? ButterTheme.deficit : ButterTheme.goldDim.opacity(0.3), lineWidth: 1.5)
            )
        }
    }
}
