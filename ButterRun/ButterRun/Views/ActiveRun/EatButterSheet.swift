import SwiftUI

struct EatButterSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onEat: (ButterServing, Double) -> Void

    @State private var customTsp: Double = 1.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("🧈")
                    .font(.system(size: 48))

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
                                Text(serving.emoji)
                                    .font(.title2)
                                Text(serving.displayName)
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                Spacer()
                                Text("\(String(format: "%.0f", serving.teaspoonEquivalent * 34)) cal")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(ButterTheme.textSecondary)
                            }
                            .padding(16)
                            .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                    }

                    // Custom amount
                    HStack {
                        Text("✏️")
                            .font(.title2)
                        Text("Custom")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                        Spacer()
                        TextField("tsp", value: $customTsp, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .keyboardType(.decimalPad)
                        Button("Add") {
                            onEat(.custom, customTsp)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ButterTheme.primary)
                    }
                    .padding(16)
                    .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
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
                }
            }
        }
    }
}
