# Butter Run

> Run it off. One pat at a time.

A fun iOS run-tracking app where the core metric isn't calories — it's **teaspoons of butter**. Track your runs, watch the butter melt in real time, and try the **Butter Zero Challenge**: eat just enough butter during your run to finish at net zero.

## Features

- **GPS Run Tracking** with real-time butter calculation
- **Butter Zero Challenge** — log butter eaten, aim for net zero calories
- **Voice Feedback** — "You just melted 5 teaspoons of butter!"
- **Share Cards** — shareable post-run images
- **Run History** — all past runs with butter stats and splits
- **Cute butter-themed UI** — warm golden design with melting animations

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
- **AVFoundation** for voice feedback
- **MapKit** for route display

## Getting Started

1. Open `ButterRun/` in Xcode 15+
2. Create a new iOS App project (SwiftUI, SwiftData, iOS 17)
3. Add all source files from the `ButterRun/ButterRun/` directory
4. Set bundle identifier and signing team
5. Build and run on device (GPS requires physical device)

See [DESIGN.md](DESIGN.md) for the full design specification.

## License

MIT
