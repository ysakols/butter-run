import SwiftUI

struct SheetHeader: View {
    let title: String
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 12)

            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(ButterTheme.textPrimary)

                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)
            }
            .padding(.horizontal, ButterSpacing.horizontalPadding)
            .padding(.bottom, 12)
        }
    }
}
