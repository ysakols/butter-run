# Performance Fix Plan — Butter Run

Step-by-step implementation plan for all 6 issues from the performance evaluation.
Deployment target: **iOS 18.0+**

---

## Fix 1 (P0): Async Share Image Rendering

**Problem:** `ShareImageRenderer.render()` runs at 3× scale on the main thread, freezing the UI for 2–5 seconds when the user taps "Share."

**Files:**
- `Services/ShareImageRenderer.swift`
- `Views/Summary/RunSummaryView.swift`
- `ViewModels/RunSummaryViewModel.swift`
- `ButterRunTests/Unit/ShareImageRendererTests.swift`

**Steps:**

1. **`ShareImageRenderer.swift`** — Make `render()` async:
   - Keep `@MainActor` for `ImageRenderer` setup and `.uiImage` access (SwiftUI requires main thread).
   - Capture the raw `UIImage` on main, then move `stripMetadata(from:)` to a detached task:
     ```swift
     @MainActor
     static func render(run: Run, usesMiles: Bool, mode: ShareCardMode = .story) async -> UIImage? {
         let view = ShareCardContent(run: run, usesMiles: usesMiles, mode: mode)
         let renderer = ImageRenderer(content: view)
         renderer.scale = 3.0
         guard let rawImage = renderer.uiImage else { return nil }
         return await Task.detached(priority: .userInitiated) {
             stripMetadata(from: rawImage) ?? rawImage
         }.value
     }
     ```
   - Make `stripMetadata` a `nonisolated static` method (it uses only CoreGraphics, no UI).

2. **`RunSummaryView.swift`** — Add loading state to `generateAndShare()`:
   - Add `@State private var isGeneratingShare = false`.
   - Update `generateAndShare()`:
     ```swift
     private func generateAndShare() {
         guard !isGeneratingShare else { return }
         isGeneratingShare = true
         Task {
             shareImage = await ShareImageRenderer.render(run: run, usesMiles: usesMiles, mode: shareMode)
             showShareSheet = shareImage != nil
             isGeneratingShare = false
         }
     }
     ```
   - Show `ProgressView` overlay on the share button when `isGeneratingShare` is true.
   - Disable the share button while generating.

3. **`RunSummaryViewModel.swift`** — Update `generateShareImage()` (line 40–42):
   ```swift
   @MainActor
   func generateShareImage() async -> UIImage? {
       await ShareImageRenderer.render(run: run, usesMiles: usesMiles)
   }
   ```

4. **`ShareImageRendererTests.swift`** — Update all 3 test calls to use `await`:
   ```swift
   let image = await ShareImageRenderer.render(run: run, usesMiles: true, mode: .story)
   ```

**Risk:** Low. The `ImageRenderer.uiImage` capture is still on main (required), only the EXIF strip moves off-main.

---

## Fix 2 (P0): Background Route Simplification

**Problem:** Douglas-Peucker algorithm (up to 20 binary-search iterations over 5000+ points) runs on the main thread, causing stutter at end of long runs.

**Files:**
- `Services/LocationService.swift`
- `ViewModels/ActiveRunViewModel.swift`

**Steps:**

1. **`LocationService.swift`** — Add an async variant for heavy callers:
   ```swift
   /// Async route encoding — runs Douglas-Peucker off the main thread.
   func encodeRouteAsync() async -> Data? {
       // Fast path: cache hit
       if !routeIsDirty, let cached = cachedRouteData {
           return cached
       }
       if routeBuffer.count <= 5000 {
           // Lightweight — just JSON encode, fine on any thread
           return encodeRoute()
       }
       // Heavy path: dispatch simplification to background
       let buffer = routeBuffer  // snapshot value type
       return await withCheckedContinuation { continuation in
           DispatchQueue.global(qos: .userInitiated).async {
               let asLocations = buffer.map { CLLocation(latitude: $0[0], longitude: $0[1]) }
               let simplified = self.simplifyRoute(asLocations, maxPoints: 5000)
               let coords = simplified.map { [$0.coordinate.latitude, $0.coordinate.longitude] }
               let data = try? JSONEncoder().encode(coords)
               DispatchQueue.main.async {
                   self.cachedRouteData = data
                   self.routeIsDirty = false
               }
               continuation.resume(returning: data)
           }
       }
   }
   ```
   - The existing sync `encodeRoute()` stays unchanged — no protocol change needed.
   - `encodeRouteAsync()` is an implementation detail on `LocationService`, not on the `LocationTracking` protocol.
   - `MockLocationService` in tests (`ActiveRunViewModelTests.swift:35`) is unaffected — it only implements the sync protocol method.

