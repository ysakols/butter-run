import SwiftUI
import MapKit

/// Displays a route polyline on a map. Used in both active run (live) and summary (static).
struct RunMapView: View {
    let routeCoordinates: [CLLocationCoordinate2D]
    let isLive: Bool

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            if routeCoordinates.count >= 2 {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(ButterTheme.gold, lineWidth: 4)
            }

            if let last = routeCoordinates.last, isLive {
                Annotation("", coordinate: last) {
                    Circle()
                        .fill(ButterTheme.gold)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControlVisibility(.hidden)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ButterTheme.surfaceBorder, lineWidth: 1))
    }
}

/// A compact map thumbnail for the run summary screen.
struct RunMapThumbnail: View {
    let routeData: Data?

    private var coordinates: [CLLocationCoordinate2D] {
        guard let data = routeData else { return [] }
        return LocationService.decodeRoute(data)
    }

    var body: some View {
        if coordinates.count >= 2 {
            RunMapView(routeCoordinates: coordinates, isLive: false)
                .frame(height: 200)
                .allowsHitTesting(false)
        }
    }
}
