import MapKit
import SwiftUI

struct MapSnapshotService {
    /// Renders a map snapshot with a route polyline overlay.
    /// Returns nil if route data is empty or snapshot fails.
    @MainActor
    static func renderSnapshot(
        routeData: Data?,
        size: CGSize = CGSize(width: 360, height: 150)
    ) async -> UIImage? {
        guard let data = routeData else { return nil }
        let coordinates = LocationService.decodeRoute(data)
        guard coordinates.count >= 2 else { return nil }

        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        let rect = polyline.boundingMapRect
        let padding = max(rect.size.width, rect.size.height) * 0.2
        let paddedRect = rect.insetBy(dx: -padding, dy: -padding)

        let options = MKMapSnapshotter.Options()
        options.mapRect = paddedRect
        options.size = size
        options.scale = 0
        options.mapType = .standard
        options.pointOfInterestFilter = .excludingAll

        let snapshotter = MKMapSnapshotter(options: options)

        do {
            let snapshot = try await snapshotter.start()
            let image = snapshot.image

            let renderer = UIGraphicsImageRenderer(size: image.size)
            return renderer.image { context in
                image.draw(at: .zero)
                let cgContext = context.cgContext
                cgContext.setStrokeColor(UIColor(ButterTheme.gold).cgColor)
                cgContext.setLineWidth(4.0)
                cgContext.setLineCap(.round)
                cgContext.setLineJoin(.round)
                let path = CGMutablePath()
                for (index, coordinate) in coordinates.enumerated() {
                    let point = snapshot.point(for: coordinate)
                    if index == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
                cgContext.addPath(path)
                cgContext.strokePath()
            }
        } catch {
            return nil
        }
    }
}
