import Foundation
import HealthKit

class HealthKitService {
    private let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }

        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            return true
        } catch {
            return false
        }
    }

    func readWeight() async -> Double? {
        guard isAvailable else { return nil }

        let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            healthStore.execute(query)
        }
    }

    func saveWorkout(run: Run) async -> Bool {
        guard isAvailable else { return false }

        let startDate = run.startDate
        let endDate = run.endDate ?? Date()

        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor

        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: config,
            device: .local()
        )

        do {
            try await builder.beginCollection(at: startDate)

            // Add energy burned sample
            let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let energySample = HKQuantitySample(
                type: energyType,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: run.totalCaloriesBurned),
                start: startDate,
                end: endDate
            )

            // Add distance sample
            let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
            let distanceSample = HKQuantitySample(
                type: distanceType,
                quantity: HKQuantity(unit: .meter(), doubleValue: run.distanceMeters),
                start: startDate,
                end: endDate
            )

            try await builder.addSamples([energySample, distanceSample])
            try await builder.endCollection(at: endDate)
            try await builder.addMetadata([
                "ButterBurnedTsp": run.totalButterBurnedTsp,
                "Source": "Butter Run"
            ])
            try await builder.finishWorkout()
            return true
        } catch {
            builder.discardWorkout()
            return false
        }
    }
}
