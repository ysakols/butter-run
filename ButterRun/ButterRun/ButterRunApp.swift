import SwiftUI
import SwiftData

// MARK: - Schema Versioning

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [
        Run.self,
        UserProfile.self,
        Split.self,
        ButterEntry.self,
        Achievement.self
    ]
}

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] = [
        Run.self,
        UserProfile.self,
        Split.self,
        ButterEntry.self,
        Achievement.self,
        RunDraft.self
    ]
}

enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] = [
        Run.self,
        UserProfile.self,
        Split.self,
        ButterEntry.self,
        Achievement.self,
        RunDraft.self
    ]
}

enum ButterRunMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    static var stages: [MigrationStage] = [
        .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
        .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self)
    ]
}

// MARK: - App

@main
struct ButterRunApp: App {
    @StateObject private var stravaAuth = StravaAuthService()
    let container: ModelContainer
    let containerError: Error?

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--reset-state")

        do {
            let schema = Schema([
                Run.self,
                Split.self,
                ButterEntry.self,
                UserProfile.self,
                Achievement.self,
                RunDraft.self,
            ])
            let config: ModelConfiguration
            if isUITesting {
                config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            } else {
                config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            }
            container = try ModelContainer(
                for: schema,
                migrationPlan: isUITesting ? nil : ButterRunMigrationPlan.self,
                configurations: [config]
            )
            containerError = nil
        } catch {
            // Fallback: create an in-memory container so the app can launch
            containerError = error
            do {
                container = try ModelContainer(
                    for: Schema([Run.self, Split.self, ButterEntry.self, UserProfile.self, Achievement.self, RunDraft.self]),
                    configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
                )
            } catch {
                fatalError("Failed to create even an in-memory ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let error = containerError {
                    DatabaseErrorView(error: error)
                } else {
                    ContentView()
                        .environmentObject(stravaAuth)
                }
            }
            .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}

struct DatabaseErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Database Error")
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text("Butter Run couldn't load your data. Try deleting and reinstalling the app.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    private let skipOnboarding = ProcessInfo.processInfo.arguments.contains("--skip-onboarding")
    @AppStorage("tosAcceptedVersion") private var tosAcceptedVersion: String = ""

    /// Increment this when the ToS changes materially to re-trigger acceptance.
    private static let currentTosVersion = "2026-04-07-v2"

    var body: some View {
        Group {
            if tosAcceptedVersion != Self.currentTosVersion {
                LegalAcceptanceView {
                    tosAcceptedVersion = Self.currentTosVersion
                }
            } else if profiles.isEmpty && !skipOnboarding {
                OnboardingWalkthroughView()
            } else {
                CrashRecoveryWrapper {
                    MainTabView()
                }
            }
        }
        .onAppear {
            // UI testing: create a default profile when skipping onboarding
            if skipOnboarding && profiles.isEmpty {
                let profile = UserProfile(
                    displayName: "Test Runner",
                    weightKg: 70.0,
                    preferredUnit: "miles",
                    voiceFeedbackEnabled: false,
                    splitDistance: "mile"
                )
                modelContext.insert(profile)
            }

            // Enforce UserProfile singleton — delete duplicates if any
            if profiles.count > 1 {
                for extra in profiles.dropFirst() {
                    modelContext.delete(extra)
                }
            }

            // Purge stale drafts on launch
            let service = RunDraftService(container: modelContext.container)
            service.purgeStale(context: modelContext)
        }
    }
}

/// Shared snapshot type used to encode/decode butter entries in run drafts.
/// Used by both ActiveRunViewModel (encoder) and CrashRecoveryWrapper (decoder).
struct DraftEntrySnapshot: Codable {
    let servingRaw: String
    let tsp: Double
    let timestamp: Date
}

/// Checks for an unfinished run draft on app launch
struct CrashRecoveryWrapper<Content: View>: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showRecoveryPrompt = false
    @State private var recoveredDraft: RunDraft?
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .onAppear(perform: checkForDraft)
            .alert("Unfinished Run", isPresented: $showRecoveryPrompt) {
                Button("Save Run") {
                    saveAsManualRun()
                }
                Button("Discard", role: .destructive) {
                    discardDraft()
                }
            } message: {
                if let draft = recoveredDraft {
                    let duration = ButterFormatters.duration(draft.elapsedSeconds)
                    Text("You had an unfinished run from \(draft.startDate.formatted(date: .abbreviated, time: .shortened)) (\(duration)). Would you like to save it?")
                } else {
                    Text("You had an unfinished run that cannot be resumed.")
                }
            }
    }

    private func checkForDraft() {
        let service = RunDraftService(container: modelContext.container)
        if let draft = service.loadDraft(context: modelContext) {
            recoveredDraft = draft
            showRecoveryPrompt = true
        }
    }

    private func saveAsManualRun() {
        guard let draft = recoveredDraft else { return }

        let run = Run(startDate: draft.startDate, isButterZeroChallenge: draft.isButterZeroChallenge)
        run.endDate = draft.startDate.addingTimeInterval(draft.elapsedSeconds + draft.pausedDuration)
        run.distanceMeters = draft.distanceMeters
        run.durationSeconds = draft.elapsedSeconds
        run.totalButterBurnedTsp = draft.butterBurnedTsp
        run.totalButterEatenTsp = draft.butterEatenTsp
        run.netButterTsp = draft.butterEatenTsp - draft.butterBurnedTsp
        run.totalCaloriesBurned = draft.butterBurnedTsp * ButterCalculator.caloriesPerTeaspoon
        run.isManualEntry = true
        run.routePolyline = draft.routePointsData

        if draft.distanceMeters > 0 && draft.elapsedSeconds > 0 {
            run.averagePaceSecondsPerKm = draft.elapsedSeconds / (draft.distanceMeters / 1000.0)
        }

        // Decode and attach butter entries from draft, preserving original serving types and timestamps
        if let entriesData = draft.butterEntriesData {
            if let snapshots = try? JSONDecoder().decode([DraftEntrySnapshot].self, from: entriesData) {
                let entries = snapshots.map { snapshot -> ButterEntry in
                    let serving = ButterServing(rawValue: snapshot.servingRaw) ?? .custom
                    let entry = ButterEntry(serving: serving, customTeaspoons: serving == .custom ? snapshot.tsp : 0)
                    entry.timestamp = snapshot.timestamp
                    return entry
                }
                run.butterEntries = entries
            }
        }

        modelContext.insert(run)
        try? modelContext.save()
        discardDraft()
    }

    private func discardDraft() {
        let service = RunDraftService(container: modelContext.container)
        service.deleteDraft(context: modelContext)
        recoveredDraft = nil
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Run", systemImage: "figure.run")
                }

            RunHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            ChurnGuideView()
                .tabItem {
                    Label("Guide", systemImage: "book")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(ButterTheme.gold)
    }
}

