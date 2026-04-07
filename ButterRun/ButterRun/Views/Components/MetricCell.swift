import SwiftUI

struct MetricCell: View {
    let value: String
    let label: String
    let icon: String?

    init(_ value: String, label: String, icon: String? = nil) {
        self.value = value
        self.label = label
        self.icon = icon
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(ButterTheme.textPrimary)

            HStack(spacing: 3) {
                if let icon {
                    Text(icon)
                        .font(.system(size: 10))
                }
                Text(label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(ButterTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(ButterTheme.goldDim.opacity(0.2), lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
