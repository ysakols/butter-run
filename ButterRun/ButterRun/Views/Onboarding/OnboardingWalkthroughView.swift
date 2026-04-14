import SwiftUI
import SwiftData
import CoreLocation

struct OnboardingWalkthroughView: View {
    @Environment(\.modelContext) private var modelContext
    @FocusState private var focusedField: ProfileField?

    private enum ProfileField {
        case name, weight
    }

    @State private var currentPage = 0
    @State private var displayName = ""
    @State private var weightValue: Double = 0
    @State private var weightText: String = ""
    @State private var weightUnit: String = Locale.current.measurementSystem == .us ? "lbs" : "kg"
    @State private var useMiles: Bool = Locale.current.measurementSystem == .us
    @State private var locationManager = CLLocationManager()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let totalPages = 4

    private var weightKgForStorage: Double {
        if weightUnit == "lbs" {
            return weightValue / 2.20462
        }
        return weightValue
    }

    private var isFormValid: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty && weightValue > 0
    }

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            butterZeroPage.tag(1)
            churnTrackerPage.tag(2)
            profilePage.tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: currentPage)
        .background(ButterTheme.background.ignoresSafeArea())
    }

    // MARK: - Shared Page Wrapper

    /// Wraps each onboarding page with a consistent layout:
    /// Fixed top margin, content, flexible space, page dots, buttons pinned at the bottom.
    private func pageWrapper<Content: View>(
        page: Int,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> some View
    ) -> some View {
        VStack(spacing: 0) {
            // Fixed top margin (not a Spacer — won't expand and steal space)
            Color.clear.frame(height: 80)

            content()

            // Sole flexible spacer — pushes dots + buttons to the bottom
            Spacer(minLength: 20)

            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<totalPages, id: \.self) { i in
                    if i == page {
                        Capsule()
                            .fill(ButterTheme.gold)
                            .frame(width: 20, height: 7)
                    } else {
                        Circle()
                            .fill(ButterTheme.textSecondary.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }
            }
            .padding(.bottom, 16)

            footer()
                .padding(.bottom, 40)
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        pageWrapper(page: 0) {
            OnboardingPage(
                emoji: "",
                title: "Butter Run",
                body: "Run it off. One pat at a time."
            ) {
                VStack(spacing: 0) {
                    ButterPatView(size: 56, style: .solid)
                        .padding(.bottom, -48)

                    featureCard(
                        text: "Track runs in pats of butter",
                        detail: "Every calorie you burn converts to pats. One pat \u{2248} 34 calories. A 5K burns about 8 pats!"
                    )
                }
            }
        } footer: {
            navigationButtons(page: 0)
        }
    }

    // MARK: - Page 2: Butter Zero

    private var butterZeroPage: some View {
        pageWrapper(page: 1) {
            OnboardingPage(
                emoji: "\u{2696}\u{FE0F}",
                title: "Butter Zero",
                body: "Bring butter on your run and eat it as you go. Try to burn exactly as many pats as you eat."
            ) {
                ButterZeroScale(netPats: 0.0)
                    .padding(.horizontal, 24)
            }
        } footer: {
            navigationButtons(page: 1)
        }
    }

    // MARK: - Page 3: Churn Tracker

    private var churnTrackerPage: some View {
        pageWrapper(page: 2) {
            OnboardingPage(
                emoji: "\u{1F9C8}",
                title: "Churn Tracker",
                body: "Carry cream in a sealed bag while you run. Your running motion churns it into butter \u{2014} usually in 6\u{2013}10 km."
            ) {
                churnStagesRow
            }
        } footer: {
            navigationButtons(page: 2)
        }
    }

    // MARK: - Page 4: Profile

    private var profilePage: some View {
        pageWrapper(page: 3) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ButterPatView(size: 40, style: .solid)
                        .padding(.bottom, 12)

                    Text("Let\u{2019}s get started")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(ButterTheme.textPrimary)

                    Text("We use your weight to estimate pats burned per run.")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 6)

                    VStack(spacing: 16) {
                        TextField("Your name", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                            .font(ButterTypography.body)
                            .accessibilityLabel("Your name")
                            .focused($focusedField, equals: .name)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Weight")
                                    .font(ButterTypography.body)
                                    .foregroundStyle(ButterTheme.textPrimary)

                                InfoButton(
                                    title: "Why weight?",
                                    bodyText: "Heavier runners burn more per mile. Include pack weight for accuracy."
                                )

                                Spacer()

                                TextField(weightUnit, text: $weightText)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .keyboardType(.decimalPad)
                                    .accessibilityLabel("Weight in \(weightUnit)")
                                    .focused($focusedField, equals: .weight)
                                    .onChange(of: weightText) { _, newValue in
                                        weightValue = Double(newValue) ?? 0
                                    }

                                Picker("Weight unit", selection: $weightUnit) {
                                    Text("lbs").tag("lbs")
                                    Text("kg").tag("kg")
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 100)
                            }

                            Text("Include backpack weight for accuracy.")
                                .font(ButterTypography.secondaryLabel)
                                .foregroundStyle(ButterTheme.textSecondary)
                        }
                        .onChange(of: weightUnit) { oldUnit, newUnit in
                            if oldUnit == "kg" && newUnit == "lbs" {
                                weightValue = (weightValue * 2.20462).rounded()
                            } else if oldUnit == "lbs" && newUnit == "kg" {
                                weightValue = (weightValue / 2.20462).rounded()
                            }
                            if weightValue > 0 {
                                weightText = String(Int(round(weightValue)))
                            }
                        }

                        Picker("Distance units", selection: $useMiles) {
                            Text("Miles").tag(true)
                            Text("Kilometers").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        } footer: {
            HStack(spacing: 12) {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { currentPage = 2 }
                } label: {
                    Text("Back")
                        .font(ButterTypography.buttonText)
                        .foregroundStyle(ButterTheme.textSecondary)
                        .frame(height: ButterSpacing.buttonHeight)
                        .frame(maxWidth: .infinity)
                        .background(ButterTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: ButterSpacing.buttonCornerRadius))
                        .overlay(RoundedRectangle(cornerRadius: ButterSpacing.buttonCornerRadius).stroke(ButterTheme.surfaceBorder, lineWidth: 1))
                }
                .accessibilityLabel("Back")

                Button(action: createProfile) {
                    Text("Let\u{2019}s Churn \u{1F9C8}")
                        .font(ButterTypography.buttonText)
                        .foregroundStyle(ButterTheme.onPrimaryAction)
                        .frame(maxWidth: .infinity)
                        .frame(height: ButterSpacing.buttonHeight)
                        .background(ButterTheme.gold)
                        .clipShape(RoundedRectangle(cornerRadius: ButterSpacing.buttonCornerRadius))
                }
                .accessibilityLabel("Let's Churn")
                .accessibilityHint("Create your profile and start using Butter Run")
                .disabled(!isFormValid)
                .opacity(isFormValid ? 1.0 : 0.5)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Shared Components

    private func featureCard(text: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\u{1F9C8} " + text)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(ButterTheme.textPrimary)
            Text(detail)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ButterSpacing.cardPadding)
        .background(ButterTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: ButterSpacing.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ButterSpacing.cardCornerRadius)
                .strokeBorder(ButterTheme.surfaceBorder, lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    private var churnStagesRow: some View {
        HStack(spacing: 12) {
            churnStage(emoji: "\u{1F4A7}", label: "Liquid")
            churnArrow
            churnStage(emoji: "\u{1F4A8}", label: "Foamy")
            churnArrow
            churnStage(emoji: "\u{2601}\u{FE0F}", label: "Whipped")
            churnArrow
            churnStage(emoji: "\u{1F9C8}", label: "Butter!")
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Churn stages: Liquid, Foamy, Whipped, Butter")
    }

    private func churnStage(emoji: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(emoji)
                .font(.system(size: 24))
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)
        }
    }

    private var churnArrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(ButterTheme.textSecondary.opacity(0.5))
    }

    private func navigationButtons(page: Int) -> some View {
        HStack(spacing: 12) {
            if page > 0 {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { currentPage = page - 1 }
                } label: {
                    Text("Back")
                        .font(ButterTypography.buttonText)
                        .foregroundStyle(ButterTheme.textSecondary)
                        .frame(height: ButterSpacing.buttonHeight)
                        .frame(maxWidth: .infinity)
                        .background(ButterTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: ButterSpacing.buttonCornerRadius))
                        .overlay(RoundedRectangle(cornerRadius: ButterSpacing.buttonCornerRadius).stroke(ButterTheme.surfaceBorder, lineWidth: 1))
                }
                .accessibilityLabel("Back")
            }

            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { currentPage = page + 1 }
            } label: {
                Text("Next")
                    .font(ButterTypography.buttonText)
                    .foregroundStyle(ButterTheme.onPrimaryAction)
                    .frame(maxWidth: .infinity)
                    .frame(height: ButterSpacing.buttonHeight)
                    .background(ButterTheme.gold)
                    .clipShape(RoundedRectangle(cornerRadius: ButterSpacing.buttonCornerRadius))
            }
            .accessibilityLabel("Next")
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Actions

    private func createProfile() {
        guard weightValue > 0 else { return }
        let trimmedName = String(displayName.trimmingCharacters(in: .whitespaces).prefix(100))
        let profile = UserProfile(
            displayName: trimmedName,
            weightKg: weightKgForStorage,
            preferredUnit: useMiles ? "miles" : "kilometers",
            voiceFeedbackEnabled: true,
            splitDistance: useMiles ? "mile" : "kilometer"
        )
        profile.weightUnit = weightUnit
        modelContext.insert(profile)

        // Request location permission early so it doesn't interrupt the first run
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }
}
