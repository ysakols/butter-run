import Foundation

protocol VoiceFeedback: AnyObject {
    var isEnabled: Bool { get set }
    func reset()
    func checkMilestones(
        butterTsp: Double,
        distanceMeters: Double,
        pace: String,
        isButterZero: Bool,
        netButter: Double,
        usesMiles: Bool
    )
    func announceRunEnd(totalButterTsp: Double, netButter: Double?, isButterZero: Bool)
    func announceChurnStage(_ stageName: String)
    func announceAutoPause(paused: Bool)
    func announcePauseResume(paused: Bool)
    func stop()
}