// MARK: - Legal Acceptance Flow

/// Two-step acceptance: user must scroll through and accept both ToS and Privacy Policy
/// before any data is collected or onboarding begins.
struct LegalAcceptanceView: View {
    let onAccept: () -> Void
    @State private var tosAccepted = false
    @State private var privacyAccepted = false

    var body: some View {
        if !tosAccepted {
            ScrollableDocumentView(
                title: "Terms of Service",
                icon: "doc.text",
                text: LegalText.termsOfService,
                buttonLabel: "I Accept the Terms of Service",
                stepLabel: "Step 1 of 2"
            ) {
                tosAccepted = true
            }
        } else if !privacyAccepted {
            ScrollableDocumentView(
                title: "Privacy Policy",
                icon: "hand.raised",
                text: LegalText.privacyPolicy,
                buttonLabel: "I Accept the Privacy Policy",
                stepLabel: "Step 2 of 2"
            ) {
                privacyAccepted = true
                // Log consent locally
                UserDefaults.standard.set(Date().ISO8601Format(), forKey: "tosConsentTimestamp")
                UserDefaults.standard.set(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown", forKey: "tosConsentAppVersion")
                onAccept()
            }
        }
    }
}

/// A scrollable full-text document view. The accept button only becomes enabled
/// once the user has scrolled near the bottom of the document.
struct ScrollableDocumentView: View {
    let title: String
    let icon: String
    let text: String
    let buttonLabel: String
    let stepLabel: String
    let onAccept: () -> Void

