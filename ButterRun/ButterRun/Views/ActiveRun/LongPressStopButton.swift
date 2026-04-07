import SwiftUI

struct LongPressStopButton: View {
    let onComplete: () -> Void

    @State private var isPressed = false
    @State private var progress: CGFloat = 0
    @State private var timer: Timer?
    @State private var showConfirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let holdDuration: Double = 3.0
    private let size: CGFloat = 56 // ButterSpacing.controlButtonSize

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(ButterTheme.deficit)
                .frame(width: size, height: size)

            // Progress ring (only when pressing)
            if isPressed && !reduceMotion {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ButterTheme.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: size + 6, height: size + 6)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: progress)
            }

            // Stop icon
            Image(systemName: "stop.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            // Accessibility fallback label
            if reduceMotion {
                Text("Hold to stop")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(ButterTheme.textSecondary)
                    .offset(y: 20)
            }
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.1), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        startHold()
                    }
                }
                .onEnded { _ in
                    cancelHold()
                }
        )
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .accessibilityLabel("Stop run")
        .accessibilityHint("Double-tap to confirm stopping the run")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            showConfirmation = true
        }
        .confirmationDialog("End this run?", isPresented: $showConfirmation, titleVisibility: .visible) {
            Button("End Run", role: .destructive) {
                onComplete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your run will be saved.")
        }
    }

    private func startHold() {
        isPressed = true
        progress = 0

        // Light haptic at start
        let lightFeedback = UIImpactFeedbackGenerator(style: .light)
        lightFeedback.impactOccurred()

        var firedHaptic1s = false
        var firedHaptic2s = false

        let startTime = Date()
        let newTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { t in
            let elapsed = Date().timeIntervalSince(startTime)
            progress = min(CGFloat(elapsed / holdDuration), 1.0)

            // Haptic at 1s and 2s (fire once each)
            if elapsed >= 1.0 && !firedHaptic1s {
                firedHaptic1s = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            if elapsed >= 2.0 && !firedHaptic2s {
                firedHaptic2s = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }

            // Complete at 3s — show confirmation
            if elapsed >= holdDuration {
                t.invalidate()
                self.timer = nil
                progress = 1.0
                isPressed = false
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                showConfirmation = true
            }
        }
        timer = newTimer
        RunLoop.current.add(newTimer, forMode: .common)
    }

    private func cancelHold() {
        isPressed = false
        progress = 0
        timer?.invalidate()
        timer = nil
    }
}
