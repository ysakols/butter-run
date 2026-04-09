# ButterRun Comprehensive Review &amp; Remediation Plan

**Date:** 2026-04-09
**Scope:** Full repo audit -- security, docs, legal, code quality, tests, CI/CD
**Total Findings:** ~195 across 6 review domains
**Summary:** 5 CRITICAL, 19 HIGH, 52 MEDIUM, 71 LOW, 8 Positive

---

## MASTER ISSUE INVENTORY

### CRITICAL (5 issues -- fix immediately)

| # | Domain | Issue | File(s) | Lines |
|---|--------|-------|---------|-------|
| C1 | Docs | README claims "no network requests" -- factually false (Strava, MapKit, HealthKit, CrashReport all make network calls) | README.md | 67 |
| C2 | Code | ActiveRunViewModel missing @MainActor -- @Observable state mutated from timer/Combine callbacks without actor isolation; will break under Swift 6 strict concurrency | ViewModels/ActiveRunViewModel.swift | 17 |
| C3 | UI | LongPressStopButton Timer fires on RunLoop, mutates @State without @MainActor guarantee; UIImpactFeedbackGenerator created per tick (~30fps) | Views/ActiveRun/LongPressStopButton.swift | 90-113 |
| C4 | UI | HomeView uses hardcoded DispatchQueue.main.asyncAfter delays (0.3s, 1.0s) for sheet-to-fullScreenCover sequencing -- race condition causes silent presentation failure | Views/Home/HomeView.swift | 135-151 |
| C5 | Tests | CI only runs unit tests (-only-testing:ButterRunTests), all 6 UI test files completely skipped | .github/workflows/ci.yml | 125 |

### HIGH (19 issues)

