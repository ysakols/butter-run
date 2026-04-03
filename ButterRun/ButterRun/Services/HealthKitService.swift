import Foundation
import HealthKit

class HealthKitService {
    private let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }

        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
              let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            return false
        }

        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            energyType,
            distanceType
        ]
        let typesToRead: Set<HKObjectType> = [
            bodyMassType
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

        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
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
            guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return false }
            let energySample = HKQuantitySample(
                type: energyType,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: run.totalCaloriesBurned),
                start: startDate,
                end: endDate
            )

            // Add distance sample
            guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return false }
            let distanceSample = HKQuantitySample(
                type: distanceType,
                quantity: HKQuantity(unit: .meter(), doubleValue: run.distanceMeters),
                start: startDate,
                end: endDate
            )

            try await builder.addSamples([energySample, distanceSample])

            // Add a pause/resume event to account for paused time so
            // HealthKit records active duration matching run.durationSeconds
            let totalElapsed = endDate.timeIntervalSince(startDate)
            let pausedTime = totalElapsed - run.durationSeconds
            if pausedTime > 1 {
                let pauseDate = endDate.addingTimeInterval(-pausedTime)
                let resumeDate = endDate
                try await builder.addWorkoutEvents([
                    HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: pauseDate, duration: 0), metadata: nil),
                    HKWorkoutEvent(type: .resume, dateInterval: DateInterval(start: resumeDate, duration: 0), metadata: nil)
                ])
            }

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
