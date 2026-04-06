import SwiftUI
import SwiftData

struct RunEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Bindable var run: Run
    let usesMiles: Bool

    @State private var distanceValue: Double = 0
    @State private var notes: String = ""
    @State private var durationHours: Int = 0
    @State private var durationMinutes: Int = 0
    @State private var durationSeconds: Int = 0
    @State private var runDate: Date = .now

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

                    // Duration (editable)
                    HStack {
                        Text("Duration")
                            .foregroundStyle(ButterTheme.textPrimary)
                        Spacer()
                        TextField("0", value: $durationHours, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .keyboardType(.numberPad)
                        Text("h")
                            .foregroundStyle(ButterTheme.textSecondary)
                        TextField("0", value: $durationMinutes, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .keyboardType(.numberPad)
                        Text("m")
                            .foregroundStyle(ButterTheme.textSecondary)
                        TextField("0", value: $durationSeconds, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .keyboardType(.numberPad)
                        Text("s")
                            .foregroundStyle(ButterTheme.textSecondary)
                    }

                    // Date (editable)
                    DatePicker("Date", selection: $runDate, displayedComponents: .date)
                        .foregroundStyle(ButterTheme.textPrimary)
                        .tint(ButterTheme.gold)

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
                        .foregroundStyle(ButterTheme.onPrimaryAction)
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
        .onAppear {
            distanceValue = usesMiles ? run.distanceMiles : run.distanceKm
            notes = run.notes ?? ""
            let totalSeconds = Int(run.durationSeconds)
            durationHours = totalSeconds / 3600
            durationMinutes = (totalSeconds % 3600) / 60
            durationSeconds = totalSeconds % 60
            runDate = run.startDate
        }
    }

    private func saveChanges() {
        let newDistanceMeters = usesMiles ? distanceValue * 1609.344 : distanceValue * 1000.0
        run.distanceMeters = newDistanceMeters
        run.notes = notes.isEmpty ? nil : notes

        // Update duration
        let newDurationSeconds = Double(durationHours * 3600 + durationMinutes * 60 + durationSeconds)
        run.durationSeconds = newDurationSeconds

        // Update date
        run.startDate = runDate

        // Recalculate pace
        if newDistanceMeters > 0 && newDurationSeconds > 0 {
            run.averagePaceSecondsPerKm = newDurationSeconds / (newDistanceMeters / 1000.0)
        }

        // Recalculate butter burned
        if newDurationSeconds > 0 {
            let weightKg = profiles.first?.weightKg ?? 70.0
            let durationMinutes = newDurationSeconds / 60.0
            let speedMps = newDistanceMeters > 0 ? newDistanceMeters / newDurationSeconds : 0
            let speedMph = ButterCalculator.metersPerSecondToMph(speedMps)
            let met = ButterCalculator.metValue(forSpeedMph: speedMph)
            let calories = ButterCalculator.caloriesBurned(
                weightKg: weightKg, met: met, durationMinutes: durationMinutes
            )
            run.totalCaloriesBurned = calories
            run.totalButterBurnedTsp = ButterCalculator.caloriesToButterTsp(calories)
            run.netButterTsp = run.totalButterEatenTsp - run.totalButterBurnedTsp
        }

        dismiss()
    }
}
