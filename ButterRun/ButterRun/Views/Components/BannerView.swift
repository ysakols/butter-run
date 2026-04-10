import SwiftUI

struct BannerView: View {
    @Environment(\.colorScheme) private var colorScheme

    enum BannerType {
        case warn, error, info, pause

        func backgroundColor(for colorScheme: ColorScheme) -> Color {
            let base: Color = {
                switch self {
                case .warn: return Color(hex: "FFF3E0")
                case .error: return Color(hex: "FFE8E8")
                case .info: return Color(hex: "E8F4FE")
                case .pause: return ButterTheme.gold.opacity(0.15)
                }
            }()
            return colorScheme == .dark ? base.opacity(0.3) : base
        }

        var borderColor: Color {
            switch self {
            case .warn: return Color(hex: "F5A623")
            case .error: return ButterTheme.deficit
            case .info: return Color(hex: "64B5F6")
            case .pause: return ButterTheme.gold
            }
        }

        var textColor: Color {
            switch self {
            case .warn: return Color(hex: "E67E22")
            case .error: return ButterTheme.deficit
            case .info: return Color(hex: "1976D2")
            case .pause: return ButterTheme.goldDim
            }
        }
    }

    let type: BannerType
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(type.textColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(type.backgroundColor(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(type.borderColor, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: text)
        }
    }
}
