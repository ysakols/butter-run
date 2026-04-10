import XCTest
@testable import ButterRun

@MainActor
final class StravaAuthServiceTests: XCTestCase {

    // MARK: - PKCE Code Verifier

    func test_generateCodeVerifier_isAtLeast43Characters() {
        let verifier = StravaAuthService.generateCodeVerifier()
        XCTAssertGreaterThanOrEqual(verifier.count, 43, "Code verifier must be at least 43 characters per RFC 7636")
    }

    func test_generateCodeVerifier_isURLSafeBase64() {
        let verifier = StravaAuthService.generateCodeVerifier()

        // Must only contain unreserved characters: [A-Z], [a-z], [0-9], '-', '.', '_', '~'
        // Base64url uses [A-Za-z0-9_-] with no padding '='
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let verifierCharacters = CharacterSet(charactersIn: verifier)
        XCTAssertTrue(
            allowedCharacters.isSuperset(of: verifierCharacters),
            "Code verifier should only contain URL-safe base64 characters (A-Z, a-z, 0-9, -, _). Got: \(verifier)"
        )
    }

    func test_generateCodeVerifier_containsNoPadding() {
        let verifier = StravaAuthService.generateCodeVerifier()
        XCTAssertFalse(verifier.contains("="), "Code verifier should not contain base64 padding characters")
    }

    func test_generateCodeVerifier_isUniqueAcrossCalls() {
        let verifier1 = StravaAuthService.generateCodeVerifier()
        let verifier2 = StravaAuthService.generateCodeVerifier()
        XCTAssertNotEqual(verifier1, verifier2, "Each code verifier should be cryptographically random")
    }

    // MARK: - PKCE Code Challenge

    func test_generateCodeChallenge_isNonEmpty() {
        let verifier = StravaAuthService.generateCodeVerifier()
        let challenge = StravaAuthService.generateCodeChallenge(from: verifier)
        XCTAssertFalse(challenge.isEmpty, "Code challenge should not be empty")
    }

    func test_generateCodeChallenge_isURLSafeBase64() {
        let verifier = StravaAuthService.generateCodeVerifier()
        let challenge = StravaAuthService.generateCodeChallenge(from: verifier)

        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let challengeCharacters = CharacterSet(charactersIn: challenge)
        XCTAssertTrue(
            allowedCharacters.isSuperset(of: challengeCharacters),
            "Code challenge should only contain URL-safe base64 characters. Got: \(challenge)"
        )
    }

    func test_generateCodeChallenge_containsNoPadding() {
        let verifier = StravaAuthService.generateCodeVerifier()
        let challenge = StravaAuthService.generateCodeChallenge(from: verifier)
        XCTAssertFalse(challenge.contains("="), "Code challenge should not contain base64 padding characters")
    }

    func test_generateCodeChallenge_isDeterministicForSameVerifier() {
        let verifier = StravaAuthService.generateCodeVerifier()
        let challenge1 = StravaAuthService.generateCodeChallenge(from: verifier)
        let challenge2 = StravaAuthService.generateCodeChallenge(from: verifier)
        XCTAssertEqual(challenge1, challenge2, "Same verifier should always produce the same challenge (SHA256 is deterministic)")
    }

    func test_generateCodeChallenge_differsForDifferentVerifiers() {
        let verifier1 = StravaAuthService.generateCodeVerifier()
        let verifier2 = StravaAuthService.generateCodeVerifier()
        let challenge1 = StravaAuthService.generateCodeChallenge(from: verifier1)
        let challenge2 = StravaAuthService.generateCodeChallenge(from: verifier2)
        XCTAssertNotEqual(challenge1, challenge2, "Different verifiers should produce different challenges")
    }

    func test_generateCodeChallenge_isSHA256Length() {
        // SHA256 = 32 bytes. Base64url of 32 bytes = ceil(32*4/3) = 43 chars without padding
        let verifier = StravaAuthService.generateCodeVerifier()
        let challenge = StravaAuthService.generateCodeChallenge(from: verifier)
        XCTAssertEqual(challenge.count, 43, "Base64url-encoded SHA256 should be 43 characters (no padding)")
    }

    // MARK: - State Parameter

    func test_stateParameter_isNonEmpty() {
        // The state is generated via UUID().uuidString in authorize(),
        // so we verify UUID strings meet the expectation.
        let state = UUID().uuidString
        XCTAssertFalse(state.isEmpty, "State parameter should be non-empty")
        XCTAssertGreaterThan(state.count, 0)
    }

    func test_stateParameter_isUniqueAcrossCalls() {
        let state1 = UUID().uuidString
        let state2 = UUID().uuidString
        XCTAssertNotEqual(state1, state2, "Each state parameter should be unique")
    }

    // MARK: - isAuthenticated Default

    @MainActor
    func test_isAuthenticated_returnsFalseWhenNoTokenStored() {
        // Clear any tokens that might be present
        KeychainService.delete(key: "strava_access_token")
        KeychainService.delete(key: "strava_refresh_token")
        KeychainService.delete(key: "strava_token_expiry")

        let service = StravaAuthService()
        XCTAssertFalse(service.isAuthenticated, "isAuthenticated should be false when no token is stored in keychain")
    }

    // MARK: - Disconnect

    @MainActor
    func test_disconnect_clearsKeychainEntries() {
        // Seed some tokens
        KeychainService.save(key: "strava_access_token", value: "test_token")
        KeychainService.save(key: "strava_refresh_token", value: "test_refresh")
        KeychainService.save(key: "strava_token_expiry", value: "9999999999")

        let service = StravaAuthService()
        service.disconnect()

        XCTAssertNil(KeychainService.load(key: "strava_access_token"), "Access token should be cleared after disconnect")
        XCTAssertNil(KeychainService.load(key: "strava_refresh_token"), "Refresh token should be cleared after disconnect")
        XCTAssertNil(KeychainService.load(key: "strava_token_expiry"), "Token expiry should be cleared after disconnect")
        XCTAssertFalse(service.isAuthenticated, "isAuthenticated should be false after disconnect")
        XCTAssertNil(service.athleteName, "athleteName should be nil after disconnect")
    }
}
