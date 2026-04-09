import XCTest
@testable import ButterRun

final class DeepLinkRouterTests: XCTestCase {

    // MARK: - URL Building

    func test_url_forRunID_producesExpectedFormat() {
        let id = UUID()
        let url = DeepLinkRouter.url(forRunID: id)
        XCTAssertEqual(url.absoluteString, "butterrun://run/\(id.uuidString)")
    }

    // MARK: - URL Parsing

    func test_parse_validRunURL() {
        let id = UUID()
        let url = DeepLinkRouter.url(forRunID: id)
        XCTAssertEqual(DeepLinkRouter.parse(url), .run(id))
    }

    func test_parse_lowercaseUUID() {
        let id = UUID()
        let url = URL(string: "butterrun://run/\(id.uuidString.lowercased())")!
        XCTAssertEqual(DeepLinkRouter.parse(url), .run(id))
    }

    func test_parse_uppercaseUUID() {
        let id = UUID()
        let url = URL(string: "butterrun://run/\(id.uuidString.uppercased())")!
        XCTAssertEqual(DeepLinkRouter.parse(url), .run(id))
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

    // MARK: - Router Handle & Consume

    func test_handle_validURL_setsPending() {
        let router = DeepLinkRouter()
        let id = UUID()

        let handled = router.handle(DeepLinkRouter.url(forRunID: id))

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

        router.handle(DeepLinkRouter.url(forRunID: first))
        router.handle(DeepLinkRouter.url(forRunID: second))

        XCTAssertEqual(router.pending, .run(second))
    }

    func test_consume_returnsAndClearsPending() {
        let router = DeepLinkRouter()
        let id = UUID()
        router.handle(DeepLinkRouter.url(forRunID: id))

        let consumed = router.consume()

        XCTAssertEqual(consumed, .run(id))
        XCTAssertNil(router.pending)
    }

    func test_consume_returnsNilWhenEmpty() {
        let router = DeepLinkRouter()

        XCTAssertNil(router.consume())
    }
}
