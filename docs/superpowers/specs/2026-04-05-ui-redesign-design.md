# Butter Run — UI Redesign Spec

**Date:** 2026-04-05
**Status:** Implemented
**Scope:** Full visual redesign + terminology change + new features

## Context

The Butter Run app works but has visual and UX issues: dark theme feels heavy, the butter mascot is generic, the "teaspoons" unit doesn't connect with the butter theme, there's no onboarding walkthrough, and users lack contextual help throughout. This redesign addresses all of these while adding a Churn Guide tab and improving the Butter Zero experience.

## Key Design Decisions

These are **intentional changes** from the current codebase:

| Decision | Current | New | Rationale |
|----------|---------|-----|-----------|
| Theme | Dark (#1A1A1C bg) | Light cream (#FFFDF7 bg) | Crisper, cleaner, "dairy packaging" feel |
| Dark mode | Forced dark everywhere | Light only (v1.0) | Simplify launch; dark mode is a future add |
| Primary unit | Teaspoons (tsp) | Pats | More butter-themed and tangible |
| Unit equivalence | 1 pat = 1.06 tsp (36 cal) | 1 pat = 1 tsp exactly (34 cal) | Simplify; change `ButterServing.pat.teaspoonEquivalent` to 1.0. Eat sheet presets: pat/tbsp/half-stick/custom (no separate tsp option). Existing stored entries with 1.06 are left as-is. |
| Butter Zero score | 0-100 internal score | Deleted entirely | Remove `butterZeroScore` from `ButterCalculator`, `Run` model, all ViewModels, `ShareImageRenderer`, `VoiceFeedbackService`, and all tests. Share card uses +/- pats display instead. |
| Terminology | "teaspoons melted" | "pats burned" | "Burned" is clearer than "melted" |
| Abbreviation | "BZ:" in ContextualStrip | Always "Butter Zero" | No abbreviations; clarity over brevity |
| Butter Zero scoring | 0-100 score | +/- pats from net zero | More intuitive, no arbitrary scoring |
| Share button | "Share My Churn" | "Share My Run" | Clearer for social sharing context |
| Onboarding | Single-page form | 4-page walkthrough | Explain the unique concepts before signup |
| Navigation | 3 tabs (Run, History, Settings) | 4 tabs (+Churn Guide) | Practical churning instructions deserve a tab |
| Settings: HealthKit | Single disabled toggle | Integrations section (Health, Strava, Garmin) | Future-proofed; Strava/Garmin as "Coming Soon" |
| Weight input | kg only | lbs/kg toggle | US users expect pounds |
| Stop button | Tap → confirmation dialog | Hold 3 sec → confirmation dialog | Prevent accidental stops mid-run |
| Run Edit | Distance + notes editable; date/duration read-only | All fields editable | Users should be able to correct mistakes |
| Butter facts | 10 facts, random per view load | 40 facts, random per view load | More variety; same rotation behavior |
| Location privacy | "We never share or store" | "We never share; saved locally only (unless integration)" | More accurate with Strava/Health sync |

## Color Palette (Design Tokens)

All colors pass WCAG AA on cream background unless noted.

```swift
// ButterTheme — Light Mode
enum ButterTheme {
    static let background = Color(hex: "FFFDF7")      // Warm cream page bg
    static let surface = Color(hex: "FFFFFF")          // Cards, sheets
    static let surfaceBorder = Color(hex: "F0E6D0")    // Card borders
    static let gold = Color(hex: "D4940A")             // Primary accent (4.8:1 on cream)
    static let goldDim = Color(hex: "B87D08")          // Pressed/secondary accent (5.9:1)
    static let goldLight = Color(hex: "FFF3D6")        // Tinted backgrounds
    static let textPrimary = Color(hex: "1C1C1E")      // Body text (14.2:1)
    static let textSecondary = Color(hex: "6B6B70")    // Labels, captions (4.6:1)
    static let success = Color(hex: "2D8E40")          // Butter Zero positive (4.7:1)
    static let deficit = Color(hex: "CC3333")          // Negative states (4.5:1)
    static let onPrimaryAction = Color.white            // Text on gold buttons

    // Semantic colors (not in palette swatch, used inline)
    static let warning = Color(hex: "E67E22")          // GPS weak banner
    static let info = Color(hex: "1976D2")             // Info banners
    static let toastBackground = Color(hex: "1C1C1E")  // Dark toast pill
}
```

## Spacing & Sizing Tokens (in pt)

```swift
enum ButterSpacing {
    static let cardPadding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 16
    static let buttonHeight: CGFloat = 50
    static let buttonCornerRadius: CGFloat = 14
    static let inputCornerRadius: CGFloat = 12
    static let sheetCornerRadius: CGFloat = 20
    static let horizontalPadding: CGFloat = 16    // Screen edge padding
    static let cardGap: CGFloat = 10              // Between cards
    static let sectionGap: CGFloat = 16           // Between major sections
    static let controlButtonSize: CGFloat = 56    // Eat/Pause/Stop circles
    static let controlButtonLarge: CGFloat = 68   // Pause (center, larger)
    static let minTouchTarget: CGFloat = 44       // Apple minimum
    static let infoBtnSize: CGFloat = 44          // Info button tap target (visual: 18pt circle with 44pt hit area)
    static let tabBarHeight: CGFloat = 49         // Standard iOS tab bar
}
```

## Typography

All text uses SF Rounded (`.fontDesign(.rounded)` in SwiftUI).

| Use | Style | Size | Weight |
|-----|-------|------|--------|
| Hero numbers | Custom | 48-56pt | .black |
| Screen titles | .title2 | ~22pt | .bold |
| Card titles | Custom | 14pt | .bold |
| Body text | .body | ~17pt | .regular |
| Secondary labels | .caption | ~12pt | .regular |
| Stat values | Custom | 18-20pt | .heavy |
| Stat labels | Custom | 10pt | .semibold |
| Button text | Custom | 17pt | .bold |
| Tab bar labels | .caption2 | ~10pt | .semibold |

## Screen Inventory

All screens are mockup'd in `/mockups/complete.html` (17 sections).

### Main Screens (5)
1. **Home** — Weekly pats summary, Butter Zero toggle + scale, Churn toggle, "Start Churning"
2. **Active Run (Metrics)** — Pats hero, Butter Zero scale, 2x2 metric grid, 3 equal circle buttons
3. **Active Run (Map)** — Compact pats display, route map (~50%), Butter Zero bar, controls
4. **Run Summary** — Butter stick animation, 6 stats, Butter Zero result, splits, achievement, share
5. **Churn Guide** — What You Need (3 steps), Temperature + Body Heat, 5 Stages, Tips

### Sub-Screens (4)
6. **History** — All-time stats, chronological run list, swipe-to-delete, "+ Manual"
7. **Run Detail** — Tap from History; butter hero, route map, BZ result, 6 stats, splits, butter eaten log
8. **Settings** — Profile, Units, Run Settings, Integrations, Butter Math, About, Delete All Data
9. **Onboarding** — 4-page walkthrough (Welcome, Butter Zero, Churn, Profile)

### Sheets (4)
10. **Eat Butter** — Half-sheet; 2x2 preset grid (tsp/pat/tbsp/½stick) + custom input
11. **Churn Setup** — Half-sheet; cream type, amount, room temp toggle
12. **Manual Run Entry** — Full sheet; date picker, distance, duration, units, estimated pats preview
13. **Run Edit** — Full sheet; distance, duration, date (all editable), notes

### Dialogs & Alerts (6)
14. **End Run** — "End run?" → Finish Run / Cancel
15. **Delete All Data** — "Delete All Data?" → Delete Everything / Cancel → Onboarding
16. **Delete Run** — "Delete this run?" → Delete / Cancel → stays on History
17. **Crash Recovery** — "Unfinished Run" → Discard (resume not possible: timer state not persisted)
18. **Recalculate Weight** — "Recalculate Past Runs?" → Recalculate / Skip
19. **Room Temp Warning** — "Room temperature cream won't churn properly" → OK

### Run States & Banners (4)
19. **Paused** — Gold banner "Run Paused", dimmed metrics, green Resume button
20. **GPS Weak** — Orange banner "GPS signal weak — distance may be inaccurate"
21. **GPS Lost** — Red banner "GPS signal lost — distance paused"
22. **Auto-Paused** — Gold banner "Auto-paused — not moving", "Start moving to resume"

### Transient UI (3)
23. **Undo Toast** — Dark pill "Added 1 pat (36 cal)" + "Undo" link; 8-sec auto-dismiss
24. **Auto-Pause Toast** — Dark pill "Auto-paused"
25. **Resume Toast** — Dark pill "Resumed"

### Empty & Error States (4)
26. **Empty History** — Faded butter illustration, "No runs yet", "Tap Run to start"
27. **First Launch Home** — 0.0 pats, "Get out there and burn some butter!"
28. **Location Pre-Ask** — 📍 icon, explanation text, "Allow Location" CTA
29. **Location Denied** — Red heading, "Open Settings" button with instructions

### Other (4)
30. **Achievement Unlock Overlay** — Full-screen cream overlay on Summary; emoji, title, "Awesome!" dismiss button. Appears immediately when Summary loads if achievements were earned. Tapping "Awesome!" reveals Summary underneath. Multiple achievements: show one at a time, sequential.
31. **Share Cards** — Story (9:16) and Square (1:1) formats
32. **Splash Screen** — Cream background, butter pat illustration, "Butter Run" text
33. **Tooltip Popovers** — 7 locations; `.popover(isPresented:)` with `.presentationCompactAdaptation(.popover)`

## ContextualStrip During Active Run

The existing `ContextualStrip.swift` is **kept but redesigned**:
- Butter Zero row: shows "Butter Zero" (never "BZ:"), net pats value, directional arrow
- Churn progress row: shows stage name + progress bar (unchanged logic)
- The "Quick Eat" button on the strip is **removed** — replaced by the dedicated circular Eat button in the control row. One less tap target to worry about during a run.

## Stop Button Interaction

The stop button uses a **3-second long press**:

1. User presses and holds the red stop button
2. A circular progress ring fills around the button over 3 seconds (gold stroke, clockwise)
3. Haptic feedback: light impact at start, medium impact at 1s/2s, heavy at 3s
4. If released before 3 seconds: ring resets, nothing happens
5. At 3 seconds: confirmation dialog appears ("End run?" → Finish Run / Cancel)
6. Ring animation respects `accessibilityReduceMotion` — if reduced, show "Hold to stop" label instead of ring

## Butter Zero Scale

The Butter Zero scale is **dynamic** — no hardcoded range:

- The center point is always "net zero" (0.0 pats)
- The dot position is calculated as: `centerX + (netPats / maxAbsNetPats) * halfWidth`
- `maxAbsNetPats` is the maximum absolute value of net pats seen in the current run/history, clamped to minimum ±2 so the scale doesn't compress for tiny values
- Labels: "− pats" (left) / "net zero" (center) / "+ pats" (right)
- Dot color: gold if |net| < 0.5 pats, green (success) if |net| 0.5-2.0 pats, amber (goldDim) if |net| 2.0-4.0 pats, red (deficit) if |net| > 4.0 pats
- The scale auto-zooms: if net is +12 pats, the scale extends to show ±15

## New Component: InfoButton

```swift
struct InfoButton: View {
    let title: String
    let body: String
    @State private var showPopover = false

    var body: some View {
        Button { showPopover.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(ButterTheme.textSecondary)
        }
        .frame(minWidth: 44, minHeight: 44) // Touch target
        .popover(isPresented: $showPopover) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(.subheadline, design: .rounded, weight: .bold))
                Text(body).font(.system(.caption, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
            }
            .padding(12)
            .presentationCompactAdaptation(.popover)
        }
    }
}
```

**Placement locations (7):**
1. Home → next to "Butter Zero" toggle
2. Home → next to "Churn Tracker" toggle
3. Active Run → next to "Butter Zero" scale title
4. Run Detail → next to "Butter Zero" title
5. Onboarding Page 4 → next to "Your weight" label
6. Settings → next to "Butter Math" section header
7. Settings → next to "Integrations" section header

## Location Permission Flow

**When triggered:** First time user taps "Start Churning" on Home, if location permission is `.notDetermined`.

**Flow:**
1. Show pre-ask screen (📍 "Location Access" with explanation)
2. User taps "Allow Location" → iOS system permission dialog appears
3. If granted → proceed to Active Run (or Churn Setup if churn enabled)
4. If denied → show "Location Denied" screen with "Open Settings" button
5. On subsequent launches: if previously denied, show denied state when tapping Start Churning

## Reusable Component Library

Build these first, then use across all screens:

1. `ButterCard` — White bg, gold border, 16pt radius, 16pt padding
2. `ButterZeroScale` — Horizontal scale with center dot, dynamic range
3. `MetricCell` — Value + label in bordered cell
4. `StatRow` — 3-column even grid with dividers
5. `BannerView(type:text:)` — .warn / .error / .info / .pause variants
6. `ToastView(text:action:)` — Dark pill, auto-dismiss
7. `InfoButton(title:body:)` — 44pt tap target, popover
8. `GoldButton(title:)` — Full-width gold CTA
9. `SecondaryButton(title:)` — Outlined variant
10. `SheetHeader(title:onCancel:)` — Handle + title + Cancel
11. `OnboardingPage` — Centered layout with emoji, title, body, dots
12. `SplitTable` — Mile/Pace/Pats/Elev grid
13. `HistoryRow` — Date + stats left, pats right
14. `SegmentedControl` — Cream/gold styled picker

## Code Impact Map

### Files to MODIFY (existing code changes)

**Theme switch (Phase 2) — remove `.preferredColorScheme(.dark)` from 9 files:**
1. `ButterRunApp.swift` (OnboardingView)
2. `HomeView.swift`
3. `ActiveRunView.swift`
4. `EatButterSheet.swift`
5. `RunSummaryView.swift`
6. `RunHistoryView.swift`
7. `RunEditView.swift`
8. `ManualRunEntryView.swift`
9. `SettingsView.swift`

**Theme switch — fix `foregroundStyle(ButterTheme.background)` on gold buttons (7 files):**
`RunSummaryView`, `RunEditView`, `ButterRunApp` (OnboardingView), `ChurnSetupSheet`, `ManualRunEntryView`, `ContextualStrip`, `ChurnButton` → change to `.onPrimaryAction`

**Theme switch — replace `.white.opacity(...)` borders (6+ files):**
`ShareImageRenderer`, `HomeView`, `ContextualStrip`, `RunMapView`, `ActiveRunView`, `ButterZeroBar`, `MetricGridView` → change to `surfaceBorder`

**Terminology (Phase 3) — "tsp" → "pats" display strings (8 files):**
`HomeView`, `RunHistoryView`, `EatButterSheet`, `RunSummaryView`, `RunDetailView`, `ActiveRunView`, `ButterZeroBar`, `ContextualStrip`

**Terminology — voice strings (1 file):** `VoiceFeedbackService` (4 speech strings)

**Terminology — achievement descriptions (1 file):** `Achievement.swift` (10 descriptions)

### Files to DELETE or REPLACE
- `ButterZeroBar.swift` → replaced by new `ButterZeroScale`
- `ButterCalculator.butterZeroScore()` → deleted (no replacement)
- `Run.butterZeroScore` computed property → deleted
- `Image("butter-pat")` references (9 files) → replaced by `ButterPatView()` or final asset

### Files to CREATE (new)
- `Views/Guide/ChurnGuideView.swift` — new Tab 3
- `Views/Onboarding/OnboardingWalkthroughView.swift` — 4-page rewrite
- `Views/Components/InfoButton.swift`
- `Views/Components/ButterZeroScale.swift`
- `Views/Components/BannerView.swift`
- `Views/Components/ToastView.swift`
- `Views/Components/GoldButton.swift`
- `Views/Components/SecondaryButton.swift`
- `Views/Components/SheetHeader.swift`
- `Views/ActiveRun/LongPressStopButton.swift` — 3-sec hold with ring animation

### Files to REFACTOR (extract reusable components)
These are not new — they extract existing inline code into shared components:
- `MetricCell` — extracted from `MetricGridView` inline cells
- `StatRow` — extracted from `RunSummaryView` stats grid
- `SplitTable` — extracted from `RunSummaryView` / `RunDetailView` split rows
- `HistoryRow` — extracted from `RunHistoryView` inline row

### Data Model Changes

**`ButterEntry.swift`:** Change `ButterServing.pat.teaspoonEquivalent` from `1.06` to `1.0`. Remove the separate `teaspoon` case from the Eat Butter sheet presets — pat IS tsp now.

**`UserProfile` (SwiftData migration V2→V3):** Add `weightUnit: String = "kg"` field. Requires new `SchemaV3` and `MigrationPlan` stage. Lightweight migration (additive field with default).

**`ButterCalculator.swift`:** Delete `butterZeroScore(netTsp:)` function entirely.

**`Run` model:** Delete `butterZeroScore` computed property. No schema migration needed (it was computed, not stored).

**`MainTabView`:** Add 4th tab for `ChurnGuideView`.

### Test Impact

**Tests that BREAK and need updating (8 files):**

| Test File | Why | Action |
|-----------|-----|--------|
| `ButterZeroScoringTests.swift` | `butterZeroScore` deleted | Delete all 6 tests |
| `ButterCalculatorTests.swift` | Score tests + "tsp" assertions | Delete score tests, update format assertions |
| `FormatterTests.swift` | Asserts "tsp" in output | Update to assert "pats" |
| `StartStopRunUITests.swift` | `"teaspoons melted"` accessibility | Update to `"pats burned"` |
| `ButterZeroFlowUITests.swift` | `"quick add one teaspoon"` accessibility | Update to `"pat"` |
| `OnboardingUITests.swift` | Assumes single-page, kg-only | Rewrite for 4-page + lbs/kg |
| `AchievementServiceTests.swift` | May reference "teaspoon" descriptions | Update strings |
| `ActiveRunViewModelTests.swift` | If `butterZeroScore` API used | Remove score references |

**New tests to ADD:**
- Pat formatter tests (`pats()`, `patsWithCals()`)
- `ButterZeroScale` dynamic range calculation
- `LongPressStopButton` 3-sec gesture
- Location permission pre-ask flow
- lbs/kg weight conversion
- Run Edit with all editable fields
- ChurnGuideView renders correctly

## Implementation Order

### Phase 1: Foundation (no visual changes to existing screens)
1. Add `ButterLightTheme` to `Constants.swift` with new palette
2. Add `ButterSpacing` and `ButterTypography` token enums
3. Add formatters to `Formatters.swift`:
   - `pats(_ tsp: Double) -> String` returns `"8.4 pats"` (since 1 pat = 1 tsp, just relabels)
   - `patsWithDetail(_ tsp: Double) -> String` returns `"≈ 8.4 tsp (286 cals)"` (secondary line)
   - Deprecate `butter(tsp:)` with `@available(*, deprecated, renamed: "pats")`
4. Build component library (14 components above)
5. Run all tests — must pass, nothing visual changed yet

### Phase 2: Theme Switch
6. Replace `ButterTheme` hex values with light palette
7. Remove `.preferredColorScheme(.dark)` from all 9 views
8. Fix all `foregroundStyle(ButterTheme.background)` on gold buttons → `.onPrimaryAction`
9. Fix all `.white.opacity(0.12)` borders → `surfaceBorder`
10. Update `ButterStickView` gradient hex
11. Update `ShareImageRenderer` for light card design
12. Update `ChurnButton` gradient for light backgrounds

### Phase 3: Terminology
13. Replace "tsp" display strings with "pats" using new formatters in all view files
14. Update `VoiceFeedbackService` — "pats burned" in all speech strings (replace "teaspoons melted")
15. Update all 10 achievement descriptions (e.g., "Burn your first pat" not "teaspoon")
16. Change `ButterServing.pat.teaspoonEquivalent` from 1.06 to 1.0
17. Remove `teaspoon` preset from Eat Butter sheet — presets become: pat / tbsp / half-stick / custom
18. Fix "BZ:" → "Butter Zero" in ContextualStrip
19. Rename "Share My Churn" → "Share My Run" in RunSummaryView
20. Delete `butterZeroScore` from ButterCalculator, Run model, all ViewModels
21. Update ShareImageRenderer: remove score-based conditional layout, use +/- pats display

### Phase 4: New Features
18. Rewrite `OnboardingView` as 4-page `TabView(.page)`
19. Create `ChurnGuideView` + add as Tab 3
20. Add `InfoButton` to 7 locations
21. Build `ButterZeroScale` replacing `ButterZeroBar` (dynamic range, no 0-100 score)
22. Add location permission pre-ask flow
23. Implement 3-sec hold gesture on stop button
24. Make Run Edit fields all editable (date, duration)
25. Add lbs/kg toggle to onboarding and Settings weight input
26. Replace HealthKit toggle with Integrations section
27. Add 30 new butter facts to `ButterFacts.trivia`
28. Display achievements on Run Summary
29. Build Achievement Unlock overlay

### Phase 5: Polish & Test
30. Update all UI tests for new terminology and navigation
31. Add unit tests for pat formatters
32. Accessibility audit (44pt targets, contrast, VoiceOver labels)
33. Splash screen (cream bg + butter illustration + "Butter Run")
34. Share card redesign (light theme, "Share My Run")
35. Final visual QA pass

## Verification

To verify the redesign is complete:

1. **Build + run on simulator** — all screens render with light theme
2. **Onboarding flow** — 4 pages swipe correctly, profile creates on "Let's Churn"
3. **Start a run** — location permission asks, Active Run shows pats + Butter Zero
4. **Eat butter** — sheet shows 4 presets, undo toast appears 8 sec
5. **Stop run** — 3-sec hold, confirmation, Summary shows with achievements
6. **History** — runs show in pats with calories, tap to detail, swipe to delete
7. **Churn Guide tab** — new tab renders, all 5 stages visible
8. **Settings** — Integrations section shows Apple Health + Coming Soon for Strava/Garmin
9. **Tooltips** — 7 info buttons all show popovers
10. **Run all tests** — all pass with new terminology
11. **VoiceOver** — navigate through every screen, all elements labeled
12. **Dynamic Type** — increase to AX3, verify no clipping

## Mockup Reference Files

All visual mockups are in `/mockups/`:
- `complete.html` — 17 sections, every screen and state (PRIMARY REFERENCE)
- `flows.html` — 7 flow diagrams, complete button map, all dialogs
- `index.html` — earlier iteration (superseded by complete.html)
- `screens2.html` — earlier iteration (superseded by complete.html)
