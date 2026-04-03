# Butter Run — App Design Specification

> *"Run it off. One pat at a time."*

A fun iOS run-tracking app where the core metric isn't calories — it's **teaspoons of butter**. The goal: achieve **Butter Zero** by eating just enough butter during your run to perfectly offset what you burn.

---

## 1. Core Concept

### The Butter Math
| Serving | Calories |
|---------|----------|
| 1 teaspoon | 34 kcal |
| 1 pat (restaurant) | 36 kcal |
| 1 tablespoon | 102 kcal |
| 1 stick (US) | 810 kcal |

### Calorie Burn Formula (MET-based)
```
Calories/min = (MET × 3.5 × bodyWeight_kg) / 200
Butter teaspoons = totalCalories / 34
```

### MET Values by Pace
| Pace | Speed | MET |
|------|-------|-----|
| Brisk walk | 4.0 mph | 5.0 |
| Easy jog | 5.0 mph | 8.3 |
| Moderate run | 6.0 mph | 9.8 |
| Tempo run | 7.0 mph | 11.0 |
| Fast run | 8.0 mph | 11.8 |
| Sprint | 10.0 mph | 14.5 |

### Example
A 70 kg runner at 6 mph for 30 min:
```
Calories = 9.8 × 70 × 0.5 = 343 kcal
Butter = 343 / 34 = ~10.1 teaspoons 🧈
```

---

## 2. App Flow — Three Phases

### Phase 1: Pre-Run (Home Screen)
- Big butter-yellow **"CHURN"** button to start a run
- Current weight displayed (editable in settings)
- Quick stats: last run summary, weekly butter burned
- Optional: set a **Butter Goal** (target tsp to burn, or Butter Zero challenge)
- Weather glance (pulled from device)

### Phase 2: Active Run
- **Primary metric**: 🧈 Butter Burned (tsp) — large, center screen
- **Secondary metrics** (configurable grid):
  - Elapsed time
  - Distance (mi/km)
  - Current pace
  - Average pace
  - Live Butter Rate (tsp/min)
- **Butter Zero Mode**: Shows net butter balance when user logs butter eaten mid-run
  - Tap "Eat Butter" button → pick serving size (pat, tsp, tbsp) → balance updates
  - Goal bar shows progress toward Butter Zero
- **Map view** toggle: live GPS route
- **Auto-pause** when stopped
- **Voice announcements**: "You just melted 5 teaspoons of butter!" at milestones
- **Lock screen**: Live Activity widget showing butter burned + distance

### Phase 3: Post-Run Summary
- **Hero animation**: butter stick melting proportional to burn
- Route map with pace-colored overlay
- **Stats card**:
  - Total butter burned (tsp + visual stick diagram)
  - Distance, duration, avg pace, best split
  - Butter Zero score (if in challenge mode): how close to net zero
  - Elevation gain
- **Split table**: per-mile breakdown with butter per split
- **Share card**: "I melted 2 tablespoons of butter on my run! 🧈🏃" — branded, shareable image
- Save / discard run

---

## 3. Feature Set

### Core Features (v1.0)
1. **GPS Run Tracking** — CoreLocation, background updates
2. **Real-time Butter Calculation** — MET-based, updates every second
3. **Butter Zero Challenge** — Log butter eaten, track net balance
4. **Churn Tracker** — CoreMotion accelerometer estimates butter-churning progress through 5 stages (Liquid → Foamy → Whipped → Breaking → Butter)
5. **Run History** — All past runs with butter stats
6. **User Profile** — Weight, preferred units (mi/km), display name
7. **Split Tracking** — Per-mile or per-km splits
8. **Voice Feedback** — Butter milestone announcements via AVSpeechSynthesizer
9. **Share Cards** — Post-run shareable image generation

