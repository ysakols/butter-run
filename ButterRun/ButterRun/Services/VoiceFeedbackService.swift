import AVFoundation

class VoiceFeedbackService: VoiceFeedback {
    private let synthesizer = AVSpeechSynthesizer()
    var isEnabled: Bool = true

    private var lastAnnouncedTsp: Int = 0
    private var lastAnnouncedMile: Int = 0
    private var announcedHalfTsp: Bool = false
    private var hasAnnouncedNearZero: Bool = false

    func reset() {
        lastAnnouncedTsp = 0
        lastAnnouncedMile = 0
        announcedHalfTsp = false
        hasAnnouncedNearZero = false
    }

    func checkMilestones(
        butterTsp: Double,
        distanceMeters: Double,
        pace: String,
        isButterZero: Bool,
        netButter: Double,
        usesMiles: Bool
    ) {
        guard isEnabled else { return }

        // First announcement at 0.5 tsp for early wow moment
        if !announcedHalfTsp && butterTsp >= 0.5 {
            speak("Half a teaspoon of butter melted. Keep going!")
            announcedHalfTsp = true
        }

        let currentTsp = Int(butterTsp)
        let unitMeters = usesMiles ? 1609.344 : 1000.0
        let unitName = usesMiles ? "Mile" : "Kilometer"
        let currentUnit = Int(distanceMeters / unitMeters)

        if currentTsp > lastAnnouncedTsp {
            if currentTsp % 3 == 0 {
                let tbsp = currentTsp / 3
                speak("That's \(tbsp) tablespoon\(tbsp == 1 ? "" : "s") of butter!")
            } else {
                speak("\(currentTsp) teaspoon\(currentTsp == 1 ? "" : "s") of butter melted.")
            }
            lastAnnouncedTsp = currentTsp
        }

        if currentUnit > lastAnnouncedMile && currentUnit > 0 {
            let tspStr = String(format: "%.1f", butterTsp)
            speak("\(unitName) \(currentUnit) complete. Pace: \(pace). \(tspStr) teaspoons burned.")
            lastAnnouncedMile = currentUnit
        }

        if isButterZero && abs(netButter) < 0.3 && netButter != 0 && !hasAnnouncedNearZero {
            speak("You're approaching Butter Zero! Nice churning!")
            hasAnnouncedNearZero = true
        } else if isButterZero && abs(netButter) > 1.0 {
            hasAnnouncedNearZero = false
        }
    }

    func announceRunEnd(totalButterTsp: Double, netButter: Double?, isButterZero: Bool) {
        guard isEnabled else { return }

        let tspStr = String(format: "%.1f", totalButterTsp)
        var message = "Run complete! You melted \(tspStr) teaspoons of butter."

        if isButterZero, let net = netButter {
            let score = ButterCalculator.butterZeroScore(netTsp: net)
            message += " Butter Zero score: \(score) out of 100."
        }

        speak(message)
    }

    func announceChurnStage(_ stageName: String) {
        guard isEnabled else { return }
        if stageName == "Butter" {
            speak("Congratulations! You made butter!")
        } else {
            speak("Churn stage: \(stageName)")
        }
    }

    func announceAutoPause(paused: Bool) {
        guard isEnabled else { return }
        speak(paused ? "Auto paused" : "Resumed")
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = 0.8
        synthesizer.speak(utterance)
    }
}
