import SwiftUI

struct SplitTable: View {
    struct SplitRow: Identifiable {
        var id: Int { index }
        let index: Int
        let pace: String
        let pats: String
        let elevation: String
        let isPartial: Bool
    }

    let splits: [SplitRow]
    let usesMiles: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text(usesMiles ? "Mile" : "Km")
                    .frame(width: 36, alignment: .leading)
                Text("Pace")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text("Pats")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text("Elev")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(ButterTheme.textSecondary)
            .padding(.bottom, 4)

            // Rows
            ForEach(splits) { split in
                HStack(spacing: 0) {
                    Text("\(split.index)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .frame(width: 36, alignment: .leading)
                    Text(split.pace)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(split.pats)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(split.elevation)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(ButterTheme.textPrimary)
                .padding(.vertical, 4)
                .opacity(split.isPartial ? 0.6 : 1.0)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Split \(split.index): pace \(split.pace), \(split.pats) pats, elevation \(split.elevation)")

                if split.id != splits.last?.id {
                    Divider()
                        .overlay(ButterTheme.textSecondary.opacity(0.15))
                }
            }
        }
    }
}
