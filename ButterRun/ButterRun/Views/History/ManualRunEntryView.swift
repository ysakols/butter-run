import SwiftUI
import SwiftData

struct ManualRunEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @State private var date = Date()
    @State private var distanceValue: Double = 0
    @State private var durationMinutes: Double = 0
    @State private var useMiles = true

    private var profile: UserProfile? { profiles.first }

    private var distanceMeters: Double {
        useMiles ? distanceValue * 1609.344 : distanceValue * 1000.0
    }

    private var durationSeconds: Double {
        durationMinutes * 60.0
    }

    private var estimatedButter: Double {
        guard durationSeconds > 0, distanceMeters > 0 else { return 0 }
        let weightKg = profile?.weightKg ?? 70.0
        let speedMps = distanceMeters / durationSeconds
        let speedMph = ButterCalculator.metersPerSecondToMph(speedMps)
        let met = ButterCalculator.metValue(forSpeedMph: speedMph)
        let calories = ButterCalculator.caloriesBurned(
            weightKg: weightKg,
            met: met,
            durationMinutes: durationMinutes
        )
        return ButterCalculator.caloriesToButterTsp(calories)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Log a Run")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(ButterTheme.textPrimary)

                VStack(spacing: 16) {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(ButterTheme.gold)

                    HStack {
                        Text("Distance")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(ButterTheme.textPrimary)
                            .frame(width: 80, alignment: .leading)
                        TextField("0.0", value: $distanceValue, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .keyboardType(.decimalPad)
                        Text(useMiles ? "mi" : "km")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(ButterTheme.textSecondary)
                            .frame(width: 30, alignment: .leading)
                    }

                    HStack {
                        Text("Duration")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(ButterTheme.textPrimary)
                            .frame(width: 80, alignment: .leading)
                        TextField("0", value: $durationMinutes, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .keyboardType(.decimalPad)
                        Text("min")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(ButterTheme.textSecondary)
                            .frame(width: 30, alignment: .leading)
                    }

                    Picker("Units", selection: $useMiles) {
                        Text("Miles").tag(true)
                        Text("Kilometers").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                if estimatedButter > 0 {
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f pats", estimatedButter))
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(ButterTheme.gold)
                        Text("Estimated butter burned")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(ButterTheme.textSecondary)
                    }
                    .padding()
                    .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                Spacer()

                Button {
                    saveManualRun()
                } label: {
                    Text("Save Run")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(ButterTheme.onPrimaryAction)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ButterTheme.gold, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .disabled(distanceValue <= 0 || durationMinutes <= 0)
                .opacity(distanceValue > 0 && durationMinutes > 0 ? 1.0 : 0.5)
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
        .onAppear {
            useMiles = profile?.usesMiles ?? true
        }
    }

    private func saveManualRun() {
        guard distanceValue > 0, durationMinutes > 0 else { return }
        let clampedDistance = min(distanceValue, 1000.0)
        let clampedDuration = min(durationMinutes, 2880.0)
        let distMeters = useMiles ? clampedDistance * 1609.344 : clampedDistance * 1000.0
        let durSeconds = clampedDuration * 60.0

        let run = Run(startDate: date, isButterZeroChallenge: false)
        run.endDate = date.addingTimeInterval(durSeconds)
        run.distanceMeters = distMeters
        run.durationSeconds = durSeconds
        run.isManualEntry = true

        if distMeters > 0 {
            run.averagePaceSecondsPerKm = durSeconds / (distMeters / 1000.0)
        }

        let weightKg = profile?.weightKg ?? 70.0
        let speedMps = distMeters > 0 ? distMeters / durSeconds : 0
        let speedMph = ButterCalculator.metersPerSecondToMph(speedMps)
        let butter = ButterCalculator.butterBurned(
            weightKg: weightKg, speedMph: speedMph, durationMinutes: clampedDuration
        )
        run.totalButterBurnedTsp = butter
        run.totalCaloriesBurned = butter * ButterCalculator.caloriesPerTeaspoon

        modelContext.insert(run)
        try? modelContext.save()
        dismiss()
    }
}
