# Performance Fix Plan — Butter Run

Step-by-step implementation plan for all 6 issues from the performance evaluation.

---

## Fix 1 (P0): Async Share Image Rendering

**Problem:** `ShareImageRenderer.render()` runs at 3x scale on the main thread, freezing the UI for 2–5 seconds when the user taps "Share."

**Files:**
- `Services/ShareImageRenderer.swift`
- `Views/Summary/RunSummaryView.swift`
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
   - Make `stripMetadata` a `static` non-isolated method (it uses only CoreGraphics, no UI).

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

3. **`ShareImageRendererTests.swift`** — Update test calls to use `await`.

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
       let buffer = routeBuffer  // snapshot
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
   - The existing sync `encodeRoute()` stays unchanged for callers that need synchronous access.
   - No protocol change needed — `encodeRoute()` on the protocol stays sync; `encodeRouteAsync()` is an implementation detail used by the ViewModel.

2. **`ActiveRunViewModel.swift`** — Use async encoding in non-critical paths:
   - **`updateMetrics()` (line 454–461):** Replace the sync `encodeRoute()` call with a `Task` that calls `encodeRouteAsync()`. Add a guard flag (`isEncodingRoute`) to prevent overlapping tasks:
     ```swift
     private var isEncodingRoute = false
     
     // In updateMetrics(), replace the route update block:
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
   - **`checkDraftSave()` (line 528):** Same pattern — use `Task` with async encode.
   - **`stopRun()` (line 305):** Keep the sync `encodeRoute()` call. By this point the route was already cached by the 5-second update cycle, so it hits the fast path (just returns `cachedRouteData`).

**Risk:** Low. The sync path is unchanged. The async path only activates for routes >5000 points. `stopRun()` always hits the cache.

---

## Fix 3 (P1): Paginate Run History

**Problem:** `@Query` loads all `Run` objects into memory. `ForEach` renders all rows. Degrades linearly with run count.

**Files:**
- `Views/History/RunHistoryView.swift`

**Steps:**

1. **Add progressive display** — keep `@Query` for reactivity but limit rendered rows:
   ```swift
   @State private var visibleCount = 50
   ```

2. **Update the `ForEach`** in the "All Runs" section:
   ```swift
   Section("All Runs") {
       ForEach(runs.prefix(visibleCount), id: \.id) { run in
           NavigationLink { ... } label: { ... }
       }
       .onDelete { ... }  // adjust indexing for prefix
       
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

3. **Fix `onDelete` for prefixed array** — the delete handler indexes into the full `runs` array, but `ForEach` only shows a prefix. Adjust:
   ```swift
   .onDelete { indexSet in
       if let index = indexSet.first, index < runs.count {
           runToDelete = runs[index]
           showDeleteConfirmation = true
       }
   }
   ```
   This works because `runs.prefix(visibleCount)` preserves indexing relative to `runs`.

**Note:** SwiftData `@Query` fetches all matching objects, but SwiftData uses faulting for relationship properties (`splits`, `butterEntries`, `routePolyline`). Scalar fields on `Run` are ~200 bytes each, so 1000 runs = ~200 KB. The pagination primarily prevents `List` from creating all row views upfront and bounds the `viewModel.load(runs:)` iteration for summary stats.

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

That's it. One line change. The `beginCollection` call either succeeds within milliseconds or hangs indefinitely (entitlement issue), so 2 seconds is more than enough to distinguish success from failure.

**Risk:** Negligible.

---

## Fix 5 (P2): Index `Run.startDate`

**Problem:** `startDate` is the primary sort key for all queries but has no database index.

**File:**
- `Models/Run.swift`

**Constraint:** The app targets iOS 17.0. The SwiftData `#Index` macro requires iOS 18.0+.

**Steps:**

1. **Add an availability-gated index** using `#Index` for iOS 18+ users (majority of the user base by now), with graceful degradation for iOS 17:
   ```swift
   @Model
   class Run {
       // existing properties...
   }

   // Index for faster history queries (iOS 18+)
   #if swift(>=5.10)
   @available(iOS 18.0, *)
   extension Run {
       static var schemaMetadata: [Schema.PropertyMetadata] {
           // SwiftData picks up #Index at migration time
       }
   }
   #endif
   ```

   Actually, the correct approach is simpler. SwiftData `#Index` is a schema-level macro applied alongside `@Model`. Since it requires iOS 18, the cleanest approach:
   ```swift
   @Model
   class Run {
       @Attribute(.spotlight) var id: UUID
       @Attribute(.spotlight) var startDate: Date
       // ...
   }
   ```
   `startDate` already has `@Attribute(.spotlight)` which creates a CoreSpotlight index. For database-level query performance, we need to wait for iOS 18 or bump the deployment target.

**Alternative:** Since raising the deployment target to iOS 18 may not be desired, and `.spotlight` already provides indexing, mark this as **deferred** until the app drops iOS 17 support. The pagination fix (Fix 3) is the more impactful improvement for query performance.

**Decision:** Add a `// TODO: Add #Index([\.startDate]) when iOS 18 is the minimum target` comment and defer the actual implementation.

**Risk:** None (deferred).

---

## Fix 6 (P3): Batch Delete Drafts

**Problem:** `RunDraftService.saveDraft()` fetches all `RunDraft` objects into memory just to delete them before inserting a new one. Runs every 30 seconds during a run.

**File:**
- `Services/RunDraftService.swift`

**Steps:**

1. **Replace fetch-then-delete with `try context.delete(model:)`** (iOS 17 batch delete):
   ```swift
   // Before (lines 36-41):
   let descriptor = FetchDescriptor<RunDraft>()
   if let existing = try? context.fetch(descriptor) {
       for draft in existing {
           context.delete(draft)
       }
   }
   
   // After:
   try? context.delete(model: RunDraft.self)
   ```
   `ModelContext.delete(model:)` performs a batch delete without loading objects into memory.

2. **Apply the same pattern to `deleteDraft()`** (lines 75-84):
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

3. **Apply to `purgeStale()`** (lines 89-101) — this one needs a predicate for the date filter:
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

**Risk:** Low. `ModelContext.delete(model:)` is the idiomatic SwiftData pattern. Tests in `RunDraftServiceTests.swift` should cover this.

---

## Implementation Order

| Step | Fix | Effort | Dependencies |
|------|-----|--------|--------------|
| 1 | Fix 4: HealthKit timeout | 5 min | None |
| 2 | Fix 6: Batch delete drafts | 15 min | None |
| 3 | Fix 5: Index startDate | 5 min | None (deferred — add TODO comment) |
| 4 | Fix 3: Paginate history | 30 min | None |
| 5 | Fix 1: Async share rendering | 45 min | None |
| 6 | Fix 2: Background route simplification | 45 min | None |

**Total estimated effort:** ~2.5 hours

Start with the easy wins (Fixes 4, 5, 6) to build momentum, then tackle the two async refactors (Fixes 1, 2) which require more careful testing.
