import XCTest
@testable import ButterRun

// NOTE: Activity name/description formatting logic is private to StravaUploadService.
// These tests verify expected format conventions but do not call the actual methods.
// TODO: Extract formatting as internal testable functions in StravaUploadService.
@MainActor
final class StravaTests: XCTestCase {

    // MARK: - StravaConfig Tests

    func test_isConfigured_emptyCredentials_returnsFalse() {
        // Default clientID and clientSecret are empty strings
        XCTAssertFalse(StravaConfig.isConfigured)
    }

    func test_urls_areValid() {
        XCTAssertNotNil(URL(string: StravaConfig.authorizeURL), "authorizeURL should be a valid URL")
        XCTAssertNotNil(URL(string: StravaConfig.tokenURL), "tokenURL should be a valid URL")
        XCTAssertNotNil(URL(string: StravaConfig.baseAPIURL), "baseAPIURL should be a valid URL")
        XCTAssertNotNil(URL(string: StravaConfig.redirectURI), "redirectURI should be a valid URL")
    }

    func test_callbackScheme_matchesRedirectURI() {
        let expectedPrefix = StravaConfig.callbackScheme + "://"
        XCTAssertTrue(
            StravaConfig.redirectURI.hasPrefix(expectedPrefix),
            "redirectURI '\(StravaConfig.redirectURI)' should start with '\(expectedPrefix)'"
        )
    }

    // MARK: - Activity Name

    func test_activityName_format() {
        let run = Run(startDate: .now, isButterZeroChallenge: false)
        run.distanceMeters = 5000.0
        run.totalButterBurnedTsp = 2.5
        XCTAssertEqual(StravaUploadService.activityName(for: run), "Butter Run - 3.1 mi (burned 2.5 pats)")

        let zeroRun = Run(startDate: .now, isButterZeroChallenge: false)
        XCTAssertEqual(StravaUploadService.activityName(for: zeroRun), "Butter Run - 0.0 mi (burned 0.0 pats)")
    }

    // MARK: - Activity Description

    func test_activityDescription_format() {
        let run = Run(startDate: .now, isButterZeroChallenge: false)
        run.distanceMeters = 8000.0
        run.totalButterBurnedTsp = 4.2
        run.totalCaloriesBurned = 350.0
        run.elevationGainMeters = 120.0
        run.notes = "Felt great today!"

        let description = StravaUploadService.activityDescription(for: run)
        XCTAssertTrue(description.contains("Elevation gain: 120 m"))
        XCTAssertTrue(description.contains("Calories: 350"))
        XCTAssertTrue(description.contains("Felt great today!"))

        // Zero elevation and nil notes should be omitted
        let simpleRun = Run(startDate: .now, isButterZeroChallenge: false)
        simpleRun.distanceMeters = 3000.0
        simpleRun.totalCaloriesBurned = 150.0
        let simpleDesc = StravaUploadService.activityDescription(for: simpleRun)
        XCTAssertFalse(simpleDesc.contains("Elevation gain"))
        XCTAssertEqual(simpleDesc, "Tracked with Butter Run\nDistance: 1.9 mi\nButter burned: 0.0 pats\nCalories: 150")
    }

    // MARK: - StravaUploadError Tests

    func test_allErrors_haveNonEmptyDescriptions() {
        let errors: [StravaUploadError] = [
            .notAuthenticated,
            .uploadFailed("some reason"),
            .invalidResponse,
            .noRouteData
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "\(error) description should not be empty")
        }
        // Verify uploadFailed interpolates its associated value
        let uploadError = StravaUploadError.uploadFailed("timeout")
        XCTAssertTrue(uploadError.errorDescription!.contains("timeout"), "uploadFailed should include the reason")
    }

    // MARK: - UploadStatus Tests

    func test_uploadStatus_withActivityId() {
        let status = UploadStatus(id: 123, status: "Your activity is ready.", activityId: 456)
        XCTAssertEqual(status.id, 123)
        XCTAssertEqual(status.status, "Your activity is ready.")
        XCTAssertEqual(status.activityId, 456)
    }

    func test_uploadStatus_withoutActivityId() {
        let status = UploadStatus(id: 789, status: "Your activity is still being processed.", activityId: nil)
        XCTAssertEqual(status.id, 789)
        XCTAssertEqual(status.status, "Your activity is still being processed.")
        XCTAssertNil(status.activityId)
    }
}
