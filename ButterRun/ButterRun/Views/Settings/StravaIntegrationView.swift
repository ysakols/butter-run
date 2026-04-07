import SwiftUI

/// A polished card-style view for managing the Strava integration.
/// Shows connection status, athlete info, auto-share toggle, and connect/disconnect actions.
struct StravaIntegrationView: View {
    @EnvironmentObject private var stravaAuth: StravaAuthService
    @Binding var autoShareToStrava: Bool

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDisconnectConfirmation = false

    /// Strava brand orange
    private let stravaOrange = Color(red: 0.99, green: 0.32, blue: 0.15)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Content
            if stravaAuth.isAuthenticated {
                connectedContent
            } else {
                disconnectedContent
            }
        }
        .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(stravaAuth.isAuthenticated ? ButterTheme.success.opacity(0.3) : ButterTheme.surfaceBorder, lineWidth: 1)
        )
        .confirmationDialog(
            "Disconnect Strava?",
            isPresented: $showDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) {
                disconnectStrava()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your Strava account will be unlinked. You can reconnect anytime.")
        }
        .alert("Connection Failed", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            // Strava icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(stravaOrange)
                    .frame(width: 40, height: 40)

                Image(systemName: "figure.run")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Strava")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(ButterTheme.textPrimary)

                Text(stravaAuth.isAuthenticated ? "Connected" : "Not connected")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(stravaAuth.isAuthenticated ? ButterTheme.success : ButterTheme.textSecondary)
            }

            Spacer()

            // Status badge
            statusBadge
        }
        .padding(16)
    }

    private var statusBadge: some View {
        Group {
            if stravaAuth.isAuthenticated {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(ButterTheme.success)
            } else {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 22))
                    .foregroundStyle(ButterTheme.textSecondary.opacity(0.5))
            }
        }
    }

    // MARK: - Connected

    private var connectedContent: some View {
        VStack(spacing: 0) {
            divider

            // Athlete info
            if let name = stravaAuth.athleteName, !name.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(stravaOrange.opacity(0.8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(ButterTheme.textPrimary)
                        Text("Strava Athlete")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(ButterTheme.textSecondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                divider
            }

            // Auto-share toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-share runs")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(ButterTheme.textPrimary)
                    Text("Upload to Strava when you finish a run")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
                }

                Spacer()

                Toggle("", isOn: $autoShareToStrava)
                    .tint(stravaOrange)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            divider

            // Disconnect button
            Button {
                showDisconnectConfirmation = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "link.badge.plus")
                        .rotationEffect(.degrees(45))
                    Text("Disconnect")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                }
                .foregroundStyle(ButterTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Disconnected

    private var disconnectedContent: some View {
        VStack(spacing: 0) {
            divider

            // Description
            VStack(spacing: 8) {
                Text("Share your Butter Runs on Strava")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(ButterTheme.textPrimary)

                Text("Upload activities with distance, pace, route, and butter stats automatically after each run.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Connect button
            Button {
                connectStrava()
            } label: {
                HStack(spacing: 8) {
                    if stravaAuth.isAuthorizing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "link")
                            .font(.system(size: 14, weight: .bold))
                    }

                    Text(stravaAuth.isAuthorizing ? "Connecting..." : "Connect Strava")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(stravaOrange, in: RoundedRectangle(cornerRadius: 10))
            }
            .disabled(stravaAuth.isAuthorizing)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(ButterTheme.surfaceBorder)
            .frame(height: 1)
    }

    // MARK: - Actions

    private func connectStrava() {
        guard StravaConfig.isConfigured else {
            errorMessage = "Strava is not configured. Developer needs to set client credentials in StravaConfig."
            showError = true
            return
        }

        // isAuthorizing is managed by StravaAuthService and clears when auth completes or fails
        stravaAuth.authorize()
    }

    private func disconnectStrava() {
        stravaAuth.disconnect()
        autoShareToStrava = false
    }
}
