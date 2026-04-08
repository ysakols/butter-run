import SwiftUI
import ImageIO
import UniformTypeIdentifiers

enum ShareCardMode {
    case story    // 9:16 (1080x1920) for TikTok/Stories
    case square   // 1:1 (1080x1080) for Instagram feed
}

struct ShareImageRenderer {
    @MainActor
    static func render(run: Run, usesMiles: Bool, mode: ShareCardMode = .story) async -> UIImage? {
        let view = ShareCardContent(run: run, usesMiles: usesMiles, mode: mode)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0

        guard let rawImage = renderer.uiImage else { return nil }

        // Convert to PNG on main actor, then strip metadata off-main using Sendable Data
        guard let pngData = rawImage.pngData() else { return rawImage }

        let strippedData = await Task.detached(priority: .userInitiated) {
            stripMetadata(from: pngData)
        }.value

        return strippedData.flatMap { UIImage(data: $0) } ?? rawImage
    }

    /// Remove all metadata (EXIF, GPS, etc.) from PNG data. Returns clean PNG data.
    private static func stripMetadata(from pngData: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(pngData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        // Write image without any metadata
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return mutableData as Data
    }
}

struct ShareCardContent: View {
    let run: Run
    let usesMiles: Bool
    let mode: ShareCardMode

    private var cardWidth: CGFloat {
        switch mode {
        case .story: return 360   // 1080px at 3x
        case .square: return 360  // 1080px at 3x
        }
    }

    private var cardHeight: CGFloat {
        switch mode {
        case .story: return 640   // 1920px at 3x
        case .square: return 360  // 1080px at 3x
        }
    }

    /// Format butter in the most shareable unit
    private var heroButterText: String {
        let tsp = run.totalButterBurnedTsp
        if tsp >= 24 {
            return String(format: "%.1f sticks", tsp / 24.0)
        } else if tsp >= 3 {
            return String(format: "%.1f tablespoons", tsp / 3.0)
        } else {
            return String(format: "%.1f pats", tsp)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: mode == .story ? 60 : 20)

            // Brand header
            VStack(spacing: 8) {
                ButterPatView(size: 56, style: .solid)

                Text("BUTTER RUN")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(ButterTheme.textPrimary)
                    .tracking(2)
            }

            Spacer(minLength: mode == .story ? 40 : 16)

            // Hero section
            VStack(spacing: 8) {
                Text("I ran off")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)

                Text(heroButterText)
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(ButterTheme.gold)
                    .minimumScaleFactor(0.7)

                Text("of butter")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
            }

            if run.isButterZeroChallenge {
                Spacer(minLength: 16)
                VStack(spacing: 4) {
                    Text(ButterFormatters.netPats(run.netButterTsp))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(ButterTheme.gold)
                    Text("net pats")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(ButterTheme.textSecondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ButterTheme.surfaceBorder, lineWidth: 1))
                .padding(.horizontal, 24)
            }

            // Churn result (when churn was active and progress is meaningful)
            if let churn = run.churnResult, churn.finalProgress >= 0.05 {
                Spacer(minLength: 12)
                let stage = ChurnStage(rawValue: churn.finalStage) ?? .liquid
                VStack(spacing: 4) {
                    if stage >= .butter {
                        Text("I made butter!")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(ButterTheme.gold)
                    } else {
                        Text("Churn: \(stage.name) (\(Int(churn.finalProgress * 100))%)")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(ButterTheme.gold)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(ButterTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ButterTheme.surfaceBorder, lineWidth: 1))
                .padding(.horizontal, 24)
            }

            Spacer(minLength: mode == .story ? 32 : 16)

            // Stats line
            let distanceStr = usesMiles
                ? String(format: "%.2f mi", run.distanceMiles)
                : String(format: "%.2f km", run.distanceKm)
            let paceStr = formatPace(run.averagePaceSecondsPerKm, miles: usesMiles)

            VStack(spacing: 4) {
                Text("\(distanceStr) \u{2022} \(run.formattedDuration)")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(ButterTheme.textPrimary)
                Text("\(paceStr) avg pace")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
            }

            Spacer(minLength: mode == .story ? 40 : 16)

            // Hashtags
            VStack(spacing: 4) {
                Text("#ButterRun")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(ButterTheme.textSecondary)
                Text("#ButterRunChallenge")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary.opacity(0.7))
            }

            Spacer(minLength: mode == .story ? 24 : 12)

            // CTA — prominent, full opacity
            VStack(spacing: 2) {
                Text("Download free:")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
                Text("butterrun.app")
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .foregroundStyle(ButterTheme.gold)
            }

            Spacer(minLength: mode == .story ? 60 : 20)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(ButterTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(ButterTheme.gold.opacity(0.3), lineWidth: 2)
        )
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(ButterTheme.textPrimary)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)
        }
    }

    private func formatPace(_ secondsPerKm: Double, miles: Bool) -> String {
        let secondsPerUnit = miles ? secondsPerKm * 1.60934 : secondsPerKm
        let mins = Int(secondsPerUnit) / 60
        let secs = Int(secondsPerUnit) % 60
        let unit = miles ? "/mi" : "/km"
        return String(format: "%d:%02d%@", mins, secs, unit)
    }
}