2. **`ActiveRunViewModel.swift`** — Use async encoding in the two non-critical paths:

   Add a guard flag:
   ```swift
   private var isEncodingRoute = false
   ```

   **`updateMetrics()` (lines 454–461)** — replace the sync route update block:
   ```swift
   if lastRouteUpdate.map({ Date().timeIntervalSince($0) >= 5 }) ?? true {
       if locationService.routeIsDirty, !isEncodingRoute {
           isEncodingRoute = true
           let service = locationService as? LocationService
           Task { @MainActor in
               if let data = await service?.encodeRouteAsync() ?? locationService.encodeRoute() {
                   routeCoordinates = LocationService.decodeRoute(data)
               }
               isEncodingRoute = false
           }
       }
       lastRouteUpdate = Date()
   }
   ```

   **`checkDraftSave()` (line 528)** — wrap route encode in a Task:
   ```swift
   let service = locationService as? LocationService
   Task { @MainActor in
       let routeData = await service?.encodeRouteAsync() ?? locationService.encodeRoute()
       draftService?.saveDraft(
           startDate: startDate ?? .now,
           // ... remaining params unchanged ...
           routeData: routeData,
           butterEntriesData: entriesData
       )
   }
   ```

   **`stopRun()` (line 305)** — keep the sync `locationService.encodeRoute()` call. By this point the route was already cached by the 5-second update cycle, so it hits the fast path (returns `cachedRouteData`).

**Risk:** Low. The sync path is unchanged. The async path only activates for routes >5000 points. `stopRun()` always hits the cache.

---

## Fix 3 (P1): Paginate Run History

**Problem:** `@Query` loads all `Run` objects. `ForEach` renders all rows. Degrades linearly with run count.

**Files:**
- `Views/History/RunHistoryView.swift`

**Steps:**

1. Add state for progressive display:
   ```swift
   @State private var visibleCount = 50
   ```

2. Update the `ForEach` in the "All Runs" section (lines 50–65):
   ```swift
   Section("All Runs") {
       ForEach(runs.prefix(visibleCount), id: \.id) { run in
           NavigationLink {
               RunDetailView(run: run, usesMiles: usesMiles)
           } label: {
               RunRowView(run: run, usesMiles: usesMiles)
           }
           .listRowBackground(ButterTheme.surface)
       }
       .onDelete { indexSet in
           if let index = indexSet.first, index < runs.count {
               runToDelete = runs[index]
               showDeleteConfirmation = true
           }
       }

       if visibleCount < runs.count {
           Button {
               visibleCount += 50
           } label: {
               Text("Show More (\(runs.count - visibleCount) remaining)")
                   .font(.system(.body, design: .rounded))
                   .foregroundStyle(ButterTheme.gold)
                   .frame(maxWidth: .infinity)
                   .padding(.vertical, 8)
           }
           .listRowBackground(ButterTheme.surface)
       }
   }
   ```

   `runs.prefix(visibleCount)` preserves indices from the original array, so `onDelete` indexing is correct.

**Note:** SwiftData uses faulting for relationship properties (`splits`, `butterEntries`, `routePolyline`). Scalar fields on `Run` are ~200 bytes each, so even 1000 runs = ~200 KB. The pagination primarily bounds the `List` row creation and the `viewModel.load(runs:)` summary iteration.

**Risk:** Very low. Purely additive change.

---

## Fix 4 (P2): Reduce HealthKit Timeout

**Problem:** 5-second hardcoded timeout blocks the post-run flow when HealthKit entitlements are missing.

**File:**
- `Services/HealthKitService.swift`

**Steps:**

1. **Line 108** — Change the timeout from 5 seconds to 2 seconds:
   ```swift
   // Before:
   try? await Task.sleep(nanoseconds: 5_000_000_000)
   // After:
   try? await Task.sleep(nanoseconds: 2_000_000_000)
   ```

