import SwiftUI

struct InfoButton: View {
    let title: String
    let bodyText: String
    @State private var showPopover = false

    var body: some View {
        Button { showPopover.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ButterTheme.textSecondary)
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Info")
        .accessibilityHint(title)
        .popover(isPresented: $showPopover) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(ButterTheme.textPrimary)
                Text(bodyText)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(width: 260)
            .presentationCompactAdaptation(.popover)
        }
    }
}
