import Foundation
import AuthenticationServices
import UIKit

@MainActor
class StravaAuthService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {

    @Published var isAuthenticated: Bool = false
    @Published var athleteName: String?

    private var authSession: ASWebAuthenticationSession?

    private enum Keys {
        static let accessToken = "strava_access_token"
        static let refreshToken = "strava_refresh_token"
        static let tokenExpiry = "strava_token_expiry"
    }

    var accessToken: String? {
        KeychainService.load(key: Keys.accessToken)
    }

    override init() {
        super.init()
        isAuthenticated = KeychainService.load(key: Keys.accessToken) != nil
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // ASWebAuthenticationSession always calls this on the main thread.
        // Use DispatchQueue.main.sync for safety under strict concurrency.
        DispatchQueue.main.sync {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }

    // MARK: - Authorize

    func authorize() {
        guard StravaConfig.isConfigured else {
            print("Strava is not configured. Set clientID and clientSecret in StravaConfig.")
            return
        }

        guard let url = buildAuthorizeURL() else { return }

        authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: StravaConfig.callbackScheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    print("Strava auth error: \(error.localizedDescription)")
                    self.authSession = nil
                    return
                }

                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    print("Strava auth: missing code in callback URL.")
                    self.authSession = nil
                    return
                }

                do {
                    try await self.exchangeToken(code: code)
                } catch {
                    print("Strava token exchange failed: \(error.localizedDescription)")
                }
                self.authSession = nil
            }
        }

        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = false
        authSession?.start()
    }

    // MARK: - Exchange Token

    func exchangeToken(code: String) async throws {
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
            athleteName = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
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
        guard let token = accessToken else {
            clearKeychain()
            isAuthenticated = false
            athleteName = nil
            return
        }

        Task {
            var request = URLRequest(url: URL(string: "https://www.strava.com/oauth/deauthorize")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            _ = try? await URLSession.shared.data(for: request)

            clearKeychain()
            isAuthenticated = false
            athleteName = nil
        }
    }

    // MARK: - Private Helpers

    private func buildAuthorizeURL() -> URL? {
        var components = URLComponents(string: StravaConfig.authorizeURL)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: StravaConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: StravaConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope", value: StravaConfig.scopes)
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
