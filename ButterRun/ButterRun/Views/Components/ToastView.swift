import SwiftUI

struct ToastView: View {
    let text: String
    let actionLabel: String?
    let onAction: (() -> Void)?
    let autoDismissSeconds: Double

    @Binding var isPresented: Bool

    init(text: String, actionLabel: String? = nil, onAction: (() -> Void)? = nil, autoDismissSeconds: Double = 8, isPresented: Binding<Bool>) {
        self.text = text
        self.actionLabel = actionLabel
        self.onAction = onAction
        self.autoDismissSeconds = autoDismissSeconds
        self._isPresented = isPresented
    }

    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            if let actionLabel, let onAction {
                Button(action: onAction) {
                    Text(actionLabel)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(ButterTheme.gold)
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(actionLabel)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(hex: "1C1C1E"))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: text)
            DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissSeconds) {
                withAnimation { isPresented = false }
            }
        }
    }
}
