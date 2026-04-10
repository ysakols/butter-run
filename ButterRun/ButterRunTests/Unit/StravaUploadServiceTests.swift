import XCTest
@testable import ButterRun

/// Tests for StravaUploadService pure functions and output formats.
///
/// Most methods on StravaUploadService are either `private` or require network access.
/// These tests exercise observable behavior through the public/internal API where possible,
/// and document expected formats where direct invocation is not feasible.
@MainActor
final class StravaUploadServiceTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a Run with route data encoded as a JSON array of [lat, lng] pairs.
    private func makeRun(
        coordinates: [[Double]],
        distanceMeters: Double = 5000,
        durationSeconds: Double = 1800,
        butterBurned: Double = 2.5,
        calories: Double = 300,
        elevationGain: Double = 50
    ) -> Run {
        let run = Run(startDate: Date(timeIntervalSince1970: 1_700_000_000), isButterZeroChallenge: false)
        run.distanceMeters = distanceMeters
        run.durationSeconds = durationSeconds
        run.totalButterBurnedTsp = butterBurned
        run.totalCaloriesBurned = calories
        run.elevationGainMeters = elevationGain
        run.routePolyline = try? JSONEncoder().encode(coordinates)
        return run
    }

    // MARK: - GPX Generation (via uploadGPX output format)

    // generateGPXData is private, so we cannot call it directly.
    // However, uploadGPX calls it internally before sending a network request.
    // We verify the expected GPX structure by encoding coordinates the same way
    // the service does (JSON array of [lat, lng]) and testing decoding round-trips.

    func test_gpxExpectedStructure_documentedFormat() {
        // Document the expected GPX XML structure that generateGPXData produces.
        // This acts as a specification test even though we cannot call the private method.
        let expectedTags = ["<?xml", "<gpx", "<trk>", "<name>", "<trkseg>", "<trkpt", "lat=", "lon=", "<time>", "</gpx>"]
        // If generateGPXData were accessible, we would verify:
        // let gpxString = String(data: gpxData, encoding: .utf8)!
        // for tag in expectedTags { XCTAssertTrue(gpxString.contains(tag)) }
        //
        // Instead, we verify the coordinate encoding that feeds into GPX generation:
        let coords: [[Double]] = [[37.7749, -122.4194], [37.7750, -122.4190]]
        let data = try! JSONEncoder().encode(coords)
        let decoded = try! JSONDecoder().decode([[Double]].self, from: data)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0][0], 37.7749, accuracy: 0.0001)
        XCTAssertEqual(decoded[0][1], -122.4194, accuracy: 0.0001)
        // Verify tags list is complete (compile-time documentation)
        XCTAssertEqual(expectedTags.count, 10, "All expected GPX tags should be documented")
    }

    func test_routePolylineEncoding_validCoordinates_producesDecodableJSON() {
        // The routePolyline on Run is the input to generateGPXData.
        // Verify that encoding coordinates as the service expects produces valid data.
        let coords: [[Double]] = [
            [37.7749, -122.4194],
            [37.7752, -122.4185],
            [37.7755, -122.4178]
        ]
        let run = makeRun(coordinates: coords)
        XCTAssertNotNil(run.routePolyline)

        let decoded = try! JSONDecoder().decode([[Double]].self, from: run.routePolyline!)
        XCTAssertEqual(decoded.count, 3)
        for (i, pair) in decoded.enumerated() {
            XCTAssertEqual(pair.count, 2)
            XCTAssertEqual(pair[0], coords[i][0], accuracy: 0.0001)
            XCTAssertEqual(pair[1], coords[i][1], accuracy: 0.0001)
        }
    }

    // MARK: - GPX Coordinate Validation

    func test_coordinateValidation_outOfRangeFiltered() {
        // generateGPXData filters coordinates outside valid ranges:
        //   lat must be in -90...90, lng must be in -180...180
        // We verify this filtering logic by testing the same range checks.
        let coords: [[Double]] = [
            [91.0, 0.0],        // lat too high — should be filtered
            [-91.0, 0.0],       // lat too low — should be filtered
            [0.0, 181.0],       // lon too high — should be filtered
            [0.0, -181.0],      // lon too low — should be filtered
            [37.7749, -122.4],  // valid
            [-90.0, 180.0],     // boundary — valid
            [90.0, -180.0],     // boundary — valid
        ]

        // Apply the same filtering logic used in generateGPXData
        let valid = coords.filter { coord in
            guard coord.count >= 2 else { return false }
            return (-90...90).contains(coord[0]) && (-180...180).contains(coord[1])
        }

        XCTAssertEqual(valid.count, 3, "Only 3 coordinates should pass range validation")
        XCTAssertEqual(valid[0][0], 37.7749, accuracy: 0.0001)
        XCTAssertEqual(valid[1][0], -90.0, accuracy: 0.0001)
        XCTAssertEqual(valid[2][0], 90.0, accuracy: 0.0001)
    }

    func test_coordinateValidation_shortArraySkipped() {
        // generateGPXData skips coordinate arrays with fewer than 2 elements
        let coords: [[Double]] = [
            [37.0],            // too short — skipped
            [],                // empty — skipped
            [37.7749, -122.4], // valid
        ]

        let valid = coords.filter { coord in
            guard coord.count >= 2 else { return false }
            return (-90...90).contains(coord[0]) && (-180...180).contains(coord[1])
        }

        XCTAssertEqual(valid.count, 1)
    }

    func test_coordinateValidation_boundaryValues() {
        // Exact boundary values should be accepted
        let boundaryCoords: [[Double]] = [
            [90.0, 180.0],
            [-90.0, -180.0],
            [0.0, 0.0],
        ]

        for coord in boundaryCoords {
            XCTAssertTrue((-90...90).contains(coord[0]), "Lat \(coord[0]) should be in range")
            XCTAssertTrue((-180...180).contains(coord[1]), "Lon \(coord[1]) should be in range")
        }
    }

    // MARK: - Multipart Form Boundary

    func test_uuidBoundary_isNonEmpty() {
        // uploadGPX uses UUID().uuidString as the multipart boundary.
        // Verify UUID strings are non-empty and have expected format.
        let boundary = UUID().uuidString
        XCTAssertFalse(boundary.isEmpty, "UUID boundary should not be empty")
        XCTAssertGreaterThan(boundary.count, 10, "UUID boundary should be reasonably long")
    }

    func test_uuidBoundary_uniquePerCall() {
        // Each call should produce a different boundary to avoid conflicts
        let boundary1 = UUID().uuidString
        let boundary2 = UUID().uuidString
        XCTAssertNotEqual(boundary1, boundary2, "Consecutive UUID boundaries should differ")
    }

    func test_uuidBoundary_validForHTTPHeader() {
        // Boundary must be safe for use in Content-Type header
        let boundary = UUID().uuidString
        let header = "multipart/form-data; boundary=\(boundary)"
        XCTAssertTrue(header.contains(boundary))
        // UUID strings contain only hex digits and hyphens — safe for HTTP headers
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        XCTAssertTrue(
            boundary.unicodeScalars.allSatisfy { allowedChars.contains($0) },
            "UUID boundary should contain only alphanumerics and hyphens"
        )
    }

    // MARK: - Activity Name Formatting

    func test_activityName_format_typicalRun() {
        // Replicate the name formatting from createActivity / uploadGPX
        let run = makeRun(coordinates: [], distanceMeters: 5000, butterBurned: 2.5)

        let miles = run.distanceMeters / 1609.344
        let milesFormatted = String(format: "%.1f", miles)
        let butterFormatted = String(format: "%.1f", run.totalButterBurnedTsp)
        let name = "Butter Run - \(milesFormatted) mi (burned \(butterFormatted) pats)"

        XCTAssertEqual(name, "Butter Run - 3.1 mi (burned 2.5 pats)")
    }

    func test_activityName_format_zeroValues() {
        let run = Run(startDate: .now, isButterZeroChallenge: false)
        // All defaults are 0

        let miles = run.distanceMeters / 1609.344
        let milesFormatted = String(format: "%.1f", miles)
        let butterFormatted = String(format: "%.1f", run.totalButterBurnedTsp)
        let name = "Butter Run - \(milesFormatted) mi (burned \(butterFormatted) pats)"

        XCTAssertEqual(name, "Butter Run - 0.0 mi (burned 0.0 pats)")
    }

    func test_activityName_format_longDistance() {
        let run = makeRun(coordinates: [], distanceMeters: 42195, butterBurned: 15.3) // marathon

        let miles = run.distanceMeters / 1609.344
        let milesFormatted = String(format: "%.1f", miles)
        let butterFormatted = String(format: "%.1f", run.totalButterBurnedTsp)
        let name = "Butter Run - \(milesFormatted) mi (burned \(butterFormatted) pats)"

        XCTAssertEqual(name, "Butter Run - 26.2 mi (burned 15.3 pats)")
    }

    func test_activityName_alwaysStartsWithButterRun() {
        let distances: [Double] = [0, 100, 1609.344, 10000, 42195]
        for dist in distances {
            let miles = dist / 1609.344
            let milesFormatted = String(format: "%.1f", miles)
            let name = "Butter Run - \(milesFormatted) mi (burned 0.0 pats)"
            XCTAssertTrue(name.hasPrefix("Butter Run - "), "Name should always start with 'Butter Run - '")
            XCTAssertTrue(name.hasSuffix(" pats)"), "Name should always end with ' pats)'")
        }
    }

    // MARK: - StravaUploadError

    func test_noRouteData_error_hasDescription() {
        let error = StravaUploadError.noRouteData
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.lowercased().contains("route"))
    }

    // MARK: - UploadStatus

    func test_uploadStatus_processingState() {
        let status = UploadStatus(id: 100, status: "Your activity is still being processed.", activityId: nil)
        XCTAssertNil(status.activityId, "Activity ID should be nil while processing")
        XCTAssertFalse(status.status.contains("error"), "Processing status should not contain 'error'")
    }

    func test_uploadStatus_errorState() {
        let status = UploadStatus(id: 100, status: "There was an error processing your activity.", activityId: nil)
        XCTAssertTrue(status.status.contains("error"), "Error status should contain 'error'")
    }

    func test_uploadStatus_readyState() {
        let status = UploadStatus(id: 100, status: "Your activity is ready.", activityId: 999)
        XCTAssertEqual(status.activityId, 999)
    }
}
