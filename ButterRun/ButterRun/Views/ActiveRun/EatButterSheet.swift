import SwiftUI

struct EatButterSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onEat: (ButterServing, Double) -> Void

    @State private var customTsp: Double = 1.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image("butter-pat")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)

                Text("How much butter?")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(ButterTheme.textPrimary)

                VStack(spacing: 12) {
                    ForEach(
                        [ButterServing.teaspoon, .pat, .tablespoon, .halfStick],
                        id: \.rawValue
                    ) { serving in
                        Button {
                            onEat(serving, 0)
                            dismiss()
                        } label: {
                            HStack {
                                Text(serving.displayName)
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                    .foregroundStyle(ButterTheme.textPrimary)
                                Spacer()
                                Text("\(String(format: "%.0f", serving.teaspoonEquivalent * 34)) cal")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(ButterTheme.textSecondary)
                            }
                            .padding(16)
                            .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .frame(minHeight: 44)
                        .accessibilityLabel("\(serving.displayName), \(String(format: "%.0f", serving.teaspoonEquivalent * 34)) calories")
                    }

                    // Custom amount
                    HStack {
                        Text("Custom")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(ButterTheme.textPrimary)
                        Spacer()
                        TextField("tsp", value: $customTsp, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .keyboardType(.decimalPad)
                            .accessibilityLabel("Custom amount in teaspoons")
                        Text("tsp")
                            .foregroundStyle(ButterTheme.textSecondary)
                        Button("Add") {
                            onEat(.custom, customTsp)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ButterTheme.gold)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .padding(16)
                    .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                Spacer()
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
        }
        .preferredColorScheme(.dark)
    }
}
