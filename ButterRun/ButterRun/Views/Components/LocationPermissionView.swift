import SwiftUI
import CoreLocation

struct LocationPermissionView: View {
    let onAllow: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "location.circle")
                .font(.system(size: 56))
                .foregroundStyle(ButterTheme.gold)
                .accessibilityHidden(true)

            Text("Location Access")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(ButterTheme.textPrimary)

            Text("Butter Run needs your location to track distance, pace, and route during runs.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Privacy assurance
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(ButterTheme.success)
                Text("We never share your location data; it is only saved locally on your phone (unless you share it via an integration).")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
            }
            .padding(12)
            .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ButterTheme.surfaceBorder, lineWidth: 1))
            .padding(.horizontal, 24)
            .accessibilityElement(children: .combine)

            Spacer()

            // Allow button
            Button {
                onAllow()
            } label: {
                Text("Allow Location")
                    .font(ButterTypography.buttonText)
                    .foregroundStyle(ButterTheme.onPrimaryAction)
                    .frame(maxWidth: .infinity)
                    .frame(height: ButterSpacing.buttonHeight)
                    .background(ButterTheme.gold, in: RoundedRectangle(cornerRadius: ButterSpacing.buttonCornerRadius))
            }
            .accessibilityLabel("Allow Location")
            .accessibilityHint("Grant location access to track your runs")
            .padding(.horizontal, 32)

            // Not now
            Button {
                onDeny()
            } label: {
                Text("Not Now")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
            }
            .accessibilityLabel("Not Now")
            .accessibilityHint("Skip location access for now")
            .padding(.bottom, 32)
        }
        .background(ButterTheme.background.ignoresSafeArea())
    }
}
