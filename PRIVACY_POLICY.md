# Privacy Policy — Butter Run

**Last updated:** April 7, 2026

Butter Run ("the App") is committed to protecting your privacy. This policy explains what data the App collects, how it is used, and your rights.

## Data Collection

### Location Data
- **What:** GPS coordinates during active runs only.
- **Why:** To track your running route, calculate distance, and compute pace and calorie burn.
- **Storage:** All location data is stored locally on your device. It is never transmitted to any Developer-controlled server.
- **Retention:** Run routes are saved to your run history on-device. You can delete individual runs at any time.

### Health & Fitness Data
- **What:** Body weight (read from Apple Health, if authorized) and workout data (saved to Apple Health, if authorized).
- **Why:** Weight is used to improve calorie-burn accuracy. Workout data is saved so your runs appear in your Apple Health activity rings.
- **Storage:** Weight is read on-demand and not stored separately. Workout data is written to Apple Health at your request.

### Motion Data
- **What:** Accelerometer and pedometer data during active runs.
- **Why:** To track cadence, step count, and the Churn Tracker feature (butter-churning simulation).
- **Storage:** Processed metrics (cadence, step count, churn stage) are stored locally with each run. Raw sensor data is not retained.

### User Preferences & Profile
- **What:** Display name, body weight, preferred units (miles/km), voice feedback setting, split distance preference.
- **Why:** To personalize the App experience and calculate calorie burn.
- **Storage:** Stored locally on your device using SwiftData. This data constitutes personally identifiable information (PII) and is never transmitted off your device except as described below.

## Data Sharing

Butter Run does not sell or share your data with third parties for advertising, analytics, or marketing purposes. The App has:
- No analytics or tracking SDKs
- No advertising frameworks
- No Developer-controlled server-side components

However, the App may transmit data in the following circumstances:

### Apple Framework Communication
The App uses Apple's native frameworks (CoreLocation, CoreMotion, HealthKit, MapKit, AVFoundation), which may involve standard system-level communication with Apple's servers (e.g., MapKit loading map tiles, HealthKit syncing health data via iCloud if enabled by the user in iOS Settings).

### Strava Integration (Optional)
If you choose to connect your Strava account, the App will:
- Authenticate via OAuth through Strava's website (no password is stored by the App)
- Store your Strava access and refresh tokens securely in the iOS Keychain
- Transmit run data (distance, duration, GPS route coordinates, activity type) to Strava's API **only when you explicitly initiate an upload**
- Store your Strava athlete name locally for display purposes

Strava integration is entirely optional and user-initiated. You can disconnect Strava at any time from the App's Settings. Data transmitted to Strava is subject to [Strava's Privacy Policy](https://www.strava.com/legal/privacy).

## Data Not Collected

Butter Run does **not** collect:
- Email addresses or contact information (beyond what you voluntarily enter as your display name)
- Device identifiers or fingerprints
- Usage analytics or crash reports (beyond what Apple provides via App Store Connect)
- Photos, contacts, or calendar data
- Financial or payment information

## Third-Party Services

Butter Run uses Apple's native frameworks (CoreLocation, CoreMotion, HealthKit, MapKit, AVFoundation) and optionally integrates with Strava for activity sharing. No other third-party SDKs or services are included.

## Your Rights

- **Access:** All your data is visible within the App (run history, settings).
- **Deletion:** Delete individual runs from run history, or delete the App to remove all locally stored data. To delete data shared with Strava, use Strava's own data management tools.
- **Portability:** Runs saved to Apple Health can be exported through Apple's Health app.
- **Data Requests:** To request information about your data or exercise your rights under applicable privacy laws (including CCPA), contact us using the information below.

## Children's Privacy

Butter Run is not intended for children under 13. The App does not knowingly collect personal data from children under 13. If you believe a child under 13 has provided personal data through the App, please contact us so we can take appropriate action.

## Changes to This Policy

We may update this policy from time to time. Material changes will be communicated through the App with at least fourteen (14) days' notice. Changes will be reflected in the "Last updated" date above.

## Contact

If you have questions about this privacy policy, please open an issue on the [Butter Run GitHub repository](https://github.com/ysakols/butter-run) or email spltr3app@gmail.com.
