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
            speak("Half a pat of butter burned. Keep going!")
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
                speak("\(currentTsp) pat\(currentTsp == 1 ? "" : "s") of butter burned.")
            }
            lastAnnouncedTsp = currentTsp
        }

        if currentUnit > lastAnnouncedMile && currentUnit > 0 {
            let tspStr = String(format: "%.1f", butterTsp)
            speak("\(unitName) \(currentUnit) complete. Pace: \(pace). \(tspStr) pats burned.")
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
        var message = "Run complete! You burned \(tspStr) pats of butter."

        if isButterZero, let net = netButter {
            let netStr = String(format: "%.1f", abs(net))
            if abs(net) < 0.5 {
                message += " Butter Zero achieved! Net: \(netStr) pats."
            } else {
                message += " Net: \(netStr) pats \(net > 0 ? "surplus" : "deficit")."
            }
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

    /// Override point for testing — called with every announcement text.
    /// Production implementation is a no-op; test subclasses capture the text.
    func announceForTesting(_ text: String) {}

    private func speak(_ text: String) {
        announceForTesting(text)
        // Required for background playback during active runs
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = 0.8
        synthesizer.speak(utterance)
    }
}
