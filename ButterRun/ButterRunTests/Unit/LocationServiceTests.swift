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

    func test_encodeRouteAsync_emptyBuffer_returnsNil() async {
        let service = LocationService()
        let data = await service.encodeRouteAsync()
        // Empty route buffer with no dirty flag — should return nil (cached nil)
        XCTAssertNil(data)
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
}