| # | Domain | Issue | File(s) |
|---|--------|-------|---------|
| H1 | Security | Strava client_secret embedded in app binary via Info.plist/xcconfig -- extractable from IPA | Services/StravaConfig.swift, Info.plist |
| H2 | Security | No concurrent token refresh protection -- two simultaneous refreshes invalidate each other, de-authenticating user | Services/StravaAuthService.swift:167-203 |
| H3 | Code | bestPaceSecondsPerKm and averagePaceSecondsPerKm initialized to 0 (infinitely fast) instead of optional/infinity | Models/Run.swift:18-19 |
| H4 | Code | All 4 ViewModels missing @MainActor (Swift 6 concurrency) | ViewModels/*.swift |
| H5 | Code | stopRun() callable from .idle state, creates degenerate Run with 0 distance/duration | ViewModels/ActiveRunViewModel.swift:276 |
| H6 | UI | try? modelContext.save() silently swallows errors in 5 locations -- user can lose entire run data | ActiveRunView:303, ManualRunEntryView:160, RunHistoryView:133, SettingsView:345, RunSummaryView:464 |
| H7 | UI | No location permission check before starting run -- deep link can start run without GPS permission | Views/ActiveRun/ActiveRunView.swift:126-131 |
| H8 | UI | OnboardingPage uses AnyView type erasure -- defeats SwiftUI structural identity/diffing | Views/Components/OnboardingPage.swift:9 |
| H9 | UI | RunSummaryView .onAppear fetches ALL runs with no predicate, can fire multiple times causing duplicate HealthKit syncs | Views/Summary/RunSummaryView.swift:185-198 |
| H10 | UI | SettingsView saves profile on every keystroke of displayName | Views/Settings/SettingsView.swift:185 |
| H11 | UI | Conflicting accessibility: .accessibilityElement(children: .contain) with .accessibilityLabel makes VoiceOver ignore the label | Views/ActiveRun/ContextualStrip.swift:97-99 |
| H12 | UI | Duplicate .onChange(of: runs.count) handlers on same view hierarchy | Views/History/RunHistoryView.swift:119-149 |
| H13 | Docs | README says iOS 17.0+ but project targets iOS 18.0+ | README.md:40 |
| H14 | Docs | DESIGN.md severely stale -- lists ~35 files vs ~70+ actual, wrong colors, wrong terminology, missing Strava/HealthKit/achievements | DESIGN.md |
| H15 | Docs | Privacy policy omits crash reporting feature entirely | PRIVACY_POLICY.md, LegalText.swift |
| H16 | Docs | PrivacyInfo.xcprivacy missing Strava data-sharing disclosure (location linked to Strava identity) | PrivacyInfo.xcprivacy |
| H17 | Tests | Zero tests for Strava OAuth + Upload (648 lines of untested network/auth code) | Services/StravaAuthService.swift, StravaUploadService.swift |
| H18 | Tests | Zero tests for LocationService.didUpdateLocations -- the core GPS processing (distance, speed, elevation, spike rejection) | Services/LocationService.swift:264-339 |
| H19 | Tests | ActiveRunViewModel.updateMetrics() (core 1-second metrics loop) never exercised in tests | ViewModels/ActiveRunViewModel.swift:404-492 |
### MEDIUM (52 issues -- fix before release)

| # | Domain | Issue | File(s) |
|---|--------|-------|---------|
| M1 | Security | No certificate pinning on Strava API connections | Services/StravaAuthService.swift, StravaUploadService.swift |
| M2 | Security | Crash reports stored as plaintext, may contain sensitive data in backtraces | Services/CrashReportService.swift:100-108 |
| M3 | Security | CI missing security scanning (no secret scanning, no static analysis) | .github/workflows/ci.yml |
| M4 | Security | PrivacyInfo.xcprivacy doesn't declare Strava data sharing | PrivacyInfo.xcprivacy |
| M5 | Security | Location data stored unencrypted in SwiftData/SQLite | Services/LocationService.swift, ButterRunApp.swift:108-110 |
| M6 | Code | UserProfile.preferredUnit and splitDistance are stringly-typed (should be enums) | Models/UserProfile.swift:15-16 |
| M7 | Code | No validation on weightKg -- can be 0/negative causing divide-by-zero | Models/UserProfile.swift:14 |
| M8 | Code | netButterTsp is denormalized stored field that can desync from eaten-burned | Models/Run.swift:23 |
| M9 | Code | Split model missing id property (unlike all other @Model types) | Models/Split.swift:12 |
| M10 | Code | ButterEntry allows customTeaspoons of 0 or negative | Models/ButterEntry.swift:56-61 |
| M11 | Code | ButterServing.teaspoon and .pat are 100% identical enum cases | Models/ButterEntry.swift:4-46 |
| M12 | Code | ActiveRunViewModel.eatButter doesn't validate negative customTsp | ViewModels/ActiveRunViewModel.swift:353-367 |
| M13 | Code | ActiveRunViewModel.deinit doesn't cancel pendingDraftTask or clear cancellables | ViewModels/ActiveRunViewModel.swift:101-104 |
| M14 | Code | ActiveRunViewModel resumeRun() drift correction edge cases | ViewModels/ActiveRunViewModel.swift:254-259 |
| M15 | Code | RunSummaryViewModel holds strong reference to SwiftData @Model | ViewModels/RunSummaryViewModel.swift:6 |
| M16 | Code | Schema migration uses only .lightweight with no fallback for non-additive changes | ButterRunApp.swift:60-65 |
| M17 | Code | Achievement.typeRaw returns optional without validation/migration path | Models/Achievement.swift:74-76 |
| M18 | Code | metValue returns 1.0 (resting MET) for speed=0, burns calories while stationary | Services/ButterCalculator.swift:29 |
| M19 | Code | ButterChurnEstimator progress/stage mutations lack @MainActor compile-time enforcement | Services/ButterChurnEstimator.swift:49-51 |
| M20 | Code | SWIFT_VERSION set to 5.0 instead of 6.0 (iOS 18 target) | project.pbxproj, generate_xcodeproj.py |
| M21 | UI | RunMapView and other views use hardcoded frame heights (200px) | ActiveRunView.swift:78 |
| M22 | UI | ChurnSetupSheet silently clamps cream amount without user feedback | Views/ActiveRun/ChurnSetupSheet.swift:76-80 |
| M23 | UI | BannerView uses hardcoded light-mode colors -- broken in dark mode | Views/Components/BannerView.swift:9-30 |
| M24 | UI | ButterStickView and ButterStickMeter missing accessibility labels | Views/Components/ButterStickView.swift |
| M25 | UI | GoldButton missing accessibility label and minimum tap target | Views/Components/GoldButton.swift:3-30 |
| M26 | UI | OnboardingPage dots have no accessibility for page position | Views/Components/OnboardingPage.swift:48-61 |
| M27 | UI | SegmentedControl missing .isSelected accessibility trait | Views/Components/SegmentedControl.swift:10-27 |
| M28 | UI | SheetHeader drag handle not hidden from VoiceOver | Views/Components/SheetHeader.swift:9-13 |
| M29 | UI | SplitTable UUID regenerated every view update (breaks SwiftUI diffing) | Views/Components/SplitTable.swift:5 |
| M30 | UI | RunEditView accepts negative duration values | Views/History/RunEditView.swift:39-56 |
| M31 | UI | ManualRunEntryView no feedback on successful save | Views/History/ManualRunEntryView.swift:133-162 |
| M32 | UI | RunHistoryView onDelete index may mismatch with prefix(visibleCount) | Views/History/RunHistoryView.swift:85-89 |
| M33 | UI | SettingsView recalculateRuns() processes all runs synchronously on main thread | Views/Settings/SettingsView.swift:328-346 |
| M34 | UI | SettingsView no loading indicator for HealthKit authorization | Views/Settings/SettingsView.swift:217-231 |
| M35 | UI | ShareSheetView (RunSummaryView) will crash on iPad -- no popover source | Views/Summary/RunSummaryView.swift:528-544 |
| M36 | UI | ChurnGuideView uses deprecated .navigationBarHidden(true) | Views/Guide/ChurnGuideView.swift:36 |
| M37 | UI | EatButterSheet custom amount silently clamps without feedback | Views/ActiveRun/EatButterSheet.swift:59-61 |
| M38 | UI | InfoButton popover hardcoded width (260px) overflows with Dynamic Type | Views/Components/InfoButton.swift:28 |
| M39 | UI | RunDetailView RouteMapView missing accessibility | Views/History/RunDetailView.swift:210-220 |
| M40 | Build | No xcconfig existence validation at build time | ButterRun.xcconfig.template |
| M41 | Build | No build caching in CI | .github/workflows/ci.yml |
| M42 | Build | Script doesn't detect new/removed files without re-running generate_xcodeproj.py | scripts/generate_xcodeproj.py |
| M43 | Build | generate_icon.py has hardcoded absolute path | generate_icon.py:5 |
| M44 | Build | Missing .env and credential file patterns in .gitignore | .gitignore |
| M45 | Docs | No GDPR compliance language in privacy policy | PRIVACY_POLICY.md |
| M46 | Docs | Strava tokens not mentioned as PII in privacy policy | PRIVACY_POLICY.md |
| M47 | Docs | DESIGN.md development phases all unchecked despite completion | DESIGN.md:512-540 |
| M48 | Docs | UI redesign spec still says "Draft -- Pending user review" | docs/superpowers/specs/2026-04-05-ui-redesign-design.md |
| M49 | Docs | PrivacyInfo.xcprivacy missing "Body" data type for weight | PrivacyInfo.xcprivacy |
| M50 | Docs | Crash report data not declared in privacy manifest | PrivacyInfo.xcprivacy |
| M51 | Tests | ChurnEstimator.processSample() and lifecycle (start/stop/pause) untested | Tests/Unit/ChurnEstimatorTests.swift |
| M52 | Tests | LocationService.simplifyRoute (Douglas-Peucker algorithm) untested | Services/LocationService.swift:139-187 |
### LOW (71 issues -- fix opportunistically)

Key LOW items (abbreviated -- full details in agent reports):

- **Security:** Athlete name in UserDefaults not Keychain; crash report file permissions 0o644 should be 0o600; deep link scheme not validated against source; Strava error responses may contain sensitive data; RunDraftService logger uses .public privacy; token expiry stored as unparsed string
- **Code:** Run.churnResult decodes JSON on every access (no caching); Run.formattedDuration duplicates ButterFormatters.duration(); HomeViewModel.load() uses O(n log n) sort instead of O(n) max(); HomeViewModel doesn't reset lastRunSummary when runs empty; Formatters pace conversion uses 1.60934 vs 1.609344 elsewhere; deprecated _butterLegacy method chain; Color(hex:) returns silent black for invalid input; ButterFacts.random force-index fallback
- **UI:** All 37 view files have hardcoded English strings (zero localization); ToastView auto-dismiss timer restarts on reappear; no haptic on achievement unlock; DispatchQueue.main.asyncAfter for animation timing; RunSummaryView generateAndShare() sets @State without MainActor; RunHistoryView empty state doesn't offer manual entry; various missing accessibility labels on maps/cards
- **Build:** No code coverage in scheme/CI; no shebang portability issues; Pillow/google-genai dependencies not declared in requirements.txt; mockup CSS duplicated across 4 HTML files; iOS 18.0 minimum is aggressive
- **Docs:** Contact email spltr3app@gmail.com appears to be for different app; MIT license may conflict with App Store monetization; LegalText.swift comment references wrong type name; ToS Section 16 not in survival clause; no data retention period for Strava tokens
- **Tests:** StravaTests replicate logic inline instead of calling actual code; WeightConversionTests test arithmetic not app code; CrashReportServiceTests are trivial smoke tests; LongPressStopButtonTests have no real assertions; ShareImageRendererTests only check non-nil; various missing boundary/edge case tests

### POSITIVE FINDINGS (8 items -- no action needed)

- PKCE OAuth implementation is correct (SecRandomCopyBytes, SHA256, base64url)
- Keychain uses kSecAttrAccessibleWhenUnlockedThisDeviceOnly
- ShareImageRenderer strips EXIF/GPS metadata from shared images
- All debug print() statements wrapped in #if DEBUG
- CI actions pinned to SHA hashes (not mutable tags)
- CI permissions scoped to contents: read (least privilege)
- RunDraftService enforces main-thread with dispatchPrecondition
- GPX coordinate validation present (lat -90..90, lon -180..180)

---

## ORDER-DEPENDENT EXECUTION PLAN

> **Principle:** Each phase builds on the prior. Items within a phase can be parallelized.

### PHASE 1: Data Integrity & Crash Prevention (do first -- prevents data loss)

**Why first:** These bugs can cause data loss, crashes, or corrupt state for real users right now.

**Step 1.1** -- Fix Run model pace initialization
- File: `Models/Run.swift:18-19`
- Change `averagePaceSecondsPerKm: Double = 0` and `bestPaceSecondsPerKm: Double = 0` to `Double = Double.infinity` or make them `Double?`
- Update all display sites to handle infinity/nil (check ButterFormatters.pace already guards)
- **Depends on:** Nothing

**Step 1.2** -- Fix ShareSheetView iPad crash
- File: `Views/Summary/RunSummaryView.swift:528-544`
- Add `controller.popoverPresentationController?.sourceView = ...` and `sourceRect`
- **Depends on:** Nothing

**Step 1.3** -- Fix SplitTable UUID regeneration
- File: `Views/Components/SplitTable.swift:5`
- Change `let id = UUID()` to `let id: Int` based on split index
- **Depends on:** Nothing

**Step 1.4** -- Add save error handling
- Files: `ActiveRunView.swift:303`, `ManualRunEntryView.swift:160`, `RunHistoryView.swift:133`, `SettingsView.swift:345`, `RunSummaryView.swift:464`
- Replace all `try? modelContext.save()` with do/catch + user-facing error alert
- **Depends on:** Nothing

**Step 1.5** -- Fix HomeView sheet-to-cover race condition
- File: `Views/Home/HomeView.swift:135-151`
- Replace DispatchQueue.main.asyncAfter with `.sheet(onDismiss:)` closure to trigger fullScreenCover
- **Depends on:** Nothing

**Step 1.6** -- Fix LongPressStopButton thread safety
- File: `Views/ActiveRun/LongPressStopButton.swift:90-113`
- Replace Timer with Task-based approach; create UIImpactFeedbackGenerator once in startHold()
- **Depends on:** Nothing

**Step 1.7** -- Guard stopRun() against invalid states
- File: `ViewModels/ActiveRunViewModel.swift:276`
- Add `guard state == .running || state == .paused` at top of stopRun()
- **Depends on:** Nothing

**Step 1.8** -- Validate inputs: weightKg, customTeaspoons, negative customTsp
- Files: `Models/UserProfile.swift:14`, `Models/ButterEntry.swift:56-61`, `ViewModels/ActiveRunViewModel.swift:353-367`
- Add clamps/guards for zero/negative values
- **Depends on:** Nothing

### PHASE 2: Concurrency & Thread Safety (do second -- prevents undefined behavior)

**Why second:** These won't crash today but will break under Swift 6 and cause subtle bugs.

**Step 2.1** -- Add @MainActor to all ViewModels
- Files: `ViewModels/ActiveRunViewModel.swift:17`, `ViewModels/HomeViewModel.swift`, `ViewModels/RunHistoryViewModel.swift`, `ViewModels/RunSummaryViewModel.swift`
- Add `@MainActor` class annotation to all four
- Update any call sites that need `await` or `Task { @MainActor in }`
- **Depends on:** Phase 1 (so tests pass after changes)

**Step 2.2** -- Add concurrent token refresh serialization
- File: `Services/StravaAuthService.swift:167-203`
- Add actor-based or Task-lock pattern: first caller refreshes, subsequent callers await the same result
- **Depends on:** Nothing (but do after 2.1 for consistency)

**Step 2.3** -- Fix ActiveRunViewModel deinit cleanup
- File: `ViewModels/ActiveRunViewModel.swift:101-104`
- Cancel `pendingDraftTask`, call `cancellables.removeAll()` in deinit
- **Depends on:** Step 2.1

**Step 2.4** -- Add @MainActor to ButterChurnEstimator mutations
- File: `Services/ButterChurnEstimator.swift:49-51, 173-184`
- Mark progress/currentStage mutations with @MainActor
- **Depends on:** Step 2.1

**Step 2.5** -- Fix RunSummaryView .onAppear guard
- File: `Views/Summary/RunSummaryView.swift:185-198`
- Add `@State private var hasPerformedSetup = false` guard; add FetchDescriptor limit
- **Depends on:** Nothing

**Step 2.6** -- Debounce SettingsView displayName saves
- File: `Views/Settings/SettingsView.swift:185`
- Save on view disappear or after 0.5s debounce, not every keystroke
- **Depends on:** Nothing

**Step 2.7** -- Update SWIFT_VERSION to 6.0
- Files: `scripts/generate_xcodeproj.py:453,460,470,480,486`, then regenerate project.pbxproj
- **Depends on:** Steps 2.1-2.4 (all concurrency fixes must be in place first)
### PHASE 3: Security Hardening (do third -- before any public release)

**Why third:** These don't crash the app but affect user privacy and App Store compliance.

**Step 3.1** -- Fix README false privacy claim
- File: `README.md:67`
- Replace "No analytics, no tracking, no network requests" with accurate description mentioning optional Strava/HealthKit
- **Depends on:** Nothing (can be done anytime but is CRITICAL)

**Step 3.2** -- Add crash reporting to Privacy Policy and LegalText
- Files: `PRIVACY_POLICY.md`, `ButterRun/ButterRun/Utilities/LegalText.swift`
- Add "Crash Reports" section: what's captured (app version, build, iOS version, device model, stack trace), stored locally, only transmitted if user explicitly emails
- Update "Data Not Collected" section
- **Depends on:** Nothing

**Step 3.3** -- Update PrivacyInfo.xcprivacy
- File: `ButterRun/ButterRun/PrivacyInfo.xcprivacy`
- Set NSPrivacyCollectedDataTypeLinked=true for PreciseLocation (linked to Strava identity when uploaded)
- Add crash data type declaration
- Consider body/weight data type
- **Depends on:** Step 3.2

**Step 3.4** -- Add GDPR compliance language to Privacy Policy
- File: `PRIVACY_POLICY.md`, `LegalText.swift`
- Add "For Users in the European Economic Area" section with legal basis, rights, DPO contact
- **Depends on:** Step 3.2

**Step 3.5** -- Fix crash report file permissions
- File: `Services/CrashReportService.swift:120`
- Change `0o644` to `0o600`
- Add FileProtectionType.complete to crash report URL
- **Depends on:** Nothing

**Step 3.6** -- Add security scanning to CI
- File: `.github/workflows/ci.yml`
- Add trufflesecurity/trufflehog or GitHub secret scanning step
- **Depends on:** Nothing

**Step 3.7** -- Add .env and credential patterns to .gitignore
- File: `.gitignore`
- Add: `.env*`, `*.p12`, `*.mobileprovision`, `*.cer`, `*.key`, `*.pem`, `credentials.*`
- **Depends on:** Nothing

### PHASE 4: Code Quality &amp; Architecture (do fourth -- improves maintainability)

**Step 4.1** -- Replace stringly-typed UserProfile fields with enums
- File: `Models/UserProfile.swift:15-16,25`
- Create DistanceUnit, SplitUnit, WeightUnit enums with String raw values
- Update all call sites
- **Depends on:** Phase 2 (concurrency fixes)

**Step 4.2** -- Fix OnboardingPage AnyView to generic
- File: `Views/Components/OnboardingPage.swift:9`
- Change to `struct OnboardingPage<Content: View>: View`
- Update call sites in OnboardingWalkthroughView.swift
- **Depends on:** Nothing

**Step 4.3** -- Make netButterTsp a computed property (or add didSet)
- File: `Models/Run.swift:23`
- Either make computed from eaten-burned or add didSet recalculation
- **Depends on:** Step 1.8

**Step 4.4** -- Add id to Split model
- File: `Models/Split.swift:12`
- Add `var id: UUID = UUID()` for consistency with other @Model types
- **Depends on:** Nothing

**Step 4.5** -- Fix accessibility across all views (batch fix)
- Files: ButterStickView, GoldButton, OnboardingPage, SegmentedControl, SheetHeader, ContextualStrip, RunDetailView, RunMapView
- Add proper .accessibilityLabel, .accessibilityHidden, .isSelected traits
- **Depends on:** Nothing

**Step 4.6** -- Fix dark mode colors in BannerView
- File: `Views/Components/BannerView.swift:9-30`
- Use asset catalog colors or @Environment(\.colorScheme) conditional
- **Depends on:** Nothing

**Step 4.7** -- Move recalculateRuns to background
- File: `Views/Settings/SettingsView.swift:328-346`
- Wrap in Task with @MainActor only for final save
- **Depends on:** Step 2.1

**Step 4.8** -- Add location permission check before run start
- File: `Views/ActiveRun/ActiveRunView.swift:126-131`
- Check CLLocationManager.authorizationStatus in onAppear, show alert if denied
- **Depends on:** Nothing

### PHASE 5: Documentation Sync (do fifth -- after code changes stabilize)

**Step 5.1** -- Update README feature list, deployment target, add Strava setup instructions
- File: `README.md`
- Fix iOS 17 to 18, add missing features, add xcconfig setup steps
- **Depends on:** Phase 4

**Step 5.2** -- Add "Superseded" banner to DESIGN.md
- File: `DESIGN.md`
- Add banner at top: "This document reflects the original v1.0 design. See docs/superpowers/specs/2026-04-05-ui-redesign-design.md for the current design."
- Check off completed phase items
- **Depends on:** Nothing

**Step 5.3** -- Update UI redesign spec status
- File: `docs/superpowers/specs/2026-04-05-ui-redesign-design.md:4`
- Change "Draft -- Pending user review" to "Implemented"
- Fix duplicate item 19 numbering
- **Depends on:** Nothing

**Step 5.4** -- Fix LegalText.swift comment
- File: `Utilities/LegalText.swift:5`
- Change "ContentView.currentTosVersion" to actual containing type
- **Depends on:** Nothing

### PHASE 6: Test Coverage (do sixth -- validates all prior fixes)

**Step 6.1** -- Enable UI tests in CI
- File: `.github/workflows/ci.yml:125`
- Remove `-only-testing:ButterRunTests` or add separate UI test job
- **Depends on:** Phase 5 (docs/code stable)

**Step 6.2** -- Add StravaAuthService tests
- New file: `ButterRunTests/Unit/StravaAuthServiceTests.swift`
- Test: PKCE generation, state validation, token refresh serialization (Step 2.2), disconnect
- Mock URLSession and KeychainService
- **Depends on:** Step 2.2

**Step 6.3** -- Add StravaUploadService tests
- New file: `ButterRunTests/Unit/StravaUploadServiceTests.swift`
- Test: GPX generation (pure function), multipart form, API response parsing, polling
- **Depends on:** Nothing

**Step 6.4** -- Add LocationService delegate tests
- Expand: `ButterRunTests/Unit/LocationServiceTests.swift`
- Test: didUpdateLocations distance accumulation, GPS spike rejection (>100m), accuracy filtering (<20m), elevation gain/loss, weak/lost signal, Douglas-Peucker simplification
- **Depends on:** Nothing

**Step 6.5** -- Add KeychainService tests
- New file: `ButterRunTests/Unit/KeychainServiceTests.swift`
- Test: save/load roundtrip, delete, overwrite, empty string
- **Depends on:** Nothing

**Step 6.6** -- Fix StravaTests to call actual code
- File: `ButterRunTests/Unit/StravaTests.swift`
- Extract formatting as internal testable functions on StravaUploadService, test those
- **Depends on:** Step 6.3

**Step 6.7** -- Add ActiveRunViewModel.updateMetrics() tests
- File: `ButterRunTests/Integration/ActiveRunViewModelTests.swift`
- Simulate location updates via MockLocationService, verify butter burn, splits, auto-pause
- **Depends on:** Step 2.1

**Step 6.8** -- Add ChurnEstimator lifecycle tests
- File: `ButterRunTests/Unit/ChurnEstimatorTests.swift`
- Test processSample with stage transitions, start/stop/pause lifecycle, ChurnResult output
- **Depends on:** Nothing

**Step 6.9** -- Add missing AchievementService test cases
- File: `ButterRunTests/Unit/AchievementServiceTests.swift`
- Add tests for: patOnTheBack, poundPounder, butterSculptor, fiveRunStreak, butterFingers
- **Depends on:** Nothing

**Step 6.10** -- Enable code coverage in CI
- Files: `.github/workflows/ci.yml`, `ButterRun.xcscheme`
- Add `-enableCodeCoverage YES` to xcodebuild, add codeCoverageEnabled to scheme
- **Depends on:** Step 6.1

### PHASE 7: Build &amp; Tooling Polish (do last)

**Step 7.1** -- Add CI build caching
- File: `.github/workflows/ci.yml`
- Add actions/cache for DerivedData keyed on swift file + pbxproj hash
- **Depends on:** Step 6.1

**Step 7.2** -- Add CI check that pbxproj matches generated output
- File: `.github/workflows/ci.yml`
- Run generate_xcodeproj.py and diff against committed pbxproj
- **Depends on:** Nothing

**Step 7.3** -- Fix generate_icon.py hardcoded path
- File: `generate_icon.py:5`
- Use `os.path.dirname(os.path.abspath(__file__))` for relative path
- **Depends on:** Nothing

**Step 7.4** -- Add requirements.txt for Python dependencies
- New file: `requirements.txt`
- Add Pillow>=10.0, google-genai
- **Depends on:** Nothing

---

## EXECUTION DEPENDENCY GRAPH

```
Phase 1 (Data Integrity) ── no dependencies, do first
    |
Phase 2 (Concurrency) ── depends on Phase 1
    |
Phase 3 (Security) ── can parallel with Phase 2, but logically after
    |
Phase 4 (Code Quality) ── depends on Phase 2
    |
Phase 5 (Docs) ── depends on Phase 4 (code changes finalized)
    |
Phase 6 (Tests) ── depends on Phase 5 (tests validate final code)
    |
Phase 7 (Build/Tooling) ── depends on Phase 6
```

## VERIFICATION

After each phase:
1. Run `xcodebuild build` to verify compilation
2. Run `xcodebuild test -only-testing:ButterRunTests` to verify unit tests pass
3. After Phase 6: Run full test suite including UI tests
4. After Phase 7: Verify CI pipeline passes end-to-end
5. Final: Manual walkthrough of complete run lifecycle (start -> track -> eat butter -> stop -> summary -> share -> history)
