import SwiftUI

struct RunEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var run: Run
    let usesMiles: Bool

    @State private var distanceValue: Double = 0
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    // Distance (editable)
                    HStack {
                        Text("Distance")
                            .foregroundStyle(ButterTheme.textPrimary)
                        Spacer()
                        TextField("0.0", value: $distanceValue, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .keyboardType(.decimalPad)
                        Text(usesMiles ? "mi" : "km")
                            .foregroundStyle(ButterTheme.textSecondary)
                    }

                    // Duration (read-only)
                    HStack {
                        Text("Duration")
                            .foregroundStyle(ButterTheme.textPrimary)
                        Spacer()
                        Text(run.formattedDuration)
                            .foregroundStyle(ButterTheme.textSecondary)
                    }

                    // Date (read-only)
                    HStack {
                        Text("Date")
                            .foregroundStyle(ButterTheme.textPrimary)
                        Spacer()
                        Text(run.startDate, format: .dateTime.month().day().year())
                            .foregroundStyle(ButterTheme.textSecondary)
                    }

                    Divider()

                    // Notes
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(ButterTheme.textSecondary)
                        TextEditor(text: $notes)
                            .frame(height: 100)
                            .scrollContentBackground(.hidden)
                            .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(ButterTheme.textPrimary)
                    }
                }
                .padding(.horizontal)

                Spacer()

                Button {
                    saveChanges()
                } label: {
                    Text("Save Changes")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(ButterTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ButterTheme.gold, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
            .padding(.top, 24)
            .background(ButterTheme.background.ignoresSafeArea())
            .navigationTitle("Edit Run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ButterTheme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            distanceValue = usesMiles ? run.distanceMiles : run.distanceKm
            notes = run.notes ?? ""
        }
    }

    private func saveChanges() {
        let newDistanceMeters = usesMiles ? distanceValue * 1609.344 : distanceValue * 1000.0
        run.distanceMeters = newDistanceMeters
        run.notes = notes.isEmpty ? nil : notes

        // Recalculate pace
        if newDistanceMeters > 0 {
            run.averagePaceSecondsPerKm = run.durationSeconds / (newDistanceMeters / 1000.0)
        }

        dismiss()
    }
}
