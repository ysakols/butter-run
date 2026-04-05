import Foundation

struct StravaConfig {

    static let clientID = ""
    static let clientSecret = ""

    static let authorizeURL = "https://www.strava.com/oauth/mobile/authorize"
    static let tokenURL = "https://www.strava.com/oauth/token"
    static let baseAPIURL = "https://www.strava.com/api/v3"
    static let redirectURI = "butterrun://strava-callback"
    static let callbackScheme = "butterrun"
    static let scopes = "activity:write,activity:read,read"

    static var isConfigured: Bool {
        !clientID.isEmpty && !clientSecret.isEmpty
    }
}
