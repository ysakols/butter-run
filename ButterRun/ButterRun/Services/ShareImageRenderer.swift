import SwiftUI
import ImageIO
import UniformTypeIdentifiers

struct ShareImageRenderer {
    @MainActor
    static func render(run: Run, usesMiles: Bool) -> UIImage? {
        let view = ShareCardContent(run: run, usesMiles: usesMiles)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0

        guard let uiImage = renderer.uiImage else { return nil }

        // Strip EXIF/GPS metadata
        return stripMetadata(from: uiImage)
    }

    /// Remove all metadata (EXIF, GPS, etc.) from the image
    private static func stripMetadata(from image: UIImage) -> UIImage? {
        guard let data = image.pngData(),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return image
        }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return image
        }

        // Write image without any metadata
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            return image
        }

        return UIImage(data: mutableData as Data)
    }
}

struct ShareCardContent: View {
    let run: Run
    let usesMiles: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("BUTTER RUN")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(ButterTheme.textPrimary)
                Spacer()
            }

            Text(String(format: "%.1f tsp", run.totalButterBurnedTsp))
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundStyle(ButterTheme.gold)

            Text("of butter melted")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(ButterTheme.textSecondary)

            HStack(spacing: 24) {
                statItem(
                    value: usesMiles
                        ? String(format: "%.2f mi", run.distanceMiles)
                        : String(format: "%.2f km", run.distanceKm),
                    label: "Distance"
                )
                statItem(value: run.formattedDuration, label: "Time")
                statItem(
                    value: formatPace(run.averagePaceSecondsPerKm, miles: usesMiles),
                    label: "Pace"
                )
            }

            if run.isButterZeroChallenge {
                HStack {
                    Text("Butter Zero Score:")
                        .font(.system(.caption, design: .rounded))
                    Text("\(run.butterZeroScore)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                }
                .foregroundStyle(ButterTheme.textSecondary)
            }

            if let churn = run.churnResult {
                let stage = ChurnStage(rawValue: churn.finalStage) ?? .liquid
                Text("Churn: \(stage.name) (\(Int(churn.finalProgress * 100))%)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(ButterTheme.gold)
            }

            Divider()
                .overlay(ButterTheme.surface)

            HStack {
                Text("#ButterRun #ButterZero")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary.opacity(0.6))
                Spacer()
                Text("butterrun.app")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary.opacity(0.6))
            }
        }
        .padding(24)
        .frame(width: 340)
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
