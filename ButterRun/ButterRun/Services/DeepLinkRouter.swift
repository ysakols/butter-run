import Foundation
import Observation

/// Destination types supported by deep links.
enum DeepLinkDestination: Equatable {
    case run(UUID)
}

/// Parses incoming URLs and drives programmatic navigation for deep links.
///
/// URL format: `butterrun://run/{UUID}`
///
/// The router is injected into the environment as an `@Observable` object so that
/// ``MainTabView`` can switch tabs and ``RunHistoryView`` can push the target run.
@Observable
final class DeepLinkRouter {
    private static let scheme = "butterrun"

    /// The pending destination to navigate to. Views consume via ``consume()``.
    private(set) var pending: DeepLinkDestination?

    /// Attempts to parse a URL into a navigation destination.
    /// Returns `true` if the URL was recognized and a destination was set.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let destination = Self.parse(url) else { return false }
        pending = destination
        return true
    }

    /// Returns and clears the pending destination atomically.
    func consume() -> DeepLinkDestination? {
        defer { pending = nil }
        return pending
    }

    /// Builds a deep link URL for a specific run.
    static func url(forRunID id: UUID) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "run"
        components.path = "/\(id.uuidString)"
        return components.url!
    }

    /// Pure parsing function — extracts a destination from a URL without side effects.
    static func parse(_ url: URL) -> DeepLinkDestination? {
        guard url.scheme == scheme else { return nil }
        guard url.host() == "run" else { return nil }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let idString = pathComponents.first,
              let id = UUID(uuidString: idString) else {
            return nil
        }

        return .run(id)
    }
}