### Nice-to-Have (v1.1+)
- **HealthKit Integration** — Sync runs + calories to Apple Health
- **Apple Watch Companion** — Butter burned on wrist
- **Achievements / Badges**:
  - "Pat on the Back" — burn 1 pat (36 cal)
  - "Tablespoon Triumph" — burn 1 tbsp (102 cal)
  - "Stick Slayer" — burn 1 stick (810 cal)
  - "Pound Pounder" — burn 1 lb of butter (3,240 cal)
  - "Butter Sculptor" — 50 runs completed
  - "Perfect Zero" — Butter Zero within ±0.5 tsp
- **Butter Trivia** — Fun facts on loading screens
- **Social Feed** — See friends' butter burns
- **Training Plans** — "Melt a stick this week"
- **Widgets** — Home screen weekly butter summary

---

## 4. UI/UX Design Language

### Color Palette
| Role | Color | Hex |
|------|-------|-----|
| Primary (Butter Yellow) | Warm golden yellow | `#F5C542` |
| Secondary (Toast Brown) | Warm brown | `#8B6914` |
| Background | Cream/off-white | `#FFF8E7` |
| Surface | White | `#FFFFFF` |
| Text Primary | Dark brown | `#3E2723` |
| Text Secondary | Medium brown | `#6D4C41` |
| Accent (Melted) | Deep amber | `#E8A317` |
| Success (Zero!) | Fresh green | `#4CAF50` |
| Active Run BG | Dark charcoal | `#1A1A1A` |

### Typography
- **Display** (butter count): SF Rounded Black, 64pt
- **Headings**: SF Rounded Bold
- **Body**: SF Pro Rounded Regular
- **Monospace metrics**: SF Mono (for pace, time)

### Design Principles
1. **Butter-forward**: Every screen should feel warm, golden, and slightly playful
2. **Glanceable**: Mid-run metrics must be readable in 0.5 seconds at arm's length
3. **Delightful**: Micro-animations (butter melting, churning) at key moments
4. **Minimal friction**: One tap from launch to running
5. **Dark mode for active run**: High contrast on dark background for outdoor visibility

### Key Animations
- **Churn button**: Gentle wobble/pulse on home screen
- **Butter melt**: Stick progressively melts as you burn (active run + summary)
- **Butter Zero hit**: Confetti/sparkle animation when net = 0
- **Pat stamp**: Toast-stamp animation when logging butter eaten
- **Split notification**: Quick butter pat slides in from side

### App Icon
- A stick of butter with running shoes / legs
- Golden yellow background with subtle motion lines
- Rounded corners matching iOS style

---

## 5. Technical Architecture

### Platform & Stack
| Component | Technology |
|-----------|-----------|
| Platform | iOS 17+ |
| Language | Swift 5.9+ |
| UI Framework | SwiftUI |
| Architecture | MVVM + Services |
| Persistence | SwiftData |
| Location | CoreLocation (CLLocationManager) |
| Motion | CoreMotion (CMPedometer, CMMotionManager) |
| Health | HealthKit (optional) |
| Audio | AVFoundation (voice feedback) |
| Maps | MapKit |
| Charts | Swift Charts |
| Sharing | ShareLink + custom renderer |

