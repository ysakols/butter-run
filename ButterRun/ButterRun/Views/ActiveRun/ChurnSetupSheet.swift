import SwiftUI

struct ChurnSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onStart: (ChurnConfiguration) -> Void

    @State private var creamType = "heavy"
    @State private var creamCups: Double = 1.0
    @State private var isRoomTemp = false
    @State private var showRoomTempWarning = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ButterPatView(size: 48, style: .solid)
                    .accessibilityHidden(true)

                Text("Churn Setup")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(ButterTheme.textPrimary)

                Text("Tell us about your cream so we can estimate churning progress.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 16) {
                    // Cream type
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Cream Type")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(ButterTheme.textSecondary)

                        Picker("Cream Type", selection: $creamType) {
                            Text("Heavy Cream (36%+)").tag("heavy")
                            Text("Whipping Cream (30%)").tag("whipping")
                        }
                        .pickerStyle(.segmented)
                    }

                    // Amount
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Amount")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(ButterTheme.textSecondary)

                        HStack {
                            TextField("cups", value: $creamCups, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .keyboardType(.decimalPad)
                            Text("cups")
                                .foregroundStyle(ButterTheme.textSecondary)
                        }
                    }

                    // Room temp toggle
                    Toggle(isOn: $isRoomTemp) {
                        Text("Cream is room temperature")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(ButterTheme.textPrimary)
                    }
                    .tint(ButterTheme.gold)
                    .onChange(of: isRoomTemp) { _, newValue in
                        if newValue {
                            showRoomTempWarning = true
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                Button {
                    let validCups = creamCups.isFinite ? creamCups : 1.0
                    let config = ChurnConfiguration(
                        creamType: creamType,
                        creamCups: min(20.0, max(0.1, validCups)),
                        isRoomTemp: isRoomTemp
                    )
                    onStart(config)
                } label: {
                    Text("Start Churning")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(ButterTheme.onPrimaryAction)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ButterTheme.gold, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding(.top, 24)
            .background(ButterTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ButterTheme.textSecondary)
                }
            }
            .alert("Room Temperature Warning", isPresented: $showRoomTempWarning) {
                Button("OK") {}
            } message: {
                Text("Room temperature cream won't churn properly. For best results, use cold cream. Progress will be capped at the Whipped stage.")
            }
        }
    }
}
