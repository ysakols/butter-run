import SwiftUI

struct ChurnGuideView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Churn Guide")
                            .font(ButterTypography.screenTitle)
                            .foregroundStyle(ButterTheme.textPrimary)
                        Text("How to make butter on a run")
                            .font(ButterTypography.secondaryLabel)
                            .foregroundStyle(ButterTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ButterSpacing.horizontalPadding)

                    // MARK: - Card 1: What You Need
                    whatYouNeedCard

                    // MARK: - Card 2: Temperature + Body Heat (gold)
                    temperatureCard

                    // MARK: - Card 3: The 5 Stages
                    stagesCard

                    // MARK: - Card 4: Tips
                    tipsCard
                }
                .padding(.bottom, 32)
            }
            .background(ButterTheme.background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }

    // MARK: - What You Need

    private var whatYouNeedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What You Need")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(ButterTheme.textPrimary)

            numberedStep(
                number: 1,
                title: "Heavy cream (36%+ fat)",
                description: "About 1 cup (250 ml). Light cream won't work."
            )
            numberedStep(
                number: 2,
                title: "Two zip-lock bags",
                description: "Fill 60-70% full. Double-bag for leak safety."
            )
            numberedStep(
                number: 3,
                title: "Running vest or pack",
                description: "Tuck bags in. Leave slightly loose to bounce."
            )
        }
        .padding(ButterSpacing.cardPadding)
        .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: ButterSpacing.cardCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: ButterSpacing.cardCornerRadius).strokeBorder(ButterTheme.surfaceBorder, lineWidth: 1))
        .padding(.horizontal, ButterSpacing.horizontalPadding)
        .accessibilityElement(children: .combine)
    }

    private func numberedStep(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(ButterTheme.gold, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(ButterTheme.textPrimary)
                Text(description)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
            }
        }
    }

    // MARK: - Temperature + Body Heat

    private var temperatureCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("\u{1F321}\u{FE0F}")
                Text("Temperature + Body Heat")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(ButterTheme.textPrimary)
            }

            Text("Start cold — straight from the fridge. Your body heat gradually warms it toward the ideal churning temp (50-59\u{00B0}F).")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(ButterTheme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                temperatureBullet(
                    label: "Cool days (<65\u{00B0}F):",
                    detail: "No ice needed. Body heat is your friend."
                )
                temperatureBullet(
                    label: "Warm days (>72\u{00B0}F):",
                    detail: "Add an ice pack next to the bag. Use outer pocket."
                )
            }

            Text("Above 68\u{00B0}F cream temp = failure. Fat won't separate.")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(ButterTheme.deficit)
        }
        .padding(ButterSpacing.cardPadding)
        .background(ButterTheme.goldLight, in: RoundedRectangle(cornerRadius: ButterSpacing.cardCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: ButterSpacing.cardCornerRadius).strokeBorder(ButterTheme.gold, lineWidth: 1))
        .padding(.horizontal, ButterSpacing.horizontalPadding)
        .accessibilityElement(children: .combine)
    }

    private func temperatureBullet(label: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(ButterTheme.textPrimary)
            Text(detail)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)
        }
    }

    // MARK: - The 5 Stages

    private var stagesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The 5 Stages")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(ButterTheme.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                stageCell(emoji: "\u{1F4A7}", name: "Liquid", timing: "Start", highlight: false)
                stageCell(emoji: "\u{1FAE7}", name: "Foamy", timing: "~2km", highlight: false)
                stageCell(emoji: "\u{2601}\u{FE0F}", name: "Whipped", timing: "~3km", highlight: false)
                stageCell(emoji: "\u{1F538}", name: "Breaking", timing: "~5km", highlight: false)
                stageCell(emoji: "\u{1F9C8}", name: "Butter!", timing: "6-10km", highlight: true)
            }

            Text("Squeeze bag every 2-3 km. Trails churn faster than roads.")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)
        }
        .padding(ButterSpacing.cardPadding)
        .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: ButterSpacing.cardCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: ButterSpacing.cardCornerRadius).strokeBorder(ButterTheme.surfaceBorder, lineWidth: 1))
        .padding(.horizontal, ButterSpacing.horizontalPadding)
        .accessibilityElement(children: .combine)
    }

    private func stageCell(emoji: String, name: String, timing: String, highlight: Bool) -> some View {
        VStack(spacing: 4) {
            Text(emoji)
                .font(.title2)
            Text(name)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(highlight ? ButterTheme.gold : ButterTheme.textPrimary)
            Text(timing)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(highlight ? ButterTheme.goldLight : ButterTheme.background)
        )
    }

    // MARK: - Tips

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tips")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(ButterTheme.textPrimary)

            tipRow(emoji: "\u{1F9C2}", text: "Add a pinch of salt before sealing")
            tipRow(emoji: "\u{1F9CA}", text: "Freeze ice cubes with cream on warm days")
            tipRow(emoji: "\u{1F3D4}\u{FE0F}", text: "Hills and stairs speed up churning")
            tipRow(emoji: "\u{1F956}", text: "Bring bread to eat your butter at the finish")
            tipRow(emoji: "\u{23F1}\u{FE0F}", text: "Expect 45-60 min of running (6-10 km)")
            tipRow(emoji: "\u{1F321}\u{FE0F}", text: "Morning runs in cool weather work best")
        }
        .padding(ButterSpacing.cardPadding)
        .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: ButterSpacing.cardCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: ButterSpacing.cardCornerRadius).strokeBorder(ButterTheme.surfaceBorder, lineWidth: 1))
        .padding(.horizontal, ButterSpacing.horizontalPadding)
        .accessibilityElement(children: .combine)
    }

    private func tipRow(emoji: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(emoji)
                .font(.system(.caption))
            Text(text)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(ButterTheme.textPrimary)
        }
    }
}

#Preview {
    ChurnGuideView()
}
