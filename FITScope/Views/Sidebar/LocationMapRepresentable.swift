/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the Software), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import MapKit
import SwiftUI

/// An `NSViewRepresentable` wrapping an `MKMapView` centred on a single
/// coordinate, with a pin at that point.
///
/// It reports the map's tile-loading lifecycle back to its host through
/// ``loadState`` — progress SwiftUI's own `Map` does not surface — so the host
/// can show a loading indicator while tiles load and an offline fallback when
/// they fail to.
struct LocationMapRepresentable: NSViewRepresentable
{
    /// The coordinate to centre on and mark.
    let coordinate: CLLocationCoordinate2D

    /// The map's tile-loading state, written from the map view's delegate.
    @Binding var loadState: LocationMapView.LoadState

    /// The initial extent shown around ``coordinate``, in metres on a side —
    /// wide enough to place the site in its surroundings without losing it.
    private static let spanMeters = 4000.0

    /// Creates the delegate coordinator that relays the loading callbacks.
    func makeCoordinator() -> Coordinator
    {
        Coordinator( self )
    }

    /// Builds the map view, centres it on the coordinate and drops the
    /// capture-location pin.
    ///
    /// - Parameter context: The representable context.
    /// - Returns: The configured map view.
    func makeNSView( context: Context ) -> MKMapView
    {
        let mapView      = MKMapView()
        mapView.delegate = context.coordinator

        mapView.setRegion( self.region, animated: false )
        mapView.setAccessibilityIdentifier( AccessibilityIdentifier.LocationMapView.map )

        let annotation        = MKPointAnnotation()
        annotation.coordinate = self.coordinate
        annotation.title      = "Capture Location"

        mapView.addAnnotation( annotation )

        return mapView
    }

    /// Re-centres the map and moves the pin when the coordinate changes.
    ///
    /// - Parameters:
    ///   - mapView: The hosted map view.
    ///   - context: The representable context.
    func updateNSView( _ mapView: MKMapView, context: Context )
    {
        guard let annotation = mapView.annotations.compactMap( { $0 as? MKPointAnnotation } ).first,
              Self.differ( annotation.coordinate, self.coordinate )
        else
        {
            return
        }

        annotation.coordinate = self.coordinate

        mapView.setRegion( self.region, animated: false )
    }

    /// The map's region: a square of ``spanMeters`` centred on the coordinate.
    private var region: MKCoordinateRegion
    {
        MKCoordinateRegion(
            center:             self.coordinate,
            latitudinalMeters:  Self.spanMeters,
            longitudinalMeters: Self.spanMeters
        )
    }

    /// Whether two coordinates differ — `CLLocationCoordinate2D` is not
    /// `Equatable`, so its components are compared directly.
    ///
    /// - Parameters:
    ///   - lhs: The first coordinate.
    ///   - rhs: The second coordinate.
    /// - Returns: `true` when the latitude or longitude differs.
    private static func differ( _ lhs: CLLocationCoordinate2D, _ rhs: CLLocationCoordinate2D ) -> Bool
    {
        lhs.latitude != rhs.latitude || lhs.longitude != rhs.longitude
    }

    /// Relays the map view's tile-loading lifecycle into the host's ``loadState``.
    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate
    {
        /// The owning representable, whose binding the callbacks write through.
        private let parent: LocationMapRepresentable

        /// Creates the coordinator.
        ///
        /// - Parameter parent: The owning representable.
        init( _ parent: LocationMapRepresentable )
        {
            self.parent = parent
        }

        /// The map began loading tiles.
        ///
        /// - Parameter mapView: The reporting map view.
        func mapViewWillStartLoadingMap( _ mapView: MKMapView )
        {
            self.update( .loading )
        }

        /// The map finished loading its tiles.
        ///
        /// - Parameter mapView: The reporting map view.
        func mapViewDidFinishLoadingMap( _ mapView: MKMapView )
        {
            self.update( .loaded )
        }

        /// The map failed to load its tiles — most commonly because the device is
        /// offline.
        ///
        /// - Parameters:
        ///   - mapView: The reporting map view.
        ///   - error:   The underlying load error.
        func mapViewDidFailLoadingMap( _ mapView: MKMapView, withError error: any Error )
        {
            self.update( .failed )
        }

        /// Writes a new state to the host on the main queue, off the current call
        /// stack, so it is never set from within a SwiftUI view-update pass.
        ///
        /// - Parameter state: The new loading state.
        private func update( _ state: LocationMapView.LoadState )
        {
            DispatchQueue.main.async
            {
                self.parent.loadState = state
            }
        }
    }
}