    @State private var hasScrolledToBottom = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(ButterTheme.gold)
                    Text(title)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(ButterTheme.textPrimary)
                }
                Text(stepLabel)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Scrollable document text
            GeometryReader { outerGeo in
                ScrollView {
                    Text(text)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(ButterTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)

                    // Invisible marker at the bottom to detect scroll position
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ScrollBottomPreferenceKey.self, value: geo.frame(in: .named("scroll")).maxY)
                    }
                    .frame(height: 1)
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollBottomPreferenceKey.self) { maxY in
                    if maxY < outerGeo.size.height + 100 {
                        hasScrolledToBottom = true
                    }
                }
            }
            .background(ButterTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)

            // Accept button
            VStack(spacing: 6) {
                if !hasScrolledToBottom {
                    Text("Please scroll to the bottom to continue")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
                }

                Button(action: onAccept) {
                    Text(buttonLabel)
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(ButterTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            hasScrolledToBottom ? ButterTheme.gold : ButterTheme.gold.opacity(0.3),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                }
                .disabled(!hasScrolledToBottom)
                .padding(.horizontal, 16)
            }
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(ButterTheme.background.ignoresSafeArea())
        .preferredColorScheme(.light)
    }
}

private struct ScrollBottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

// MARK: - Embedded Legal Text

/// Legal text embedded directly in the app binary for immutability and offline access.
/// SYNC: When updating, keep in sync with /TERMS_OF_SERVICE.md and /PRIVACY_POLICY.md.
/// Also bump ContentView.currentTosVersion to re-trigger acceptance for existing users.
enum LegalText {

