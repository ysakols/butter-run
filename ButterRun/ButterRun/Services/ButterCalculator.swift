import Foundation

struct ButterCalculator {
    static let caloriesPerTeaspoon: Double = 34.0
    static let caloriesPerTablespoon: Double = 102.0
    static let caloriesPerStick: Double = 810.0
    static let caloriesPerPound: Double = 3240.0

    // MET values indexed by speed in mph, sourced from the
    // Compendium of Physical Activities (2024 edition).
    private static let metTable: [(speedMph: Double, met: Double)] = [
        (2.0, 2.0),   // slow walk
        (3.0, 3.3),   // moderate walk
        (3.5, 3.8),   // brisk walk
        (4.0, 5.0),   // very brisk walk
        (5.0, 8.3),   // jogging
        (5.5, 9.0),
        (6.0, 9.8),   // moderate run
        (6.7, 10.5),
        (7.0, 11.0),  // tempo
        (8.0, 11.8),  // fast
        (9.0, 12.8),
        (10.0, 14.5), // sprint
        (14.0, 23.0), // elite sprint
    ]

    /// Interpolates MET value for a given speed in mph.
    static func metValue(forSpeedMph speed: Double) -> Double {
        guard speed > 0 else { return 1.0 }

        // Clamp to table range
        if speed <= metTable.first!.speedMph { return metTable.first!.met }
        if speed >= metTable.last!.speedMph { return metTable.last!.met }

        // Linear interpolation between two surrounding entries
        for i in 0..<(metTable.count - 1) {
            let lower = metTable[i]
            let upper = metTable[i + 1]
            if speed >= lower.speedMph && speed <= upper.speedMph {
                let ratio = (speed - lower.speedMph) / (upper.speedMph - lower.speedMph)
                return lower.met + ratio * (upper.met - lower.met)
            }
        }

        return 8.3 // fallback to jogging
    }

    /// Convert meters/second to miles/hour.
    static func metersPerSecondToMph(_ mps: Double) -> Double {
        mps * 2.23694
    }

    /// Calculate calories burned.
    /// Formula: Calories/min = (MET × 3.5 × weightKg) / 200
    static func caloriesBurned(
        weightKg: Double,
        met: Double,
        durationMinutes: Double
    ) -> Double {
        (met * 3.5 * weightKg / 200.0) * durationMinutes
    }

    /// Convert calories to teaspoons of butter.
    static func caloriesToButterTsp(_ calories: Double) -> Double {
        calories / caloriesPerTeaspoon
    }

    /// All-in-one: given weight, speed, and duration, return tsp of butter burned.
    static func butterBurned(
        weightKg: Double,
        speedMph: Double,
        durationMinutes: Double
    ) -> Double {
        let met = metValue(forSpeedMph: speedMph)
        let cal = caloriesBurned(weightKg: weightKg, met: met, durationMinutes: durationMinutes)
        return caloriesToButterTsp(cal)
    }

    /// Net butter balance (positive = surplus, negative = deficit, zero = perfect).
    static func netButter(burnedTsp: Double, eatenTsp: Double) -> Double {
        eatenTsp - burnedTsp
    }

    /// Butter Zero score (0-100). 100 = perfect net zero.
    static func butterZeroScore(netTsp: Double) -> Int {
        let score = 100.0 - abs(netTsp) * 20.0
        return max(0, min(100, Int(score)))
    }

    /// Human-friendly butter description.
    static func butterDescription(tsp: Double) -> String {
        if tsp < 1 {
            return String(format: "%.1f tsp", tsp)
        } else if tsp < 3 {
            return String(format: "%.1f tsp", tsp)
        } else if tsp < 24 { // less than 1 stick
            let tbsp = tsp / 3.0
            return String(format: "%.1f tbsp", tbsp)
        } else {
            let sticks = tsp / 24.0
            return String(format: "%.1f sticks", sticks)
        }
    }
}
