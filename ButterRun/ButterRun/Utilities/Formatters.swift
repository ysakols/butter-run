import Foundation

enum ButterFormatters {
    /// Format seconds into "M:SS" or "H:MM:SS".
    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds)
        if total >= 3600 {
            let h = total / 3600
            let m = (total % 3600) / 60
            let s = total % 60
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            let m = total / 60
            let s = total % 60
            return String(format: "%d:%02d", m, s)
        }
    }

    /// Format pace (seconds per km) into "M:SS /mi" or "M:SS /km".
    static func pace(secondsPerKm: Double, usesMiles: Bool) -> String {
        let secondsPerUnit = usesMiles ? secondsPerKm * 1.60934 : secondsPerKm
        guard secondsPerUnit.isFinite && secondsPerUnit > 0 else { return "--:--" }
        let mins = Int(secondsPerUnit) / 60
        let secs = Int(secondsPerUnit) % 60
        let unit = usesMiles ? "/mi" : "/km"
        return String(format: "%d:%02d%@", mins, secs, unit)
    }

    /// Format distance with unit.
    static func distance(meters: Double, usesMiles: Bool) -> String {
        if usesMiles {
            let miles = meters / 1609.344
            return String(format: "%.2f mi", miles)
        } else {
            let km = meters / 1000.0
            return String(format: "%.2f km", km)
        }
    }

    /// Format butter amount with appropriate unit.
    static func butter(tsp: Double) -> String {
        if abs(tsp) < 0.1 {
            return "0.0 tsp"
        }
        return String(format: "%.1f tsp", tsp)
    }

    /// Format butter with emoji.
    static func butterWithEmoji(tsp: Double) -> String {
        "🧈 \(butter(tsp: tsp))"
    }

    /// Speed in mph from m/s.
    static func speedMph(metersPerSecond: Double) -> Double {
        metersPerSecond * 2.23694
    }

    // MARK: - Pat Formatters (v2 — pats as primary unit)

    /// Format butter amount in pats (1 pat = 1 tsp = 34 cal).
    @available(*, deprecated, message: "Use pats() instead")
    static func _butterLegacy(tsp: Double) -> String { butter(tsp: tsp) }

    /// Format butter amount as pats.
    static func pats(_ tsp: Double) -> String {
        if abs(tsp) < 0.1 {
            return "0.0 pats"
        }
        return String(format: "%.1f pats", tsp)
    }

    /// Format pats with tsp and calorie detail for secondary display.
    /// Returns "≈ 8.4 tsp (286 cals)" for use beneath the hero number.
    static func patsWithDetail(_ tsp: Double) -> String {
        let cals = Int(round(tsp * 34))
        if abs(tsp) < 0.1 {
            return "≈ 0.0 tsp (0 cals)"
        }
        return String(format: "≈ %.1f tsp (%d cals)", tsp, cals)
    }

    /// Format net pats with +/- sign for Butter Zero display.
    /// Returns "+0.3 pats" or "-1.2 pats" or "0.0 pats".
    static func netPats(_ netTsp: Double) -> String {
        if abs(netTsp) < 0.05 {
            return "0.0 pats"
        }
        let sign = netTsp > 0 ? "+" : ""
        return String(format: "%@%.1f pats", sign, netTsp)
    }

    /// Format pats with emoji.
    static func patsWithEmoji(_ tsp: Double) -> String {
        "🧈 \(pats(tsp))"
    }
}