### Project Structure
```
ButterRun/
├── ButterRunApp.swift              # App entry, schema migration, onboarding
├── Info.plist
├── Assets.xcassets/
│   ├── AppIcon
│   ├── Colors/                     # Butter palette
│   └── Images/                     # butter-pat, illustrations
│
├── Models/
│   ├── Run.swift                   # SwiftData @Model — core run entity
│   ├── Split.swift                 # Per-mile/km split data
│   ├── ButterEntry.swift           # Butter eaten during run
│   ├── ChurnResult.swift           # Churn result + ChurnStage enum
│   ├── RunDraft.swift              # Crash recovery draft checkpoint
│   ├── UserProfile.swift           # Weight, units, preferences
│   └── Achievement.swift           # Badge definitions & unlocks
│
├── ViewModels/
│   ├── HomeViewModel.swift         # Home screen state
│   └── ActiveRunViewModel.swift    # Live run state + butter calc + churn
│
├── Views/
│   ├── Home/
│   │   └── HomeView.swift          # Main screen with Churn button + WeeklyButterCard
│   ├── ActiveRun/
│   │   ├── ActiveRunView.swift     # Live run dashboard
│   │   ├── MetricGridView.swift    # Configurable metric tiles
│   │   ├── ContextualStrip.swift   # BZ balance + churn progress bar
│   │   ├── ChurnSetupSheet.swift   # Cream type/amount config
│   │   ├── EatButterSheet.swift    # Log butter eaten modal
│   │   └── RunMapView.swift        # Live route map + summary thumbnail
│   ├── Summary/
│   │   └── RunSummaryView.swift    # Post-run hero screen + splits + share
│   ├── History/
│   │   ├── RunHistoryView.swift    # List of past runs
│   │   └── RunDetailView.swift     # Individual run detail
│   ├── Settings/
│   │   └── SettingsView.swift      # Profile, units, voice, NEDA resources
│   └── Components/
│       ├── ButterStickView.swift   # Reusable butter stick graphic
│       └── ChurnButton.swift       # Animated start button
│
├── Services/
│   ├── LocationService.swift       # CoreLocation wrapper + Douglas-Peucker
│   ├── MotionService.swift         # CoreMotion pedometer
│   ├── ButterCalculator.swift      # MET-based calorie→butter math
│   ├── ButterChurnEstimator.swift  # CoreMotion device motion → churn progress
│   ├── SplitTracker.swift          # Split detection logic
│   ├── AutoPauseService.swift      # Speed-based auto-pause/resume
│   ├── VoiceFeedbackService.swift  # Speech announcements
│   ├── HapticService.swift         # Haptic feedback (splits, BZ, churn)
│   ├── RunDraftService.swift       # Crash recovery draft persistence
│   ├── ShareImageRenderer.swift    # Render share cards (9:16 + 1:1)
│   └── Protocols/
│       ├── LocationTracking.swift
│       ├── MotionTracking.swift
│       ├── VoiceFeedbackProtocol.swift
│       └── HapticFeedbackProtocol.swift
│
├── Utilities/
│   ├── Constants.swift             # ButterTheme colors, MET table
│   ├── Formatters.swift            # Time, distance, butter formatting
│   └── Extensions/
│       └── Color+Hex.swift
│
└── Preview Content/
    └── PreviewData.swift           # Sample runs for SwiftUI previews
```

### Key Service Details

#### LocationService.swift
```swift
// CoreLocation best practices for run tracking:
// - Use kCLLocationAccuracyBest for GPS
// - Set distanceFilter = 5 (meters) to balance accuracy vs battery
// - Enable allowsBackgroundLocationUpdates
// - Use activityType = .fitness
// - Request .authorizedWhenInUse (upgrade to .authorizedAlways for bg)
// - Implement pausesLocationUpdatesAutomatically = false for runs
```

#### ButterCalculator.swift
```swift
struct ButterCalculator {
    static let caloriesPerTeaspoon: Double = 34.0
    
    // MET lookup table interpolated by speed (mph)
    static func metValue(forSpeedMph speed: Double) -> Double { ... }
    
    // Calorie calculation: Cal/min = (MET × 3.5 × weightKg) / 200
    static func caloriesBurned(weightKg: Double, met: Double, durationMinutes: Double) -> Double
    
    // Convert calories to butter teaspoons
    static func caloriesToButterTsp(_ calories: Double) -> Double
    
    // Net balance for Butter Zero
    static func netButter(burnedTsp: Double, eatenTsp: Double) -> Double {
        return eatenTsp - burnedTsp  // Zero = perfect!
    }
    
    // Butter Zero score: max(0, 100 - abs(net) × 10)
    static func butterZeroScore(netTsp: Double) -> Int
}
```

#### ButterChurnEstimator.swift
```swift
// CoreMotion device motion (accelerometer + gyro fusion) at 20Hz
// Estimates butter-churning progress via RMS agitation analysis:
// 1. Accumulate 20 samples (1-second window)
// 2. Compute RMS of acceleration magnitude
// 3. Accumulate agitation × cream effectiveness multiplier
// 4. Progress = totalAgitation / agitationThreshold
// 5. Stage determined by progress thresholds
//
// ChurnStage: .liquid(0%) → .foamy(8%) → .whipped(30%) → .breaking(55%) → .butter(85%)
// Room temperature cream caps at .whipped (55%)
// Lifecycle: start(config) → pause/resume → stop() → ChurnResult
```

