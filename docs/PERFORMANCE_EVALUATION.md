# Performance Evaluation — Butter Run

**Date:** 2026-04-07
**Scope:** Full app audit — startup, tracking, UI, data, battery

---

## Overall Verdict

Butter Run is well-built for a fitness tracker. The core tracking loop (GPS + motion + metrics) is solid and efficient. There are **3 high-priority issues** that can cause visible jank or slowness, and a handful of medium-priority items worth addressing as the user base grows.

---

## High Priority Issues

### 1. Share Image Rendering Blocks the Main Thread

**Where:** `ShareImageRenderer.swift`
**What:** `ImageRenderer` generates a 1080×1920 image at 3× scale on the main thread. This allocates ~108 MB of raw pixel data and blocks the UI for 2–5 seconds during share card generation.
**Impact:** UI freezes after a run when the user taps "Share."
**Fix:** Wrap rendering in a `Task { @MainActor }` with a loading indicator, or move the heavy `CGImage` work off-main using `actor` isolation:
```swift
func render() async -> UIImage? {
    let renderer = ImageRenderer(content: cardView)
    renderer.scale = 3
    return await Task.detached {
        renderer.uiImage  // off-main rendering
    }.value
}
```

### 2. Route Simplification Runs on the Main Thread

**Where:** `LocationService.swift` — `encodeRoute()` / Douglas-Peucker algorithm
**What:** The recursive point-reduction algorithm (up to 20 binary-search iterations over 5000+ points) runs synchronously on the main thread when the route is finalized.
**Impact:** Visible stutter at end of long runs (half-marathon+). Worst case: a 2-hour run at 1 Hz = 7200 raw points needing reduction.
**Fix:** Dispatch to a background queue:
```swift
func encodeRoute() async -> Data {
    await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            let simplified = self.douglasPeucker(self.routeBuffer, epsilon: self.findEpsilon())
            continuation.resume(returning: self.encode(simplified))
        }
    }
}
```

### 3. Run History Loads All Runs Without Pagination

**Where:** `RunHistoryView.swift` — `@Query(sort: \Run.startDate, order: .reverse)`
**What:** Every `Run` object (with its relationships to splits, butter entries, and encoded route data) is fetched into memory at once. No pagination, no fetch limit.
**Impact:** Negligible today, but will degrade linearly. At ~1000 runs the list will begin to feel sluggish; at ~5000 it will spike memory noticeably.
**Fix:** Add a `fetchLimit` and implement "load more" pagination:
```swift
@Query(sort: \Run.startDate, order: .reverse, fetchLimit: 50) var runs: [Run]
```
Or use `SectionedFetchRequest` to batch by month.

---

## Medium Priority Issues

### 4. HealthKit 5-Second Hardcoded Timeout

**Where:** `HealthKitService.swift` — `saveWorkout()`
**What:** If HealthKit entitlements are missing or the store hangs, a 5-second `Task.sleep` timeout fires. During this window the post-run flow stalls.
**Fix:** Reduce timeout to 2 seconds or use `withThrowingTaskGroup` + cancellation for cleaner timeout handling.

### 5. No `@Index` on `Run.startDate`

**Where:** `Run.swift` model definition
**What:** `startDate` is the primary sort/filter key for queries but has no SwiftData index.
**Fix:** Add `@Attribute(.index)` to `startDate` for O(log n) lookups:
```swift
@Attribute(.index) var startDate: Date
```

### 6. Draft Service Fetches All Drafts Before Delete

**Where:** `RunDraftService.swift` — upsert pattern
**What:** `FetchDescriptor<RunDraft>()` loads all drafts into memory just to delete them before inserting a new one. This runs every 30 seconds during a run.
**Fix:** Use a predicate-based batch delete instead of fetch-then-delete.

---

## Low Priority / Acceptable Trade-offs

| Item | Status | Notes |
|------|--------|-------|
| **GPS accuracy: `kCLLocationAccuracyBest`** | Acceptable | Standard for fitness apps. Battery drain is expected. |
| **1-second timer in ActiveRunViewModel** | Good | Properly throttled; only triggers metric fallback if GPS stale >2s. |
| **Churn motion sampling at 20 Hz** | Good | NSLock + generation counter prevent stale writes. ~2 MB worst case. |
| **Route buffer memory (~170 KB–850 KB)** | Good | Bounded by Douglas-Peucker reduction to 5000 points max. |
| **`[weak self]` in closures** | Good | Consistently applied across all Combine subscriptions and timers. |
| **Butter entries in memory** | Good | Tiny footprint (~40 bytes each). Realistic max is <50 entries per run. |
| **Animation performance** | Good | `.numericText()` transitions at 1 Hz and melting animation are GPU-light. Accessibility `reduceMotion` respected. |
| **Audio session keep-alive** | Good | Category `.playback` with duck; deactivated 5s after run ends. |
| **Map polyline rendering** | Good | MapKit handles efficiently; coordinate thinning to 120 points for live view. |

---

## Battery & Background Tracking

| Component | Draw | Assessment |
|-----------|------|------------|
| GPS (`kCLLocationAccuracyBest`, 5m filter) | High | Expected for run tracking. `pausesLocationUpdatesAutomatically` is off — correct for fitness. |
| Pedometer (CMPedometer) | Low | Hardware-accelerated; minimal CPU. |
| Churn accelerometer (20 Hz) | Medium | Only active when churn mode enabled. Good: stopped on pause. |
| 1-second UI timer | Negligible | Invalidated on pause/stop. |
| Draft saves (every 30s) | Negligible | Small JSON write to disk. |
| Voice feedback (AVSpeechSynthesizer) | Low | On-demand only at milestones. |

**Overall battery profile:** Comparable to Apple Workout or Strava during an active run. No unnecessary background work when idle.

---

## Architecture Strengths

- **Clean separation**: ViewModels never touch SwiftData directly; services are single-responsibility.
- **Crash recovery**: Draft checkpoint every 30 seconds with 48-hour auto-purge is robust.
- **GPS spike filtering**: Rejects readings >100m apart or <20m accuracy. Prevents phantom distance.
- **Thread safety in churn estimator**: NSLock + generation counter is a solid pattern for motion callbacks.
- **Auto-pause hysteresis**: Separate thresholds for pause (0.5 m/s after 10s) and resume (0.8 m/s immediately) prevents flickering.

---

## Summary Action Items

| Priority | Issue | Effort | User Impact |
|----------|-------|--------|-------------|
| **P0** | Async share image rendering | Small | Eliminates 2–5s UI freeze |
| **P0** | Background route simplification | Small | Eliminates end-of-run stutter |
| **P1** | Paginate run history query | Medium | Prevents slowdown at scale |
| **P2** | Reduce HealthKit timeout | Small | Faster post-run flow |
| **P2** | Index `Run.startDate` | Trivial | Faster history queries |
| **P3** | Batch delete drafts | Trivial | Cleaner persistence pattern |
