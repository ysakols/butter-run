import XCTest
@testable import ButterRun

final class KeychainServiceTests: XCTestCase {

    private var testKeyPrefix: String!

    override func setUp() {
        super.setUp()
        testKeyPrefix = "test_keychain_\(UUID().uuidString)"
    }

    override func tearDown() {
        // Clean up all test keys
        KeychainService.delete(key: testKey("save_load"))
        KeychainService.delete(key: testKey("nonexistent"))
        KeychainService.delete(key: testKey("delete"))
        KeychainService.delete(key: testKey("overwrite"))
        KeychainService.delete(key: testKey("empty"))
        super.tearDown()
    }

    private func testKey(_ suffix: String) -> String {
        "\(testKeyPrefix!)_\(suffix)"
    }

    // MARK: - Save then Load

    func test_saveThenLoad_returnsSavedValue() {
        let key = testKey("save_load")
        let value = "hello_butter_world"

        let saved = KeychainService.save(key: key, value: value)
        XCTAssertTrue(saved, "save should return true on success")

        let loaded = KeychainService.load(key: key)
        XCTAssertEqual(loaded, value, "load should return the previously saved value")
    }

    // MARK: - Load Non-Existent Key

    func test_loadNonExistentKey_returnsNil() {
        let key = testKey("nonexistent")
        let loaded = KeychainService.load(key: key)
        XCTAssertNil(loaded, "load should return nil for a key that was never saved")
    }

    // MARK: - Delete then Load

    func test_deleteThenLoad_returnsNil() {
        let key = testKey("delete")
        KeychainService.save(key: key, value: "to_be_deleted")

        // Verify it was saved
        XCTAssertNotNil(KeychainService.load(key: key), "value should exist before delete")

        KeychainService.delete(key: key)

        let loaded = KeychainService.load(key: key)
        XCTAssertNil(loaded, "load should return nil after the key has been deleted")
    }

    // MARK: - Overwrite

    func test_overwriteWithNewValue_returnsNewValue() {
        let key = testKey("overwrite")
        KeychainService.save(key: key, value: "original_value")
        XCTAssertEqual(KeychainService.load(key: key), "original_value")

        KeychainService.save(key: key, value: "updated_value")
        let loaded = KeychainService.load(key: key)
        XCTAssertEqual(loaded, "updated_value", "load should return the most recently saved value after overwrite")
    }

    // MARK: - Empty String

    func test_saveEmptyString_works() {
        let key = testKey("empty")
        let saved = KeychainService.save(key: key, value: "")
        XCTAssertTrue(saved, "save should succeed with an empty string")

        let loaded = KeychainService.load(key: key)
        XCTAssertEqual(loaded, "", "load should return an empty string when an empty string was saved")
    }
}