#### SplitTracker.swift
```swift
// Monitors cumulative distance against split boundaries
// When distance crosses boundary:
// 1. Capture split snapshot (duration, pace, butter, elevation)
// 2. Publish via Combine for real-time UI updates
// 3. Trigger voice feedback
// 4. Reset accumulators, advance boundary
// Handles final partial split on run end
```

---

## 6. Data Models (SwiftData)

### Run
```swift
@Model
class Run {
    var id: UUID
    @Attribute(.spotlight) var startDate: Date
    var endDate: Date?
    var distanceMeters: Double
    var durationSeconds: Double
    var averagePaceSecondsPerKm: Double
    var bestPaceSecondsPerKm: Double
    var totalCaloriesBurned: Double
    var totalButterBurnedTsp: Double
    var totalButterEatenTsp: Double
    var netButterTsp: Double           // eaten - burned
    var elevationGainMeters: Double
    var elevationLossMeters: Double
    var averageCadence: Double?
    var routePolyline: Data?           // Encoded [[lat, lng]] via Douglas-Peucker
    var splits: [Split]
    var butterEntries: [ButterEntry]
    var isButterZeroChallenge: Bool
    var churnResultData: Data?         // Encoded ChurnResult (V2)
    var isManualEntry: Bool            // V2
    var targetDistanceMeters: Double?  // V2
    var targetDurationSeconds: Double? // V2
    var notes: String?
}
```

### Split
```swift
@Model
class Split {
    var index: Int
    var distanceMeters: Double
    var durationSeconds: Double
    var paceSecondsPerKm: Double
    var butterBurnedTsp: Double
    var elevationGainMeters: Double
    var isPartial: Bool
    var run: Run?
}
```

### ButterEntry
```swift
@Model
class ButterEntry {
    var id: UUID
    var timestamp: Date
    var servingType: String        // "teaspoon", "pat", "tablespoon", "custom"
    var teaspoonEquivalent: Double
    var run: Run?
}
```

### UserProfile
```swift
@Model
class UserProfile {
    var id: UUID
    var displayName: String
    var weightKg: Double
    var preferredUnit: String      // "miles" or "kilometers"
    var voiceFeedbackEnabled: Bool
    var splitDistance: String       // "mile" or "kilometer"
    var createdAt: Date
}
```

---

## 7. Butter Zero Challenge — The Killer Feature

### How It Works
1. Before the run, toggle **"Butter Zero Mode"** on
2. During the run, you see a **net butter balance bar** (starts at 0, goes negative as you burn)
3. At any point, tap **"Eat Butter 🧈"** → choose serving → balance adjusts toward zero
4. Goal: finish the run as close to **0.00 tsp net** as possible
5. Post-run: get a **Butter Zero Score** (based on how close to zero)

### Scoring
```
Score = max(0, 100 - abs(netButterTsp) × 10)
```
- ±0.0 tsp = 💯 Perfect Zero!
- ±1.0 tsp = 90 — Almost!
- ±5.0 tsp = 50 — Getting there
- ±10.0+ tsp = 0 — Try again!

### UX Details
- The balance bar is a horizontal meter centered at zero
- Left (red/warm) = butter deficit (burned more than eaten)
- Right (green) = butter surplus (eaten more than burned)  
- Center (gold glow) = Butter Zero!
- Haptic feedback when crossing zero

---

## 8. Voice Feedback Milestones

Announced via AVSpeechSynthesizer at natural points:

| Trigger | Announcement |
|---------|-------------|
| Every 1 tsp burned | "One more teaspoon of butter, melted!" |
| Every 1 tbsp (3 tsp) | "That's a whole tablespoon of butter!" |
| Every mile | "Mile {n} complete. {pace}. {tsp} teaspoons burned." |
| Butter Zero crossing | "You just hit Butter Zero! Nice churning!" |
| Run end | "Run complete! You melted {total} teaspoons of butter." |

