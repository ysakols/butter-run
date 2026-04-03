import AVFoundation

protocol VoiceFeedback {
    var isEnabled: Bool { get set }
    func reset()
    func checkMilestones(
        butterTsp: Double,
        distanceMiles: Double,
        pace: String,
        isButterZero: Bool,
        netButter: Double
    )
    func announceRunEnd(totalButterTsp: Double, netButter: Double?, isButterZero: Bool)
    func announceChurnStage(_ stageName: String)
    func announceAutoPause(paused: Bool)
}

class VoiceFeedbackService: VoiceFeedback {
    private let synthesizer = AVSpeechSynthesizer()
    var isEnabled: Bool = true

    private var lastAnnouncedTsp: Int = 0
    private var lastAnnouncedMile: Int = 0
    private var announcedHalfTsp: Bool = false

    func reset() {
        lastAnnouncedTsp = 0
        lastAnnouncedMile = 0
        announcedHalfTsp = false
    }

    func checkMilestones(
        butterTsp: Double,
        distanceMiles: Double,
        pace: String,
        isButterZero: Bool,
        netButter: Double
    ) {
        guard isEnabled else { return }

        // First announcement at 0.5 tsp for early wow moment
        if !announcedHalfTsp && butterTsp >= 0.5 {
            speak("Half a teaspoon of butter melted. Keep going!")
            announcedHalfTsp = true
        }

        let currentTsp = Int(butterTsp)
        let currentMile = Int(distanceMiles)

        if currentTsp > lastAnnouncedTsp {
            if currentTsp % 3 == 0 {
                let tbsp = currentTsp / 3
                speak("That's \(tbsp) tablespoon\(tbsp == 1 ? "" : "s") of butter!")
            } else {
                speak("\(currentTsp) teaspoon\(currentTsp == 1 ? "" : "s") of butter melted.")
            }
            lastAnnouncedTsp = currentTsp
        }

        if currentMile > lastAnnouncedMile && currentMile > 0 {
            let tspStr = String(format: "%.1f", butterTsp)
            speak("Mile \(currentMile) complete. Pace: \(pace). \(tspStr) teaspoons burned.")
            lastAnnouncedMile = currentMile
        }

        if isButterZero && abs(netButter) < 0.3 && netButter != 0 {
            speak("You're approaching Butter Zero! Nice churning!")
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
        speak("Churn stage: \(stageName)")
    }

    func announceAutoPause(paused: Bool) {
        guard isEnabled else { return }
        speak(paused ? "Auto paused" : "Resumed")
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = 0.8
        synthesizer.speak(utterance)
    }
}
