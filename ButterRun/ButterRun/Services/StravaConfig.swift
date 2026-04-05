import Foundation

struct StravaConfig {

    /// Loaded from Info.plist (sourced from .xcconfig, which is gitignored).
    static var clientID: String {
        Bundle.main.infoDictionary?["StravaClientID"] as? String ?? ""
    }

    /// Loaded from Info.plist (sourced from .xcconfig, which is gitignored).
    static var clientSecret: String {
        Bundle.main.infoDictionary?["StravaClientSecret"] as? String ?? ""
    }

    static let authorizeURL = "https://www.strava.com/oauth/mobile/authorize"
    static let tokenURL = "https://www.strava.com/oauth/token"
    static let baseAPIURL = "https://www.strava.com/api/v3"
    static let redirectURI = "butterrun://strava-callback"
    static let callbackScheme = "butterrun"
    static let scopes = "activity:write,activity:read"

    static var isConfigured: Bool {
        !clientID.isEmpty && !clientSecret.isEmpty
    }
}