---

## 9. Share Card Design

A rendered image (for Instagram stories, messages, etc.):

```
┌──────────────────────────────┐
│  🧈 BUTTER RUN               │
│                              │
│     10.1 tsp                 │
│   ━━━━━━━━━━━━━              │
│   [melting butter graphic]   │
│                              │
│  3.2 mi  •  28:45  •  8:59  │
│                              │
│  Butter Zero Score: 94 🎯    │
│                              │
│  butterrun.app               │
└──────────────────────────────┘
```

---

## 10. Storage & Data Strategy

### Local-First (v1.0)
- **SwiftData** for all persistence (runs, profile, achievements)
- No server required for v1.0
- All computation happens on-device
- Data stays in the app sandbox

### Future Cloud Sync (v1.1+)
- **CloudKit** for iCloud sync across devices
- Optional social features via CloudKit public database
- No custom backend needed — leverages Apple infrastructure

### Data Retention
- Runs stored indefinitely on device
- Route coordinates compressed via polyline encoding
- Periodic SwiftData cleanup for orphaned records

---

## 11. Permissions & Privacy

| Permission | Usage | Required? |
|-----------|-------|-----------|
| Location (When In Use) | GPS tracking during runs | Yes |
| Location (Always) | Background run tracking | Yes (for bg) |
| Motion & Fitness | Pedometer/cadence data | Optional |
| HealthKit | Sync workouts to Health | Optional |
| Speech | Voice announcements | No (uses device audio) |

### Privacy
- No account required
- No data leaves the device in v1.0
- No analytics or tracking SDKs
- Weight is stored locally only

---

## 12. Butter Facts & Trivia (Loading Screens)

- "It takes 21 pounds of whole milk to make 1 pound of butter."
- "Butter was invented by accident when a nomad tied a bag of milk to his horse."
- "India produces more butter than any other country — 7.6M tons/year."
- "In medieval Europe, butter was a luxury only the rich could afford."
- "France's Rouen Cathedral has a tower funded by butter sales."
- "Butter sculpting is a competitive art at US state fairs."
- "In 11th-century Norway, King Svein imposed a butter tax."
- "Vikings were buried with butter for the afterlife."

---

## 13. App Store Metadata

**Name**: Butter Run  
**Subtitle**: Melt butter. Hit zero.  
**Category**: Health & Fitness  
**Keywords**: run tracker, running, butter, calories, fitness, GPS, fun running app  

**Description**:
> Butter Run turns your calories into something you can actually picture — teaspoons of butter. Track your runs with GPS, watch the butter melt in real time, and try the Butter Zero Challenge: eat just enough butter during your run to finish at net zero. It's run tracking that's actually fun.

---

## 14. Development Phases

### Phase 1: MVP (v1.0)
- [ ] Xcode project setup with SwiftUI + SwiftData
- [ ] User profile (weight input, unit preference)
- [ ] GPS run tracking with CoreLocation
- [ ] Real-time butter calculation
- [ ] Active run screen with butter metrics
- [ ] Post-run summary with stats
- [ ] Run history list
- [ ] Basic split tracking
- [ ] Butter Zero mode (eat butter logging)
- [ ] Voice feedback at milestones
- [ ] Share card generation
- [ ] App icon and butter-themed design system

### Phase 2: Polish (v1.1)
- [ ] HealthKit integration
- [ ] Achievement / badge system
- [ ] Butter trivia loading screens
- [ ] Enhanced animations (butter melt, confetti)
- [ ] Home screen widget
- [ ] Live Activity (Dynamic Island)
- [ ] Dark mode refinements

### Phase 3: Social (v1.2+)
- [ ] CloudKit sync
- [ ] Friend butter leaderboards
- [ ] Weekly challenges ("Melt a stick this week")
- [ ] Apple Watch companion
- [ ] Training plans