    static let termsOfService = """
TERMS OF SERVICE — BUTTER RUN
Last updated: April 7, 2026

IMPORTANT: PLEASE READ THESE TERMS OF SERVICE CAREFULLY BEFORE USING BUTTER RUN. BY TAPPING "I AGREE" OR USING THE APP, YOU ACKNOWLEDGE THAT YOU HAVE READ, UNDERSTOOD, AND AGREE TO BE BOUND BY THESE TERMS. IF YOU DO NOT AGREE, DO NOT USE THE APP.

1. ACCEPTANCE OF TERMS

These Terms of Service ("Terms") constitute a legally binding agreement between you ("User," "you," or "your") and the developer of Butter Run ("Developer," "we," "us," or "our"). By downloading, installing, accessing, or using Butter Run ("the App"), you agree to these Terms in their entirety. You must be at least 13 years of age to use the App. If you are under 18, you represent that your parent or legal guardian has reviewed and agreed to these Terms on your behalf.

Your agreement is formed when you first tap "I Agree" during the App's initial setup or, if no such prompt is presented, when you first use the App after installation.

2. CHANGES TO TERMS

We reserve the right to modify these Terms at any time. Material changes will be communicated through the App (e.g., an in-app prompt requiring renewed acceptance) with at least thirty (30) days' notice before taking effect. Non-material changes take effect upon posting. Your continued use of the App after the effective date constitutes acceptance of the revised Terms. If you do not agree, you must stop using the App and delete it.

3. DESCRIPTION OF THE APP

Butter Run is a fitness and running application that provides: GPS-based run tracking (route, distance, pace); calorie burn estimation based on user-provided weight and activity data; cadence and step count tracking via device motion sensors; Churn Tracker — a gamified butter-churning simulation; voice feedback during runs; Apple HealthKit integration; optional Strava integration for sharing run activities; and run history stored locally on the device.

The App is a recreational fitness tool. It is not a medical device, health monitoring system, or clinical instrument. All metrics are estimates and approximations that may contain errors or significant deviations from actual values.

4. MEDICAL DISCLAIMER

THE APP DOES NOT PROVIDE MEDICAL ADVICE. Nothing in the App should be construed as medical advice, diagnosis, treatment recommendation, or a substitute for professional medical guidance.

Before beginning any exercise program, changing your diet, or making any health-related decisions, you must consult with a qualified physician or healthcare provider. This is especially important if you have any pre-existing medical condition, are pregnant or postpartum, are taking any medication, have a history of injury, have not exercised regularly, or are over 40 and have not recently had a medical examination.

Calorie burn estimates are mathematical approximations based on limited inputs and may be significantly inaccurate. Do not rely on these estimates for dietary planning, weight management, or any health-related purpose without independent verification by a qualified professional.

5. ASSUMPTION OF RISK

BY USING THE APP, YOU EXPRESSLY ACKNOWLEDGE AND AGREE THAT:

5.1 Your use of the App and participation in any physical activity while using the App is entirely voluntary.

5.2 Running, jogging, walking, and other physical activities carry inherent risks of injury, illness, disability, and death that cannot be eliminated. You knowingly and voluntarily assume all such risks, both known and unknown.

5.3 Specific risks include but are not limited to: cardiovascular events; musculoskeletal injuries; heat-related and cold-related illness; falls, collisions, and environmental hazards; gastrointestinal distress from eating before, during, or after running; overtraining and overexertion (including from pursuing Churn Tracker goals); distraction and reduced awareness from voice feedback or screen interaction; GPS and metric inaccuracies; unintended weight changes from inaccurate calorie estimates; aggravation of pre-existing conditions; night running and low-visibility conditions; traffic and road hazards; adverse weather; battery depletion; solo running risks; and inaccurate wearable device data.

5.4 The App does not monitor your physical condition, hydration, or safety. You are solely responsible for monitoring your own physical condition and safety at all times.

6. PROHIBITED USES

You will NOT use the App: while operating a motor vehicle, bicycle, or any vehicle or machinery; in any manner that violates applicable law; while impaired by alcohol, drugs, or medication; in any location where mobile device use is prohibited or unsafe; to provide medical advice to others; or in any manner that could endanger yourself or others.

7. RELEASE, WAIVER, AND COVENANT NOT TO SUE

7.1 TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, YOU HEREBY RELEASE, WAIVE, DISCHARGE, AND COVENANT NOT TO SUE the Developer and their officers, directors, employees, agents, affiliates, successors, and assigns ("Released Parties") from any and all liability, claims, damages, and judgments arising out of or relating to: your use of the App; any physical activity in connection with the App; any injury, illness, disability, death, or property damage; any metric inaccuracy; gastrointestinal distress; weight changes; distraction from App features; overexertion; inaccurate GPS data; aggravation of pre-existing conditions; App malfunction; or loss of data.

7.2 To the maximum extent permitted by applicable law, this release extends to claims based on the negligence of the Released Parties. This release does not apply to claims based on the Developer's gross negligence, willful misconduct, or fraud, to the extent such claims cannot be released under applicable law.

7.3 YOU EXPRESSLY WAIVE ANY RIGHTS UNDER CALIFORNIA CIVIL CODE SECTION 1542, which provides that a general release does not extend to unknown claims.

8. DISCLAIMER OF WARRANTIES

THE APP IS PROVIDED ON AN "AS IS" AND "AS AVAILABLE" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE, AND NON-INFRINGEMENT. THE DEVELOPER DOES NOT WARRANT THAT THE APP WILL BE UNINTERRUPTED, ERROR-FREE, OR SECURE. NO ADVICE OR INFORMATION OBTAINED FROM THE DEVELOPER OR THE APP SHALL CREATE ANY WARRANTY NOT EXPRESSLY STATED IN THESE TERMS. THE DEVELOPER HAS NO OBLIGATION TO MAINTAIN, SUPPORT, UPGRADE, OR UPDATE THE APP.

9. LIMITATION OF LIABILITY

IN NO EVENT SHALL THE DEVELOPER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, PUNITIVE, OR EXEMPLARY DAMAGES ARISING FROM YOUR USE OF THE APP, REGARDLESS OF THE LEGAL THEORY.

IF THE DEVELOPER IS FOUND LIABLE, TOTAL CUMULATIVE LIABILITY SHALL NOT EXCEED THE LESSER OF: (A) $50.00; OR (B) THE TOTAL AMOUNT YOU PAID FOR THE APP IN THE 12 MONTHS PRECEDING THE CLAIM.

10. INDEMNIFICATION

You agree to indemnify and hold harmless the Developer from claims arising from: your violation of these Terms; your violation of any third-party rights; your negligence or willful misconduct; or any content or data you transmit through the App.

11. NO GUARANTEED RESULTS

The App makes no guarantees regarding fitness outcomes, weight loss, weight gain, calorie expenditure, distance accuracy, pace accuracy, or any other result.

12. DISPUTE RESOLUTION AND MANDATORY ARBITRATION

12.1 You agree to first attempt informal resolution for at least 30 days.

12.2 ALL DISPUTES SHALL BE DETERMINED BY BINDING ARBITRATION administered by JAMS under its Streamlined Arbitration Rules. Arbitration shall take place remotely or in California.

12.3 CLASS ACTION WAIVER: EACH PARTY MAY BRING CLAIMS ONLY IN INDIVIDUAL CAPACITY, NOT AS PART OF ANY CLASS OR REPRESENTATIVE PROCEEDING.

12.4 For 25+ similar demands in 60 days, a bellwether process of 10 randomly selected cases applies.

12.5 Either party may bring individual small claims court actions.

12.6 For claims ≤$10,000, the Developer pays all arbitration fees. For larger claims, fees are shared unless cost-prohibitive to you.

12.7 You may opt out of arbitration within 30 days of first accepting these Terms by sending written notice to the contact in Section 24.

12.8 Arbitration proceedings are confidential unless required by law.

13. STATUTE OF LIMITATIONS

ANY CLAIM MUST BE FILED WITHIN ONE (1) YEAR AFTER IT AROSE, OR IT IS FOREVER BARRED, to the maximum extent permitted by applicable law.

14. PRIVACY AND DATA

Your use of the App is governed by our Privacy Policy. All data is stored locally on your device. The App does not transmit data to Developer-controlled servers. Apple framework communication (MapKit, HealthKit) may involve Apple's servers. Optional Strava integration transmits run data at your explicit request.

HealthKit data is never stored by the App in cloud storage, never shared with third parties, never used for advertising, and used only for fitness purposes described in the Privacy Policy.

The Developer is not responsible for any loss of data from any cause. You are responsible for backing up your device.

15. APPLE-SPECIFIC TERMS

These Terms are between you and the Developer, not Apple. Apple and its subsidiaries are third-party beneficiaries of these Terms. The Developer, not Apple, is responsible for maintenance, support, product claims, and intellectual property claims. Apple's sole warranty obligation is to refund the purchase price (if any) for App nonconformance.

16. THIRD-PARTY FRAMEWORKS

The App uses Apple frameworks (CoreLocation, CoreMotion, HealthKit, MapKit, AVFoundation). The Developer makes no warranties regarding their accuracy, reliability, or availability.

17. INTELLECTUAL PROPERTY

The App and all associated content are owned by the Developer and protected by intellectual property laws.

18. FORCE MAJEURE

The Developer is not liable for failures caused by events beyond reasonable control, including natural disasters, pandemic, internet failures, GPS satellite outages, Apple framework disruptions, or power failures.

19. TERMINATION

We may terminate your access at any time. Sections 5, 7, 8, 9, 10, 12, 13, and 17 survive termination.

20. SEVERABILITY

Invalid provisions shall be modified to the minimum extent necessary or severed. The invalidity of any provision does not affect others.

21. ENTIRE AGREEMENT

These Terms and the Privacy Policy constitute the entire agreement.

22. NO WAIVER

Failure to enforce any provision is not a waiver. Waivers must be in writing.

23. GOVERNING LAW

California law governs. If arbitration does not apply, California state and federal courts have exclusive jurisdiction.

24. CONTACT

Questions or arbitration opt-out: open an issue at github.com/ysakols/butter-run or email spltr3app@gmail.com.

25. ACKNOWLEDGMENT

BY USING BUTTER RUN, YOU ACKNOWLEDGE THAT YOU HAVE READ AND UNDERSTOOD THESE TERMS, INCLUDING THE MEDICAL DISCLAIMER (§4), ASSUMPTION OF RISK (§5), RELEASE AND WAIVER (§7), DISCLAIMER OF WARRANTIES (§8), LIMITATION OF LIABILITY (§9), MANDATORY ARBITRATION AND CLASS ACTION WAIVER (§12), AND STATUTE OF LIMITATIONS (§13), AND YOU VOLUNTARILY AGREE TO BE BOUND BY THEM.
"""

