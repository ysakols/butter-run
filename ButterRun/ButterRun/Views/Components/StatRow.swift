import SwiftUI

struct StatRow: View {
    struct Stat: Identifiable {
        let id = UUID()
        let value: String
        let label: String
    }

    let stats: [Stat]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                if index > 0 {
                    Divider()
                        .frame(height: 28)
                        .overlay(ButterTheme.textSecondary.opacity(0.2))
                }

                VStack(spacing: 2) {
                    Text(stat.value)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(ButterTheme.textPrimary)
                    Text(stat.label)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 10)
    }
}
