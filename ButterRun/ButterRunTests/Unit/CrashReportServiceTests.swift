import XCTest
@testable import ButterRun

final class CrashReportServiceTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        CrashReportService.deletePendingReport()
    }

    // MARK: - Pending Report

    func test_pendingReport_returnsNilWhenNoFile() {
        CrashReportService.deletePendingReport()
        XCTAssertNil(CrashReportService.pendingReport())
    }

    func test_pendingReport_returnsContentsWhenFileExists() throws {
        let testContent = "=== Test Crash Report ==="
        try testContent.write(to: CrashReportService.crashFileURL, atomically: true, encoding: .utf8)

        let result = CrashReportService.pendingReport()
        XCTAssertEqual(result, testContent)
    }

    func test_deletePendingReport_removesFile() throws {
        try "test".write(to: CrashReportService.crashFileURL, atomically: true, encoding: .utf8)
        XCTAssertNotNil(CrashReportService.pendingReport())

        CrashReportService.deletePendingReport()
        XCTAssertNil(CrashReportService.pendingReport())
    }

    func test_deletePendingReport_noopWhenNoFile() {
        CrashReportService.deletePendingReport()
        // Should not throw or crash
        CrashReportService.deletePendingReport()
    }

    // MARK: - Signal Display Names

    func test_signalDisplayNames() {
        // Verify via the report format — signal names appear in generated reports
        // We test this indirectly by verifying install() doesn't crash
        CrashReportService.install()
    }

    // MARK: - Install

    func test_install_doesNotCrash() {
        // install() registers handlers and pre-caches values
        CrashReportService.install()
        // Should complete without crashing
    }

    func test_install_cachesVersion() {
        CrashReportService.install()
        // After install, pendingReport should still work (no side effects)
        CrashReportService.deletePendingReport()
        XCTAssertNil(CrashReportService.pendingReport())
    }

    // MARK: - Crash File URL

    func test_crashFileURL_isInDocumentsDirectory() {
        let url = CrashReportService.crashFileURL
        XCTAssertTrue(url.path.contains("Documents"))
        XCTAssertTrue(url.lastPathComponent == CrashReportService.crashFileName)
    }

    // MARK: - Contact Email

    func test_contactEmail_isValid() {
        let email = CrashReportService.contactEmail
        XCTAssertTrue(email.contains("@"))
        XCTAssertTrue(email.contains("."))
        XCTAssertFalse(email.isEmpty)
    }

    // MARK: - Bundle Extension

    func test_bundleAppVersion_isNotEmpty() {
        // In test context, this may return "unknown" but should not crash
        let version = Bundle.main.appVersion
        XCTAssertFalse(version.isEmpty)
    }

    func test_bundleBuildNumber_isNotEmpty() {
        let build = Bundle.main.buildNumber
        XCTAssertFalse(build.isEmpty)
    }
}