    static let privacyPolicy = """
PRIVACY POLICY — BUTTER RUN
Last updated: April 7, 2026

Butter Run ("the App") is committed to protecting your privacy. This policy explains what data the App collects, how it is used, and your rights.

DATA COLLECTION

Location Data
• GPS coordinates during active runs only.
• Used to track your running route, calculate distance, and compute pace and calorie burn.
• Stored locally on your device. Never transmitted to any Developer-controlled server.
• You can delete individual runs at any time.

Health & Fitness Data
• Body weight (read from Apple Health, if authorized) and workout data (saved to Apple Health, if authorized).
• Weight improves calorie-burn accuracy. Workout data syncs with Apple Health activity rings.
• Weight is read on-demand and not stored separately. Workout data is written to Apple Health at your request.

Motion Data
• Accelerometer and pedometer data during active runs.
• Used for cadence, step count, and the Churn Tracker feature.
• Processed metrics stored locally with each run. Raw sensor data is not retained.

User Preferences & Profile
• Display name, body weight, preferred units, voice feedback setting, split distance preference.
• Used to personalize the App and calculate calorie burn.
• Stored locally on your device using SwiftData. This data is personally identifiable information (PII) and is never transmitted off your device except as described below.

DATA SHARING

Butter Run does not sell or share your data with third parties for advertising, analytics, or marketing. The App has no analytics SDKs, no advertising frameworks, and no Developer-controlled servers.

Apple Framework Communication: The App uses Apple's native frameworks (CoreLocation, CoreMotion, HealthKit, MapKit, AVFoundation), which may involve system-level communication with Apple's servers.

Strava Integration (Optional): If you connect your Strava account, the App will authenticate via OAuth, store tokens securely in the iOS Keychain, and transmit run data (distance, duration, GPS route, activity type) to Strava ONLY when you explicitly initiate an upload. You can disconnect Strava at any time. Data sent to Strava is subject to Strava's Privacy Policy.

DATA NOT COLLECTED

Butter Run does not collect: email addresses (beyond your optional display name); device identifiers; usage analytics or crash reports (beyond Apple's App Store Connect); photos, contacts, or calendar data; or financial information.

YOUR RIGHTS

• Access: All your data is visible within the App.
• Deletion: Delete individual runs, or delete the App to remove all local data. For Strava data, use Strava's data management tools.
• Portability: Runs saved to Apple Health can be exported through Apple's Health app.
• Data Requests: Contact us at spltr3app@gmail.com or via GitHub to exercise rights under applicable privacy laws (including CCPA).

CHILDREN'S PRIVACY

Butter Run is not intended for children under 13. We do not knowingly collect personal data from children under 13.

CHANGES TO THIS POLICY

Material changes will be communicated through the App with at least 30 days' notice.

CONTACT

Questions: open an issue at github.com/ysakols/butter-run or email spltr3app@gmail.com.
"""
}
