import Foundation
import AuthenticationServices
import UIKit

@MainActor
class StravaAuthService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {

    @Published var isAuthenticated: Bool = false
    @Published var isAuthorizing: Bool = false
    @Published var athleteName: String?

    private var authSession: ASWebAuthenticationSession?
    private var expectedOAuthState: String?

    private enum Keys {
        static let accessToken = "strava_access_token"
        static let refreshToken = "strava_refresh_token"
        static let tokenExpiry = "strava_token_expiry"
        static let athleteName = "strava_athlete_name"
    }

    var accessToken: String? {
        KeychainService.load(key: Keys.accessToken)
    }

    override init() {
        super.init()
        // Only show as authenticated if we have a token that isn't expired
        if let _ = KeychainService.load(key: Keys.accessToken) {
            if let expiryString = KeychainService.load(key: Keys.tokenExpiry),
               let expiresAt = TimeInterval(expiryString),
               Date().timeIntervalSince1970 < expiresAt {
                isAuthenticated = true
            } else if KeychainService.load(key: Keys.refreshToken) != nil {
                // Token expired but we have a refresh token — mark as authenticated,
                // refreshTokenIfNeeded() will handle the refresh before any API call.
                isAuthenticated = true
            }
            // Restore persisted athlete name
            athleteName = UserDefaults.standard.string(forKey: Keys.athleteName)
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Apple calls this on the main thread, so DispatchQueue.main.sync would deadlock.
        // Use MainActor.assumeIsolated since we know we're on main.
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }

    // MARK: - Authorize

    func authorize() {
        guard StravaConfig.isConfigured else {
            #if DEBUG
            print("Strava is not configured. Set clientID and clientSecret in StravaConfig.")
            #endif
            return
        }

        let state = UUID().uuidString
        expectedOAuthState = state
        guard let url = buildAuthorizeURL(state: state) else { return }

        isAuthorizing = true

        authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: StravaConfig.callbackScheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                guard let self else { return }
                defer { self.isAuthorizing = false }

                if let error {
                    #if DEBUG
                    print("Strava auth error: \(error.localizedDescription)")
                    #endif
                    self.authSession = nil
                    return
                }

                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
                      let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value,
                      returnedState == self.expectedOAuthState
                else {
                    #if DEBUG
                    print("Strava auth: missing code or state mismatch in callback URL.")
                    #endif
                    self.expectedOAuthState = nil
                    self.authSession = nil
                    return
                }
                self.expectedOAuthState = nil

                do {
                    try await self.exchangeToken(code: code)
                } catch {
                    #if DEBUG
                    print("Strava token exchange failed: \(error.localizedDescription)")
                    #endif
                }
                self.authSession = nil
            }
        }

        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = true
        authSession?.start()
    }

    // MARK: - Exchange Token

    private func exchangeToken(code: String) async throws {
        let params: [String: String] = [
            "client_id": StravaConfig.clientID,
            "client_secret": StravaConfig.clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]

        let json = try await performTokenRequest(params)

        guard let accessToken = json["access_token"] as? String,
              let refreshToken = json["refresh_token"] as? String,
              let expiresAt = json["expires_at"] as? Int
        else {
            throw StravaAuthError.invalidTokenResponse
        }

        KeychainService.save(key: Keys.accessToken, value: accessToken)
        KeychainService.save(key: Keys.refreshToken, value: refreshToken)
        KeychainService.save(key: Keys.tokenExpiry, value: String(expiresAt))

        if let athlete = json["athlete"] as? [String: Any] {
            let first = athlete["firstname"] as? String ?? ""
            let last = athlete["lastname"] as? String ?? ""
            let name = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
            athleteName = name
            UserDefaults.standard.set(name, forKey: Keys.athleteName)
        }

        isAuthenticated = true
    }

    // MARK: - Refresh Token

    /// Refreshes the access token if it will expire within 5 minutes.
    func refreshTokenIfNeeded() async throws {
        guard let expiryString = KeychainService.load(key: Keys.tokenExpiry),
              let expiresAt = TimeInterval(expiryString)
        else {
            throw StravaAuthError.missingRefreshToken
        }

        // Refresh 5 minutes before actual expiry to avoid edge-case failures
        let graceSeconds: TimeInterval = 300
        if Date().timeIntervalSince1970 + graceSeconds < expiresAt {
            return
        }

        guard let refreshToken = KeychainService.load(key: Keys.refreshToken) else {
            throw StravaAuthError.missingRefreshToken
        }

        let params: [String: String] = [
            "client_id": StravaConfig.clientID,
            "client_secret": StravaConfig.clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        let json = try await performTokenRequest(params)

        guard let newAccessToken = json["access_token"] as? String,
              let newRefreshToken = json["refresh_token"] as? String,
              let newExpiresAt = json["expires_at"] as? Int
        else {
            throw StravaAuthError.invalidTokenResponse
        }

        KeychainService.save(key: Keys.accessToken, value: newAccessToken)
        KeychainService.save(key: Keys.refreshToken, value: newRefreshToken)
        KeychainService.save(key: Keys.tokenExpiry, value: String(newExpiresAt))
    }

    // MARK: - Disconnect

    func disconnect() {
        let token = accessToken

        // Clear local state immediately so UI updates are synchronous
        clearKeychain()
        UserDefaults.standard.removeObject(forKey: Keys.athleteName)
        isAuthenticated = false
        athleteName = nil

        // Best-effort deauthorize with Strava (fire and forget)
        if let token {
            Task {
                guard let deauthURL = URL(string: "https://www.strava.com/oauth/deauthorize") else { return }
                var request = URLRequest(url: deauthURL)
                request.httpMethod = "POST"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                _ = try? await URLSession.shared.data(for: request)
            }
        }
    }

    // MARK: - Private Helpers

    private func buildAuthorizeURL(state: String) -> URL? {
        var components = URLComponents(string: StravaConfig.authorizeURL)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: StravaConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: StravaConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope", value: StravaConfig.scopes),
            URLQueryItem(name: "state", value: state)
        ]
        return components?.url
    }

    private func performTokenRequest(_ params: [String: String]) async throws -> [String: Any] {
        guard let url = URL(string: StravaConfig.tokenURL) else {
            throw StravaAuthError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Use URLComponents for proper percent-encoding of values
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else {
            throw StravaAuthError.tokenRequestFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StravaAuthError.invalidTokenResponse
        }

        return json
    }

    private func clearKeychain() {
        KeychainService.delete(key: Keys.accessToken)
        KeychainService.delete(key: Keys.refreshToken)
        KeychainService.delete(key: Keys.tokenExpiry)
    }
}

// MARK: - Errors

enum StravaAuthError: LocalizedError {
    case invalidURL
    case tokenRequestFailed
    case invalidTokenResponse
    case missingRefreshToken

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Strava URL."
        case .tokenRequestFailed:
            return "Strava token request failed."
        case .invalidTokenResponse:
            return "Invalid response from Strava token endpoint."
        case .missingRefreshToken:
            return "No refresh token available. Please re-authorize with Strava."
        }
    }
}
