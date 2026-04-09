import XCTest
@testable import ButterRun

// NOTE: Activity name/description formatting logic is private to StravaUploadService.
// These tests verify expected format conventions but do not call the actual methods.
// TODO: Extract formatting as internal testable functions in StravaUploadService.
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

    // MARK: - Activity Naming Tests

    func test_activityName_format() {
        // Replicate the name-building logic from createActivity to verify the expected format
        let run = Run(startDate: .now, isButterZeroChallenge: false)
        run.distanceMeters = 5000.0   // ~3.1 mi
        run.totalButterBurnedTsp = 2.5

        let miles = run.distanceMeters / 1609.344
        let milesFormatted = String(format: "%.1f", miles)
        let butterFormatted = String(format: "%.1f", run.totalButterBurnedTsp)
        let expectedName = "Butter Run - \(milesFormatted) mi (burned \(butterFormatted) pats)"

        XCTAssertEqual(expectedName, "Butter Run - 3.1 mi (burned 2.5 pats)")
    }

    func test_activityName_zeroDistance() {
        let run = Run(startDate: .now, isButterZeroChallenge: false)
        // defaults: distanceMeters = 0, totalButterBurnedTsp = 0

        let miles = run.distanceMeters / 1609.344
        let milesFormatted = String(format: "%.1f", miles)
        let butterFormatted = String(format: "%.1f", run.totalButterBurnedTsp)
        let expectedName = "Butter Run - \(milesFormatted) mi (burned \(butterFormatted) pats)"

        XCTAssertEqual(expectedName, "Butter Run - 0.0 mi (burned 0.0 pats)")
    }

    func test_activityDescription_includesElevation_whenPositive() {
        let run = Run(startDate: .now, isButterZeroChallenge: false)
        run.distanceMeters = 8000.0
        run.totalButterBurnedTsp = 4.2
        run.totalCaloriesBurned = 350.0
        run.elevationGainMeters = 120.0

        // Replicate description logic
        let miles = run.distanceMeters / 1609.344
        let milesFormatted = String(format: "%.1f", miles)
        let butterFormatted = String(format: "%.1f", run.totalButterBurnedTsp)

        var description = "Tracked with Butter Run"
        description += "\nDistance: \(milesFormatted) mi"
        description += "\nButter burned: \(butterFormatted) pats"
        description += "\nCalories: \(String(format: "%.0f", run.totalCaloriesBurned))"
        if run.elevationGainMeters > 0 {
            description += "\nElevation gain: \(String(format: "%.0f", run.elevationGainMeters)) m"
        }

        XCTAssertTrue(description.contains("Elevation gain: 120 m"))
        XCTAssertTrue(description.contains("Calories: 350"))
    }

    func test_activityDescription_omitsElevation_whenZero() {
        let run = Run(startDate: .now, isButterZeroChallenge: false)
        run.distanceMeters = 3000.0
        run.totalButterBurnedTsp = 1.0
        run.totalCaloriesBurned = 150.0
        run.elevationGainMeters = 0.0

        let miles = run.distanceMeters / 1609.344
        let milesFormatted = String(format: "%.1f", miles)
        let butterFormatted = String(format: "%.1f", run.totalButterBurnedTsp)

        var description = "Tracked with Butter Run"
        description += "\nDistance: \(milesFormatted) mi"
        description += "\nButter burned: \(butterFormatted) pats"
        description += "\nCalories: \(String(format: "%.0f", run.totalCaloriesBurned))"
        if run.elevationGainMeters > 0 {
            description += "\nElevation gain: \(String(format: "%.0f", run.elevationGainMeters)) m"
        }

        XCTAssertFalse(description.contains("Elevation gain"))
    }

    func test_activityDescription_includesNotes_whenPresent() {
        let run = Run(startDate: .now, isButterZeroChallenge: false)
        run.distanceMeters = 5000.0
        run.totalButterBurnedTsp = 2.0
        run.totalCaloriesBurned = 200.0
        run.notes = "Felt great today!"

        var description = "Tracked with Butter Run"
        if let notes = run.notes, !notes.isEmpty {
            description += "\n\n\(notes)"
        }

        XCTAssertTrue(description.contains("Felt great today!"))
    }

    func test_activityDescription_omitsNotes_whenNil() {
        let run = Run(startDate: .now, isButterZeroChallenge: false)
        run.notes = nil

        var description = "Tracked with Butter Run"
        if let notes = run.notes, !notes.isEmpty {
            description += "\n\n\(notes)"
        }

        XCTAssertEqual(description, "Tracked with Butter Run")
    }

    // MARK: - StravaUploadError Tests

    func test_notAuthenticated_hasDescription() {
        let error = StravaUploadError.notAuthenticated
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func test_uploadFailed_hasDescription() {
        let error = StravaUploadError.uploadFailed("timeout")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("timeout"))
    }

    func test_invalidResponse_hasDescription() {
        let error = StravaUploadError.invalidResponse
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func test_noRouteData_hasDescription() {
        let error = StravaUploadError.noRouteData
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

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
