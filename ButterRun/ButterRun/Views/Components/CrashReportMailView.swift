import SwiftUI
#if canImport(MessageUI)
import MessageUI
#endif

// MARK: - Crash Report Mail View

/// SwiftUI wrapper around MFMailComposeViewController for sending crash reports.
/// Falls back to clipboard copy when the device cannot send mail.
struct CrashReportMailView: UIViewControllerRepresentable {

    /// The raw text of the crash report.
    let reportText: String

    /// Called when the mail composer is dismissed (regardless of result).
    let onDismiss: () -> Void

    /// Recipient email (from LegalText / app contact info).
    private let recipient = CrashReportService.contactEmail

    // MARK: - UIViewControllerRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([recipient])
        composer.setSubject("Butter Run Crash Report - v\(Bundle.main.appVersion)")
        composer.setMessageBody(
            """
            Hi,

            Butter Run encountered a crash during my last session. \
            The crash report is attached for your review.

            Please let me know if you need any additional information.

            Thanks!
            """,
            isHTML: false
        )

        if let data = reportText.data(using: .utf8) {
            composer.addAttachmentData(data, mimeType: "text/plain", fileName: CrashReportService.crashFileName)
        }

        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    // MARK: - Coordinator

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true) { [weak self] in
                self?.onDismiss()
            }
        }
    }

    // MARK: - Helpers

    /// Whether the device is configured for sending email.
    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }
}
