# Privacy Policy — Butter Run

**Last updated:** April 4, 2026

Butter Run ("the App") is committed to protecting your privacy. This policy explains what data the App collects, how it is used, and your rights.

## Data Collection

### Location Data
- **What:** GPS coordinates during active runs only.
- **Why:** To track your running route, calculate distance, and compute pace and calorie burn.
- **Storage:** All location data is stored locally on your device. It is never transmitted to any server.
- **Retention:** Run routes are saved to your run history on-device. You can delete individual runs at any time.

### Health & Fitness Data
- **What:** Body weight (read from Apple Health, if authorized) and workout data (saved to Apple Health, if authorized).
- **Why:** Weight is used to improve calorie-burn accuracy. Workout data is saved so your runs appear in your Apple Health activity rings.
- **Storage:** Weight is read on-demand and not stored separately. Workout data is written to Apple Health at your request.

### Motion Data
- **What:** Accelerometer and pedometer data during active runs.
- **Why:** To track cadence, step count, and the Churn Tracker feature (butter-churning simulation).
- **Storage:** Processed metrics (cadence, step count, churn stage) are stored locally with each run. Raw sensor data is not retained.

### User Preferences
- **What:** Display name, preferred units (miles/km), voice feedback setting, split distance preference.
- **Why:** To personalize the App experience.
- **Storage:** Stored locally on your device using SwiftData.

## Data Sharing

**Butter Run does not share, sell, or transmit any of your data to third parties.** The App has:
- No analytics or tracking SDKs
- No advertising frameworks
- No server-side components
- No network requests of any kind

All data remains on your device.

## Data Not Collected

Butter Run does **not** collect:
- Email addresses or contact information
- Device identifiers or fingerprints
- Usage analytics or crash reports (beyond what Apple provides via App Store Connect)
- Photos, contacts, or calendar data
- Financial or payment information

## Third-Party Services

Butter Run uses only Apple's native frameworks (CoreLocation, CoreMotion, HealthKit, MapKit, AVFoundation). No third-party SDKs or services are included.

## Your Rights

- **Access:** All your data is visible within the App (run history, settings).
- **Deletion:** Delete individual runs from run history, or delete the App to remove all data.
- **Portability:** Runs saved to Apple Health can be exported through Apple's Health app.

## Children's Privacy

Butter Run does not knowingly collect data from children under 13. The App does not require account creation or collect personally identifiable information.

## Changes to This Policy

We may update this policy from time to time. Changes will be reflected in the "Last updated" date above.

## Contact

If you have questions about this privacy policy, please open an issue on the [Butter Run GitHub repository](https://github.com/ysakols/butter-run).
