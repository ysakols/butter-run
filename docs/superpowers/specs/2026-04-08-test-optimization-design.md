# Test Suite Optimization: Fix, Speed Up, Improve Coverage

**Date**: 2026-04-08
**Status**: Draft

## Problem

The ButterRun test suite has three issues:
1. **All 13 UI tests fail** with `kAXErrorServerNotFound` — the app doesn't launch in the simulator
2. **Tests are slow** — redundant app launches, 5s timeouts, per-test ModelContainer creation
3. **Low code coverage** — many services and ViewModels have no tests; coverage shows 2.8% when only UI tests run
4. **Warnings** — QoS priority inversions in SwiftData tests, Sendable capture in LocationService

## Phase 1: Fix Failures and Warnings

### 1.1 UI Test Launch Failure

**Diagnosis needed**: All UI tests fail with `kAXErrorServerNotFound` (accessibility server can't find main window). This means the app isn't presenting a window at all. Possible causes:
- Stale simulator state (fix: `xcrun simctl erase <UDID>`)
- UI test runner signing issue with empty `DEVELOPMENT_TEAM`
- App crash during init (CrashReportService.install or ModelContainer creation)

**Fix approach**:
1. Erase the simulator to clear stale state
2. Check if adding `CODE_SIGN_IDENTITY=-` to UI test target fixes runner installation
3. If still failing, add diagnostic `print()` statements to `ButterRunApp.init()` and check simulator console
4. Increase `waitForExistence` timeouts from 5s to 10s as a safety net for slow simulator launches

### 1.2 LocationService Sendable Warning

**File**: `ButterRun/Services/LocationService.swift:205`

The `DispatchQueue.global().async` closure captures `self` (via the `buffer` and `routeGeneration` access before the closure). The `[weak self]` is on the `withCheckedContinuation` closure but not propagated correctly.

**Fix**: Capture all needed values before the closure:
```swift
let generationAtStart = routeGeneration
let bufferCopy = buffer
return await withCheckedContinuation { continuation in
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        let asLocations = bufferCopy.map { ... }
        // ...
    }
}
```

### 1.3 QoS Priority Inversion Warnings

**Files**: `RunDraftServiceTests.swift`, `SwiftDataPersistenceTests.swift`, `AchievementServiceTests.swift`

**Cause**: `ModelContainer` init does schema work on a utility-QoS thread while the test (running at user-interactive QoS) blocks waiting for it.

**Fix**: Mark `setUp()` as `@MainActor` so container creation happens on the main actor, avoiding the QoS mismatch:
```swift
@MainActor
override func setUp() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    container = try ModelContainer(for: ..., configurations: config)
    context = ModelContext(container)
}
```

## Phase 2: Speed Optimization

### 2.1 Reduce UI Test Timeouts

Every UI test uses 5-second `waitForExistence` timeouts. For elements that appear immediately (tab bar buttons, toggle switches, form fields), reduce to 3s. Keep 5s only for operations that involve navigation transitions or sheet presentations.

**Files to modify**: All 6 UI test files in `ButterRunUITests/`

### 2.2 Extract Shared UI Test Helpers

Create `ButterRunUITests/Helpers/UITestHelpers.swift` with:
- `navigateToSettings(app:)` — taps Settings tab, waits for nav bar
- `startAndStopRun(app:)` — start → pause → long-press stop → confirm → done
- `navigateToOnboardingProfilePage(app:)` — tap Next 3 times to reach profile page

**Files affected**:
- `SettingsUITests.swift` — 6 tests duplicate `navigateToSettings()`
- `HistoryUITests.swift` — 4 tests duplicate run lifecycle
- `OnboardingUITests.swift` — 3 tests duplicate "tap Next 3 times"
- `StartStopRunUITests.swift` — 7 tests duplicate `tapStartRun()`

### 2.3 Share ModelContainer Across Tests

Create `ButterRunTests/Helpers/TestModelContainer.swift`:
```swift
import SwiftData
@testable import ButterRun

@MainActor
enum TestModelContainer {
    static func create() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Run.self, Split.self, ButterEntry.self,
                 UserProfile.self, Achievement.self, RunDraft.self,
            configurations: config
        )
    }
}
```

Each test suite creates the container once in `setUp()` but gets a fresh `ModelContext` per test (contexts are cheap, containers are expensive).

**Files to modify**: `SwiftDataPersistenceTests.swift`, `RunDraftServiceTests.swift`, `AchievementServiceTests.swift`

### 2.4 Create Explicit Test Plan

Replace the autocreated test plan with `ButterRun/ButterRun.xctestplan`:
- Enable code coverage for `ButterRun` target
- Include both `ButterRunTests` and `ButterRunUITests`
- Configure parallel execution appropriately (parallel for unit tests, serial for UI tests)

## Phase 3: Coverage Improvement

### 3.1 Identify Coverage Gaps

Services with **no tests**:
- `KeychainService` — token storage/retrieval
- `HapticService` — can test via protocol mock
- `MotionService` — can test via protocol mock

ViewModels with **no or minimal tests**:
- `HomeViewModel` — no tests
- `RunSummaryViewModel` — no tests
- `ActiveRunViewModel` — partially tested, needs churn integration tests

Services with **partial tests**:
- `StravaAuthService` — auth URL construction, callback parsing testable without network
- `StravaUploadService` — upload payload construction testable without network
- `ShareImageRenderer` — tested but slow (image rendering)

### 3.2 Priority Test Additions

Add tests for the highest-value untested code (business logic, not UI):

1. **RunSummaryViewModel** — summary calculations, share text generation
2. **HomeViewModel** — state management, run start/stop coordination
3. **KeychainService** — token CRUD (use in-memory keychain mock)
4. **StravaAuthService** — URL construction, callback URL parsing, error handling
5. **StravaUploadService** — payload construction, GPX generation

Each new test file follows existing patterns (in-memory SwiftData, protocol mocks).

## Files to Create

| File | Purpose |
|------|---------|
| `ButterRunUITests/Helpers/UITestHelpers.swift` | Shared UI test navigation helpers |
| `ButterRunTests/Helpers/TestModelContainer.swift` | Shared SwiftData container factory |
| `ButterRun.xctestplan` | Explicit test plan with coverage enabled |
| `ButterRunTests/Unit/RunSummaryViewModelTests.swift` | New coverage |
| `ButterRunTests/Unit/HomeViewModelTests.swift` | New coverage |
| `ButterRunTests/Unit/KeychainServiceTests.swift` | New coverage |
| `ButterRunTests/Unit/StravaAuthServiceTests.swift` | New coverage |

## Files to Modify

| File | Changes |
|------|---------|
| `LocationService.swift` | Fix Sendable capture warning |
| `SwiftDataPersistenceTests.swift` | Use shared container, `@MainActor` setUp |
| `RunDraftServiceTests.swift` | Use shared container, `@MainActor` setUp |
| `AchievementServiceTests.swift` | Use shared container, `@MainActor` setUp |
| All 6 UI test files | Reduce timeouts, use shared helpers |
| `ButterRun.xcscheme` | Reference explicit test plan |

## Verification

1. `xcodebuild build-for-testing` succeeds with no warnings
2. `xcodebuild test-without-building -only-testing:ButterRunTests` — all unit tests pass
3. UI tests pass when run from Xcode IDE (after simulator erase)
4. No QoS priority inversion warnings in test output
5. Code coverage > 30% (up from 2.8%)
6. Test suite completes faster than before (measure with `time` on CLI run)
