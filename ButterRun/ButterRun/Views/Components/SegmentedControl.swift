import SwiftUI

struct ButterSegmentedControl: View {
    @Binding var selection: Int
    let options: [String]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        selection = index
                    }
                } label: {
                    Text(option)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(selection == index ? ButterTheme.textPrimary : ButterTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selection == index
                                ? ButterTheme.surface
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .shadow(color: selection == index ? .black.opacity(0.06) : .clear, radius: 2, y: 1)
                }
            }
        }
        .padding(2)
        .background(Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Segment selector")
    }
}
