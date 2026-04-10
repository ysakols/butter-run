# Butter Run

> Run it off. One pat at a time.

A fun iOS run-tracking app where the core metric isn't calories — it's **pats of butter**. Track your runs, watch the butter melt in real time, and try the **Butter Zero Challenge**: eat just enough butter during your run to finish at net zero.

## Features

- **GPS Run Tracking** with real-time butter calculation
- **Churn Tracker** — run with cream, track butter-churning progress through 5 stages via accelerometer
- **Butter Zero Challenge** — log butter eaten, aim for net zero calories
- **Voice Feedback** — "5 pats of butter burned!"
- **Share Cards** — shareable post-run images with churn results
- **Run History** — all past runs with butter stats and splits
- **Light cream-themed UI** — warm gold-on-cream design
- **Strava Integration** — share runs to Strava
- **HealthKit Sync** — sync workouts with Apple Health
- **Achievements** — unlock badges for butter milestones
- **Crash Reporting** — automatic run draft recovery
- **Manual Run Entry** — log runs after the fact
- **Deep Linking** — open specific screens via URL

## The Math

| Butter | Calories |
|--------|----------|
| 1 tsp | 34 kcal |
| 1 tbsp | 102 kcal |
| 1 stick | 810 kcal |

Calorie burn uses MET-based formulas from the Compendium of Physical Activities.

## Tech Stack

- **SwiftUI** + **SwiftData** (iOS 17+)
- **CoreLocation** for GPS tracking
- **CoreMotion** for cadence/pedometer
- **HealthKit** for weight & workout sync
- **AVFoundation** for voice feedback
- **MapKit** for route display

## Getting Started

### Prerequisites

- Xcode 16 or later
- iOS 18.0+ deployment target
- An Apple Developer account (for device testing and HealthKit)

### Build & Run

1. Clone the repository
2. Copy the signing config template:
   ```bash
   cp ButterRun/ButterRun.xcconfig.template ButterRun/ButterRun.xcconfig
   ```
3. Edit `ButterRun/ButterRun.xcconfig` and fill in your `DEVELOPMENT_TEAM` and `BUNDLE_ID_PREFIX`
4. Open `ButterRun/ButterRun.xcodeproj` in Xcode
5. Select a device or simulator and press Run

> **Note:** GPS tracking requires a physical device. The simulator can only test non-location features.

### Regenerating the Xcode Project

If you add or remove source files, regenerate the project:

```bash
python3 scripts/generate_xcodeproj.py
```

## Privacy

Butter Run collects no data beyond what stays on your device. No analytics or tracking. All run data stays on your device. Optional integrations (Strava, Apple Health) transmit data only at your request. See [PRIVACY_POLICY.md](PRIVACY_POLICY.md) for details.

## Design

See [DESIGN.md](DESIGN.md) for the full design specification.

## License

MIT