One line. The `beginCollection` call either succeeds within milliseconds or hangs indefinitely (entitlement issue), so 2 seconds is more than enough.

**Side effect:** `HealthKitServiceTests.test_saveWorkout_withoutAuthorization_returnsFalse` will finish 3 seconds faster per run.

**Risk:** Negligible.

---

## Fix 5 (P2): Index `Run.startDate`

**Problem:** `startDate` is the primary sort key for all queries but has no database index.

**File:**
- `Models/Run.swift`

**Steps:**

1. Add the `#Index` macro after the `Run` class definition:
   ```swift
   @Model
   class Run {
       // ... existing properties ...
   }

   #Index<Run>([\.startDate])
   ```

   SwiftData handles lightweight schema migration automatically — adding an index does not require a versioned migration plan.

2. The existing `@Attribute(.spotlight)` on `startDate` provides CoreSpotlight indexing (for system search). `#Index` adds a **SQLite index** for faster SwiftData query sorting and filtering. Both can coexist.

**Risk:** Negligible. Additive schema change with automatic migration.

---

## Fix 6 (P3): Batch Delete Drafts

**Problem:** `RunDraftService.saveDraft()` fetches all `RunDraft` objects into memory just to delete them before inserting a new one. Runs every 30 seconds during a run.

**File:**
- `Services/RunDraftService.swift`

**Steps:**

1. **`saveDraft()` (lines 36–41)** — Replace fetch-then-delete with batch delete:
   ```swift
   // Before:
   let descriptor = FetchDescriptor<RunDraft>()
   if let existing = try? context.fetch(descriptor) {
       for draft in existing {
           context.delete(draft)
       }
   }

   // After:
   try? context.delete(model: RunDraft.self)
   ```

2. **`deleteDraft()` (lines 75–84)** — Same pattern:
   ```swift
   func deleteDraft(context: ModelContext) {
       do {
           try context.delete(model: RunDraft.self)
           try context.save()
       } catch {
           logger.error("Failed to delete run draft: \(error, privacy: .public)")
       }
   }
   ```

3. **`purgeStale()` (lines 89–101)** — Use predicate-based batch delete:
   ```swift
   func purgeStale(context: ModelContext) {
       let cutoff = Date().addingTimeInterval(-48 * 60 * 60)
       do {
           try context.delete(model: RunDraft.self, where: #Predicate<RunDraft> {
               $0.lastCheckpoint < cutoff
           })
           try context.save()
       } catch {
           logger.error("Failed to purge stale drafts: \(error, privacy: .public)")
       }
   }
   ```

**Test coverage:** `RunDraftServiceTests` covers save/overwrite/delete/purge flows. The batch delete API is a drop-in replacement — same observable behavior, less memory.

**Risk:** Low.

---

## Deployment Target Change

Bump `IPHONEOS_DEPLOYMENT_TARGET` from `17.0` to `18.0` in:
- `scripts/generate_xcodeproj.py` (3 occurrences: lines 449, 467, 480)
- `ButterRun/ButterRun.xcodeproj/project.pbxproj` (6 occurrences)

Best approach: update `generate_xcodeproj.py` then regenerate the Xcode project with `python3 scripts/generate_xcodeproj.py`.

---

## Implementation Order

| Step | Fix | Effort | Files Changed |
|------|-----|--------|---------------|
| 0 | Bump deployment target to iOS 18 | trivial | `generate_xcodeproj.py`, regenerate project |
| 1 | Fix 4: HealthKit timeout | 1 line | `HealthKitService.swift` |
| 2 | Fix 5: Index startDate | 1 line | `Run.swift` |
| 3 | Fix 6: Batch delete drafts | 3 methods | `RunDraftService.swift` |
| 4 | Fix 3: Paginate history | 1 file | `RunHistoryView.swift` |
| 5 | Fix 1: Async share rendering | 4 files | `ShareImageRenderer.swift`, `RunSummaryView.swift`, `RunSummaryViewModel.swift`, tests |
| 6 | Fix 2: Background route simplification | 2 files | `LocationService.swift`, `ActiveRunViewModel.swift` |

Start with the easy wins (Fixes 4, 5, 6) to build momentum, then tackle the two async refactors (Fixes 1, 2) which require more careful testing.
