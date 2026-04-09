import XCTest
@testable import ButterRun

final class DeepLinkRouterTests: XCTestCase {

    // MARK: - URL Parsing

    func test_parse_validRunURL() {
        let id = UUID()
        let url = URL(string: "butterrun://run/\(id.uuidString)")!
        let destination = DeepLinkRouter.parse(url)
        XCTAssertEqual(destination, .run(id))
    }

    func test_parse_lowercaseUUID() {
        let id = UUID()
        let url = URL(string: "butterrun://run/\(id.uuidString.lowercased())")!
        let destination = DeepLinkRouter.parse(url)
        XCTAssertEqual(destination, .run(id))
    }

    func test_parse_uppercaseUUID() {
        let id = UUID()
        let url = URL(string: "butterrun://run/\(id.uuidString.uppercased())")!
        let destination = DeepLinkRouter.parse(url)
        XCTAssertEqual(destination, .run(id))
    }

    func test_parse_wrongScheme_returnsNil() {
        let url = URL(string: "https://run/\(UUID().uuidString)")!
        XCTAssertNil(DeepLinkRouter.parse(url))
    }

    func test_parse_wrongHost_returnsNil() {
        let url = URL(string: "butterrun://settings/\(UUID().uuidString)")!
        XCTAssertNil(DeepLinkRouter.parse(url))
    }

    func test_parse_missingUUID_returnsNil() {
        let url = URL(string: "butterrun://run/")!
        XCTAssertNil(DeepLinkRouter.parse(url))
    }

    func test_parse_invalidUUID_returnsNil() {
        let url = URL(string: "butterrun://run/not-a-uuid")!
        XCTAssertNil(DeepLinkRouter.parse(url))
    }

    func test_parse_stravaCallback_returnsNil() {
        let url = URL(string: "butterrun://strava-callback?code=abc")!
        XCTAssertNil(DeepLinkRouter.parse(url))
    }

    func test_parse_noPath_returnsNil() {
        let url = URL(string: "butterrun://run")!
        XCTAssertNil(DeepLinkRouter.parse(url))
    }

    // MARK: - Router Handle

    func test_handle_validURL_setsPending() {
        let router = DeepLinkRouter()
        let id = UUID()
        let url = URL(string: "butterrun://run/\(id.uuidString)")!

        let handled = router.handle(url)

        XCTAssertTrue(handled)
        XCTAssertEqual(router.pending, .run(id))
    }

    func test_handle_invalidURL_doesNotSetPending() {
        let router = DeepLinkRouter()
        let url = URL(string: "butterrun://unknown/path")!

        let handled = router.handle(url)

        XCTAssertFalse(handled)
        XCTAssertNil(router.pending)
    }

    func test_handle_replacesExistingPending() {
        let router = DeepLinkRouter()
        let first = UUID()
        let second = UUID()

        router.handle(URL(string: "butterrun://run/\(first.uuidString)")!)
        router.handle(URL(string: "butterrun://run/\(second.uuidString)")!)

        XCTAssertEqual(router.pending, .run(second))
    }
}
