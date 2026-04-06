import SwiftUI

struct HistoryRow: View {
    let date: String
    let subtitle: String
    let pats: String
    let calories: String
    let badges: [String]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(date)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(ButterTheme.textPrimary)

                HStack(spacing: 4) {
                    Text(subtitle)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)

                    ForEach(badges, id: \.self) { badge in
                        Text(badge)
                            .font(.system(size: 10))
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(pats)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(ButterTheme.textPrimary)
                Text(calories)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
            }
        }
        .padding(.vertical, 8)
    }
}
