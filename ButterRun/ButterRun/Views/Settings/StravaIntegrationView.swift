import SwiftUI

// MARK: - Compact Row for Settings List

/// A compact row version of Strava integration that fits inside a List Section.
struct StravaIntegrationRow: View {
    @EnvironmentObject private var stravaAuth: StravaAuthService
    @Binding var autoShareToStrava: Bool

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDisconnectConfirmation = false

    private let stravaOrange = Color(red: 0.99, green: 0.32, blue: 0.15)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Strava")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(ButterTheme.textPrimary)
                    Text(stravaAuth.isAuthenticated ? "Connected" : "Not connected")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(stravaAuth.isAuthenticated ? ButterTheme.success : ButterTheme.textSecondary)
                }
                Spacer()

                if stravaAuth.isAuthenticated {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ButterTheme.success)
                } else {
                    Button {
                        connectStrava()
                    } label: {
                        Text(stravaAuth.isAuthorizing ? "..." : "Connect")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(stravaOrange, in: Capsule())
                    }
                    .disabled(stravaAuth.isAuthorizing)
                }
            }

            if stravaAuth.isAuthenticated {
                HStack {
                    Toggle("Auto-share runs", isOn: $autoShareToStrava)
                        .font(.system(.caption, design: .rounded))
                        .tint(stravaOrange)
                }

                Button {
                    showDisconnectConfirmation = true
                } label: {
                    Text("Disconnect")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
                }
            }
        }
        .confirmationDialog("Disconnect Strava?", isPresented: $showDisconnectConfirmation, titleVisibility: .visible) {
            Button("Disconnect", role: .destructive) {
                stravaAuth.disconnect()
                autoShareToStrava = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your Strava account will be unlinked.")
        }
        .alert("Connection Failed", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func connectStrava() {
        guard StravaConfig.isConfigured else {
            errorMessage = "Strava is not configured."
            showError = true
            return
        }
        stravaAuth.authorize()
    }
}
