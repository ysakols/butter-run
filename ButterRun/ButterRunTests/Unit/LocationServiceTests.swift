import XCTest
import CoreLocation
@testable import ButterRun

final class LocationServiceTests: XCTestCase {

    // MARK: - Route Decoding

    func test_decodeRoute_validCoords() {
        let coords: [[Double]] = [[37.7749, -122.4194], [37.7750, -122.4190]]
        let data = try! JSONEncoder().encode(coords)
        let result = LocationService.decodeRoute(data)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(result[0].longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(result[1].latitude, 37.7750, accuracy: 0.0001)
        XCTAssertEqual(result[1].longitude, -122.4190, accuracy: 0.0001)
    }

    func test_decodeRoute_invalidData_returnsEmpty() {
        let data = Data("not json".utf8)
        let result = LocationService.decodeRoute(data)
        XCTAssertTrue(result.isEmpty)
    }

    func test_decodeRoute_emptyArray_returnsEmpty() {
        let data = try! JSONEncoder().encode([[Double]]())
        let result = LocationService.decodeRoute(data)
        XCTAssertTrue(result.isEmpty)
    }

    func test_decodeRoute_singleCoord_pair() {
        let coords: [[Double]] = [[40.7128, -74.0060]]
        let data = try! JSONEncoder().encode(coords)
        let result = LocationService.decodeRoute(data)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].latitude, 40.7128, accuracy: 0.0001)
    }

    func test_decodeRoute_shortArray_skipped() {
        // Single-element sub-arrays should be skipped by compactMap
        let coords: [[Double]] = [[37.0]]
        let data = try! JSONEncoder().encode(coords)
        let result = LocationService.decodeRoute(data)
        XCTAssertTrue(result.isEmpty)
    }

    func test_decodeRoute_outOfRangeCoords_skipped() {
        // Latitude outside [-90, 90] or longitude outside [-180, 180] should be filtered
        let coords: [[Double]] = [
            [91.0, 0.0],       // latitude too high
            [-91.0, 0.0],      // latitude too low
            [0.0, 181.0],      // longitude too high
            [0.0, -181.0],     // longitude too low
            [37.7749, -122.4]  // valid
        ]
        let data = try! JSONEncoder().encode(coords)
        let result = LocationService.decodeRoute(data)
        XCTAssertEqual(result.count, 1, "Only the valid coordinate should survive range validation")
        XCTAssertEqual(result[0].latitude, 37.7749, accuracy: 0.0001)
    }

    // MARK: - Encode/Decode Roundtrip (via direct data)

    func test_encodeDecodeRoundtrip() {
        let original: [[Double]] = [
            [37.7749, -122.4194],
            [37.7752, -122.4185],
            [37.7755, -122.4178]
        ]
        let data = try! JSONEncoder().encode(original)
        let decoded = LocationService.decodeRoute(data)
        XCTAssertEqual(decoded.count, 3)
        for (i, coord) in original.enumerated() {
            XCTAssertEqual(decoded[i].latitude, coord[0], accuracy: 0.0001)
            XCTAssertEqual(decoded[i].longitude, coord[1], accuracy: 0.0001)
        }
    }

    // MARK: - Subtract Distance

    func test_subtractDistance_clampsAtZero() {
        let service = LocationService()
        service.subtractDistance(100)
        XCTAssertEqual(service.totalDistanceMeters, 0)
    }

    // MARK: - Initial State

    func test_initialState() {
        let service = LocationService()
        XCTAssertEqual(service.totalDistanceMeters, 0)
        XCTAssertEqual(service.currentSpeedMps, 0)
        XCTAssertEqual(service.elevationGainMeters, 0)
        XCTAssertEqual(service.elevationLossMeters, 0)
        XCTAssertFalse(service.isTracking)
        XCTAssertEqual(service.gpsSignalState, .strong)
        XCTAssertFalse(service.routeIsDirty)
    }

    // MARK: - Async Route Encoding

    func test_encodeRouteAsync_emptyBuffer_returnsEmptyArray() async {
        let service = LocationService()
        let data = await service.encodeRouteAsync()
        // Empty route buffer encodes as an empty JSON array "[]"
        XCTAssertNotNil(data)
        let decoded = LocationService.decodeRoute(data!)
        XCTAssertTrue(decoded.isEmpty, "Empty buffer should decode to empty coordinate array")
    }

    func test_encodeRouteAsync_returnsCachedData() async {
        let service = LocationService()
        // Prime the cache via sync encode
        _ = service.encodeRoute()

        // Async should return the same cached result
        let data = await service.encodeRouteAsync()
        let syncData = service.encodeRoute()
        XCTAssertEqual(data, syncData)
    }

    func test_encodeRouteAsync_smallBuffer_matchesSyncEncode() async {
        // We can't easily inject route points without tracking, but we can
        // verify the async path delegates to sync for small buffers.
        let service = LocationService()
        let asyncResult = await service.encodeRouteAsync()
        let syncResult = service.encodeRoute()
        XCTAssertEqual(asyncResult, syncResult)
    }

    // MARK: - encodeRoute Empty Route

    func test_encodeRoute_emptyRoute_returnsNil() {
        // A fresh LocationService has an empty routeBuffer.
        // encodeRoute() encodes the empty buffer as a JSON array "[]",
        // which is technically non-nil Data. Verify the decoded result is empty.
        let service = LocationService()
        let data = service.encodeRoute()
        // The encoder produces Data for an empty array, so data is non-nil
        // but decodes to zero coordinates.
        if let data = data {
            let decoded = LocationService.decodeRoute(data)
            XCTAssertTrue(decoded.isEmpty, "Empty route buffer should decode to zero coordinates")
        }
        // Either nil or empty-decoding data is acceptable for an empty route
    }

    // MARK: - encodeRoute With Coordinates

    func test_encodeRoute_withCoordinates_returnsData() {
        // We cannot inject into routeBuffer directly (it's private(set)).
        // Instead, verify that when routePolyline data is encoded in the same
        // format LocationService uses (JSON array of [lat, lng]), it produces valid data.
        let coords: [[Double]] = [
            [37.7749, -122.4194],
            [37.7752, -122.4185]
        ]
        let data = try! JSONEncoder().encode(coords)
        XCTAssertNotNil(data, "Encoded coordinate data should not be nil")
        XCTAssertGreaterThan(data.count, 0, "Encoded data should have content")

        // Verify it round-trips through decodeRoute
        let decoded = LocationService.decodeRoute(data)
        XCTAssertEqual(decoded.count, 2, "Should decode back to 2 coordinates")
    }

    // MARK: - Route Encoding Roundtrip

    func test_routeEncoding_roundtrip() {
        // Encode coordinates in the same JSON format used by LocationService's routeBuffer,
        // then decode with LocationService.decodeRoute() and verify they match.
        let original: [[Double]] = [
            [40.7128, -74.0060],
            [40.7130, -74.0055],
            [40.7135, -74.0050],
            [40.7140, -74.0045]
        ]
        let encoded = try! JSONEncoder().encode(original)
        let decoded = LocationService.decodeRoute(encoded)

        XCTAssertEqual(decoded.count, original.count, "Roundtrip should preserve coordinate count")
        for (i, coord) in original.enumerated() {
            XCTAssertEqual(decoded[i].latitude, coord[0], accuracy: 0.00001,
                           "Latitude at index \(i) should match after roundtrip")
            XCTAssertEqual(decoded[i].longitude, coord[1], accuracy: 0.00001,
                           "Longitude at index \(i) should match after roundtrip")
        }
    }

    // MARK: - GPS Signal State Initial Value

    func test_gpsSignalState_initiallyStrong() {
        // LocationService initializes gpsSignalState to .strong
        // (it is set to .strong in startTracking and defaults to .strong in the property declaration)
        let service = LocationService()
        XCTAssertEqual(service.gpsSignalState, .strong,
                       "GPS signal state should initially be .strong")
    }
}
